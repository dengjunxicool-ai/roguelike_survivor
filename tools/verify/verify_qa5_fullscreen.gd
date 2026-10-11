extends "res://tools/verify/qa_app_fixture.gd"
const Settings = preload("res://scripts/ui/ui_settings_service.gd")

func run() -> void:
	var service: RefCounted = Settings.new()
	app = APP.instantiate()
	root.add_child(app)
	await settle(12)
	ui = app.get_node("UIManager")
	ui.transition_to("SETTINGS")
	await settle(12)
	var controller: RefCounted = ui._settings_controller
	var button: CheckBox = controller._fullscreen_button
	if Engine.is_embedded_in_editor():
		check(button.disabled, "embedded window does not offer a nonworking fullscreen toggle")
		check(not button.button_pressed, "embedded checkbox reflects actual window mode")
	elif DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(800,600))
		await settle(12)
		button.set_pressed_no_signal(false)
		await click(button)
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "actual settings click enters fullscreen")
		check(DisplayServer.window_get_size() == DisplayServer.screen_get_size(), "fullscreen covers the display")
		check(SaveManager.get_fullscreen_enabled(), "successful fullscreen toggle persists")
		await click(button)
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "actual settings click exits fullscreen")
		check(DisplayServer.window_get_size() == Vector2i(800,600), "fullscreen roundtrip restores window size")
		check(not SaveManager.get_fullscreen_enabled(), "windowed preference persists")
		check(service.call("apply_window_mode", false) == true, "window service reports successful application")
	else:
		check(service.call("apply_window_mode", true) == false, "headless window cannot report fullscreen success")
	await finish()
