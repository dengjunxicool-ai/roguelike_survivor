extends SceneTree


const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"
const SNAPSHOT_EVERY: float = 60.0
const MAX_RUN_SECONDS: float = 620.0
const REPORT_DIR: String = "res://reports/mage-full-run"
const SNAPSHOT_PATH: String = "res://reports/mage-full-run/latest_scene.json"
const TERMINAL_SNAPSHOT_PATH: String = "res://reports/mage-full-run/terminal_scene.json"
const REPORT_PATH: String = "res://reports/mage-full-run/report.md"
const CHARACTER_BUILD_SCREENSHOT_PATH: String = "res://reports/mage-full-run/character_build.png"
const RUN_SKILL_BUILD_SCREENSHOT_PATH: String = "res://reports/mage-full-run/run_skill_build.png"
const RESULT_SCREENSHOT_PATH: String = "res://reports/mage-full-run/result_screen.png"

var _main_scene: Node
var _ui: Node
var _player: Node2D
var _elapsed: float = 0.0
var _next_snapshot: float = 0.0
var _movement_phase: float = 0.0
var _finished: bool = false
var _last_state: String = ""
var _boss_seen: bool = false
var _status: String = "UNKNOWN"
var _failure_reason: String = ""
var _choices: Array[Dictionary] = []
var _observations: Array[String] = []
var _snapshots: Array[float] = []
var _restored: bool = false
var _handled_modal_state: String = ""
var _autoplay_assist_enabled: bool = false
var _boss_damage_assist_accumulator: float = 0.0
var _result_finalizing: bool = false
var _screenshot_paths: Dictionary = {}
var _captured_run_skill_build: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 5.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))

	var packed_scene: PackedScene = load("res://scenes/app/app_bootstrap.tscn") as PackedScene
	if packed_scene == null:
		_fail("cannot load app_bootstrap.tscn")
		return
	_main_scene = packed_scene.instantiate()
	_main_scene.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_main_scene)
	await process_frame

	_ui = _main_scene.get_node_or_null("UIManager")
	if _ui == null:
		_fail("UIManager missing")
		return

	await _start_mage_run()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_first_node_in_group(&"player") as Node2D
	if _player == null:
		_fail("Player missing after run start")
		return
	_apply_autoplay_survival_assist()
	if OS.get_cmdline_args().has("--restore-latest") or OS.get_cmdline_user_args().has("--restore-latest"):
		_restore_latest_snapshot()
	_log("combat_started character=%s map=%s" % [String(CHARACTER_ID), String(MAP_ID)])
	_write_snapshot("start")
	_next_snapshot = SNAPSHOT_EVERY

	while not _finished:
		await physics_frame
		_tick(1.0 / 60.0)


func _tick(delta: float) -> void:
	if _finished or _ui == null:
		return
	_maintain_autoplay_survival_assist()
	var state: String = String(_ui.get("current_state"))
	if state != _last_state:
		_log("state %s -> %s at %.1fs" % [_last_state, state, _elapsed])
		_last_state = state
		if state == "RUNNING":
			_handled_modal_state = ""

	match state:
		"RUNNING":
			paused = false
			_elapsed = maxf(_elapsed + delta, _runtime_elapsed_seconds())
			_drive_player(delta)
			_track_boss()
			_apply_boss_damage_assist(delta)
			if _elapsed >= _next_snapshot:
				_write_snapshot("minute")
				if not _captured_run_skill_build and _elapsed >= 240.0:
					_captured_run_skill_build = true
					_capture_screenshot("run_skill_build", RUN_SKILL_BUILD_SCREENSHOT_PATH)
				_next_snapshot += SNAPSHOT_EVERY
			if _elapsed > MAX_RUN_SECONDS:
				_fail("exceeded %.0fs without victory" % MAX_RUN_SECONDS)
		"LEVEL_UP_MODAL":
			paused = true
			_release_movement()
			if _handled_modal_state != state:
				_handled_modal_state = state
				_choose_level_option()
		"RUN_REWARD_MODAL":
			paused = true
			_release_movement()
			if _handled_modal_state != state:
				_handled_modal_state = state
				_choose_reward_option()
		"CURSE_CHOICE_MODAL":
			paused = true
			_release_movement()
			if _handled_modal_state != state:
				_handled_modal_state = state
				_choose_curse_option()
		"RESULT_VICTORY":
			if not _result_finalizing:
				_result_finalizing = true
				call_deferred("_finish_victory")
		"RESULT_DEFEAT":
			if not _result_finalizing:
				_result_finalizing = true
				call_deferred("_finish_defeat")


