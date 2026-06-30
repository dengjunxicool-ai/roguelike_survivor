extends SceneTree


const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"
const RUN_SECONDS: float = 180.0
const SAMPLE_INTERVAL_SECONDS: float = 5.0
const REPORT_DIR: String = "res://reports/performance-run"
const SAMPLES_PATH: String = "res://reports/performance-run/latest_samples.json"
const REPORT_PATH: String = "res://reports/performance-run/report.md"

var _main_scene: Node
var _ui: Node
var _player: Node2D
var _elapsed: float = 0.0
var _next_sample: float = 0.0
var _movement_phase: float = 0.0
var _finished: bool = false
var _handled_modal_state: String = ""
var _samples: Array[Dictionary] = []
var _frame_ms_values: Array[float] = []
var _max_frame_ms: float = 0.0
var _spike_33ms_count: int = 0
var _spike_50ms_count: int = 0
var _last_tick_usec: int = 0
var _failure_reason: String = ""
var _run_seconds: float = RUN_SECONDS


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 1.0
	_run_seconds = _get_duration_arg(RUN_SECONDS)
	if OS.get_cmdline_user_args().has("--disable-player-attack"):
		root.set_meta("debug_player_attack_disabled", true)
	if OS.get_cmdline_user_args().has("--profile-enemy"):
		root.set_meta("profile_enemy_physics", true)
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
	await _start_run()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_first_node_in_group(&"player") as Node2D
	if _player == null:
		_fail("Player missing after run start")
		return
	_apply_autoplay_survival_assist()
	print("[PerformanceRun] started character=%s map=%s duration=%.0fs" % [String(CHARACTER_ID), String(MAP_ID), _run_seconds])
	_last_tick_usec = Time.get_ticks_usec()
	_next_sample = 0.0
	while not _finished:
		await process_frame
		_tick()


func _tick() -> void:
	var now_usec: int = Time.get_ticks_usec()
	var frame_ms: float = float(now_usec - _last_tick_usec) / 1000.0
	_last_tick_usec = now_usec
	if frame_ms > 0.0 and frame_ms < 1000.0:
		_frame_ms_values.append(frame_ms)
		_max_frame_ms = maxf(_max_frame_ms, frame_ms)
		if frame_ms >= 33.333:
			_spike_33ms_count += 1
		if frame_ms >= 50.0:
			_spike_50ms_count += 1
	if _ui == null:
		return
	var state: String = String(_ui.get("current_state"))
	match state:
		"RUNNING":
			paused = false
			var delta_seconds: float = frame_ms / 1000.0
			_elapsed = maxf(_elapsed + delta_seconds, _runtime_elapsed_seconds())
			_maintain_autoplay_survival_assist()
			_drive_player(delta_seconds)
			if _elapsed >= _next_sample:
				_record_sample("interval")
				_next_sample += SAMPLE_INTERVAL_SECONDS
			if _elapsed >= _run_seconds:
				_record_sample("finished")
				_write_outputs("PASS")
				_finish(0)
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
		"RESULT_DEFEAT", "RESULT_VICTORY":
			_record_sample("ended_early")
			_failure_reason = "run ended early in state %s" % state
			_write_outputs("ENDED_EARLY")
			_finish(1)
		_:
			_release_movement()


func _start_run() -> void:
	await process_frame
	_ui.call("transition_to", "TITLE")
	await process_frame
	_ui.call("transition_to", "CHARACTER_SELECT")
	await process_frame
	var loadout_controller: RefCounted = _ui.get("_character_loadout_controller") as RefCounted
	if loadout_controller != null:
		loadout_controller.call("refresh", CHARACTER_ID)
	await process_frame
	_ui.call("_on_loadout_confirmed", CHARACTER_ID)
	await process_frame
	_ui.call("_start_run", MAP_ID)
	await process_frame
	await physics_frame


func _drive_player(delta: float) -> void:
	_movement_phase += delta
	_release_movement()
	var direction: Vector2 = _survival_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(_movement_phase * 1.3)
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


