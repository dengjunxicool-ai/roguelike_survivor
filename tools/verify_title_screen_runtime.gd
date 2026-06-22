extends SceneTree


const APP_SCENE_PATH: String = "res://scenes/app_bootstrap.tscn"
const REQUIRED_MAIN_TITLE: String = "Survivor"


func _init() -> void:
	var packed_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	var failed: bool = false
	failed = _assert(packed_scene != null, "app bootstrap scene loads") or failed
	if packed_scene == null:
		_finish(failed)
		return

	var app: Node = packed_scene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var ui_manager: Node = app.get_node_or_null("UIManager")
	failed = _assert(ui_manager != null, "UIManager exists") or failed
	if ui_manager != null:
		print("[TitleScreenRuntimeCheck] viewport rect=", ui_manager.get_viewport().get_visible_rect())
		failed = _assert(String(ui_manager.get("current_state")) == "TITLE", "UIManager reaches TITLE") or failed

	var title_screen: Control = app.find_child("TITLE", true, false) as Control
	failed = _assert(title_screen != null, "TITLE screen exists in runtime tree") or failed
	failed = _assert(title_screen != null and title_screen.visible, "TITLE screen is visible") or failed

	var title_panel: Control = app.find_child("TitlePanel", true, false) as Control
	if title_panel != null:
		print("[TitleScreenRuntimeCheck] title panel rect=", title_panel.get_global_rect())

	var main_title: Label = _find_label_with_text(app, REQUIRED_MAIN_TITLE)
	failed = _assert(main_title != null, "runtime Survivor label exists") or failed
	if main_title != null:
		var title_rect: Rect2 = main_title.get_global_rect()
		print("[TitleScreenRuntimeCheck] title rect=", title_rect)
		print("[TitleScreenRuntimeCheck] title color=", main_title.get_theme_color("font_color"))
		failed = _assert(main_title.is_visible_in_tree(), "runtime Survivor label visible in tree") or failed
		failed = _assert(title_rect.position.x >= 300.0 and title_rect.position.y >= 70.0, "runtime Survivor uses design-space layout") or failed
		failed = _assert(title_rect.size.y >= 60.0, "runtime Survivor label has drawable height") or failed
		failed = _assert(main_title.get_theme_color("font_color") == Color.WHITE, "runtime Survivor label color is white") or failed
	_finish(failed)


func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child: Node in node.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null


func _assert(condition: bool, message: String) -> bool:
	if condition:
		print("[TitleScreenRuntimeCheck] PASS ", message)
		return false
	push_error("[TitleScreenRuntimeCheck] FAIL %s" % message)
	return true


func _finish(failed: bool) -> void:
	print("[TitleScreenRuntimeCheck] done failed=%s" % str(failed))
	quit(1 if failed else 0)