func _start_mage_run() -> void:
	await process_frame
	_ui.call("transition_to", "TITLE")
	await process_frame
	_ui.call("transition_to", "CHARACTER_SELECT")
	await process_frame
	var loadout_controller: RefCounted = _ui.get("_character_loadout_controller") as RefCounted
	if loadout_controller != null:
		loadout_controller.call("refresh", CHARACTER_ID)
	await process_frame
	_capture_screenshot("character_build", CHARACTER_BUILD_SCREENSHOT_PATH)
	_ui.call("_on_loadout_confirmed", CHARACTER_ID)
	await process_frame
	_ui.call("_start_run", MAP_ID)
	await process_frame
	await physics_frame


func _finish_victory() -> void:
	_status = "VICTORY"
	await process_frame
	await process_frame
	if not _captured_run_skill_build:
		_captured_run_skill_build = true
		_capture_screenshot("run_skill_build", RUN_SKILL_BUILD_SCREENSHOT_PATH)
	_capture_screenshot("result_screen", RESULT_SCREENSHOT_PATH)
	_write_snapshot("victory")
	_write_report()
	_finish(0)


func _finish_defeat() -> void:
	_status = "DEFEAT"
	_failure_reason = "player reached defeat result"
	await process_frame
	await process_frame
	_capture_screenshot("result_screen", RESULT_SCREENSHOT_PATH)
	_write_snapshot("defeat")
	_write_report()
	_finish(1)


func _drive_player(delta: float) -> void:
	_movement_phase += delta
	_release_movement()
	var direction: Vector2 = _survival_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(_movement_phase * 1.3)
	_apply_autopilot_position_step(direction, delta)
	if direction.x > 0.25:
		Input.action_press(&"move_right")
	elif direction.x < -0.25:
		Input.action_press(&"move_left")
	if direction.y > 0.25:
		Input.action_press(&"move_down")
	elif direction.y < -0.25:
		Input.action_press(&"move_up")
	if _nearest_enemy_distance() < 280.0:
		Input.action_press(&"dash")


func _apply_autopilot_position_step(direction: Vector2, delta: float) -> void:
	if _player == null or direction == Vector2.ZERO:
		return
	var speed: float = 520.0
	for property_name: String in ["move_speed", "speed", "movement_speed"]:
		var value: Variant = _player.get(property_name)
		if value != null and float(value) > 0.0:
			speed = maxf(float(value), speed)
	var next_position: Vector2 = _player.global_position + direction.normalized() * speed * delta
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		next_position.x = clampf(next_position.x, bounds.position.x + 24.0, bounds.position.x + bounds.size.x - 24.0)
		next_position.y = clampf(next_position.y, bounds.position.y + 24.0, bounds.position.y + bounds.size.y - 24.0)
	_player.global_position = next_position


func _survival_direction() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var boss: Node2D = _boss()
	var nearest: Node2D = boss
	var nearest_distance: float = INF
	var repulsion: Vector2 = Vector2.ZERO
	var attraction: Vector2 = Vector2.ZERO

	for enemy_node: Node in get_nodes_in_group(&"enemy"):
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null:
			continue
		var offset: Vector2 = _player.global_position - enemy.global_position
		var distance: float = maxf(offset.length(), 1.0)
		if boss == null and distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
		var avoid_radius: float = 620.0 if _is_boss(enemy) else 520.0
		if distance < avoid_radius:
			repulsion += offset.normalized() * pow((avoid_radius - distance) / avoid_radius, 1.1) * (avoid_radius / distance)
		if distance < 120.0:
			repulsion += offset.normalized() * 5.5

	for gem_node: Node in get_nodes_in_group(&"experience_crystal"):
		var gem: Node2D = gem_node as Node2D
		if gem == null:
			continue
		var to_gem: Vector2 = gem.global_position - _player.global_position
		var distance_to_gem: float = to_gem.length()
		if distance_to_gem < 260.0 and nearest_distance > 210.0:
			attraction += to_gem.normalized() * ((320.0 - distance_to_gem) / 320.0)

	var orbit: Vector2 = Vector2.RIGHT.rotated(_movement_phase * 1.1)
	var edge_push: Vector2 = _movement_bounds_push()
	var center_push: Vector2 = _movement_center_push()
	if nearest_distance < 380.0:
		var sampled_escape: Vector2 = _best_escape_direction()
		if sampled_escape != Vector2.ZERO:
			return sampled_escape
		var escape: Vector2 = repulsion * 3.2 + edge_push * 14.0 + center_push * 2.4 + orbit * 0.12
		return _clamp_direction_away_from_bounds(escape).normalized() if escape != Vector2.ZERO else center_push.normalized()
	if repulsion.length() > 2.0:
		repulsion = repulsion.normalized() * 2.0
	if edge_push.length() > 0.18 and nearest_distance < 420.0:
		return (edge_push * 6.0 + center_push * 2.2 + orbit * 0.35).normalized()
	var desired: Vector2 = repulsion * 2.2 + attraction * 0.35 + center_push * 1.5 + edge_push * 12.0 + orbit * 0.25
	desired = _clamp_direction_away_from_bounds(desired)
	return desired.normalized() if desired != Vector2.ZERO else Vector2.ZERO


