extends SceneTree


const APP_BOOTSTRAP_PATH: String = "res://scenes/app/app_bootstrap.tscn"
const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"
const CARD_SKILL_ID: StringName = &"fire_cast_meteor_rain"


var _failed: bool = false
var _active_app: Node


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	var result: Dictionary = await _run_fire_skill_card_case(CARD_SKILL_ID)
	print("[verify_fire_skill_card_selection_runtime] result=%s" % str(result))
	_expect(bool(result.get("option_generated", false)), "fire skill option is generated", result.get("option_generated", false))
	_expect(bool(result.get("granted", false)), "fire skill is granted", result.get("granted", false))
	_expect(bool(result.get("target_spawned", true)) == false, "fire skill selection does not spawn a target", result.get("target_spawned", true))
	_expect(int(result.get("cast_count", 0)) >= 1, "fire skill casts at least once", result.get("cast_count", 0))
	_expect(int(result.get("enemy_count_after", -1)) == int(result.get("enemy_count_before", -2)), "fire skill selection does not create enemies", "%s -> %s" % [str(result.get("enemy_count_before", "missing")), str(result.get("enemy_count_after", "missing"))])
	_expect(_result_allows_no_target(result), "no-target selection is accepted without damage trace", result)
	await _teardown()
	if not _failed:
		print("[verify_fire_skill_card_selection_runtime] PASS")
	quit(1 if _failed else 0)


func _run_fire_skill_card_case(skill_id: StringName) -> Dictionary:
	await _teardown()
	var app_scene: PackedScene = load(APP_BOOTSTRAP_PATH) as PackedScene
	if app_scene == null:
		_fail("app bootstrap scene loads", APP_BOOTSTRAP_PATH)
		return {}

	_active_app = app_scene.instantiate()
	root.add_child(_active_app)
	current_scene = _active_app
	await _wait_process_frames(3)

	var ui_manager: Node = _active_app.find_child("UIManager", true, false)
	if ui_manager == null or not ui_manager.has_method("start_developer_debug_run"):
		_fail("UIManager.start_developer_debug_run exists", "missing")
		return {}

	ui_manager.call("start_developer_debug_run", {
		"character_id": CHARACTER_ID,
		"map_id": MAP_ID
	})
	root.set_meta("developer_mode_enabled", true)
	root.set_meta("debug_control_mode", true)
	root.set_meta("debug_manual_spawn_only", true)
	root.set_meta("debug_enemy_forced_state", "idle")
	await _wait_for_player(90)
	await _wait_process_frames(5)

	var panel: Node = _active_app.find_child("DevDebugPanel", true, false)
	if panel == null:
		panel = root.find_child("DevDebugPanel", true, false)
	if panel == null or not panel.has_method("debug_run_fire_skill_chain"):
		_fail("DevDebugPanel.debug_run_fire_skill_chain exists", "missing")
		return {}
	if not panel.has_method("debug_select_god_skill_cards"):
		_fail("DevDebugPanel.debug_select_god_skill_cards exists", "missing")
		return {}

	var fire_selection_variant: Variant = panel.call("debug_select_god_skill_cards", &"fire")
	if fire_selection_variant is Dictionary:
		var fire_selection: Dictionary = fire_selection_variant as Dictionary
		_expect(int(fire_selection.get("card_count", 0)) >= 1, "fire god shows skill cards", fire_selection.get("card_count", 0))
	else:
		_fail("debug_select_god_skill_cards returns Dictionary for fire", typeof(fire_selection_variant))

	var enemy_count_before: int = get_nodes_in_group(&"enemies").size()
	var result_variant: Variant = await panel.call("debug_run_fire_skill_chain", skill_id)
	if result_variant is Dictionary:
		var result: Dictionary = result_variant as Dictionary
		result["enemy_count_before"] = enemy_count_before
		result["enemy_count_after"] = get_nodes_in_group(&"enemies").size()
		return result
	_fail("debug_run_fire_skill_chain returns Dictionary", typeof(result_variant))
	return {}


func _result_allows_no_target(result: Dictionary) -> bool:
	if not bool(result.get("silent_no_target_allowed", false)):
		return false
	return int(result.get("damage_record_count", -1)) == 0 and int(result.get("damage_popup_count", -1)) == 0


func _wait_for_player(max_frames: int) -> Node:
	for _frame_index: int in range(max_frames):
		var player: Node = get_first_node_in_group(&"player")
		if player != null and player.get_node_or_null("SkillExecutor") != null and player.get_node_or_null("SkillManager") != null:
			return player
		await process_frame
	return null


func _teardown() -> void:
	if _active_app != null and is_instance_valid(_active_app):
		_active_app.queue_free()
		_active_app = null
	current_scene = null
	root.set_meta("developer_mode_enabled", false)
	root.set_meta("debug_control_mode", false)
	root.set_meta("debug_manual_spawn_only", false)
	root.set_meta("debug_enemy_forced_state", "")
	root.set_meta("debug_player_attack_disabled", false)
	await _wait_process_frames(3)


func _wait_process_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await process_frame


func _expect(condition: bool, expected: String, actual: Variant) -> void:
	if condition:
		print("PASS expected=%s actual=%s" % [expected, str(actual)])
	else:
		_failed = true
		print("FAIL expected=%s actual=%s" % [expected, str(actual)])


func _fail(expected: String, actual: Variant) -> void:
	_expect(false, expected, actual)
