extends SceneTree


const APP_SCENE_PATH: String = "res://scenes/app/app_bootstrap.tscn"

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "app bootstrap scene loads")
	if packed_scene == null:
		_finish()
		return
	var app: Node = packed_scene.instantiate()
	root.add_child(app)
	for _index: int in range(4):
		await process_frame
	var ui: Node = app.get_node_or_null("UIManager")
	_expect(ui != null, "UIManager exists")
	if ui == null:
		_finish()
		return
	_expect(String(ui.get("current_state")) == "TITLE", "app reaches TITLE")
	ui.call("transition_to", "CHARACTER_SELECT")
	_dispatch_cancel(true)
	_expect(String(ui.get("current_state")) == "CHARACTER_SELECT", "ui_cancel leaves character selection unchanged")
	_dispatch_cancel(false)
	ui.call("_on_loadout_confirmed", &"mage")
	_expect(String(ui.get("current_state")) == "MAP_SELECT", "loadout controller flow reaches MAP_SELECT")
	ui.call("_start_run", &"abandoned_dungeon")
	for _index: int in range(120):
		await process_frame
		if String(ui.get("current_state")) == "RUNNING":
			break
	_expect(String(ui.get("current_state")) == "RUNNING", "controller start flow reaches RUNNING")
	_expect(not paused, "running scene is unpaused")

	var pause_button: Button = app.find_child("PauseButton", true, false) as Button
	_expect(pause_button != null, "runtime pause button exists")
	if pause_button != null:
		print("[PauseInputRuntimeCheck] pause focus_mode=", pause_button.focus_mode)
		_expect(pause_button.focus_mode == Control.FOCUS_ALL, "pause button supports keyboard focus with FOCUS_ALL")

	_dispatch_cancel(false)
	_expect(String(ui.get("current_state")) == "RUNNING", "released ui_cancel does not pause")
	_dispatch_cancel_echo()
	_expect(String(ui.get("current_state")) == "RUNNING", "echoed ui_cancel does not pause")
	_dispatch_cancel(true)
	_expect(String(ui.get("current_state")) == "PAUSE_MENU", "pressed ui_cancel transitions RUNNING to PAUSE_MENU")
	_expect(paused, "pause menu pauses the scene tree")
	_expect(root.is_input_handled(), "pause action is consumed")
	_dispatch_cancel(false)
	_expect(String(ui.get("current_state")) == "PAUSE_MENU", "released ui_cancel does not resume")
	_dispatch_cancel_echo()
	_expect(String(ui.get("current_state")) == "PAUSE_MENU", "echoed ui_cancel does not resume")
	_dispatch_cancel(true)
	_expect(String(ui.get("current_state")) == "RUNNING", "pressed ui_cancel transitions PAUSE_MENU to RUNNING")
	_expect(not paused, "resume unpauses the scene tree")
	_expect(root.is_input_handled(), "resume action is consumed")
	_dispatch_cancel(false)
	if pause_button != null and pause_button.focus_mode == Control.FOCUS_ALL:
		pause_button.grab_focus()
		_expect(pause_button.has_focus(), "visible pause button can receive keyboard focus")
	app.queue_free()
	await process_frame
	_finish()


func _dispatch_cancel(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = pressed
	root.push_input(event, true)


func _dispatch_cancel_echo() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = true
	root.push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PauseInputRuntimeCheck] PASS ", message)
		return
	_failed = true
	push_error("[PauseInputRuntimeCheck] FAIL %s" % message)


func _finish() -> void:
	print("[PauseInputRuntimeCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)
