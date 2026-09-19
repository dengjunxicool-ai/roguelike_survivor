extends SceneTree


const APP_SCENE_PATH: String = "res://scenes/app/app_bootstrap.tscn"
const REQUIRED_MAIN_TITLE: String = "Survivor"
const TitleScreenControllerScript: Script = preload("res://scripts/ui/screens/title_screen_controller.gd")


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
	failed = await _verify_minimum_viewport_menu() or failed
	_finish(failed)


func _verify_minimum_viewport_menu() -> bool:
	var failed: bool = false
	var controller: RefCounted = TitleScreenControllerScript.new()
	var screen: Control = controller.call("build") as Control
	root.add_child(screen)
	screen.visible = true
	controller.call("reveal_actions")
	await process_frame
	await process_frame
	var menu: Control = screen.find_child("ActionMenu", true, false) as Control
	failed = _assert(menu != null, "action menu exists") or failed
	if menu == null:
		screen.queue_free()
		return failed
	var desktop_rect: Rect2 = menu.get_global_rect()
	controller.call("update_layout", Vector2(320, 240))
	await process_frame
	await process_frame
	await process_frame
	var menu_rect: Rect2 = menu.get_global_rect()
	print("[TitleScreenRuntimeCheck] minimum viewport menu rect=", menu_rect, " requested size=", menu.custom_minimum_size)
	failed = _assert(menu.custom_minimum_size.x > 0.0 and menu.custom_minimum_size.y > 0.0, "320x240 menu requested size is positive") or failed
	failed = _assert(menu_rect.size.x > 0.0 and menu_rect.size.y > 0.0, "320x240 menu drawable size is positive") or failed
	failed = _assert(menu_rect.position.x >= 0.0 and menu_rect.end.x <= 320.0, "320x240 menu stays within viewport width") or failed
	failed = _assert(menu_rect.position.y >= 0.0 and menu_rect.position.y < 240.0, "320x240 menu top stays inside viewport") or failed
	failed = _assert(menu_rect.end.y <= 240.0, "320x240 menu bottom stays inside viewport") or failed
	var buttons: Array[Node] = menu.find_children("*", "Button", true, false)
	failed = _assert(not buttons.is_empty(), "action menu contains buttons") or failed
	if not buttons.is_empty():
		var last_action: Button = buttons.back() as Button
		var ancestor: Node = last_action.get_parent()
		while ancestor != null and not ancestor is ScrollContainer:
			ancestor = ancestor.get_parent()
		var scroll: ScrollContainer = ancestor as ScrollContainer
		failed = _assert(scroll != null, "last action has a scroll host") or failed
		if scroll != null:
			failed = _assert(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "320x240 action list has vertical overflow") or failed
			scroll.ensure_control_visible(last_action)
			await process_frame
			await process_frame
			var last_rect: Rect2 = last_action.get_global_rect()
			var scroll_rect: Rect2 = scroll.get_global_rect()
			failed = _assert(scroll.scroll_vertical > 0, "last action can be reached by vertical scrolling") or failed
			failed = _assert(last_rect.position.y >= scroll_rect.position.y - 1.0 and last_rect.end.y <= scroll_rect.end.y + 1.0, "last action fits inside visible scroll area") or failed
	controller.call("update_layout", Vector2(1280, 720))
	await process_frame
	await process_frame
	await process_frame
	failed = _assert(menu.get_global_rect().is_equal_approx(desktop_rect), "desktop menu geometry survives compact resize") or failed
	screen.queue_free()
	return failed


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
