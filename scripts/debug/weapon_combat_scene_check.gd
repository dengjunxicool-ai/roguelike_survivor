extends SceneTree


const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const REPORT_PATH: String = "res://reports/combat-scene-checks/weapon_combat_scene_check.txt"
const APP_BOOTSTRAP_PATH: String = "res://scenes/app_bootstrap.tscn"
const ENEMY_SCENE_PATH: String = "res://scenes/enemy.tscn"
const CHARACTER_ID: StringName = &"mage"
const WEAPON_ID: StringName = &"fire_staff"
const MAP_ID: StringName = &"abandoned_dungeon"

var _failed: bool = false
var _report_lines: Array[String] = []
var _active_app: Node


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	await process_frame
	_report_lines.append("[WeaponCombatSceneCheck] START")

	await _run_case_soulburn_lv2()
	await _run_case_burst_single_lv2()
	await _run_case_burst_three_lv2()

	_report_lines.append("[WeaponCombatSceneCheck] %s" % ("DONE_WITH_CONCERNS" if _failed else "DONE"))
	_write_report()
	for line: String in _report_lines:
		print(line)
	quit(1 if _failed else 0)


func _run_case_soulburn_lv2() -> void:
	var case_id: String = "mage_fire_staff_soulburn_lv2_small_slime_attack_once"
	var scene: Dictionary = await _create_case_scene(case_id, &"fire_staff_branch_soulburn", 2)
	var player: Node2D = scene.get("player") as Node2D
	if player == null:
		return
	var enemy: Node2D = await _spawn_enemy(player, &"small_slime", player.global_position + Vector2(160.0, 0.0), 18)

	var result: Dictionary = await _attack_once(player)
	var records: Array = result.get("records", [])
	var direct_record: Dictionary = _find_direct_fireball_record(records, enemy, true)
	var direct_actual_record: Dictionary = direct_record if not direct_record.is_empty() else _find_direct_fireball_record(records, enemy, false)
	_report_trace(case_id, records)

	_expect(case_id, int(result.get("cast_count", 0)) >= 1, "at least one cast", result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
	_expect(case_id, not direct_record.is_empty(), "direct fireball trace source_weapon_id=fire_staff", _format_record_summary(direct_actual_record), "DebugCombatTrace.damage")
	_expect(case_id, not direct_record.is_empty() and is_equal_approx(float(direct_record.get("raw_amount", -1.0)), 16.0) and int(direct_record.get("final_amount", -1)) == 17, "direct fireball trace source_weapon_id=fire_staff, raw config damage 16, mage runtime final damage 17", _format_record_summary(direct_actual_record), "DebugCombatTrace.damage")
	_expect(case_id, int(enemy.get("current_health")) == 1, "target HP 1 after raw config damage 16 and mage runtime final damage 17", int(enemy.get("current_health")), "EnemyBase.current_health")
	var status_api_ok: bool = _assert_status_api(case_id, enemy, "target")
	var soul_ember_stack: int = _get_status_stack(enemy, &"soul_ember")
	var burn_stack: int = _get_status_stack(enemy, &"burn")
	_expect(case_id, status_api_ok and soul_ember_stack == 1, "soul_ember stack 1", soul_ember_stack, "EnemyBase.get_status_stack")
	_expect(case_id, status_api_ok and burn_stack == 0, "burn stack 0", burn_stack, "EnemyBase.get_status_stack")
	await _teardown_case_scene()


func _run_case_burst_single_lv2() -> void:
	var case_id: String = "mage_fire_staff_burst_lv2_single_slime_attack_once"
	var scene: Dictionary = await _create_case_scene(case_id, &"fire_staff_branch_burst", 2)
	var player: Node2D = scene.get("player") as Node2D
	if player == null:
		return
	var enemy: Node2D = await _spawn_enemy(player, &"small_slime", player.global_position + Vector2(160.0, 0.0), 200)

	var result: Dictionary = await _attack_once(player)
	var records: Array = result.get("records", [])
	var direct_record: Dictionary = _find_direct_fireball_record(records, enemy, true)
	var direct_actual_record: Dictionary = direct_record if not direct_record.is_empty() else _find_direct_fireball_record(records, enemy, false)
	var explosion_record: Dictionary = _find_explosion_record(records, {
		"source_skill_id": "fireball",
		"damage_origin": "reaction",
		"damage_type": "area_direct",
		"element": "fire"
	})
	_report_trace(case_id, records)

	_expect(case_id, int(result.get("cast_count", 0)) >= 1, "at least one cast", result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
	_expect(case_id, not direct_record.is_empty(), "direct fireball trace source_weapon_id=fire_staff", _format_record_summary(direct_actual_record), "DebugCombatTrace.damage")
	_expect(case_id, not direct_record.is_empty() and is_equal_approx(float(direct_record.get("raw_amount", -1.0)), 16.0) and int(direct_record.get("final_amount", -1)) == 17, "direct fireball trace source_weapon_id=fire_staff, raw config damage 16, mage runtime final damage 17", _format_record_summary(direct_actual_record), "DebugCombatTrace.damage")
	_expect(case_id, not explosion_record.is_empty(), "explosion trace origin=reaction type=area_direct element=fire", _format_record_summary(explosion_record), "DebugCombatTrace.explosion")
	_expect_source_weapon_if_present(case_id, explosion_record, "explosion trace", "DebugCombatTrace.explosion")
	var status_api_ok: bool = _assert_status_api(case_id, enemy, "target")
	var burn_stack: int = _get_status_stack(enemy, &"burn")
	_expect(case_id, status_api_ok and burn_stack == 0, "burn stack 0 when fewer than 3 normal enemies are hit by explosion", burn_stack, "explosion_multi_hit_burn")
	await _teardown_case_scene()


func _run_case_burst_three_lv2() -> void:
	var case_id: String = "mage_fire_staff_burst_lv2_three_slime_burn_threshold"
	var scene: Dictionary = await _create_case_scene(case_id, &"fire_staff_branch_burst", 2)
	var player: Node2D = scene.get("player") as Node2D
	if player == null:
		return
	var enemies: Array[Node2D] = []
	enemies.append(await _spawn_enemy(player, &"small_slime", player.global_position + Vector2(160.0, 0.0), 200))
	enemies.append(await _spawn_enemy(player, &"small_slime", player.global_position + Vector2(160.0, 36.0), 200))
	enemies.append(await _spawn_enemy(player, &"small_slime", player.global_position + Vector2(160.0, -36.0), 200))

	var result: Dictionary = await _attack_once(player)
	var records: Array = result.get("records", [])
	var direct_record: Dictionary = _find_direct_fireball_record(records, enemies[0], true)
	var direct_actual_record: Dictionary = direct_record if not direct_record.is_empty() else _find_direct_fireball_record(records, enemies[0], false)
	var explosion_record: Dictionary = _find_explosion_record(records, {
		"source_skill_id": "fireball",
		"damage_origin": "reaction",
		"damage_type": "area_direct",
		"element": "fire"
	})
	_report_trace(case_id, records)

	_expect(case_id, int(result.get("cast_count", 0)) >= 1, "at least one cast", result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
	_expect(case_id, not direct_record.is_empty(), "direct fireball trace source_weapon_id=fire_staff", _format_record_summary(direct_actual_record), "DebugCombatTrace.damage")
	_expect(case_id, not explosion_record.is_empty(), "explosion trace exists", _format_record_summary(explosion_record), "DebugCombatTrace.explosion")
	_expect_source_weapon_if_present(case_id, explosion_record, "explosion trace", "DebugCombatTrace.explosion")
	for index: int in range(enemies.size()):
		var enemy: Node = enemies[index]
		var status_api_ok: bool = _assert_status_api(case_id, enemy, "enemy %d" % (index + 1))
		var burn_stack: int = _get_status_stack(enemy, &"burn")
		_expect(case_id, status_api_ok and burn_stack == 1, "enemy %d burn stack 1" % (index + 1), burn_stack, "explosion_multi_hit_burn")
	await _teardown_case_scene()


func _create_case_scene(case_id: String, branch_id: StringName, target_level: int) -> Dictionary:
	await _teardown_case_scene()
	_report_lines.append("")
	_report_lines.append("[CASE] %s" % case_id)

	var app_scene: PackedScene = load(APP_BOOTSTRAP_PATH) as PackedScene
	if app_scene == null:
		_fail(case_id, "app bootstrap scene loads", "missing", APP_BOOTSTRAP_PATH)
		return {}

	_active_app = app_scene.instantiate()
	root.add_child(_active_app)
	current_scene = _active_app
	await _wait_process_frames(3)

	var ui_manager: Node = _active_app.find_child("UIManager", true, false)
	if ui_manager == null or not ui_manager.has_method("start_developer_debug_run"):
		_fail(case_id, "UIManager.start_developer_debug_run exists", "missing", "app_bootstrap")
		return {}

	ui_manager.call("start_developer_debug_run", {
		"character_id": CHARACTER_ID,
		"weapon_id": WEAPON_ID,
		"map_id": MAP_ID,
		"branch_id": branch_id
	})
	_set_debug_metas(branch_id)
	await _wait_for_player(90)
	var player: Node2D = _get_player() as Node2D
	if player == null:
		_fail(case_id, "real player exists after developer debug run", "missing", "ui_manager.start_developer_debug_run")
		return {}

	player.set("crit_chance", 0.0)
	player.set("crit_damage", 1.0)
	_set_debug_metas(branch_id)
	var branch_ok: bool = _ensure_weapon_branch_level(player, branch_id, target_level)
	_expect(case_id, branch_ok, "fire staff branch %s Lv%d applied" % [String(branch_id), target_level], branch_ok, "WeaponBranchSystem")
	await _wait_process_frames(4)
	return {"app": _active_app, "ui_manager": ui_manager, "player": player}


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
	if skill == null or branch_system == null:
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


func _find_damage_record(records: Array, target: Node, expected: Dictionary) -> Dictionary:
	var target_id: String = str(target.get_instance_id()) if target != null else ""
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) != "damage":
			continue
		if target_id != "" and String(record.get("target_id", "")) != target_id:
			continue
		if _record_matches(record, expected):
			return record
	return {}


func _find_direct_fireball_record(records: Array, target: Node, require_source_weapon: bool) -> Dictionary:
	var expected: Dictionary = {
		"source_skill_id": "fireball",
		"damage_origin": "primary_attack",
		"damage_type": "direct_magical",
		"element": "fire"
	}
	if require_source_weapon:
		expected["source_weapon_id"] = String(WEAPON_ID)
	return _find_damage_record(records, target, expected)


func _find_explosion_record(records: Array, expected: Dictionary) -> Dictionary:
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) != "explosion":
			continue
		if _record_matches(record, expected):
			return record
	return {}


func _record_matches(record: Dictionary, expected: Dictionary) -> bool:
	for key_variant: Variant in expected.keys():
		var key: String = String(key_variant)
		var expected_value: Variant = expected[key_variant]
		var actual_value: Variant = record.get(key, null)
		if expected_value is int:
			if int(actual_value) != int(expected_value):
				return false
		elif expected_value is float:
			if not is_equal_approx(float(actual_value), float(expected_value)):
				return false
		else:
			if str(actual_value) != str(expected_value):
				return false
	return true


func _assert_status_api(case_id: String, target: Node, label: String) -> bool:
	var ok: bool = target != null and target.has_method("get_status_stack")
	var actual: String = "available" if ok else "missing target" if target == null else "missing get_status_stack"
	_expect(case_id, ok, "%s status API get_status_stack available" % label, actual, "EnemyBase.get_status_stack")
	return ok


func _expect_source_weapon_if_present(case_id: String, record: Dictionary, label: String, source: String) -> void:
	if String(record.get("source_weapon_id", "")) != "":
		_expect(case_id, String(record.get("source_weapon_id", "")) == String(WEAPON_ID), "%s source_weapon_id=fire_staff" % label, _format_record_summary(record), source)


func _get_status_stack(target: Node, status_id: StringName) -> int:
	if target != null and target.has_method("get_status_stack"):
		return int(target.call("get_status_stack", status_id))
	return -1


func _format_record_summary(record: Dictionary) -> String:
	if record.is_empty():
		return "{}"
	var parts: Array[String] = []
	for key: String in ["type", "target", "source_skill_id", "source_weapon_id", "damage_origin", "damage_type", "element", "final_amount", "raw_amount", "amount"]:
		if record.has(key):
			parts.append("%s=%s" % [key, str(record[key])])
	return "{%s}" % ", ".join(parts)


func _report_trace(case_id: String, records: Array) -> void:
	_report_lines.append("TRACE %s records=%d" % [case_id, records.size()])
	for index: int in range(records.size()):
		if not (records[index] is Dictionary):
			continue
		var record: Dictionary = records[index]
		_report_lines.append("TRACE %s #%d %s" % [case_id, index + 1, _format_record_summary(record)])


func _expect(case_id: String, condition: bool, expected: String, actual: Variant, source: String) -> void:
	if condition:
		_report_lines.append("PASS %s expected=%s actual=%s source=%s" % [case_id, expected, str(actual), source])
	else:
		_failed = true
		_report_lines.append("FAIL %s expected=%s actual=%s source=%s" % [case_id, expected, str(actual), source])


func _fail(case_id: String, expected: String, actual: Variant, source: String) -> void:
	_expect(case_id, false, expected, actual, source)


func _wait_process_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await process_frame


func _write_report() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(REPORT_PATH)
	var directory_path: String = absolute_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory_path)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("[WeaponCombatSceneCheck] Could not write report: %s" % absolute_path)
		return
	file.store_string("\n".join(_report_lines) + "\n")
	file.close()
