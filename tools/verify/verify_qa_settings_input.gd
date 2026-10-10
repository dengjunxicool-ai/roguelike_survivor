extends "res://tools/verify/qa_app_fixture.gd"
const Locale = preload("res://scripts/ui/localization_service.gd")
func text_values(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label or node is Button: result.append(str(node.text))
	for child: Node in node.get_children(): result.append_array(text_values(child))
	return result
func run() -> void:
	await setup_run()
	var directions: Array = [[KEY_LEFT,&"move_left",Vector2.LEFT],[KEY_RIGHT,&"move_right",Vector2.RIGHT],[KEY_UP,&"move_up",Vector2.UP],[KEY_DOWN,&"move_down",Vector2.DOWN]]
	for row: Array in directions:
		var event := InputEventKey.new()
		event.keycode = row[0]
		event.physical_keycode = row[0]
		event.pressed = true
		check(InputMap.event_is_action(event,row[1]),"arrow bound to " + str(row[1]))
		Input.parse_input_event(event)
		await settle(2)
		check(player._get_movement_input_direction().is_equal_approx(row[2]),"physical arrow drives player " + str(row[1]))
		event.pressed = false
		Input.parse_input_event(event)
		await settle(2)
		check(player._get_movement_input_direction().is_zero_approx(),"release stops movement")
	for row: Array in [[KEY_A,&"move_left",Vector2.LEFT],[KEY_D,&"move_right",Vector2.RIGHT],[KEY_W,&"move_up",Vector2.UP],[KEY_S,&"move_down",Vector2.DOWN]]:
		var event := InputEventKey.new()
		event.physical_keycode = row[0]
		event.pressed = true
		Input.parse_input_event(event)
		await settle(2)
		check(player._get_movement_input_direction().is_equal_approx(row[2]),"WASD still drives player " + str(row[1]))
		event.pressed = false
		Input.parse_input_event(event)
	await settle(2)
	for key: int in [KEY_LEFT,KEY_UP]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		Input.parse_input_event(event)
	await settle(2)
	check(player._get_movement_input_direction().is_equal_approx(Vector2(-1,-1).normalized()),"diagonal movement stays normalized")
	for key: int in [KEY_LEFT,KEY_UP]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = false
		Input.parse_input_event(event)
	await settle(2)
	ui.transition_to("TITLE")
	ui.transition_to("SETTINGS")
	await settle()
	var controller: RefCounted = ui._settings_controller
	controller._master_slider.value = 37.0
	var before_count: int = buttons(ui).size()
	controller._on_language_selected(1)
	await settle()
	var screen: Node = ui._screen_registry.get_screen("SETTINGS")
	check(text_values(screen).has("Back to Title") and text_values(screen).has("Settings"),"current settings and panel title refresh to English")
	check(text_values(ui._screen_registry.get_screen("PAUSE_MENU")).has("Resume"),"previously built pause controls follow locale")
	await capture("settings-English")
	check(is_equal_approx(controller._master_slider.value,37.0),"language change preserves audio slider")
	check(SaveManager.get_language_id() == "en" and Locale.get_language_id() == "en", "selected locale persisted")
	ui.transition_to("TITLE")
	await settle()
	check(text_values(ui._screen_registry.get_screen("TITLE")).has("Settings"),"previously built title menu follows locale")
	await capture("title-English")
	ui.transition_to("SETTINGS")
	controller._on_language_selected(0)
	await settle()
	check(text_values(screen).has("返回主菜单") and text_values(screen).has("设置"),"switch back refreshes existing settings")
	check(buttons(ui).size() == before_count,"locale changes create no duplicate controls")
	await finish()
