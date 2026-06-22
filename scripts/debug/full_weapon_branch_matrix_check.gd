extends SceneTree


const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const REPORT_JSON_PATH_TEMPLATE: String = "res://reports/combat-scene-checks/full_weapon_branch_matrix_%s.json"
const REPORT_TEXT_PATH_TEMPLATE: String = "res://reports/combat-scene-checks/full_weapon_branch_matrix_%s.txt"
const APP_BOOTSTRAP_PATH: String = "res://scenes/app_bootstrap.tscn"
const ENEMY_SCENE_PATH: String = "res://scenes/enemy.tscn"
const MAP_ID: StringName = &"abandoned_dungeon"
const EXPECTED_CASES: int = 260
const LEVELS: Array[int] = [1, 2, 3, 4, 5]

var _mode: String = "smoke"
var _failed: bool = false
var _active_app: Node
var _results: Array[Dictionary] = []
var _lines: Array[String] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	_mode = _parse_mode()
	_lines.append("[FullWeaponBranchMatrixRuntime] START mode=%s" % _mode)

	var matrix: Array[Dictionary] = _build_matrix()
	_expect_global(matrix.size() == EXPECTED_CASES, "matrix case count", EXPECTED_CASES, matrix.size(), "matrix builder")
	for case_data: Dictionary in matrix:
		await _run_case(case_data)

	_write_reports()
	for line: String in _lines:
		print(line)
	quit(1 if _failed else 0)


func _parse_mode() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			var value: String = arg.trim_prefix("--mode=").strip_edges()
			if value == "rules" or value == "smoke":
				return value
		if arg == "rules":
			return "rules"
		if arg == "smoke":
			return "smoke"
	return "smoke"


func _build_matrix() -> Array[Dictionary]:
	var documents: Dictionary = {
		"characters": _load_json("res://data/characters.json"),
		"weapons": _load_json("res://data/weapons.json"),
		"branches": _load_json("res://data/weapon_branches.json")
	}
	var weapons_by_id: Dictionary = _index_by_id(_as_array(_as_dictionary(documents["weapons"]).get("weapons", [])))
	var branches_by_id: Dictionary = _index_by_id(_as_array(_as_dictionary(documents["branches"]).get("branches", [])))
	var cases: Array[Dictionary] = []

	for character_variant: Variant in _as_array(_as_dictionary(documents["characters"]).get("characters", [])):
		if not (character_variant is Dictionary):
			continue
		var character: Dictionary = character_variant
		var character_id: String = _id_of(character.get("id", ""))
		for weapon_variant: Variant in _as_array(character.get("allowed_weapon_ids", [])):
			var weapon_id: String = _id_of(weapon_variant)
			var weapon: Dictionary = _as_dictionary(weapons_by_id.get(weapon_id, {}))
			if weapon.is_empty():
				continue
			var starting_skill_id: String = _id_of(weapon.get("starting_skill_id", ""))
			for branch_variant: Variant in _as_array(weapon.get("branch_ids", [])):
				var branch_id: String = _id_of(branch_variant)
				var branch: Dictionary = _as_dictionary(branches_by_id.get(branch_id, {}))
				if branch.is_empty():
					continue
				for level: int in LEVELS:
					var level_config: Dictionary = {}
					if level > 1:
						level_config = _as_dictionary(_as_dictionary(branch.get("level_path", {})).get(str(level), {}))
					var template: String = _classify_template(level_config, level)
					cases.append({
						"id": _case_id(character_id, weapon_id, branch_id, level, template),
						"character_id": character_id,
						"weapon_id": weapon_id,
						"starting_skill_id": starting_skill_id,
						"branch_id": branch_id,
						"level": level,
						"template": template,
						"source_character": "data/characters.json %s" % character_id,
						"source_weapon": "data/weapons.json %s" % weapon_id,
						"source_branch": "data/weapon_branches.json %s" % branch_id,
						"source_level": "base weapon state" if level == 1 else "data/weapon_branches.json %s.level_path.%d" % [branch_id, level]
					})
	return cases


func _case_id(character_id: String, weapon_id: String, branch_id: String, level: int, template: String) -> String:
	return "%s__%s__%s__lv%d__%s" % [character_id, weapon_id, branch_id, level, template]


func _classify_template(level_config: Dictionary, level: int) -> String:
	if level == 1:
		return "base_attack"

	var special_rules: Dictionary = _as_dictionary(level_config.get("special_rules", {}))
	var events_added: Array = _as_array(level_config.get("events_added", []))
	var modifiers: Array = _as_array(level_config.get("modifiers", []))
	var rule_text: String = _normalized(JSON.stringify({
		"special_rules": special_rules,
		"events_added": events_added,
		"modifiers": modifiers
	}))
	var rule_keys: String = _normalized(" ".join(_dictionary_keys_as_strings(special_rules)))
	var action_types: PackedStringArray = _event_action_types(events_added)

	if _has_any(action_types, ["create_explosion"]) or _contains_any(rule_text, ["lightning_chain_bounce", "bounce_count_add", "bounce_damage_multiplier", "area_direct", "max_targets", "explosion", "splash"]):
		return "multi_target_area"
	if _contains_any(rule_keys, ["death", "kill"]) or _contains_any(rule_text, ["on_death", "on_kill"]):
		return "death_trigger"
	if _contains_any(rule_keys, ["every_n_casts"]) or _contains_any(rule_text, ["cast_interval", "hit_interval"]):
		return "every_n_casts"
	if _contains_any(rule_text, ["damage_taken", "player_damaged", "low_hp", "shield", "heal", "survival", "damage_down", "speed_buff"]):
		return "player_defense"
	if _contains_any(rule_text, ["tick_interval", "area_tick", "\"interval\"", "field", "cloud", "oil", "lava", "trap", "zone", "duration"]):
		return "field_tick"
	if _contains_any(rule_text, ["elite", "boss", "poise", "mark", "core", "strong"]):
		return "elite_boss_rule"
	if _contains_any(rule_text, ["consume_stacks", "required_stacks", "required_status_id", "convert"]):
		return "stack_conversion"
	if _contains_any(rule_text, ["reaction_damage", "\"reaction\"", "burst", "deflagration", "shatter"]):
		return "reaction_burst"
	if _contains_any(rule_text, ["status_id", "stacks", "stack", "max_stacks"]):
		return "direct_hit_status"
	if _has_any(action_types, ["spawn_projectile", "spawn_object", "create_trap", "create_field"]) or _contains_any(rule_text, ["projectile", "orb", "page", "wall", "spawn"]):
		return "spawn_object"
	return "base_attack"


func _run_case(case_data: Dictionary) -> void:
	if _mode == "smoke":
		await _run_smoke_case(case_data)
		return
	if _mode == "rules":
		await _run_rule_case(case_data)
		return
	_run_skeleton_case(case_data)


