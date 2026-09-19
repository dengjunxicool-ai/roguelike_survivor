extends SceneTree

const CharacterLoadoutControllerScript: Script = preload("res://scripts/ui/screens/character_loadout_controller.gd")

var _failed: bool = false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var controller: RefCounted = CharacterLoadoutControllerScript.new()
	var screen: Control = controller.call("build") as Control
	viewport.add_child(screen)
	screen.visible = true
	controller.call("refresh", &"mage")

	_assert(screen.find_child("CharacterCardList", true, false) != null, "CharacterCardList exists")
	_assert(screen.find_child("CharacterPortraitTexture", true, false) != null, "CharacterPortraitTexture exists")
	_assert(screen.find_child("CharacterRoleLabel", true, false) != null, "CharacterRoleLabel exists")
	_assert(screen.find_child("CharacterStatsList", true, false) != null, "CharacterStatsList exists")
	_assert(screen.find_child("CharacterTraitLabel", true, false) != null, "CharacterTraitLabel exists")
	_assert(screen.find_child("CharacterStartingSkillLabel", true, false) != null, "CharacterStartingSkillLabel exists")
	_assert(screen.find_child("CharacterConfirmButton", true, false) != null, "CharacterConfirmButton exists")
	_assert(screen.find_child("CharacterWeaponList", true, false) == null, "obsolete loadout list removed")
	var confirm_button: Button = screen.find_child("CharacterConfirmButton", true, false) as Button
	_assert(confirm_button != null and not confirm_button.disabled, "character confirm is enabled when starting skill resolves")

	var text_dump: String = _collect_text(screen)
	_assert(text_dump.contains("选择角色"), "screen title is readable")
	_assert(text_dump.contains("初始技能"), "starting skill text is shown")
	_assert(text_dump.contains("角色特质"), "trait text is shown")
	_assert(not text_dump.contains("武器"), "legacy loadout wording is hidden from character select")

	await _verify_layout(controller, screen, viewport)
	viewport.queue_free()
	await process_frame

	if _failed:
		push_error("verify_character_select_ui: FAIL")
		quit(1)
	else:
		print("verify_character_select_ui: PASS")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failed = true
		push_error("FAIL: %s" % message)


func _collect_text(node: Node) -> String:
	var parts: Array[String] = []
	var label: Label = node as Label
	if label != null:
		parts.append(label.text)
	var button: Button = node as Button
	if button != null:
		parts.append(button.text)
	for child: Node in node.get_children():
		parts.append(_collect_text(child))
	return "\n".join(parts)


func _verify_layout(controller: RefCounted, screen: Control, viewport: SubViewport) -> void:
	var row: BoxContainer = _find_content_row(screen)
	_assert(row != null, "character content row exists")
	if row == null:
		return
	_assert(row.name == "CharacterContentRow", "character content row is named")
	var scroll: ScrollContainer = row.get_parent().get_parent() as ScrollContainer
	# At these widths the desktop panel minima are 260 + 320 + 320,
	# with two 16px gaps, 56px outer margins, and the vertical scrollbar.
	var threshold: int = 988 + ceili(scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	var widths: Array[int] = [1280, 720, 900, threshold - 1, threshold, threshold + 1, 1280]
	for width: int in widths:
		viewport.size = Vector2i(width, 720)
		controller.call("update_layout", Vector2(viewport.size))
		await _settle_layout()
		_assert(screen.size.is_equal_approx(Vector2(viewport.size)), "character actual viewport is %dx720" % width)
		_assert(row.vertical == (width < threshold), "character orientation fits panel minima at width %d (threshold %d)" % [width, threshold])
		var usable: Rect2 = scroll.get_global_rect()
		usable.size.x = minf(usable.size.x, float(width) - 56.0)
		if scroll.get_v_scroll_bar().visible:
			usable.size.x -= scroll.get_v_scroll_bar().size.x
		_assert(_verify_horizontal_bounds(row, usable, width), "character rendered content stays within viewport at width %d" % width)
		var confirm: Control = screen.find_child("CharacterConfirmButton", true, false) as Control
		scroll.ensure_control_visible(confirm)
		await _settle_layout()
		_assert(scroll.get_global_rect().encloses(confirm.get_global_rect()), "character confirm is reachable at width %d" % width)
		scroll.scroll_vertical = 0


func _settle_layout() -> void:
	for frame: int in range(8):
		await process_frame


func _verify_horizontal_bounds(node: Node, usable: Rect2, width: int) -> bool:
	var in_bounds: bool = true
	var control: Control = node as Control
	if control != null and control.is_visible_in_tree():
		var rect: Rect2 = control.get_global_rect()
		in_bounds = rect.position.x >= usable.position.x - 1.0 and rect.end.x <= usable.end.x + 1.0
		if not in_bounds:
			print("Character overflow at %d: %s %s outside %s" % [width, control.name, rect, usable])
	for child: Node in node.get_children():
		in_bounds = _verify_horizontal_bounds(child, usable, width) and in_bounds
	return in_bounds


func _find_content_row(screen: Control) -> BoxContainer:
	var named_row: BoxContainer = screen.find_child("CharacterContentRow", true, false) as BoxContainer
	if named_row != null:
		return named_row
	var list_panel: Control = screen.find_child("CharacterListPanel", true, false) as Control
	return list_panel.get_parent() as BoxContainer if list_panel != null else null