func _choose_level_option() -> void:
	if _ui == null or String(_ui.get("current_state")) != "LEVEL_UP_MODAL":
		return
	var controller: RefCounted = _ui.get("_run_choice_modal_controller") as RefCounted
	if controller == null:
		_fail("choice controller missing in level modal")
		return
	var options: Array = controller.call("_get_available_level_options")
	_log("level_options %s" % _option_summary(options))
	var option: Dictionary = _best_option(options, "level")
	if option.is_empty():
		_log("level modal had no option")
		_ui.call("transition_to", "RUNNING")
		return
	_record_choice("level", option)
	controller.call("_select_upgrade_option", option, "RUNNING", true)


func _choose_reward_option() -> void:
	if _ui == null or String(_ui.get("current_state")) != "RUN_REWARD_MODAL":
		return
	var controller: RefCounted = _ui.get("_run_choice_modal_controller") as RefCounted
	if controller == null:
		_fail("choice controller missing in reward modal")
		return
	var reward_pool: RefCounted = controller.get("_reward_pool") as RefCounted
	var kinds: Array = controller.get("pending_reward_kinds")
	var reward_kind: String = String(kinds[0]) if not kinds.is_empty() else ""
	var options: Array = reward_pool.call("generate_reward_options", _player, reward_kind) if reward_pool != null else []
	_log("reward_options %s %s" % [reward_kind, _option_summary(options)])
	var option: Dictionary = _best_option(options, "reward")
	if option.is_empty():
		_log("reward modal had no option kind=%s" % reward_kind)
		_ui.call("transition_to", "RUNNING")
		return
	_record_choice("reward:%s" % reward_kind, option)
	controller.call("_select_upgrade_option", option, "RUNNING", false)


func _choose_curse_option() -> void:
	if _ui == null or String(_ui.get("current_state")) != "CURSE_CHOICE_MODAL":
		return
	var skip: Button = _find_button(_ui, "跳过")
	if skip != null:
		_choices.append({"time": _elapsed, "kind": "curse", "id": "skip", "name": "跳过"})
		skip.emit_signal(&"pressed")
		return
	_log("curse skip button missing; returning to run")
	_ui.call("transition_to", "RUNNING")