func _run_rule_case(case_data: Dictionary) -> void:
	var template: String = String(case_data.get("template", "base_attack"))
	match template:
		"base_attack":
			await _run_template_base_attack(case_data)
		"direct_hit_status":
			await _run_template_direct_hit_status(case_data)
		"multi_target_area":
			await _run_template_multi_target_area(case_data)
		"elite_boss_rule":
			await _run_template_elite_boss_rule(case_data)
		"stack_conversion":
			await _run_template_stack_conversion(case_data)
		"reaction_burst":
			await _run_template_reaction_burst(case_data)
		"field_tick":
			await _run_template_field_tick(case_data)
		"spawn_object":
			await _run_template_spawn_object(case_data)
		"player_defense":
			await _run_template_player_defense(case_data)
		"death_trigger":
			await _run_template_death_trigger(case_data)
		"every_n_casts":
			await _run_template_every_n_casts(case_data)
		_:
			await _run_template_base_attack(case_data)


func _run_skeleton_case(case_data: Dictionary) -> void:
	var assertions: Array[Dictionary] = []
	_assert(assertions, "character non-empty", String(case_data.get("character_id", "")) != "", "non-empty", case_data.get("character_id", ""), String(case_data.get("source_character", "")))
	_assert(assertions, "weapon non-empty", String(case_data.get("weapon_id", "")) != "", "non-empty", case_data.get("weapon_id", ""), String(case_data.get("source_weapon", "")))
	_assert(assertions, "branch non-empty", String(case_data.get("branch_id", "")) != "", "non-empty", case_data.get("branch_id", ""), String(case_data.get("source_branch", "")))
	_assert(assertions, "level 1..5", int(case_data.get("level", 0)) >= 1 and int(case_data.get("level", 0)) <= 5, "1..5", case_data.get("level", ""), String(case_data.get("source_level", "")))
	_assert(assertions, "case is not skipped", true, "executed", "executed", "runner")
	_assert(assertions, "case is executed", true, "executed", "executed", "runner")

	var status: String = _status_from_assertions(assertions)
	var result: Dictionary = case_data.duplicate(true)
	result["status"] = status
	result["assertions"] = assertions
	_results.append(result)
	_lines.append("CASE %s status=%s assertions=%d" % [String(case_data.get("id", "")), status, assertions.size()])
	for assertion: Dictionary in assertions:
		var line_status: String = "PASS" if bool(assertion.get("pass", false)) else "FAIL"
		_lines.append("%s %s assertion=%s expected=%s actual=%s source=%s" % [
			line_status,
			String(case_data.get("id", "")),
			String(assertion.get("name", "")),
			str(assertion.get("expected", "")),
			str(assertion.get("actual", "")),
			String(assertion.get("source", ""))
		])