func _survival_direction() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var repulsion: Vector2 = Vector2.ZERO
	var attraction: Vector2 = Vector2.ZERO
	var nearest_distance: float = INF
	for enemy_node: Node in get_nodes_in_group(&"enemy"):
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null:
			continue
		var offset: Vector2 = _player.global_position - enemy.global_position
		var distance: float = maxf(offset.length(), 1.0)
		nearest_distance = minf(nearest_distance, distance)
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
	var center_push: Vector2 = _movement_center_push()
	var edge_push: Vector2 = _movement_bounds_push()
	var desired: Vector2 = repulsion * 2.4 + attraction * 0.35 + center_push * 1.7 + edge_push * 12.0 + orbit * 0.25
	return desired.normalized() if desired != Vector2.ZERO else Vector2.ZERO


func _choose_level_option() -> void:
	var controller: RefCounted = _ui.get("_run_choice_modal_controller") as RefCounted
	if controller == null:
		_ui.call("transition_to", "RUNNING")
		return
	var options: Array = controller.call("_get_available_level_options")
	var option: Dictionary = _best_option(options)
	if option.is_empty():
		_ui.call("transition_to", "RUNNING")
		return
	controller.call("_select_upgrade_option", option, "RUNNING", true)
	_handled_modal_state = ""


func _choose_reward_option() -> void:
	var controller: RefCounted = _ui.get("_run_choice_modal_controller") as RefCounted
	if controller == null:
		_ui.call("transition_to", "RUNNING")
		return
	var reward_pool: RefCounted = controller.get("_reward_pool") as RefCounted
	var kinds: Array = controller.get("pending_reward_kinds")
	var reward_kind: String = String(kinds[0]) if not kinds.is_empty() else ""
	var options: Array = reward_pool.call("generate_reward_options", _player, reward_kind) if reward_pool != null else []
	var option: Dictionary = _best_option(options)
	if option.is_empty():
		_ui.call("transition_to", "RUNNING")
		return
	controller.call("_select_upgrade_option", option, "RUNNING", false)
	_handled_modal_state = ""


func _choose_curse_option() -> void:
	var skip: Button = _find_button(_ui, "跳过")
	if skip == null:
		skip = _find_button(_ui, "璺宠繃")
	if skip != null:
		skip.emit_signal(&"pressed")
	else:
		_ui.call("transition_to", "RUNNING")
	_handled_modal_state = ""