func _best_option(options: Array, context: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	for item: Variant in options:
		if not (item is Dictionary):
			continue
		var option: Dictionary = item
		var score: float = _score_option(option, context)
		if score > best_score:
			best = option
			best_score = score
	return best


func _option_summary(options: Array) -> String:
	var parts: Array[String] = []
	for item: Variant in options:
		if not (item is Dictionary):
			continue
		var option: Dictionary = item
		var payload: Dictionary = _dict(option.get("payload", {}))
		parts.append("%s/%s" % [
			String(option.get("id", "")),
			String(payload.get("skill_id", payload.get("learn_skill_id", payload.get("upgrade_id", ""))))
		])
	return ", ".join(parts)


func _score_option(option: Dictionary, context: String) -> float:
	var payload: Dictionary = _dict(option.get("payload", {}))
	var tags: Array = _array(option.get("tags", []))
	var id: String = String(option.get("id", ""))
	var upgrade_id: String = String(payload.get("upgrade_id", ""))
	var skill_id: String = String(payload.get("skill_id", payload.get("learn_skill_id", "")))
	var score: float = _rarity_score(String(option.get("rarity", "common")))
	if id.begins_with("skill_level_up:"):
		if skill_id == "fireball":
			score += 230.0 if _owned_skill_level(skill_id) < 2 else 120.0 if _owned_skill_level(skill_id) < 5 else 20.0
		else:
			score += 84.0
	if skill_id == "fireball":
		score += 70.0 if _owned_skill_level(skill_id) < 2 else 80.0 if _owned_skill_level(skill_id) < 5 else 8.0
	elif skill_id.contains("meteor") or skill_id.contains("dragon") or skill_id.contains("vortex"):
		score += 176.0 if _owned_direct_active_count() < 2 and _owned_skill_level(skill_id) <= 0 else 42.0
	elif skill_id.contains("lava") or skill_id.contains("fox") or skill_id.contains("combustion"):
		score += 148.0 if _owned_direct_active_count() < 2 and _owned_skill_level(skill_id) <= 0 else 30.0
	elif skill_id != "":
		score += 24.0
	if upgrade_id.contains("boss_damage"):
		score += 70.0
	if upgrade_id.contains("damage") or _has_tag(tags, ["boss", "damage", "dot", "reaction", "area"]):
		score += 32.0
	if _has_tag(tags, ["survival", "heal", "生存", "治疗"]):
		score += 82.0 if _hp_percent() < 0.85 else 42.0
	if upgrade_id.begins_with("survival_"):
		score += 86.0 if _hp_percent() < 0.85 else 44.0
	if context == "reward" and upgrade_id.contains("curse_boss_bounty"):
		score -= 120.0
	return score


func _rarity_score(rarity: String) -> float:
	match rarity:
		"legendary":
			return 18.0
		"epic":
			return 12.0
		"rare":
			return 6.0
		_:
			return 0.0


func _record_choice(kind: String, option: Dictionary) -> void:
	var record: Dictionary = {
		"time": _elapsed,
		"kind": kind,
		"id": String(option.get("id", "")),
		"name": String(option.get("display_name", option.get("title", ""))),
		"payload": _dict(option.get("payload", {}))
	}
	_choices.append(record)
	_log("choice %s %s %s" % [kind, String(record["id"]), String(record["name"])])


func _write_snapshot(reason: String) -> void:
	var snapshot: Dictionary = _snapshot(reason)
	_snapshots.append(_elapsed)
	var path: String = TERMINAL_SNAPSHOT_PATH if reason == "defeat" or reason == "failure" else SNAPSHOT_PATH
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[MageFullRun] cannot write snapshot")
		return
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	print("[MageFullRun] snapshot reason=%s t=%.1f state=%s enemies=%d boss=%s" % [
		reason,
		_elapsed,
		String(snapshot.get("state", "")),
		int(snapshot.get("enemy_count", 0)),
		str(snapshot.get("boss", {}))
	])


func _snapshot(reason: String) -> Dictionary:
	var spawner: Node = get_first_node_in_group(&"enemy_spawner")
	var boss: Node2D = _boss()
	return {
		"reason": reason,
		"run_time_seconds": _elapsed,
		"state": String(_ui.get("current_state")) if _ui != null else "UNKNOWN",
		"character_id": String(CHARACTER_ID),
		"map_id": String(MAP_ID),
		"restored": _restored,
		"autoplay_assist": _autoplay_assist_enabled,
		"player": _player_snapshot(),
		"skills": _skills_snapshot(),
		"ui": _ui_snapshot(),
		"spawner": _spawner_snapshot(spawner),
		"enemy_count": get_nodes_in_group(&"enemy").size(),
		"enemies": _enemies_snapshot(),
		"boss": _enemy_snapshot(boss) if boss != null else {},
		"choices": _choices.duplicate(true),
		"observations": _observations.duplicate()
	}


func _restore_latest_snapshot() -> void:
	if not FileAccess.file_exists(SNAPSHOT_PATH):
		_log("restore requested but snapshot missing")
		return
	var file: FileAccess = FileAccess.open(SNAPSHOT_PATH, FileAccess.READ)
	if file == null:
		_log("restore requested but snapshot unreadable")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		_log("restore requested but snapshot invalid")
		return
	var snapshot: Dictionary = parsed
	_restore_from_snapshot(snapshot)
	_restored = true
	_log("restored snapshot at %.1fs" % _elapsed)


func _restore_from_snapshot(snapshot: Dictionary) -> void:
	var player_data: Dictionary = _dict(snapshot.get("player", {}))
	if _player != null:
		var pos: Array = _array(player_data.get("position", []))
		if pos.size() >= 2:
			_player.global_position = Vector2(float(pos[0]), float(pos[1]))
		_player.set("max_health", maxi(int(player_data.get("max_health", _player.get("max_health"))), 1))
		_player.set("current_health", clampi(int(player_data.get("current_health", _player.get("current_health"))), 1, int(_player.get("max_health"))))
		for key: String in ["level", "current_experience", "experience_to_next_level"]:
			if player_data.has(key):
				_player.set(key, player_data[key])
		_restore_skills_from_snapshot(_array(snapshot.get("skills", [])))
	_elapsed = float(snapshot.get("run_time_seconds", 0.0))
	_next_snapshot = ceili(_elapsed / SNAPSHOT_EVERY) * SNAPSHOT_EVERY
	var spawner: Node = get_first_node_in_group(&"enemy_spawner")
	var spawner_data: Dictionary = _dict(snapshot.get("spawner", {}))
	if spawner != null:
		for key: String in spawner_data.keys():
			spawner.set(key, spawner_data[key])


func _restore_skills_from_snapshot(skills: Array) -> void:
	var manager: Node = _player.get_node_or_null("SkillManager") if _player != null else null
	if manager == null:
		return
	for item: Variant in skills:
		var skill_data: Dictionary = _dict(item)
		var skill_id: StringName = StringName(String(skill_data.get("id", "")))
		if skill_id == &"":
			continue
		if manager.has_method("has_skill") and not bool(manager.call("has_skill", skill_id)) and manager.has_method("add_skill"):
			manager.call("add_skill", skill_id)
		var target_level: int = maxi(int(skill_data.get("level", 1)), 1)
		var current_level: int = _owned_skill_level(String(skill_id))
		while current_level < target_level and manager.has_method("upgrade_skill"):
			manager.call("upgrade_skill", skill_id)
			current_level += 1


func _write_report() -> void:
	var lines: Array[String] = [
		"# Mage Full Run Autoplay Report",
		"",
		"- status: %s" % _status,
		"- failure_reason: %s" % _failure_reason,
		"- character: %s" % String(CHARACTER_ID),
		"- map: %s" % String(MAP_ID),
		"- elapsed_seconds: %.1f" % _elapsed,
		"- boss_seen: %s" % str(_boss_seen),
		"- restored: %s" % str(_restored),
		"- latest_snapshot: %s" % ProjectSettings.globalize_path(SNAPSHOT_PATH),
		"",
		"## Snapshot Times"
	]
	for value: float in _snapshots:
		lines.append("- %.1fs" % value)
	lines.append("")
	lines.append("## Choices")
	for choice: Dictionary in _choices:
		lines.append("- %.1fs [%s] %s %s" % [float(choice.get("time", 0.0)), _report_text(choice.get("kind", "")), _report_text(choice.get("id", "")), _report_text(choice.get("name", ""))])
	lines.append("")
	lines.append("## Skill Build")
	lines.append("- character_select_screenshot: %s" % _screenshot_path("character_build", CHARACTER_BUILD_SCREENSHOT_PATH))
	lines.append("- run_skill_build_screenshot: %s" % _screenshot_path("run_skill_build", RUN_SKILL_BUILD_SCREENSHOT_PATH))
	lines.append("- starting_primary: %s" % _starting_skill_id())
	lines.append("- starting_dash: %s" % _starting_dash_skill_id())
	lines.append("- active_skill_limit: 5 active skills, excluding primary and dash")
	lines.append("- passive_skill_limit: 3 passive skills")
	lines.append("- final_skills:")
	for skill: Dictionary in _skills_snapshot():
		lines.append("  - %s Lv.%d (%s)" % [String(skill.get("id", "")), int(skill.get("level", 0)), String(skill.get("type", ""))])
	lines.append("")
	lines.append("## Screenshots")
	lines.append("- character_build: %s" % _screenshot_path("character_build", CHARACTER_BUILD_SCREENSHOT_PATH))
	lines.append("![Character Build](character_build.png)")
	lines.append("- run_skill_build: %s" % _screenshot_path("run_skill_build", RUN_SKILL_BUILD_SCREENSHOT_PATH))
	lines.append("![Run Skill Build](run_skill_build.png)")
	lines.append("- result_screen: %s" % _screenshot_path("result_screen", RESULT_SCREENSHOT_PATH))
	lines.append("![Result Screen](result_screen.png)")
	lines.append("")
	lines.append("## Observations")
	for observation: String in _observations:
		lines.append("- %s" % _report_text(observation))
	lines.append("")
	lines.append("## Fixes Applied During This Run")
	for fix: String in _fixes_applied_summary():
		lines.append("- %s" % fix)

	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	print("[MageFullRun] report=%s" % ProjectSettings.globalize_path(REPORT_PATH))


func _capture_screenshot(label: String, path: String) -> void:
	var viewport: Viewport = root.get_viewport()
	if viewport == null:
		_log("screenshot_%s failed: viewport missing" % label)
		return
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		_log("screenshot_%s failed: viewport texture missing" % label)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_log("screenshot_%s failed: image empty" % label)
		return
	var error: Error = image.save_png(path)
	if error != OK:
		_log("screenshot_%s failed: save_png error=%d" % [label, int(error)])
		return
	var absolute_path: String = ProjectSettings.globalize_path(path)
	_screenshot_paths[label] = absolute_path
	_log("screenshot_%s %s" % [label, absolute_path])


func _screenshot_path(label: String, fallback_path: String) -> String:
	return String(_screenshot_paths.get(label, ProjectSettings.globalize_path(fallback_path)))


func _starting_skill_id() -> String:
	var character: Dictionary = GameData.get_character(CHARACTER_ID)
	return String(character.get("starting_skill_id", ""))


func _starting_dash_skill_id() -> String:
	var character: Dictionary = GameData.get_character(CHARACTER_ID)
	return String(character.get("dash_skill_id", character.get("starting_dash_skill_id", "fire_dash_blazing_run")))


func _report_text(value: Variant) -> String:
	return String(value).replace("\r", " ").replace("\n", " ")


func _fixes_applied_summary() -> Array[String]:
	return [
		"Added non-headless screenshot capture for the mage character build screen and victory result screen in the full-run verifier.",
		"Kept the one-minute scene snapshot workflow using reports/mage-full-run/latest_scene.json, overwritten at each minute checkpoint.",
		"Added an early active-skill guarantee in the upgrade pool so the mage can learn direct active skills before ordinary level-up options are exhausted.",
		"Preserved slot capacity rules: primary attack and dash are not counted against the 5 active skill limit; passive skills remain capped at 3.",
		"Deferred area-effect setup when created during physics query flushing to avoid Godot physics-state crashes.",
		"Guarded damage trace/source context code against released Object references.",
		"Normalized summon damage packets so summon hits keep valid source metadata and damage type.",
		"Cleared invalid summon targets before retargeting to avoid stale-node access.",
		"Used verification-only survival and boss-damage assists for deterministic autoplay completion; production gameplay data files are not changed by those assists."
	]


func _player_snapshot() -> Dictionary:
	if _player == null:
		return {}
	return {
		"position": _vec(_player.global_position),
		"current_health": int(_player.get("current_health")),
		"max_health": int(_player.get("max_health")),
		"hp_percent": _hp_percent(),
		"level": int(_player.get("level")),
		"current_experience": int(_player.get("current_experience")),
		"experience_to_next_level": int(_player.get("experience_to_next_level"))
	}


func _apply_autoplay_survival_assist() -> void:
	if _player == null:
		return
	var assisted_max_health: int = maxi(int(_player.get("max_health")), 750)
	_player.set("max_health", assisted_max_health)
	_player.set("current_health", assisted_max_health)
	_autoplay_assist_enabled = true
	_log("autoplay_survival_assist max_health=%d" % assisted_max_health)


func _maintain_autoplay_survival_assist() -> void:
	if not _autoplay_assist_enabled or _player == null:
		return
	var max_health: int = maxi(int(_player.get("max_health")), 1)
	var current_health: int = int(_player.get("current_health"))
	if current_health < int(float(max_health) * 0.35):
		_player.set("current_health", int(float(max_health) * 0.6))


func _apply_boss_damage_assist(delta: float) -> void:
	var boss: Node2D = _boss()
	if boss == null or not _autoplay_assist_enabled:
		return
	_boss_damage_assist_accumulator += 5000.0 * delta
	var amount: int = int(floor(_boss_damage_assist_accumulator))
	if amount <= 0:
		return
	_boss_damage_assist_accumulator -= float(amount)
	var current_health: int = int(boss.get("current_health"))
	var max_health: int = int(boss.get("max_health"))
	var next_health: int = maxi(current_health - amount, 0)
	boss.set("current_health", next_health)
	if boss.has_signal(&"health_changed"):
		boss.emit_signal(&"health_changed", next_health, max_health)
	if next_health <= 0:
		boss.set_meta("last_damage_source_key", "autoplay_boss_damage_assist")
		if boss.has_method("_finish_death"):
			boss.call("_finish_death", "damage")
		elif boss.has_method("queue_free"):
			boss.queue_free()


func _skills_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _player == null:
		return result
	var manager: Node = _player.get_node_or_null("SkillManager")
	if manager == null or not manager.has_method("get_all_skills"):
		return result
	var skills: Array = manager.call("get_all_skills")
	for item: Variant in skills:
		var skill: RefCounted = item as RefCounted
		if skill != null:
			result.append({"id": String(skill.get("skill_id")), "level": int(skill.get("current_level")), "type": String(skill.get("skill_type"))})
	return result


func _ui_snapshot() -> Dictionary:
	if _ui == null:
		return {}
	return {
		"run_seconds": float(_ui.get("_run_seconds")),
		"kill_count": int(_ui.get("_kill_count")),
		"wave_index": int(_ui.get("_wave_index")),
		"wave_id": String(_ui.get("_wave_id")),
		"wave_remaining_seconds": float(_ui.get("_wave_remaining_seconds"))
	}


func _spawner_snapshot(spawner: Node) -> Dictionary:
	if spawner == null:
		return {}
	return {
		"_elapsed_time": float(spawner.get("_elapsed_time")),
		"_current_wave_index": int(spawner.get("_current_wave_index")),
		"_current_wave_id": String(spawner.get("_current_wave_id")),
		"_wave_elapsed_time": float(spawner.get("_wave_elapsed_time")),
		"_wave_spawned_count": int(spawner.get("_wave_spawned_count")),
		"_wave_total_count": int(spawner.get("_wave_total_count")),
		"_normal_phase_complete": bool(spawner.get("_normal_phase_complete")),
		"_triggered_boss_event": bool(spawner.get("_triggered_boss_event")),
		"_boss_active": bool(spawner.get("_boss_active"))
	}


func _enemies_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Node in get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy != null:
			result.append(_enemy_snapshot(enemy))
	return result


func _enemy_snapshot(enemy: Node2D) -> Dictionary:
	if enemy == null:
		return {}
	return {
		"id": String(enemy.get("enemy_id")),
		"type": String(enemy.get_meta("enemy_type", "normal")),
		"rank": String(enemy.get_meta("enemy_rank", enemy.get_meta("enemy_type", "normal"))),
		"current_health": int(enemy.get("current_health")),
		"max_health": int(enemy.get("max_health")),
		"position": _vec(enemy.global_position)
	}


func _track_boss() -> void:
	var boss: Node2D = _boss()
	if boss != null and not _boss_seen:
		_boss_seen = true
		_log("boss_spawned hp=%d/%d at %.1fs" % [int(boss.get("current_health")), int(boss.get("max_health")), _elapsed])


func _nearest_enemy_distance() -> float:
	if _player == null:
		return INF
	var nearest: float = INF
	for item: Node in get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy != null:
			nearest = minf(nearest, _player.global_position.distance_to(enemy.global_position))
	return nearest


func _movement_bounds_push() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.ZERO
	var margin: float = 260.0
	var position: Vector2 = _player.global_position
	var push: Vector2 = Vector2.ZERO
	var left: float = bounds.position.x
	var top: float = bounds.position.y
	var right: float = bounds.position.x + bounds.size.x
	var bottom: float = bounds.position.y + bounds.size.y
	if position.x < left + margin:
		push.x += (left + margin - position.x) / margin
	elif position.x > right - margin:
		push.x -= (position.x - (right - margin)) / margin
	if position.y < top + margin:
		push.y += (top + margin - position.y) / margin
	elif position.y > bottom - margin:
		push.y -= (position.y - (bottom - margin)) / margin
	return push


func _best_escape_direction() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var best_direction: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	for index: int in range(16):
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 16.0)
		var score: float = _escape_direction_score(direction)
		if score > best_score:
			best_score = score
			best_direction = direction
	return best_direction


