extends SceneTree


const APP_SCENE_PATH: String = "res://scenes/app/app_bootstrap.tscn"
const MAP_ID: StringName = &"abandoned_dungeon"

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

	var ui_manager: Node = app.get_node_or_null("UIManager")
	_expect(ui_manager != null, "UIManager exists")
	if ui_manager == null:
		_finish()
		return

	ui_manager.call("start_developer_debug_run", {
		"character_id": &"mage",
		"map_id": MAP_ID
	})
	await process_frame

	var overlay: Control = app.find_child("RunLoadingOverlay", true, false) as Control
	_expect(overlay != null, "run loading overlay is created")
	_expect(overlay != null and overlay.visible, "run loading overlay is visible after start")
	_expect(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "run loading overlay blocks input while starting")

	for _index: int in range(24):
		await process_frame

	_expect(String(ui_manager.get("current_state")) == "RUNNING", "UIManager enters RUNNING after start")
	_expect(app.find_child("Main", true, false) != null, "run scene exists after start")
	_expect(overlay != null and not overlay.visible, "run loading overlay hides after initialization")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[verify_run_start_loading_overlay] PASS %s" % message)
		return
	_failed = true
	push_error("[verify_run_start_loading_overlay] FAIL %s" % message)


func _finish() -> void:
	quit(1 if _failed else 0)