func _best_option(options: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	for item: Variant in options:
		if not (item is Dictionary):
			continue
		var option: Dictionary = item
		var score: float = _score_option(option)
		if score > best_score:
			best = option
			best_score = score
	return best


func _score_option(option: Dictionary) -> float:
	var payload: Dictionary = _dict(option.get("payload", {}))
	var tags: Array = _array(option.get("tags", []))
	var id: String = String(option.get("id", ""))
	var upgrade_id: String = String(payload.get("upgrade_id", ""))
	var skill_id: String = String(payload.get("skill_id", payload.get("learn_skill_id", "")))
	var score: float = _rarity_score(String(option.get("rarity", "common")))
	if id.begins_with("skill_level_up:"):
		score += 100.0
	if skill_id == "fireball":
		score += 80.0
	elif skill_id.contains("meteor") or skill_id.contains("dragon") or skill_id.contains("vortex") or skill_id.contains("lava"):
		score += 140.0
	elif skill_id != "":
		score += 32.0
	if upgrade_id.contains("damage") or _has_tag(tags, ["boss", "damage", "dot", "reaction", "area"]):
		score += 30.0
	if upgrade_id.begins_with("survival_") or _has_tag(tags, ["survival", "heal", "生存", "治疗"]):
		score += 70.0
	return score


func _record_sample(reason: String) -> void:
	var sample: Dictionary = {
		"reason": reason,
		"elapsed_seconds": _elapsed,
		"fps": Engine.get_frames_per_second(),
		"avg_frame_ms": _average(_frame_ms_values),
		"p95_frame_ms": _percentile(_frame_ms_values, 0.95),
		"p99_frame_ms": _percentile(_frame_ms_values, 0.99),
		"max_frame_ms": _max_frame_ms,
		"spike_33ms_count": _spike_33ms_count,
		"spike_50ms_count": _spike_50ms_count,
		"process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
		"physics_process_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"enemy_count": get_nodes_in_group(&"enemy").size(),
		"experience_count": get_nodes_in_group(&"experience_crystal").size(),
		"enemy_projectile_count": get_nodes_in_group(&"enemy_projectile").size(),
		"projectile_count": get_nodes_in_group(&"projectile").size(),
		"area_effect_count": _count_nodes_by_script("area_effect.gd"),
		"area_effect_sources": _area_effect_source_counts(),
		"damage_popup_count": _count_nodes_by_script("damage_number_popup.gd"),
		"enemy_profile": _enemy_profile_snapshot(),
		"player": _player_snapshot()
	}
	_samples.append(sample)
	print("[PerformanceRun] t=%.1f fps=%d avg=%.2fms p95=%.2fms p99=%.2fms max=%.2fms enemies=%d gems=%d nodes=%d popups=%d areas=%d area_sources=%s profile=%s" % [
		_elapsed,
		int(sample.get("fps", 0)),
		float(sample.get("avg_frame_ms", 0.0)),
		float(sample.get("p95_frame_ms", 0.0)),
		float(sample.get("p99_frame_ms", 0.0)),
		float(sample.get("max_frame_ms", 0.0)),
		int(sample.get("enemy_count", 0)),
		int(sample.get("experience_count", 0)),
		int(sample.get("node_count", 0)),
		int(sample.get("damage_popup_count", 0)),
		int(sample.get("area_effect_count", 0)),
		_count_summary(_dict(sample.get("area_effect_sources", {}))),
		_profile_summary(_dict(sample.get("enemy_profile", {})))
	])


func _write_outputs(status: String) -> void:
	var payload: Dictionary = {
		"status": status,
		"failure_reason": _failure_reason,
		"duration_seconds": _elapsed,
		"frame_count": _frame_ms_values.size(),
		"avg_frame_ms": _average(_frame_ms_values),
		"p95_frame_ms": _percentile(_frame_ms_values, 0.95),
		"p99_frame_ms": _percentile(_frame_ms_values, 0.99),
		"max_frame_ms": _max_frame_ms,
		"spike_33ms_count": _spike_33ms_count,
		"spike_50ms_count": _spike_50ms_count,
		"samples": _samples
	}
	var file: FileAccess = FileAccess.open(SAMPLES_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
	var lines: Array[String] = [
		"# Performance Run Report",
		"",
		"- status: %s" % status,
		"- failure_reason: %s" % _failure_reason,
		"- character: %s" % String(CHARACTER_ID),
		"- map: %s" % String(MAP_ID),
		"- elapsed_seconds: %.1f" % _elapsed,
		"- frame_count: %d" % _frame_ms_values.size(),
		"- avg_frame_ms: %.2f" % _average(_frame_ms_values),
		"- p95_frame_ms: %.2f" % _percentile(_frame_ms_values, 0.95),
		"- p99_frame_ms: %.2f" % _percentile(_frame_ms_values, 0.99),
		"- max_frame_ms: %.2f" % _max_frame_ms,
		"- frames_over_33ms: %d" % _spike_33ms_count,
		"- frames_over_50ms: %d" % _spike_50ms_count,
		"- samples_json: %s" % ProjectSettings.globalize_path(SAMPLES_PATH),
		"",
		"## Samples",
		"",
		"| t | fps | avg ms | p95 ms | p99 ms | max ms | enemies | gems | nodes | popups | areas |",
		"| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
	]
	for sample: Dictionary in _samples:
		lines.append("| %.1f | %d | %.2f | %.2f | %.2f | %.2f | %d | %d | %d | %d | %d |" % [
			float(sample.get("elapsed_seconds", 0.0)),
			int(sample.get("fps", 0)),
			float(sample.get("avg_frame_ms", 0.0)),
			float(sample.get("p95_frame_ms", 0.0)),
			float(sample.get("p99_frame_ms", 0.0)),
			float(sample.get("max_frame_ms", 0.0)),
			int(sample.get("enemy_count", 0)),
			int(sample.get("experience_count", 0)),
			int(sample.get("node_count", 0)),
			int(sample.get("damage_popup_count", 0)),
			int(sample.get("area_effect_count", 0))
		])
	file = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	print("[PerformanceRun] report=%s" % ProjectSettings.globalize_path(REPORT_PATH))


func _count_nodes_by_script(script_name: String) -> int:
	var count: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.ends_with(script_name):
			count += 1
		for child: Node in node.get_children():
			stack.append(child)
	return count


func _area_effect_source_counts() -> Dictionary:
	var counts: Dictionary = {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.ends_with("area_effect.gd"):
			var source_id: String = String(node.get("source_id")) if node.get("source_id") != null else String(node.get_meta("source_id", "unknown"))
			if source_id == "":
				source_id = "unknown"
			counts[source_id] = int(counts.get(source_id, 0)) + 1
		for child: Node in node.get_children():
			stack.append(child)
	return counts


func _count_summary(counts: Dictionary) -> String:
	if counts.is_empty():
		return "{}"
	var parts: Array[String] = []
	for key: Variant in counts.keys():
		parts.append("%s:%d" % [String(key), int(counts[key])])
	parts.sort()
	if parts.size() > 6:
		parts = parts.slice(0, 6)
		parts.append("...")
	return "{%s}" % ", ".join(parts)


func _enemy_profile_snapshot() -> Dictionary:
	for node: Node in get_nodes_in_group(&"enemy"):
		if node != null and node.has_method("get_enemy_profile_snapshot"):
			return node.call("get_enemy_profile_snapshot", true)
	return {}


func _profile_summary(profile: Dictionary) -> String:
	if profile.is_empty():
		return "{}"
	var parts: Array[String] = []
	for key: Variant in profile.keys():
		var record: Dictionary = _dict(profile[key])
		parts.append("%s=%.2fms/%d" % [
			String(key),
			float(record.get("usec", 0)) / 1000.0,
			int(record.get("count", 0))
		])
	parts.sort()
	return "{%s}" % ", ".join(parts)


func _apply_autoplay_survival_assist() -> void:
	if _player == null:
		return
	var assisted_max_health: int = maxi(int(_player.get("max_health")), 750)
	_player.set("max_health", assisted_max_health)
	_player.set("current_health", assisted_max_health)


func _maintain_autoplay_survival_assist() -> void:
	if _player == null:
		return
	var max_health: int = maxi(int(_player.get("max_health")), 1)
	var current_health: int = int(_player.get("current_health"))
	if current_health < int(float(max_health) * 0.35):
		_player.set("current_health", int(float(max_health) * 0.6))


func _player_snapshot() -> Dictionary:
	if _player == null:
		return {}
	return {
		"current_health": int(_player.get("current_health")),
		"max_health": int(_player.get("max_health")),
		"level": int(_player.get("level")),
		"current_experience": int(_player.get("current_experience")),
		"experience_to_next_level": int(_player.get("experience_to_next_level")),
		"position": [_player.global_position.x, _player.global_position.y]
	}


func _runtime_elapsed_seconds() -> float:
	if _ui != null:
		var ui_seconds: float = float(_ui.get("_run_seconds"))
		if ui_seconds > 0.0:
			return ui_seconds
	var spawner: Node = get_first_node_in_group(&"enemy_spawner")
	if spawner != null:
		return float(spawner.get("_elapsed_time"))
	return _elapsed


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


func _movement_center_push() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.ZERO
	var to_center: Vector2 = bounds.get_center() - _player.global_position
	var max_distance: float = maxf(minf(bounds.size.x, bounds.size.y) * 0.5, 1.0)
	var strength: float = clampf(to_center.length() / max_distance, 0.0, 1.0)
	return to_center.normalized() * strength if to_center.length_squared() > 0.01 else Vector2.ZERO


func _is_boss(enemy: Node) -> bool:
	return enemy != null and (enemy.is_in_group(&"bosses") or String(enemy.get_meta("enemy_rank", "")) == "boss" or String(enemy.get_meta("enemy_type", "")) == "boss")


func _find_button(root_node: Node, text: String) -> Button:
	if root_node == null:
		return null
	if root_node is Button and (root_node as Button).text.contains(text):
		return root_node as Button
	for child: Node in root_node.get_children():
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


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]


func _fail(reason: String) -> void:
	_failure_reason = reason
	push_error("[PerformanceRun] %s" % reason)
	_write_outputs("FAILED")
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


func _get_duration_arg(fallback: float) -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="):
			return maxf(float(arg.trim_prefix("--duration=")), 1.0)
	return fallback