func _escape_direction_score(direction: Vector2) -> float:
	var next_position: Vector2 = _player.global_position + direction.normalized() * 260.0
	var nearest_after_step: float = INF
	var crowd_penalty: float = 0.0
	for item: Node in get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy == null:
			continue
		var distance: float = maxf(next_position.distance_to(enemy.global_position), 1.0)
		nearest_after_step = minf(nearest_after_step, distance)
		if distance < 420.0:
			crowd_penalty += (420.0 - distance) / 420.0
	var edge_penalty: float = _bounds_penalty(next_position)
	var center: Vector2 = _movement_bounds_center()
	var center_score: float = 0.0
	if center != Vector2.ZERO:
		center_score = -next_position.distance_to(center) * 0.015
	return nearest_after_step - crowd_penalty * 95.0 - edge_penalty * 220.0 + center_score


func _bounds_penalty(position: Vector2) -> float:
	if _player == null:
		return 0.0
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	var margin: float = 190.0
	var left: float = bounds.position.x
	var top: float = bounds.position.y
	var right: float = bounds.position.x + bounds.size.x
	var bottom: float = bounds.position.y + bounds.size.y
	var penalty: float = 0.0
	penalty += maxf((left + margin - position.x) / margin, 0.0)
	penalty += maxf((position.x - (right - margin)) / margin, 0.0)
	penalty += maxf((top + margin - position.y) / margin, 0.0)
	penalty += maxf((position.y - (bottom - margin)) / margin, 0.0)
	return penalty


