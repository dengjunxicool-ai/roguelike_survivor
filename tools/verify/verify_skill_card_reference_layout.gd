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
		"display_name": "Reference Skill Lv2",
		"description": "提升 Reference Skill 至 Lv2。",
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
		_verify_card(button, "direct")

	var pooled_parent := HBoxContainer.new()
	root.add_child(pooled_parent)
	var slot_variant: Variant = controller.call("_create_choice_card_slot", pooled_parent)
	if slot_variant is Dictionary:
		var pooled_slot: Dictionary = slot_variant
		controller.call("_bind_choice_card", pooled_slot, option, "RUNNING", false)
		await process_frame
		var pooled_button: Button = pooled_slot.get("button") as Button
		_expect(pooled_button != null, "pooled card creates a button")
		if pooled_button != null:
			_verify_card(pooled_button, "pooled")
	else:
		_expect(false, "pooled card slot can be created", slot_variant)

	pooled_parent.queue_free()
	parent.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if not _failed:
		print("[verify_skill_card_reference_layout] PASS")
	quit(1 if _failed else 0)


func _verify_card(button: Button, context: String) -> void:
	_expect(button.tooltip_text == "", "%s card does not store option tooltip text" % context, button.tooltip_text)
	var title := button.find_child("SkillCardTitle", true, false) as Label
	var icon := button.find_child("SkillCardIconTexture", true, false) as TextureRect
	var description := button.find_child("SkillCardDescription", true, false) as Label
	var rarity := button.find_child("SkillCardRarity", true, false) as Label
	var values := button.find_child("SkillCardValues", true, false) as VBoxContainer
	var content_layer := button.find_child("SkillCardContentLayer", true, false) as Control

	_expect(title != null and title.text == "Reference Skill Lv2", "%s title is first-class content" % context)
	_expect(title != null and title.get_theme_font_size("font_size") <= 23, "%s title font is compact enough" % context, title.get_theme_font_size("font_size") if title != null else 0)
	_expect(icon != null and icon.texture != null, "%s icon placeholder texture is loaded" % context)
	_expect(description != null and description.visible and description.text == "提升 Reference Skill 至 Lv2。", "%s description stores plain option text" % context, description.text if description != null else "")
	_expect(content_layer != null, "%s card uses an absolute content layer" % context)
	_expect(_ratio_close(button.custom_minimum_size.x / button.custom_minimum_size.y, 720.0 / 1240.0), "%s card size matches background aspect ratio" % context, button.custom_minimum_size)
	_expect(rarity != null and rarity.text == "稀有", "%s rarity section shows only rarity name" % context, rarity.text if rarity != null else "")
	_expect(values != null and _value_rows(values).size() > 0, "%s values section has value rows" % context)
	_expect(values != null and _value_rows(values).size() <= 3, "%s values section matches prepared rows" % context, _value_rows(values).size() if values != null else 0)
	_expect(values != null and _joined_value_text(values).contains("27%"), "%s values section shows scaled numeric summary" % context, _joined_value_text(values) if values != null else "")
	_expect(values != null and not _joined_value_text(values).contains("searing_fire_path"), "%s values section does not expose internal ids" % context, _joined_value_text(values) if values != null else "")

	button.mouse_entered.emit()
	_expect(description != null and description.visible and description.text == "提升 Reference Skill 至 Lv2。", "%s whole-card hover does not alter description" % context, description.text if description != null else "")
	button.mouse_exited.emit()

	_expect(button.find_child("SkillCardDescriptionParts", true, false) == null, "%s card does not create split description parts" % context)
	_expect(button.find_child("SkillCardDescriptionDisplayName", true, false) == null, "%s card does not create display-name hover text" % context)
	_expect(button.find_child("SkillCardDescriptionHelpIcon", true, false) == null, "%s card does not show a ? icon after display_name" % context)
	_expect(button.find_child("SkillCardDisplayNameHoverArea", true, false) == null, "%s card removes display-name hover interaction" % context)
	_expect(button.find_child("SkillCardDescriptionHelpPoll", true, false) == null, "%s card does not create description hover polling" % context)

	if content_layer != null:
		_expect(_content_order(content_layer) == [
			"SkillCardTitle",
			"SkillCardIconFrame",
			"SkillCardDescription",
			"SkillCardRarity",
			"SkillCardValues"
		], "%s card content follows reference order" % context, _content_order(content_layer))
		_expect(_is_vertical_reference_order(content_layer), "%s card content is positioned top to bottom" % context, _content_offsets(content_layer))
		_expect(_slot_close(description, 0.472, 0.626), "%s description slot is centered on background panel" % context, _slot_bounds(description))
		_expect(_slot_close(rarity, 0.634, 0.684), "%s rarity slot is centered on plaque" % context, _slot_bounds(rarity))
		_expect(_slot_close(values, 0.684, 0.872), "%s values slot is centered on rows" % context, _slot_bounds(values))


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
