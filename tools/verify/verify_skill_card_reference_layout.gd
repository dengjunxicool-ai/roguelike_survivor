extends SceneTree


const RunChoiceModalControllerScript: Script = preload("res://scripts/ui/modals/run_choice_modal_controller.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parent := HBoxContainer.new()
	root.add_child(parent)

	var controller: RefCounted = RunChoiceModalControllerScript.new()
	var option: Dictionary = {
		"id": "skill_level_up:fire_attack_searing:2",
		"type": "skill_level_up",
		"display_name": "Reference Skill",
		"description": "Reference description text.",
		"rarity": "rare",
		"payload": {
			"skill_id": &"fire_attack_searing",
			"level": 2,
			"current_rarity": "normal",
			"target_rarity": "rare"
		}
	}

	controller.call("_add_upgrade_choice_card", parent, option, "RUNNING", false)
	await process_frame

	var button: Button = _first_button(parent)
	_expect(button != null, "creates a card button")
	if button != null:
		var title := button.find_child("SkillCardTitle", true, false) as Label
		var icon := button.find_child("SkillCardIconTexture", true, false) as TextureRect
		var description := button.find_child("SkillCardDescription", true, false) as Label
		var rarity := button.find_child("SkillCardRarity", true, false) as Label
		var values := button.find_child("SkillCardValues", true, false) as VBoxContainer
		var content_layer := button.find_child("SkillCardContentLayer", true, false) as Control
		_expect(title != null and title.text == "Reference Skill", "title is first-class content")
		_expect(title != null and title.get_theme_font_size("font_size") <= 23, "title font is compact enough for one-line skill names", title.get_theme_font_size("font_size") if title != null else 0)
		_expect(icon != null and icon.texture != null, "icon placeholder texture is loaded")
		_expect(description != null and description.text == "Reference description text.", "description uses option text")
		_expect(content_layer != null, "card uses an absolute content layer")
		_expect(_ratio_close(button.custom_minimum_size.x / button.custom_minimum_size.y, 720.0 / 1240.0), "card size matches the new background aspect ratio", button.custom_minimum_size)
		_expect(rarity != null and rarity.text == "稀有", "rarity section shows only the rarity name", rarity.text if rarity != null else "")
		_expect(rarity != null and not _has_extra_words(rarity.text), "rarity section has no extra prefix text", rarity.text if rarity != null else "")
		_expect(values != null, "values section is a row list")
		_expect(values != null and _value_rows(values).size() > 0, "values section has value rows")
		_expect(values != null and _value_rows(values).size() <= 3, "values section matches the three prepared background rows", _value_rows(values).size() if values != null else 0)
		_expect(values != null and _joined_value_text(values).contains("27%"), "values section shows scaled numeric summary", _joined_value_text(values) if values != null else "")
		_expect(values != null and not _has_extra_words(_joined_value_text(values)), "values section has no header or meta text", _joined_value_text(values) if values != null else "")
		_expect(values != null and not _joined_value_text(values).contains("searing_fire_path"), "values section does not expose internal ids", _joined_value_text(values) if values != null else "")
		if content_layer != null:
			_expect(_content_order(content_layer) == [
				"SkillCardTitle",
				"SkillCardIconFrame",
				"SkillCardDescription",
				"SkillCardRarity",
				"SkillCardValues"
			], "card content follows reference order", _content_order(content_layer))
			_expect(_is_vertical_reference_order(content_layer), "card content is positioned from top to bottom", _content_offsets(content_layer))
			_expect(_slot_close(description, 0.472, 0.626), "description slot is centered on the background description panel", _slot_bounds(description))
			_expect(_slot_close(rarity, 0.634, 0.684), "rarity slot is centered on the background rarity plaque", _slot_bounds(rarity))
			_expect(_slot_close(values, 0.684, 0.872), "values slot is centered on the background value rows", _slot_bounds(values))

	parent.queue_free()
	await process_frame
	if not _failed:
		print("[verify_skill_card_reference_layout] PASS")
	quit(1 if _failed else 0)


func _first_button(parent: Node) -> Button:
	for child: Node in parent.get_children():
		if child is Button:
			return child as Button
		var nested: Button = _first_button(child)
		if nested != null:
			return nested
	return null


func _content_order(parent: Node) -> Array[String]:
	var names: Array[String] = []
	if parent == null:
		return names
	for child: Node in parent.get_children():
		if child.name in [
			"SkillCardTitle",
			"SkillCardIconFrame",
			"SkillCardDescription",
			"SkillCardRarity",
			"SkillCardValues"
		]:
			names.append(str(child.name))
	return names


func _content_offsets(parent: Node) -> Array[float]:
	var offsets: Array[float] = []
	if parent == null:
		return offsets
	for name: String in _content_order(parent):
		var control := parent.get_node_or_null(name) as Control
		if control != null:
			offsets.append(control.anchor_top)
	return offsets


func _is_vertical_reference_order(parent: Node) -> bool:
	var offsets: Array[float] = _content_offsets(parent)
	if offsets.size() != 5:
		return false
	for index: int in range(1, offsets.size()):
		if offsets[index] <= offsets[index - 1]:
			return false
	return true


func _value_rows(values: VBoxContainer) -> Array[Node]:
	var rows: Array[Node] = []
	if values == null:
		return rows
	for child: Node in values.get_children():
		if child.name.begins_with("SkillCardValueRow"):
			rows.append(child)
	return rows


func _joined_value_text(values: VBoxContainer) -> String:
	var parts: Array[String] = []
	if values == null:
		return ""
	for row: Node in _value_rows(values):
		for child: Node in row.get_children():
			if child is Label:
				parts.append((child as Label).text)
	return "\n".join(parts)


func _has_extra_words(text: String) -> bool:
	for word: String in ["稀有度", "当前", "标签", "技能数值", "RARE", "normal"]:
		if text.contains(word):
			return true
	return false


func _ratio_close(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= 0.005


func _slot_close(control: Control, expected_top: float, expected_bottom: float) -> bool:
	if control == null:
		return false
	return absf(control.anchor_top - expected_top) <= 0.002 and absf(control.anchor_bottom - expected_bottom) <= 0.002


func _slot_bounds(control: Control) -> Dictionary:
	if control == null:
		return {}
	return {
		"top": control.anchor_top,
		"bottom": control.anchor_bottom
	}


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_card_reference_layout] FAIL %s actual=%s" % [label, str(actual)])