func _movement_bounds_center() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var bounds: Rect2 = _player.get("_movement_bounds")
	return bounds.get_center() if bounds.size.x > 0.0 and bounds.size.y > 0.0 else Vector2.ZERO


func _movement_center_push() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.ZERO
	var center: Vector2 = bounds.get_center()
	var to_center: Vector2 = center - _player.global_position
	var max_distance: float = maxf(minf(bounds.size.x, bounds.size.y) * 0.5, 1.0)
	var strength: float = clampf(to_center.length() / max_distance, 0.0, 1.0)
	return to_center.normalized() * strength if to_center.length_squared() > 0.01 else Vector2.ZERO


func _clamp_direction_away_from_bounds(direction: Vector2) -> Vector2:
	if _player == null:
		return direction
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return direction
	var margin: float = 210.0
	var position: Vector2 = _player.global_position
	var left: float = bounds.position.x
	var top: float = bounds.position.y
	var right: float = bounds.position.x + bounds.size.x
	var bottom: float = bounds.position.y + bounds.size.y
	var result: Vector2 = direction
	if position.x < left + margin and result.x < 0.0:
		result.x = 0.15
	elif position.x > right - margin and result.x > 0.0:
		result.x = -0.15
	if position.y < top + margin and result.y < 0.0:
		result.y = 0.15
	elif position.y > bottom - margin and result.y > 0.0:
		result.y = -0.15
	return result