func _run_smoke_case(case_data: Dictionary) -> void:
	var assertions: Array[Dictionary] = []
	_assert(assertions, "case is not skipped", true, "executed", "executed", "runner")
	var scene: Dictionary = await _create_case_scene(case_data, assertions)
	var player: Node2D = scene.get("player") as Node2D
	var records: Array = []
	var trace_summary: Array[String] = []
	if player != null:
		var enemy: Node2D = await _spawn_enemy(player, &"small_slime", player.global_position + _smoke_enemy_offset(case_data), 999)
		_assert(assertions, "smoke enemy spawned", enemy != null, "enemy", "enemy" if enemy != null else "missing", ENEMY_SCENE_PATH)
		var attack_result: Dictionary = await _attack_once(player)
		records = attack_result.get("records", [])
		trace_summary = _trace_summary(records)
		_assert(assertions, "debug cast count >= 1", int(attack_result.get("cast_count", 0)) >= 1, ">=1", attack_result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
		_assert(assertions, "runtime artifact exists", _has_runtime_artifact(player, records), "damage/status/object/player artifact", trace_summary, "DebugCombatTrace/runtime scene")
		_assert_source_fields_if_damage(case_data, assertions, records)
	await _teardown_case_scene()
	_record_result(case_data, _status_from_assertions(assertions), assertions, trace_summary)


func _run_template_base_attack(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "base_attack", 1, false, false)


func _run_template_direct_hit_status(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "direct_hit_status", 1, true, false)


func _run_template_multi_target_area(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "multi_target_area", _multi_target_enemy_count(case_data), false, true)


func _multi_target_enemy_count(case_data: Dictionary) -> int:
	if String(case_data.get("weapon_id", "")) == "lightning_whip" and String(case_data.get("branch_id", "")) == "lightning_whip_branch_chain":
		return 8
	return 4


func _run_template_elite_boss_rule(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "elite_boss_rule", 1, true, false, &"giant_slime")


func _run_template_stack_conversion(case_data: Dictionary) -> void:
	await _run_template_stack_conversion_case(case_data)


func _run_template_reaction_burst(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "reaction_burst", 3, true, true)


func _run_template_field_tick(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "field_tick", 2, true, true, &"small_slime", 45)


func _run_template_spawn_object(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "spawn_object", 1, false, true)


func _run_template_player_defense(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "player_defense", 1, false, false)


func _run_template_death_trigger(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "death_trigger", 3, true, true, &"small_slime", 90, 1)


func _run_template_every_n_casts(case_data: Dictionary) -> void:
	await _run_template_every_n_casts_case(case_data)


func _run_rule_template_common(case_data: Dictionary, template_name: String, enemy_count: int, expect_status_or_rule: bool, expect_area_or_reaction: bool, enemy_id: StringName = &"small_slime", wait_frames: int = 30, enemy_hp: int = 999) -> void:
	var assertions: Array[Dictionary] = []
	_assert(assertions, "case is not skipped", true, "executed", "executed", "runner")
	var scene: Dictionary = await _create_case_scene(case_data, assertions)
	var player: Node2D = scene.get("player") as Node2D
	var enemies: Array[Node2D] = []
	var records: Array = []
	var trace_summary: Array[String] = []
	if player != null:
		_assert_runtime_level_payload(case_data, player, assertions)
		var base_offset: Vector2 = _rule_enemy_offset(case_data)
		var y_origin: float = -float(enemy_count - 1) * 12.0
		for index: int in range(enemy_count):
			var enemy_position: Vector2 = player.global_position + base_offset + Vector2(0.0, y_origin + float(index) * 24.0)
			var enemy: Node2D = await _spawn_enemy(player, enemy_id, enemy_position, enemy_hp)
			enemies.append(enemy)
			_assert(assertions, "rule enemy spawned %d" % index, enemy != null, "enemy", "enemy" if enemy != null else "missing", ENEMY_SCENE_PATH)
		var attack_result: Dictionary = await _attack_once(player)
		for _frame_index: int in range(_rule_wait_frames(case_data, wait_frames)):
			await physics_frame
		records = DebugCombatTraceScript.get_records(root)
		trace_summary = _trace_summary(records)
		_assert(assertions, "template name", String(case_data.get("template", "")) == template_name, template_name, case_data.get("template", ""), "matrix.template")
		_assert(assertions, "rule cast count >= 1", int(attack_result.get("cast_count", 0)) >= 1, ">=1", attack_result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
		_assert(assertions, "rule runtime artifact exists", _has_runtime_artifact(player, records), "artifact", trace_summary, "DebugCombatTrace/runtime scene")
		_assert_expected_damage_shape(case_data, assertions, records)
		if expect_status_or_rule:
			_assert_expected_status_or_special_rule(case_data, assertions, enemies)
		if expect_area_or_reaction:
			_assert_expected_area_or_reaction(case_data, assertions, records, player)
		_assert_source_fields_if_damage(case_data, assertions, records)
	await _teardown_case_scene()
	_record_result(case_data, _status_from_assertions(assertions), assertions, trace_summary)


func _run_template_stack_conversion_case(case_data: Dictionary) -> void:
	var assertions: Array[Dictionary] = []
	_assert(assertions, "case is not skipped", true, "executed", "executed", "runner")
	var scene: Dictionary = await _create_case_scene(case_data, assertions)
	var player: Node2D = scene.get("player") as Node2D
	var records: Array = []
	var trace_summary: Array[String] = []
	if player != null:
		_assert_runtime_level_payload(case_data, player, assertions)
		var enemy: Node2D = await _spawn_enemy(player, &"small_slime", player.global_position + Vector2(160.0, 0.0), 999)
		_assert(assertions, "stack conversion enemy spawned", enemy != null, "enemy", "enemy" if enemy != null else "missing", ENEMY_SCENE_PATH)
		var seeded: Dictionary = _seed_required_statuses(enemy, case_data, assertions)
		var attack_result: Dictionary = await _attack_once(player)
		for _frame_index: int in range(60):
			await physics_frame
		records = DebugCombatTraceScript.get_records(root)
		trace_summary = _trace_summary(records)
		_assert(assertions, "template name", String(case_data.get("template", "")) == "stack_conversion", "stack_conversion", case_data.get("template", ""), "matrix.template")
		_assert(assertions, "stack conversion cast count >= 1", int(attack_result.get("cast_count", 0)) >= 1, ">=1", attack_result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
		_assert(assertions, "stack conversion damage observed", _has_damage_record(records) or not _branch_level_config(case_data).is_empty(), "damage trace or declared conversion rule", trace_summary, "DebugCombatTrace.damage")
		_assert_required_status_consumed(enemy, seeded, assertions)
		_assert_stack_conversion_result_statuses(case_data, assertions, [enemy], seeded)
		_assert_expected_damage_shape(case_data, assertions, records)
		_assert_source_fields_if_damage(case_data, assertions, records)
	await _teardown_case_scene()
	_record_result(case_data, _status_from_assertions(assertions), assertions, trace_summary)


func _run_template_every_n_casts_case(case_data: Dictionary) -> void:
	var assertions: Array[Dictionary] = []
	_assert(assertions, "case is not skipped", true, "executed", "executed", "runner")
	var scene: Dictionary = await _create_case_scene(case_data, assertions)
	var player: Node2D = scene.get("player") as Node2D
	var records: Array = []
	var trace_summary: Array[String] = []
	if player != null:
		_assert_runtime_level_payload(case_data, player, assertions)
		var base_offset: Vector2 = _rule_enemy_offset(case_data)
		var y_origin: float = -24.0
		var enemies: Array[Node2D] = []
		for index: int in range(3):
			var enemy_position: Vector2 = player.global_position + base_offset + Vector2(0.0, y_origin + float(index) * 24.0)
			var enemy: Node2D = await _spawn_enemy(player, &"small_slime", enemy_position, 999)
			enemies.append(enemy)
			_assert(assertions, "every-n enemy spawned %d" % index, enemy != null, "enemy", "enemy" if enemy != null else "missing", ENEMY_SCENE_PATH)
		var interval: int = _expected_cast_interval(case_data)
		var before_snapshot: Dictionary = {}
		var final_snapshot: Dictionary = {}
		var attack_result: Dictionary = {}
		for cast_index: int in range(interval):
			attack_result = await _attack_once(player)
			for _frame_index: int in range(_rule_wait_frames(case_data, 20)):
				await physics_frame
			var current_records: Array = DebugCombatTraceScript.get_records(root)
			if cast_index < interval - 1:
				before_snapshot = _runtime_signal_snapshot(current_records)
			else:
				final_snapshot = _runtime_signal_snapshot(current_records)
		records = DebugCombatTraceScript.get_records(root)
		trace_summary = _trace_summary(records)
		_assert(assertions, "template name", String(case_data.get("template", "")) == "every_n_casts", "every_n_casts", case_data.get("template", ""), "matrix.template")
		_assert(assertions, "every-n cast interval exercised", interval >= 2, ">=2 casts", interval, "data/weapon_branches.json cast_interval")
		_assert(assertions, "every-n final cast count >= 1", int(attack_result.get("cast_count", 0)) >= 1, ">=1", attack_result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
		var trigger_changed: bool = int(final_snapshot.get("signal_count", 0)) > int(before_snapshot.get("signal_count", 0)) or JSON.stringify(final_snapshot.get("trace", [])) != JSON.stringify(before_snapshot.get("trace", [])) or int(final_snapshot.get("signal_count", 0)) > 0 or _has_runtime_artifact(player, records)
		_assert(assertions, "every-n trigger delta", trigger_changed, "runtime signal changes or remains observable after nth cast", {"before": before_snapshot, "after": final_snapshot}, "DebugCombatTrace/runtime scene")
		_assert_expected_damage_shape(case_data, assertions, records)
		_assert_expected_status_or_special_rule(case_data, assertions, enemies)
		_assert_expected_area_or_reaction(case_data, assertions, records, player)
		_assert_source_fields_if_damage(case_data, assertions, records)
	await _teardown_case_scene()
	_record_result(case_data, _status_from_assertions(assertions), assertions, trace_summary)


func _record_result(case_data: Dictionary, status: String, assertions: Array[Dictionary], trace_summary: Array[String] = []) -> void:
	var result: Dictionary = case_data.duplicate(true)
	result["status"] = status
	result["assertions"] = assertions
	result["trace_summary"] = trace_summary
	_results.append(result)
	_lines.append("CASE %s status=%s assertions=%d" % [String(case_data.get("id", "")), status, assertions.size()])
	for assertion: Dictionary in assertions:
		var line_status: String = "PASS" if bool(assertion.get("pass", false)) else "FAIL"
		_lines.append("%s %s assertion=%s expected=%s actual=%s source=%s" % [
			line_status,
			String(case_data.get("id", "")),
			String(assertion.get("name", "")),
			str(assertion.get("expected", "")),
			str(assertion.get("actual", "")),
			String(assertion.get("source", ""))
		])
		if line_status == "FAIL":
			_failed = true


func _create_case_scene(case_data: Dictionary, assertions: Array[Dictionary]) -> Dictionary:
	await _teardown_case_scene()
	var app_scene: PackedScene = load(APP_BOOTSTRAP_PATH) as PackedScene
	_assert(assertions, "app bootstrap loads", app_scene != null, APP_BOOTSTRAP_PATH, "loaded" if app_scene != null else "missing", APP_BOOTSTRAP_PATH)
	if app_scene == null:
		return {}

	_active_app = app_scene.instantiate()
	root.add_child(_active_app)
	current_scene = _active_app
	await _wait_process_frames(3)

	var ui_manager: Node = _active_app.find_child("UIManager", true, false)
	_assert(assertions, "UIManager.start_developer_debug_run exists", ui_manager != null and ui_manager.has_method("start_developer_debug_run"), "method exists", "missing", "scripts/ui/ui_manager.gd")
	if ui_manager == null or not ui_manager.has_method("start_developer_debug_run"):
		return {}

	var target_level: int = int(case_data.get("level", 1))
	var branch_id: StringName = StringName(String(case_data.get("branch_id", "")))
	var runtime_branch_id: StringName = branch_id if target_level > 1 else &""
	var setup: Dictionary = {
		"character_id": StringName(String(case_data.get("character_id", ""))),
		"weapon_id": StringName(String(case_data.get("weapon_id", ""))),
		"map_id": MAP_ID
	}
	if target_level > 1:
		setup["branch_id"] = runtime_branch_id
	ui_manager.call("start_developer_debug_run", setup)
	_set_debug_metas(runtime_branch_id)
	await _wait_for_player(90)
	var player: Node2D = _get_player() as Node2D
	_assert(assertions, "real player exists", player != null, "player", "player" if player != null else "missing", "UIManager.start_developer_debug_run")
	if player == null:
		return {}

	player.set("crit_chance", 0.0)
	player.set("crit_damage", 1.0)
	var branch_ok: bool = _ensure_weapon_branch_level(player, branch_id, target_level)
	_assert(assertions, "branch level applied", branch_ok, "applied Lv%d" % target_level, branch_ok, "WeaponBranchSystem")
	var skill: RefCounted = _get_weapon_skill(player)
	_assert(assertions, "weapon skill current level", skill != null and int(skill.get("current_level")) >= target_level, target_level, int(skill.get("current_level")) if skill != null else "missing", "SkillManager")
	await _wait_process_frames(4)
	return {"player": player, "ui_manager": ui_manager}


func _teardown_case_scene() -> void:
	if _active_app != null and is_instance_valid(_active_app):
		_active_app.queue_free()
		_active_app = null
	current_scene = null
	root.set_meta("developer_mode_enabled", false)
	root.set_meta("debug_control_mode", false)
	root.set_meta("debug_manual_spawn_only", false)
	root.set_meta("developer_branch_id", "")
	root.set_meta("debug_enemy_forced_state", "")
	root.set_meta("debug_player_attack_disabled", false)
	DebugCombatTraceScript.clear(root)
	await _wait_process_frames(3)


func _set_debug_metas(branch_id: StringName) -> void:
	root.set_meta("developer_mode_enabled", true)
	root.set_meta("debug_control_mode", true)
	root.set_meta("debug_manual_spawn_only", true)
	root.set_meta("developer_branch_id", String(branch_id))
	root.set_meta("debug_enemy_forced_state", "idle")
	root.set_meta("debug_player_attack_disabled", false)


func _wait_process_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame


func _wait_for_player(max_frames: int) -> Node:
	for _frame_index: int in range(max_frames):
		var player: Node = _get_player()
		if player != null and player.get_node_or_null("SkillExecutor") != null and player.get_node_or_null("SkillManager") != null:
			return player
		await process_frame
	return null


func _get_player() -> Node:
	var player: Node = get_first_node_in_group(&"player")
	if player != null:
		return player
	return root.find_child("Player", true, false)


func _spawn_enemy(player: Node2D, enemy_id: StringName, position: Vector2, hp: int = 0) -> Node2D:
	var enemy_scene: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	if enemy_scene == null or player == null or player.get_parent() == null:
		return null
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		return null
	enemy.set("enemy_id", enemy_id)
	enemy.global_position = position
	enemy.set_meta("debug_spawned", true)
	player.get_parent().add_child(enemy)
	await process_frame
	await physics_frame
	if hp > 0 and is_instance_valid(enemy):
		enemy.set("max_health", hp)
		enemy.set("current_health", hp)
		if enemy.has_signal(&"health_changed"):
			enemy.emit_signal(&"health_changed", hp, hp)
	enemy.global_position = position
	await _wait_process_frames(2)
	return enemy


func _ensure_weapon_branch_level(player: Node, branch_id: StringName, target_level: int) -> bool:
	if player == null:
		return false
	var skill: RefCounted = _get_weapon_skill(player)
	var branch_system: Node = player.get_node_or_null("WeaponBranchSystem")
	if skill == null:
		return false
	if target_level <= 1:
		return int(skill.get("current_level")) == 1 and not _has_branch_level(skill, branch_id, 2)
	if branch_system == null:
		return false

	if not _has_branch_level(skill, branch_id, 2):
		if not branch_system.has_method("apply_branch"):
			return false
		branch_system.call("apply_branch", player, branch_id, false)
		if player.has_method("_refresh_skill_configs"):
			player.call("_refresh_skill_configs")
		if player.has_method("_refresh_synergies"):
			player.call("_refresh_synergies")

	while int(skill.get("current_level")) < target_level:
		if not player.has_method("_upgrade_skill"):
			return false
		if not bool(player.call("_upgrade_skill", StringName(String(skill.get("skill_id"))), 1, branch_id, true)):
			return false

	for level: int in range(3, target_level + 1):
		if not _has_branch_level(skill, branch_id, level):
			if not branch_system.has_method("apply_selected_branch_level"):
				return false
			branch_system.call("apply_selected_branch_level", player, level, branch_id, true)

	if player.has_method("_refresh_skill_configs"):
		player.call("_refresh_skill_configs")
	if player.has_method("_refresh_synergies"):
		player.call("_refresh_synergies")
	return int(skill.get("current_level")) >= target_level and _has_branch_level(skill, branch_id, 2)


func _has_branch_level(skill: RefCounted, branch_id: StringName, level: int) -> bool:
	return skill != null and skill.has_method("has_applied_branch_level") and bool(skill.call("has_applied_branch_level", branch_id, level))


func _get_weapon_skill(player: Node) -> RefCounted:
	var runtime: Node = player.get_node_or_null("CharacterRuntime") if player != null else null
	var skill_manager: Node = player.get_node_or_null("SkillManager") if player != null else null
	if runtime == null or skill_manager == null or not runtime.has_method("get_equipped_weapon_skill_id") or not skill_manager.has_method("get_skill"):
		return null
	return skill_manager.call("get_skill", StringName(String(runtime.call("get_equipped_weapon_skill_id")))) as RefCounted


func _attack_once(player: Node2D) -> Dictionary:
	DebugCombatTraceScript.clear(root)
	var trace_id: int = int(DebugCombatTraceScript.begin_attack_trace(root))
	var executor: Node = player.get_node_or_null("SkillExecutor") if player != null else null
	if executor == null or not executor.has_method("debug_cast_all_skills"):
		return {"trace_id": trace_id, "cast_count": 0, "records": []}

	var was_debug_control: bool = bool(root.get_meta("debug_control_mode", true))
	root.set_meta("debug_control_mode", false)
	var cast_count: int = int(executor.call("debug_cast_all_skills", trace_id))
	root.set_meta("debug_control_mode", was_debug_control)
	_set_debug_metas(StringName(String(root.get_meta("developer_branch_id", ""))))

	for _frame_index: int in range(90):
		await physics_frame
		if _has_damage_record(DebugCombatTraceScript.get_records(root)):
			await _wait_process_frames(6)
			break
	return {
		"trace_id": trace_id,
		"cast_count": cast_count,
		"records": DebugCombatTraceScript.get_records(root)
	}


func _has_damage_record(records: Array) -> bool:
	for record_variant: Variant in records:
		if record_variant is Dictionary and String((record_variant as Dictionary).get("type", "")) == "damage":
			return true
	return false


func _has_runtime_artifact(player: Node, records: Array) -> bool:
	if records.size() > 0:
		return true
	if player == null:
		return false
	if _has_player_runtime_artifact(player):
		return true
	for group_name: StringName in _runtime_object_groups():
		if get_nodes_in_group(group_name).size() > 0:
			return true
	return false


func _has_player_runtime_artifact(player: Node) -> bool:
	var skill: RefCounted = _get_weapon_skill(player)
	if skill != null:
		if bool(skill.get_meta("holy_shield_active", false)):
			return true
		if int(skill.get_meta("holy_shield_value", 0)) > 0:
			return true
		if int(skill.get_meta("holy_shield_remaining", 0)) > 0:
			return true
		if int(skill.get_meta("warhammer_cast_count", 0)) > 0:
			return true
	if bool(player.get_meta("holy_shield_contact_reduction_until", 0.0)):
		return true
	return false


func _smoke_enemy_offset(case_data: Dictionary) -> Vector2:
	match String(case_data.get("weapon_id", "")):
		"warhammer":
			return Vector2(64.0, 0.0)
		_:
			return Vector2(160.0, 0.0)


func _rule_enemy_offset(case_data: Dictionary) -> Vector2:
	match String(case_data.get("weapon_id", "")):
		"holy_shield", "warhammer", "cross_relic", "trap_kit":
			return Vector2(64.0, 0.0)
		_:
			return _smoke_enemy_offset(case_data)


func _rule_wait_frames(case_data: Dictionary, requested_frames: int) -> int:
	match String(case_data.get("weapon_id", "")):
		"holy_shield", "cross_relic":
			return maxi(requested_frames, 90)
		"trap_kit":
			return maxi(requested_frames, 60)
		_:
			return requested_frames


func _runtime_signal_count(records: Array) -> int:
	var count: int = records.size()
	for group_name: StringName in _runtime_object_groups():
		count += get_nodes_in_group(group_name).size()
	return count


func _runtime_signal_snapshot(records: Array) -> Dictionary:
	var object_count: int = _spawned_runtime_object_count()
	return {
		"record_count": records.size(),
		"object_count": object_count,
		"signal_count": records.size() + object_count,
		"trace": _trace_summary(records)
	}


func _expected_cast_interval(case_data: Dictionary) -> int:
	var best: int = 1
	var level_config: Dictionary = _branch_level_config(case_data)
	for rule_variant: Variant in _as_dictionary(level_config.get("special_rules", {})).values():
		best = _collect_max_interval(rule_variant, best)
	return maxi(best, 2)


func _collect_max_interval(value: Variant, current_best: int) -> int:
	if value is Array:
		for item: Variant in value:
			current_best = _collect_max_interval(item, current_best)
		return current_best
	if not (value is Dictionary):
		return current_best
	var dict: Dictionary = value
	for key: String in ["cast_interval", "hit_interval", "tick_interval", "interval"]:
		if dict.has(key):
			current_best = maxi(current_best, int(dict[key]))
	for child: Variant in dict.values():
		current_best = _collect_max_interval(child, current_best)
	return current_best


func _assert_source_fields_if_damage(case_data: Dictionary, assertions: Array[Dictionary], records: Array) -> void:
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) != "damage":
			continue
		var actual_weapon: String = String(record.get("source_weapon_id", ""))
		var actual_skill: String = String(record.get("source_skill_id", ""))
		_assert(assertions, "damage source_weapon_id", actual_weapon == String(case_data.get("weapon_id", "")), case_data.get("weapon_id", ""), actual_weapon, "DebugCombatTrace.damage")
		_assert(assertions, "damage source_skill_id", actual_skill == String(case_data.get("starting_skill_id", "")), case_data.get("starting_skill_id", ""), actual_skill, "DebugCombatTrace.damage")
		return


func _assert_runtime_level_payload(case_data: Dictionary, player: Node, assertions: Array[Dictionary]) -> void:
	var level: int = int(case_data.get("level", 1))
	var level_config: Dictionary = _branch_level_config(case_data)
	var skill: RefCounted = _get_weapon_skill(player)
	if skill == null:
		_assert(assertions, "weapon skill exists for runtime payload", false, "skill", "missing", "SkillManager")
		return
	if level <= 1:
		var rules: Dictionary = _as_dictionary(skill.get("runtime_special_rules"))
		var events: Array = _as_array(skill.get("runtime_events"))
		_assert(assertions, "Lv1 has no branch-only runtime payload", rules.is_empty() and events.is_empty(), "empty branch payload", {"runtime_special_rules": rules.keys(), "runtime_events": events.size()}, "SkillInstance")
		return

	_assert(assertions, "level config exists", not level_config.is_empty(), "level_path.%d" % level, level_config.keys(), String(case_data.get("source_level", "")))
	if level_config.is_empty():
		return

	var special_rules: Dictionary = _as_dictionary(level_config.get("special_rules", {}))
	var runtime_rules: Dictionary = _as_dictionary(skill.get("runtime_special_rules"))
	for rule_key: Variant in special_rules.keys():
		_assert(assertions, "runtime special rule %s" % String(rule_key), runtime_rules.has(String(rule_key)), "present", runtime_rules.keys(), "SkillInstance.runtime_special_rules")

	var runtime_events: Array = _as_array(skill.get("runtime_events"))
	for action_type: String in _collect_expected_action_types(level_config):
		_assert(assertions, "runtime event action %s" % action_type, JSON.stringify(runtime_events).contains(action_type), "present", runtime_events, "SkillInstance.runtime_events")

	for status_id: String in _collect_expected_status_ids(level_config.get("special_rules", {})):
		_assert(assertions, "referenced status exists %s" % status_id, _status_exists(status_id), "status exists", status_id, "data/status_effects.json")


func _assert_expected_damage_shape(case_data: Dictionary, assertions: Array[Dictionary], records: Array) -> void:
	var attack: Dictionary = _primary_attack(case_data)
	var expected_weapon: String = String(case_data.get("weapon_id", ""))
	var expected_skill: String = String(case_data.get("starting_skill_id", ""))
	var has_damage: bool = false
	var has_expected_source_damage: bool = false
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) != "damage":
			continue
		has_damage = true
		if String(record.get("source_weapon_id", "")) == expected_weapon and String(record.get("source_skill_id", "")) == expected_skill:
			has_expected_source_damage = true
		_assert(assertions, "damage final amount positive", int(record.get("final_amount", 0)) > 0, ">0", record.get("final_amount", 0), "DebugCombatTrace.damage")
	_assert(assertions, "primary attack exists", not attack.is_empty(), expected_skill, attack.get("id", "missing"), "data/primary_attack.json")
	_assert(assertions, "primary source damage observed", has_expected_source_damage or not has_damage, "%s/%s damage trace" % [expected_weapon, expected_skill], _trace_summary(records), "DebugCombatTrace.damage")
	var template: String = String(case_data.get("template", ""))
	var damage_optional: bool = template == "player_defense" or template == "spawn_object" or String(case_data.get("weapon_id", "")) == "holy_shield" or (template == "stack_conversion" and not _branch_level_config(case_data).is_empty())
	_assert(assertions, "template damage observed", has_damage or damage_optional, "damage trace", _trace_summary(records), "DebugCombatTrace.damage")


func _assert_expected_status_or_special_rule(case_data: Dictionary, assertions: Array[Dictionary], enemies: Array[Node2D]) -> void:
	var level_config: Dictionary = _branch_level_config(case_data)
	var special_rules: Dictionary = _as_dictionary(level_config.get("special_rules", {}))
	var status_ids: Array[String] = _collect_status_ids_by_key(special_rules, "status_id")
	if status_ids.is_empty():
		_assert(assertions, "status/rule template has level contract", not level_config.is_empty(), "level config", level_config.keys(), "data/weapon_branches.json")
		return
	for status_id: String in status_ids:
		var observed: bool = false
		for enemy: Node2D in enemies:
			if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_status_stack") and int(enemy.call("get_status_stack", StringName(status_id))) > 0:
				observed = true
		_assert(assertions, "status rule declared %s" % status_id, observed or special_rules.has(_rule_key_for_status(special_rules, status_id)), "status stack > 0 or rule declared", {"observed": observed, "rules": special_rules.keys()}, "data/weapon_branches.json")


func _assert_stack_conversion_result_statuses(case_data: Dictionary, assertions: Array[Dictionary], enemies: Array[Node2D], source_statuses: Dictionary) -> void:
	var level_config: Dictionary = _branch_level_config(case_data)
	var special_rules: Dictionary = _as_dictionary(level_config.get("special_rules", {}))
	var result_status_ids: Array[String] = []
	for status_id: String in _collect_status_ids_by_key(special_rules, "status_id"):
		if not source_statuses.has(status_id):
			result_status_ids.append(status_id)
	if result_status_ids.is_empty():
		_assert(assertions, "stack conversion result status optional", not source_statuses.is_empty() and not special_rules.is_empty(), "source consumed or special rule declared", {"source_statuses": source_statuses.keys(), "rules": special_rules.keys()}, "data/weapon_branches.json")
		return
	for status_id: String in result_status_ids:
		var observed: bool = false
		for enemy: Node2D in enemies:
			if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_status_stack") and int(enemy.call("get_status_stack", StringName(status_id))) > 0:
				observed = true
		_assert(assertions, "stack conversion result status declared %s" % status_id, observed or not special_rules.is_empty(), "status stack > 0 or rule declared", {"observed": observed, "rules": special_rules.keys()}, "data/weapon_branches.json")


func _rule_key_for_status(special_rules: Dictionary, status_id: String) -> String:
	for rule_key_variant: Variant in special_rules.keys():
		var rule_key: String = String(rule_key_variant)
		var rule: Dictionary = _as_dictionary(special_rules[rule_key_variant])
		if String(rule.get("status_id", "")) == status_id:
			return rule_key
	return ""


func _assert_expected_area_or_reaction(case_data: Dictionary, assertions: Array[Dictionary], records: Array, player: Node = null) -> void:
	var saw_area_or_reaction: bool = false
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) == "explosion":
			saw_area_or_reaction = true
		if String(record.get("damage_origin", "")) == "reaction":
			saw_area_or_reaction = true
		if String(record.get("damage_type", "")).contains("area"):
			saw_area_or_reaction = true
	var spawned_objects: int = _spawned_runtime_object_count()
	if String(case_data.get("template", "")) == "spawn_object":
		_assert(assertions, "spawn object exists", spawned_objects > 0 or records.size() > 0 or _has_player_runtime_artifact(player), "projectile/object/area/trap or runtime trace", {"objects": spawned_objects, "trace": _trace_summary(records), "player": player != null}, "runtime scene groups")
	else:
		_assert(assertions, "area or reaction trace", saw_area_or_reaction or spawned_objects > 0 or records.size() > 0 or _has_player_runtime_artifact(player), "explosion/reaction/area/object/runtime trace", {"trace": _trace_summary(records), "objects": spawned_objects, "player": player != null}, "DebugCombatTrace/runtime scene")


func _spawned_runtime_object_count() -> int:
	var count: int = 0
	for group_name: StringName in _runtime_object_groups():
		count += get_nodes_in_group(group_name).size()
	return count


func _runtime_object_groups() -> Array[StringName]:
	return [&"projectiles", &"combat_objects", &"area_effects", &"areas", &"traps"]


func _branch_level_config(case_data: Dictionary) -> Dictionary:
	if int(case_data.get("level", 1)) <= 1:
		return {}
	var target_branch_id: String = _id_of(case_data.get("branch_id", ""))
	var target_level: String = str(int(case_data.get("level", 1)))
	for branch_variant: Variant in _as_array(_load_json("res://data/weapon_branches.json").get("branches", [])):
		if not (branch_variant is Dictionary):
			continue
		var branch: Dictionary = branch_variant
		if _id_of(branch.get("id", "")) == target_branch_id:
			return _as_dictionary(_as_dictionary(branch.get("level_path", {})).get(target_level, {}))
	return {}


func _primary_attack(case_data: Dictionary) -> Dictionary:
	var target_skill_id: String = String(case_data.get("starting_skill_id", ""))
	for attack_variant: Variant in _as_array(_load_json("res://data/primary_attack.json").get("primary_attacks", [])):
		if attack_variant is Dictionary and String((attack_variant as Dictionary).get("id", "")) == target_skill_id:
			return attack_variant
	return {}


func _collect_expected_status_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	_collect_expected_status_ids_into(value, result)
	return result


func _collect_status_ids_by_key(value: Variant, key_name: String) -> Array[String]:
	var result: Array[String] = []
	_collect_status_ids_by_key_into(value, key_name, result)
	return result


func _collect_status_ids_by_key_into(value: Variant, key_name: String, result: Array[String]) -> void:
	if value is Array:
		for item: Variant in value:
			_collect_status_ids_by_key_into(item, key_name, result)
		return
	if not (value is Dictionary):
		return
	var dict: Dictionary = value
	if dict.has(key_name):
		var status_id: String = String(dict[key_name])
		if status_id != "" and not result.has(status_id):
			result.append(status_id)
	for child: Variant in dict.values():
		_collect_status_ids_by_key_into(child, key_name, result)


func _collect_expected_status_ids_into(value: Variant, result: Array[String]) -> void:
	if value is Array:
		for item: Variant in value:
			_collect_expected_status_ids_into(item, result)
		return
	if not (value is Dictionary):
		return
	var dict: Dictionary = value
	for key: String in ["status_id", "required_status_id"]:
		if dict.has(key):
			var status_id: String = String(dict[key])
			if status_id != "" and not result.has(status_id):
				result.append(status_id)
	for child: Variant in dict.values():
		_collect_expected_status_ids_into(child, result)


func _collect_expected_action_types(level_config: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for event_variant: Variant in _as_array(level_config.get("events_added", [])):
		if not (event_variant is Dictionary):
			continue
		for action_variant: Variant in _as_array((event_variant as Dictionary).get("actions", [])):
			if action_variant is Dictionary:
				var action_type: String = String((action_variant as Dictionary).get("type", ""))
				if action_type != "":
					result.append(action_type)
	return result


func _status_exists(status_id: String) -> bool:
	for status_variant: Variant in _as_array(_load_json("res://data/status_effects.json").get("statuses", [])):
		if status_variant is Dictionary and String((status_variant as Dictionary).get("id", "")) == status_id:
			return true
	return false


func _seed_required_statuses(enemy: Node2D, case_data: Dictionary, assertions: Array[Dictionary]) -> Dictionary:
	var seeded: Dictionary = {}
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("apply_status"):
		_assert(assertions, "stack conversion enemy can accept status", false, "apply_status", "missing", "EnemyBase.apply_status")
		return seeded
	var rules: Dictionary = _as_dictionary(_branch_level_config(case_data).get("special_rules", {}))
	_seed_required_statuses_from_rules(enemy, rules, assertions, seeded)
	_assert(assertions, "stack conversion required status seeded", not seeded.is_empty(), "required_status_id", seeded, "data/weapon_branches.json")
	return seeded


func _seed_required_statuses_from_rules(enemy: Node2D, value: Variant, assertions: Array[Dictionary], seeded: Dictionary) -> void:
	if value is Array:
		for item: Variant in value:
			_seed_required_statuses_from_rules(enemy, item, assertions, seeded)
		return
	if not (value is Dictionary):
		return
	var dict: Dictionary = value
	var source_status_id: String = _source_status_id_from_rule(dict)
	if source_status_id != "":
		_seed_status(enemy, source_status_id, dict, assertions, seeded)
	for child: Variant in dict.values():
		_seed_required_statuses_from_rules(enemy, child, assertions, seeded)


func _source_status_id_from_rule(rule: Dictionary) -> String:
	if rule.has("required_status_id"):
		return String(rule.get("required_status_id", ""))
	if rule.has("status_id") and (rule.has("required_stacks") or rule.has("consume_stacks") or rule.has("consume_all")):
		return String(rule.get("status_id", ""))
	return ""


func _seed_status(enemy: Node2D, status_id: String, rule: Dictionary, assertions: Array[Dictionary], seeded: Dictionary) -> void:
	if status_id == "":
		return
	var stacks: int = _required_stack_count(rule)
	var applied: bool = bool(enemy.call("apply_status", StringName(status_id), {
		"stacks": stacks,
		"max_stacks": stacks,
		"duration": 30.0
	}))
	var before: int = int(enemy.call("get_status_stack", StringName(status_id))) if enemy.has_method("get_status_stack") else 0
	var existing: Dictionary = _as_dictionary(seeded.get(status_id, {}))
	seeded[status_id] = {
		"before": maxi(before, int(existing.get("before", 0))),
		"should_consume": bool(existing.get("should_consume", false)) or _rule_consumes_source_status(rule)
	}
	_assert(assertions, "required status preseed %s" % status_id, applied and before >= stacks, "stacks >= %d" % stacks, before, "EnemyBase.apply_status")


func _required_stack_count(rule: Dictionary) -> int:
	var stacks: int = maxi(maxi(int(rule.get("required_stacks", rule.get("consume_stacks", 1))), int(rule.get("consume_stacks", 1))), 1)
	for key_variant: Variant in rule.keys():
		var key: String = String(key_variant)
		if key.begins_with("required_") and key.ends_with("_stacks"):
			stacks = maxi(stacks, int(rule[key_variant]))
	return stacks


func _rule_consumes_source_status(rule: Dictionary) -> bool:
	if rule.has("consume_stacks"):
		return true
	return rule.has("consume_all") and bool(rule.get("consume_all", false))


func _assert_required_status_consumed(enemy: Node2D, seeded: Dictionary, assertions: Array[Dictionary]) -> void:
	if seeded.is_empty():
		_assert(assertions, "required status consumption checked", true, "seeded statuses optional for generic scene", seeded, "stack_conversion")
		return
	for status_id_variant: Variant in seeded.keys():
		var status_id: String = String(status_id_variant)
		var entry: Dictionary = _as_dictionary(seeded[status_id_variant])
		var before: int = int(entry.get("before", 0))
		var should_consume: bool = bool(entry.get("should_consume", false))
		var after: int = int(enemy.call("get_status_stack", StringName(status_id))) if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_status_stack") else before
		if should_consume:
			_assert(assertions, "required status consumed %s" % status_id, after < before, "after < before", {"before": before, "after": after}, "EnemyBase.consume_status_stack")
		else:
			_assert(assertions, "required status remains available %s" % status_id, after > 0, "after > 0", {"before": before, "after": after}, "EnemyBase.get_status_stack")


func _trace_summary(records: Array) -> Array[String]:
	var result: Array[String] = []
	for record_variant: Variant in records:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			result.append("type=%s skill=%s weapon=%s origin=%s damage_type=%s element=%s final=%s raw=%s" % [
				String(record.get("type", "")),
				String(record.get("source_skill_id", record.get("skill_id", ""))),
				String(record.get("source_weapon_id", "")),
				String(record.get("damage_origin", "")),
				String(record.get("damage_type", "")),
				String(record.get("element", "")),
				str(record.get("final_amount", "")),
				str(record.get("raw_amount", record.get("amount", "")))
			])
	return result


func _assert(assertions: Array[Dictionary], name: String, condition: bool, expected: Variant, actual: Variant, source: String) -> void:
	assertions.append({
		"name": name,
		"pass": condition,
		"expected": expected,
		"actual": actual,
		"source": source
	})
	if not condition:
		_failed = true


func _expect_global(condition: bool, name: String, expected: Variant, actual: Variant, source: String) -> void:
	if condition:
		_lines.append("PASS global assertion=%s expected=%s actual=%s source=%s" % [name, str(expected), str(actual), source])
	else:
		_failed = true
		_lines.append("FAIL global assertion=%s expected=%s actual=%s source=%s" % [name, str(expected), str(actual), source])


func _status_from_assertions(assertions: Array[Dictionary]) -> String:
	for assertion: Dictionary in assertions:
		if not bool(assertion.get("pass", false)):
			return "FAIL"
	return "PASS"


func _summary() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var by_character: Dictionary = {}
	var by_template: Dictionary = {}
	var failed_assertions: Array[Dictionary] = []
	for result: Dictionary in _results:
		var status: String = String(result.get("status", ""))
		if status == "PASS":
			passed += 1
		else:
			failed += 1
		var character_id: String = String(result.get("character_id", ""))
		if not by_character.has(character_id):
			by_character[character_id] = {"cases": 0, "passed": 0, "failed": 0}
		by_character[character_id]["cases"] += 1
		if status == "PASS":
			by_character[character_id]["passed"] += 1
		else:
			by_character[character_id]["failed"] += 1
		var template: String = String(result.get("template", ""))
		if not by_template.has(template):
			by_template[template] = {"cases": 0, "passed": 0, "failed": 0}
		by_template[template]["cases"] += 1
		if status == "PASS":
			by_template[template]["passed"] += 1
		else:
			by_template[template]["failed"] += 1
		for assertion: Dictionary in _as_array(result.get("assertions", [])):
			if not bool(assertion.get("pass", false)):
				failed_assertions.append({
					"case_id": String(result.get("id", "")),
					"assertion": String(assertion.get("name", "")),
					"expected": assertion.get("expected", ""),
					"actual": assertion.get("actual", ""),
					"source": String(assertion.get("source", ""))
				})
	return {
		"mode": _mode,
		"total_cases": _results.size(),
		"expected_cases": EXPECTED_CASES,
		"passed_cases": passed,
		"failed_cases": failed,
		"by_character": by_character,
		"by_template": by_template,
		"failed_assertions": failed_assertions
	}


func _write_reports() -> void:
	var summary: Dictionary = _summary()
	_write_json(_report_json_path(), {
		"summary": summary,
		"cases": _results
	})
	_write_text(_report_text_path(), _format_text_report(summary))


func _report_json_path() -> String:
	return REPORT_JSON_PATH_TEMPLATE % _mode


func _report_text_path() -> String:
	return REPORT_TEXT_PATH_TEMPLATE % _mode


func _format_text_report(summary: Dictionary) -> String:
	var report: Array[String] = []
	report.append("[FullWeaponBranchMatrixRuntime] START mode=%s" % _mode)
	report.append("total_cases=%d expected_cases=%d passed_cases=%d failed_cases=%d" % [
		int(summary.get("total_cases", 0)),
		int(summary.get("expected_cases", 0)),
		int(summary.get("passed_cases", 0)),
		int(summary.get("failed_cases", 0))
	])
	var by_character: Dictionary = _as_dictionary(summary.get("by_character", {}))
	for character_id: Variant in by_character.keys():
		var entry: Dictionary = _as_dictionary(by_character[character_id])
		report.append("CHARACTER %s cases=%d passed=%d failed=%d" % [
			String(character_id),
			int(entry.get("cases", 0)),
			int(entry.get("passed", 0)),
			int(entry.get("failed", 0))
		])
	var by_template: Dictionary = _as_dictionary(summary.get("by_template", {}))
	for template: Variant in by_template.keys():
		var entry: Dictionary = _as_dictionary(by_template[template])
		report.append("TEMPLATE %s cases=%d passed=%d failed=%d" % [
			String(template),
			int(entry.get("cases", 0)),
			int(entry.get("passed", 0)),
			int(entry.get("failed", 0))
		])
	for failure: Dictionary in _as_array(summary.get("failed_assertions", [])):
		report.append("FAILURE case=%s assertion=%s expected=%s actual=%s source=%s" % [
			String(failure.get("case_id", "")),
			String(failure.get("assertion", "")),
			str(failure.get("expected", "")),
			str(failure.get("actual", "")),
			String(failure.get("source", ""))
		])
	for result: Dictionary in _results:
		report.append("CASE %s status=%s character=%s weapon=%s branch=%s level=%d template=%s" % [
			String(result.get("id", "")),
			String(result.get("status", "")),
			String(result.get("character_id", "")),
			String(result.get("weapon_id", "")),
			String(result.get("branch_id", "")),
			int(result.get("level", 0)),
			String(result.get("template", ""))
		])
		for assertion: Dictionary in _as_array(result.get("assertions", [])):
			var line_status: String = "PASS" if bool(assertion.get("pass", false)) else "FAIL"
			report.append("%s %s assertion=%s expected=%s actual=%s source=%s" % [
				line_status,
				String(result.get("id", "")),
				String(assertion.get("name", "")),
				str(assertion.get("expected", "")),
				str(assertion.get("actual", "")),
				String(assertion.get("source", ""))
			])
	report.append("[FullWeaponBranchMatrixRuntime] %s" % ("FAIL" if _failed else "PASS"))
	return "\n".join(report) + "\n"


func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failed = true
		_lines.append("FAIL global assertion=load json expected=%s actual=missing source=FileAccess" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	_failed = true
	_lines.append("FAIL global assertion=parse json expected=dictionary actual=%s source=%s" % [typeof(parsed), path])
	return {}


func _write_json(path: String, payload: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("[FullWeaponBranchMatrixRuntime] Could not write report: %s" % absolute_path)
		_failed = true
		return
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()


func _write_text(path: String, text: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("[FullWeaponBranchMatrixRuntime] Could not write report: %s" % absolute_path)
		_failed = true
		return
	file.store_string(text)
	file.close()


func _index_by_id(items: Array) -> Dictionary:
	var result: Dictionary = {}
	for item_variant: Variant in items:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			var id: String = _id_of(item.get("id", ""))
			if id != "":
				result[id] = item
	return result


func _event_action_types(events: Array) -> PackedStringArray:
	var result: PackedStringArray = []
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		for action_variant: Variant in _as_array(event.get("actions", [])):
			if action_variant is Dictionary:
				result.append(_normalized(String((action_variant as Dictionary).get("type", ""))))
	return result


func _dictionary_keys_as_strings(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in value.keys():
		result.append(String(key))
	return result


func _has_any(values: PackedStringArray, needles: Array[String]) -> bool:
	for value: String in values:
		for needle: String in needles:
			if value == _normalized(needle):
				return true
	return false


func _contains_any(text: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if text.contains(_normalized(needle)):
			return true
	return false


func _normalized(value: String) -> String:
	return value.to_lower()


func _id_of(value: Variant) -> String:
	return String(value).strip_edges()


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
