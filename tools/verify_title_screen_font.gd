extends SceneTree


const TitleScreenControllerScript: Script = preload("res://scripts/ui/screens/title_screen_controller.gd")
const REQUIRED_MAIN_TITLE: String = "Survivor"


func _init() -> void:
	var controller: RefCounted = TitleScreenControllerScript.new()
	var screen: Control = controller.call("build") as Control
	root.add_child(screen)
	screen.visible = true
	controller.call("update_layout", Vector2(1280, 720))
	await process_frame
	await process_frame

	var main_title: Label = _find_label_with_text(screen, REQUIRED_MAIN_TITLE)
	var failed: bool = false
	failed = _assert(main_title != null, "main title label exists") or failed
	if main_title != null:
		var font: Font = main_title.get_theme_font("font")
		failed = _assert(main_title.is_visible_in_tree(), "main title is visible in tree") or failed
		failed = _assert(main_title.size.y >= 60.0, "main title has drawable height") or failed
		failed = _assert(font != null and font.has_char("S".unicode_at(0)), "main title font supports Survivor glyphs") or failed
		failed = _assert(main_title.get_theme_color("font_color") == Color.WHITE, "main title font color is white") or failed

	print("[TitleScreenFontCheck] done failed=%s" % str(failed))
	quit(1 if failed else 0)


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
		print("[TitleScreenFontCheck] PASS ", message)
		return false
	push_error("[TitleScreenFontCheck] FAIL %s" % message)
	return true