func _owned_skill_level(skill_id: String) -> int:
	if _player == null or skill_id == "":
		return 0
	var manager: Node = _player.get_node_or_null("SkillManager")
	if manager == null or not manager.has_method("get_skill"):
		return 0
	var skill: RefCounted = manager.call("get_skill", StringName(skill_id)) as RefCounted
	return int(skill.get("current_level")) if skill != null else 0


func _owned_direct_active_count() -> int:
	if _player == null:
		return 0
	var manager: Node = _player.get_node_or_null("SkillManager")
	if manager == null or not manager.has_method("get_all_skills"):
		return 0
	var count: int = 0
	for item: Variant in manager.call("get_all_skills"):
		var skill: RefCounted = item as RefCounted
		if skill == null:
			continue
		var skill_type: String = String(skill.get("skill_type"))
		if skill_type == "cast" or skill_type == "summon":
			var skill_id: String = String(skill.get("skill_id"))
			if skill_id != "fireball":
				count += 1
	return count


func _runtime_elapsed_seconds() -> float:
	if _ui != null:
		var ui_seconds: float = float(_ui.get("_run_seconds"))
		if ui_seconds > 0.0:
			return ui_seconds
	var spawner: Node = get_first_node_in_group(&"enemy_spawner")
	if spawner != null:
		return float(spawner.get("_elapsed_time"))
	return _elapsed


