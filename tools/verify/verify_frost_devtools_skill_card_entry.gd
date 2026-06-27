extends SceneTree


const APP_BOOTSTRAP_PATH: String = "res://scenes/app/app_bootstrap.tscn"
const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"
const FROST_SKILL_ID: StringName = &"frost_attack_frostbite"

var _failed: bool = false
var _active_app: Node


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	var result: Dictionary = await _run_frost_skill_card_case()
	print("[verify_frost_devtools_skill_card_entry] result=%s" % str(result))
	_expect(bool(result.get("option_generated", false)), "frost skill option is generated", result.get("option_generated", false))
	_expect(bool(result.get("granted", false)), "frost skill is granted", result.get("granted", false))
	_expect(int(result.get("frost_card_count", 0)) >= 14, "frost god shows at least 14 skill cards", result.get("frost_card_count", 0))
	_expect(bool(result.get("frost_button_pressed", false)), "frost god button stays pressed", result.get("frost_button_pressed", false))
	_expect(bool(result.get("frost_card_found", false)), "first frost skill card exists", result.get("frost_card_found", false))
	await _teardown()
	if not _failed:
		print("[verify_frost_devtools_skill_card_entry] PASS")
	quit(1 if _failed else 0)


func _run_frost_skill_card_case() -> Dictionary:
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
	if panel == null:
		_fail("DevDebugPanel exists", "missing")
		return {}
	if not panel.has_method("debug_select_god_skill_cards"):
		_fail("DevDebugPanel.debug_select_god_skill_cards exists", "missing")
		return {}
	if not panel.has_method("debug_run_god_skill_chain"):
		_fail("DevDebugPanel.debug_run_god_skill_chain exists", "missing")
		return {}

	var frost_selection_variant: Variant = panel.call("debug_select_god_skill_cards", &"frost")
	if not (frost_selection_variant is Dictionary):
		_fail("debug_select_god_skill_cards returns Dictionary for frost", typeof(frost_selection_variant))
		return {}
	var frost_selection: Dictionary = frost_selection_variant as Dictionary
	var frost_card: Button = panel.find_child("GodSkillCard_frost_attack_frostbite", true, false) as Button
	var result_variant: Variant = await panel.call("debug_run_god_skill_chain", FROST_SKILL_ID)
	if not (result_variant is Dictionary):
		_fail("debug_run_god_skill_chain returns Dictionary for frost", typeof(result_variant))
		return {}
	var result: Dictionary = result_variant as Dictionary
	result["frost_card_count"] = int(frost_selection.get("card_count", 0))
	result["frost_button_pressed"] = bool(frost_selection.get("selected_button_pressed", false))
	result["frost_card_found"] = frost_card != null
	return result


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
