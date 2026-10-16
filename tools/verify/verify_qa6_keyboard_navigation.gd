extends "res://tools/verify/qa_app_fixture.gd"

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func focus_is_in(screen: Node) -> bool:
	var focus: Control = root.gui_get_focus_owner()
	return focus != null and focus.is_visible_in_tree() and (screen == focus or screen.is_ancestor_of(focus))

func reach_and_activate(screen: Node, text: String) -> bool:
	for step: int in 80:
		var focus: Control = root.gui_get_focus_owner()
		if focus is Button and focus.text == text:
			await key(KEY_ENTER)
			return true
		await key(KEY_TAB)
	check(false, "keyboard can reach action " + text)
	return false

func run() -> void:
	SaveManager.set_language_id("zh")
	root.size = Vector2i(1280, 720)
	create_timer(25.0, true).timeout.connect(func() -> void: push_error("QA keyboard timed out"); quit(1))
	app = APP.instantiate()
	root.add_child(app)
	await settle(12)
	ui = app.get_node("UIManager")
	await key(KEY_ENTER)
	check(ui._title_controller.actions_revealed, "keyboard reveals title actions")
	check(focus_is_in(ui._screen_registry.get_screen("TITLE")), "revealed title initializes keyboard focus")
	var first: Control = root.gui_get_focus_owner()
	await key(KEY_DOWN)
	check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner() != first, "arrow keys navigate title actions")
	await reach_and_activate(ui._screen_registry.get_screen("TITLE"), "开始冒险")
	await settle(12)
	check(ui.current_state == "CHARACTER_SELECT", "keyboard starts character selection")
	check(focus_is_in(ui._screen_registry.get_screen("CHARACTER_SELECT")), "character page initializes keyboard focus")
	await reach_and_activate(ui._screen_registry.get_screen("CHARACTER_SELECT"), "确认")
	await settle(12)
	check(ui.current_state == "MAP_SELECT", "keyboard confirms selected character")
	check(focus_is_in(ui._screen_registry.get_screen("MAP_SELECT")), "map page initializes keyboard focus")
	var start: Button = ui._map_select_controller._start_button
	await reach_and_activate(ui._screen_registry.get_screen("MAP_SELECT"), start.text)
	await create_timer(0.5, true).timeout
	check(ui.current_state == "RUNNING", "keyboard starts a real run")
	player = get_first_node_in_group(&"player")
	if player != null:
		ui._run_scene_coordinator.get_run_scene_parent(self).process_mode = Node.PROCESS_MODE_DISABLED
	check(root.gui_get_focus_owner() == null, "combat releases menu focus to preserve arrows and dash")
	await key(KEY_ESCAPE)
	check(ui.current_state == "PAUSE_MENU", "Escape opens pause")
	check(focus_is_in(ui._screen_registry.get_screen("PAUSE_MENU")), "pause initializes focus in its own actions")
	await reach_and_activate(ui._screen_registry.get_screen("PAUSE_MENU"), "继续游戏")
	check(ui.current_state == "RUNNING" and not paused, "keyboard resumes combat")
	ui._on_player_leveled_up(2)
	await settle(12)
	check(ui.current_state == "LEVEL_UP_MODAL" and paused, "upgrade opens and pauses combat")
	check(focus_is_in(ui._screen_registry.get_screen("LEVEL_UP_MODAL")), "upgrade cards initialize keyboard focus")
	await key(KEY_ENTER)
	await settle(8)
	check(ui.current_state == "RUNNING", "keyboard commits upgrade and resumes")
	ui.transition_to("RESULT_DEFEAT")
	await settle(12)
	check(focus_is_in(ui._screen_registry.get_screen("RESULT_DEFEAT")), "results initialize keyboard focus")
	await reach_and_activate(ui._screen_registry.get_screen("RESULT_DEFEAT"), "再来一局")
	check(ui.current_state == "CHARACTER_SELECT", "keyboard retries a finished run")
	await finish()