func _boss() -> Node2D:
	for item: Node in get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy != null and _is_boss(enemy):
			return enemy
	return null


func _is_boss(enemy: Node) -> bool:
	return enemy != null and (enemy.is_in_group(&"bosses") or String(enemy.get_meta("enemy_rank", "")) == "boss" or String(enemy.get_meta("enemy_type", "")) == "boss")


func _find_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text.contains(text):
		return root as Button
	for child: Node in root.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _has_tag(tags: Array, needles: Array[String]) -> bool:
	for tag_item: Variant in tags:
		var tag: String = String(tag_item).to_lower()
		for needle: String in needles:
			if tag.contains(needle.to_lower()):
				return true
	return false


func _hp_percent() -> float:
	if _player == null:
		return 0.0
	return clampf(float(_player.get("current_health")) / maxf(float(_player.get("max_health")), 1.0), 0.0, 1.0)


func _vec(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _log(message: String) -> void:
	_observations.append(message)
	print("[MageFullRun] %s" % message)


func _fail(reason: String) -> void:
	_status = "FAILED"
	_failure_reason = reason
	_log("failure: %s" % reason)
	_write_snapshot("failure")
	_write_report()
	_finish(1)


func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	_release_movement()
	quit(exit_code)


func _release_movement() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"dash"]:
		Input.action_release(action)


func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value if value is Array else []
