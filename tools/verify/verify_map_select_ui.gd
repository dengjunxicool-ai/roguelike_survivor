extends SceneTree


const MapSelectControllerScript: Script = preload("res://scripts/ui/screens/map_select_controller.gd")

var _failed: bool = false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var controller: RefCounted = MapSelectControllerScript.new()
	var screen: Control = controller.call("build") as Control
	viewport.add_child(screen)
	screen.visible = true
	controller.call("refresh", &"mage")

	_assert(screen != null, "map select screen builds")
	_assert(screen.find_child("MapSoulLabel", true, false) != null, "map select shows soul counter")
	_assert(screen.find_child("MapPreviewTexture", true, false) != null, "map select shows map preview texture")
	_assert(screen.find_child("MapEnemyPreviewList", true, false) != null, "map select shows enemy preview list")
	_assert(screen.find_child("MapLoadoutCharacterLabel", true, false) != null, "map select shows selected character")
	_assert(screen.find_child("MapLoadoutSkillLabel", true, false) != null, "map select shows starting skill")
	_assert(screen.find_child("MapLoadoutThreatLabel", true, false) != null, "map select shows threat level")
	_assert(screen.find_child("MapLoadoutWeaponLabel", true, false) == null, "map select does not show obsolete loadout label")
	_assert(screen.find_child("MapStartButton", true, false) != null, "map select has start button")

	var text: String = _collect_text(screen)
	_assert(text.contains("战斗准备"), "map select title is readable Chinese")
	_assert(text.contains("开始挑战"), "map select start button is readable Chinese")
	_assert(text.contains("废弃地牢"), "map select uses readable map names")
	_assert(not text.contains("武器"), "map select text does not expose obsolete loadout concept")

	await _verify_layout(controller, screen, viewport)
	viewport.queue_free()
	await process_frame

	if _failed:
		push_error("verify_map_select_ui: FAIL")
		quit(1)
	else:
		print("verify_map_select_ui: PASS")
		quit(0)


func _collect_text(node: Node) -> String:
	var parts: Array[String] = []
	_collect_text_recursive(node, parts)
	return "\n".join(parts)


func _collect_text_recursive(node: Node, parts: Array[String]) -> void:
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_text_recursive(child, parts)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	_failed = true
	push_error("FAIL %s" % message)


func _verify_layout(controller: RefCounted, screen: Control, viewport: SubViewport) -> void:
	var row: BoxContainer = _find_content_row(screen)
	_assert(row != null, "map content row exists")
	if row == null:
		return
	_assert(row.name == "MapContentRow", "map content row is named")
	var scroll: ScrollContainer = row.get_parent().get_parent() as ScrollContainer
	controller.call("update_layout", Vector2(1280, 720))
	await _settle_layout()
	# Read the actual rendered desktop minimum, including enemy-preview content.
	var threshold: int = ceili(row.get_combined_minimum_size().x) + 56 + ceili(scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	var widths: Array[int] = [1280, 720, 900, threshold - 1, threshold, threshold + 1, 1280]
	for width: int in widths:
		viewport.size = Vector2i(width, 720)
		controller.call("update_layout", Vector2(viewport.size))
		await _settle_layout()
		_assert(screen.size.is_equal_approx(Vector2(viewport.size)), "map actual viewport is %dx720" % width)
		_assert(row.vertical == (width < threshold), "map orientation fits panel minima at width %d (threshold %d)" % [width, threshold])
		var usable: Rect2 = scroll.get_global_rect()
		usable.size.x = minf(usable.size.x, float(width) - 56.0)
		if scroll.get_v_scroll_bar().visible:
			usable.size.x -= scroll.get_v_scroll_bar().size.x
		_assert(_verify_horizontal_bounds(row, usable, width), "map rendered content stays within viewport at width %d" % width)
		await _verify_detail_reachable(screen, scroll, width)
		scroll.scroll_vertical = 0


func _verify_detail_reachable(screen: Control, outer_scroll: ScrollContainer, width: int) -> void:
	var enemies: Control = screen.find_child("MapEnemyPreviewList", true, false) as Control
	var detail_scroll: ScrollContainer = enemies.get_parent().get_parent() as ScrollContainer
	_assert(detail_scroll.size.y >= 160.0, "map detail scroll has useful height at width %d (actual %.0f)" % [width, detail_scroll.size.y])
	_assert(enemies.get_child_count() > 0, "map has enemy preview content at width %d" % width)
	if enemies.get_child_count() == 0:
		return
	var final_preview: Control = enemies.get_child(enemies.get_child_count() - 1) as Control
	detail_scroll.ensure_control_visible(final_preview)
	await _settle_layout()
	outer_scroll.ensure_control_visible(detail_scroll)
	await _settle_layout()
	_assert(detail_scroll.scroll_vertical > 0, "map final enemy preview requires and supports scrolling at width %d" % width)
	_assert(detail_scroll.get_global_rect().encloses(final_preview.get_global_rect()), "map final enemy preview fits detail scroll at width %d" % width)
	_assert(outer_scroll.get_global_rect().encloses(final_preview.get_global_rect()), "map final enemy preview reaches visible outer scroll at width %d" % width)
	var start: Control = screen.find_child("MapStartButton", true, false) as Control
	outer_scroll.ensure_control_visible(start)
	await _settle_layout()
	_assert(outer_scroll.get_global_rect().encloses(start.get_global_rect()), "map start action is reachable at width %d" % width)
	detail_scroll.scroll_vertical = 0


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
			print("Map overflow at %d: %s %s outside %s; minimum %s; parent %s minimum %s" % [width, control.name, rect, usable, control.get_combined_minimum_size(), (control.get_parent() as Control).get_global_rect(), (control.get_parent() as Control).get_combined_minimum_size()])
	for child: Node in node.get_children():
		in_bounds = _verify_horizontal_bounds(child, usable, width) and in_bounds
	return in_bounds


func _find_content_row(screen: Control) -> BoxContainer:
	var named_row: BoxContainer = screen.find_child("MapContentRow", true, false) as BoxContainer
	if named_row != null:
		return named_row
	var preview_texture: Control = screen.find_child("MapPreviewTexture", true, false) as Control
	if preview_texture == null:
		return null
	var preview_layout: Node = preview_texture.get_parent()
	var preview_margin: Node = preview_layout.get_parent() if preview_layout != null else null
	var preview_panel: Node = preview_margin.get_parent() if preview_margin != null else null
	return preview_panel.get_parent() as BoxContainer if preview_panel != null else null
