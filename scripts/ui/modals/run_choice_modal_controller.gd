extends RefCounted
class_name RunChoiceModalController


signal transition_requested(state: String)


const STATE_RUNNING: String = "RUNNING"
const STATE_LEVEL_UP_MODAL: String = "LEVEL_UP_MODAL"
const STATE_RUN_REWARD_MODAL: String = "RUN_REWARD_MODAL"
const LEVEL_UP_OPTION_COUNT: int = 3
const UIResponsiveLayoutScript: Script = preload("res://scripts/ui/ui_responsive_layout.gd")
const UICommandDispatcherScript: Script = preload("res://scripts/ui/ui_command_dispatcher.gd")
const UICommandScript: Script = preload("res://scripts/ui/ui_command.gd")
const UIThemeServiceScript: Script = preload("res://scripts/ui/ui_theme_service.gd")
const CARD_DESIGN_SIZE: Vector2 = Vector2(342.0, 589.0)
const CARD_COMPACT_SIZE: Vector2 = Vector2(300.0, 516.6667)
const CARD_INNER_GAP: float = 36.0
const CARD_COMPACT_INNER_GAP: float = 36.0
const CARD_TEXT_LINE_HEIGHT_MULTIPLIER: float = 1.2
const DEFAULT_SKILL_CARD_ICON_TEXTURE: String = "res://icon.svg"
const SKILL_CARD_MAX_VALUE_ROWS: int = 3

const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")
const RunRewardPoolScript: Script = preload("res://scripts/upgrades/run_reward_pool.gd")
const SkillEffectSummaryBuilderScript: Script = preload("res://scripts/skills/skill_effect_summary_builder.gd")

var pending_level_up_count: int = 0
var pending_level: int = 1
var pending_reward_kinds: Array[String] = []

var _level_up_options: BoxContainer
var _curse_options: VBoxContainer
var _reward_options: BoxContainer
var _tree: SceneTree
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _upgrade_pool: RefCounted = UpgradePoolScript.new()
var _reward_pool: RefCounted = RunRewardPoolScript.new()
var _responsive_layout: RefCounted = UIResponsiveLayoutScript.new()
var _command_dispatcher: RefCounted = UICommandDispatcherScript.new()
var _choice_card_cells: Array[Control] = []
var _choice_card_buttons: Array[Button] = []
var _choice_card_labels: Array[Dictionary] = []
var _choice_gap_spacers: Array[Control] = []
var _choice_card_pools: Dictionary = {}


func setup(
	tree: SceneTree,
	level_up_options: BoxContainer,
	curse_options: VBoxContainer,
	reward_options: BoxContainer = null
) -> void:
	_tree = tree
	_level_up_options = level_up_options
	_curse_options = curse_options
	_reward_options = reward_options
	_rng.randomize()


func prewarm_choice_card_pools() -> void:
	_ensure_choice_card_pool(_level_up_options, LEVEL_UP_OPTION_COUNT)
	_hide_choice_card_pool(_level_up_options)
	_ensure_choice_card_pool(_reward_options, LEVEL_UP_OPTION_COUNT)
	_hide_choice_card_pool(_reward_options)


func reset_run() -> void:
	pending_level_up_count = 0
	pending_reward_kinds.clear()


func add_pending_level(new_level: int) -> void:
	pending_level_up_count += 1
	pending_level = new_level


func has_pending_level_up() -> bool:
	return pending_level_up_count > 0


func queue_reward(reward_kind: String) -> void:
	if reward_kind == "":
		return
	pending_reward_kinds.append(reward_kind)


func has_pending_reward() -> bool:
	return not pending_reward_kinds.is_empty()


func refresh_level_up_modal() -> void:
	var options: Array[Dictionary] = _get_level_up_options_from_pool(LEVEL_UP_OPTION_COUNT)
	if options.is_empty():
		pending_level_up_count = 0
		_hide_choice_card_pool(_level_up_options)
		call_deferred("_emit_transition", STATE_RUNNING)
		return

	_refresh_choice_card_modal(_level_up_options, options, STATE_RUNNING, true)


func refresh_curse_choice_modal() -> void:
	_clear_children(_curse_options)
	for option: Dictionary in _pick_dictionary_items(GameData.get_curse_choice_pool(), 3):
		_add_upgrade_choice_button(_curse_options, option, STATE_RUNNING, false)



func refresh_reward_modal() -> void:
	if pending_reward_kinds.is_empty():
		_hide_choice_card_pool(_reward_options)
		call_deferred("_emit_transition", STATE_RUNNING)
		return
	var reward_kind: String = pending_reward_kinds[0]
	var player: Node = _get_player()
	var options: Array[Dictionary] = _reward_pool.call("generate_reward_options", player, reward_kind)
	if options.is_empty():
		pending_reward_kinds.remove_at(0)
		_hide_choice_card_pool(_reward_options)
		call_deferred("_emit_transition", STATE_RUNNING)
		return
	_refresh_choice_card_modal(_reward_options, options, STATE_RUNNING, false)


func _get_available_level_options() -> Array[Dictionary]:
	var player: Node = _get_player()
	if player != null:
		return _get_level_up_options_from_pool(LEVEL_UP_OPTION_COUNT)

	return []


func _get_level_up_options_from_pool(count: int) -> Array[Dictionary]:
	var player: Node = _get_player()
	if player == null:
		return []

	var options: Array[Dictionary] = []
	var option_variants: Array = _upgrade_pool.call("generate_options", player, count)
	for option_variant: Variant in option_variants:
		var option_dictionary: Dictionary = _upgrade_option_to_dictionary(option_variant)
		if not option_dictionary.is_empty():
			options.append(option_dictionary)

	return options


func _upgrade_option_to_dictionary(option_variant: Variant) -> Dictionary:
	var option: RefCounted = option_variant as RefCounted
	if option != null and option.has_method("to_dictionary"):
		var dictionary_variant: Variant = option.call("to_dictionary")
		if dictionary_variant is Dictionary:
			var option_dictionary: Dictionary = dictionary_variant
			return option_dictionary

	if option_variant is Dictionary:
		var dictionary: Dictionary = option_variant
		return dictionary.duplicate(true)

	return {}


func _add_upgrade_choice_button(parent: VBoxContainer, option: Dictionary, return_state: String, consumes_pending_level: bool) -> void:
	var button: Button = _add_button(parent, "%s\n%s" % [
		_get_option_title(option),
		String(option.get("description", ""))
	])
	button.custom_minimum_size = Vector2(0, 86)
	button.pressed.connect(Callable(self, "_select_upgrade_option").bind(option, return_state, consumes_pending_level))


func _add_upgrade_choice_card(parent: BoxContainer, option: Dictionary, return_state: String, consumes_pending_level: bool) -> void:
	if _choice_card_buttons.is_empty():
		_add_choice_edge_spacer(parent)
	else:
		_add_choice_inner_gap(parent)

	var cell: CenterContainer = CenterContainer.new()
	cell.custom_minimum_size = CARD_DESIGN_SIZE
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(cell)

	var button: Button = Button.new()
	button.text = ""
	button.clip_contents = true
	button.custom_minimum_size = CARD_DESIGN_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.size_flags_stretch_ratio = 1.0
	button.add_theme_stylebox_override("normal", _create_card_style())
	button.add_theme_stylebox_override("hover", _create_card_style())
	button.add_theme_stylebox_override("pressed", _create_card_style())
	UIButtonSkin.apply_text_only(button)
	button.pressed.connect(Callable(self, "_select_upgrade_option").bind(option, return_state, consumes_pending_level))
	cell.add_child(button)
	_choice_card_cells.append(cell)
	_choice_card_buttons.append(button)

	_add_card_background(button, option)

	var content_layer: Control = Control.new()
	content_layer.name = "SkillCardContentLayer"
	content_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content_layer)

	var title_label: Label = _add_card_label(content_layer, _get_option_title(option), 23, VERTICAL_ALIGNMENT_CENTER)
	title_label.name = "SkillCardTitle"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38, 1.0))
	_set_card_slot(title_label, 0.14, 0.062, 0.86, 0.145)

	var icon_frame: Control = _add_card_icon(content_layer, option)
	_set_card_slot(icon_frame, 0.285, 0.165, 0.715, 0.405)

	var description_label: Label = _add_card_label(content_layer, _get_option_description_text(option), 15, VERTICAL_ALIGNMENT_CENTER)
	description_label.name = "SkillCardDescription"
	description_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70, 1.0))
	description_label.add_theme_constant_override("line_spacing", _get_line_spacing_for_font_size(15))
	_set_card_slot(description_label, 0.14, 0.472, 0.86, 0.626)

	var rarity_label: Label = _add_card_label(content_layer, _get_option_rarity_text(option), 18, VERTICAL_ALIGNMENT_CENTER)
	rarity_label.name = "SkillCardRarity"
	rarity_label.add_theme_color_override("font_color", Color(0.74, 0.84, 1.0, 1.0))
	_set_card_slot(rarity_label, 0.27, 0.634, 0.73, 0.684)

	var values: VBoxContainer = _add_card_value_rows(content_layer, option)
	_set_card_slot(values, 0.14, 0.684, 0.86, 0.872)

	var resize_callable: Callable = Callable(self, "_update_choice_card_sizes").bind(parent)
	if not parent.resized.is_connected(resize_callable):
		parent.resized.connect(resize_callable)
	call_deferred("_update_choice_card_sizes", parent)


func _refresh_choice_card_modal(container: BoxContainer, options: Array[Dictionary], return_state: String, consumes_pending_level: bool) -> void:
	if container == null:
		return
	_prepare_choice_card_layout(container)
	_ensure_choice_card_pool(container, LEVEL_UP_OPTION_COUNT)
	_activate_choice_card_pool(container)
	var pool: Array = _get_choice_card_pool(container)
	for index: int in range(pool.size()):
		var slot: Dictionary = pool[index]
		if index < options.size():
			_bind_choice_card(slot, options[index], return_state, consumes_pending_level)
		else:
			_set_choice_card_slot_visible(slot, false)
	call_deferred("_update_choice_card_sizes", container)


func _ensure_choice_card_pool(container: BoxContainer, count: int) -> void:
	if container == null:
		return
	var key: int = int(container.get_instance_id())
	if _choice_card_pools.has(key):
		return
	_choice_card_cells.clear()
	_choice_card_buttons.clear()
	_choice_card_labels.clear()
	_choice_gap_spacers.clear()
	_prepare_choice_card_layout(container)
	var pool: Array[Dictionary] = []
	_add_choice_edge_spacer(container)
	for index: int in range(count):
		if index > 0:
			_add_choice_inner_gap(container)
		pool.append(_create_choice_card_slot(container))
	_add_choice_edge_spacer(container)
	_choice_card_pools[key] = {
		"slots": pool,
		"cells": _choice_card_cells.duplicate(),
		"buttons": _choice_card_buttons.duplicate(),
		"labels": _choice_card_labels.duplicate(true),
		"gaps": _choice_gap_spacers.duplicate()
	}
	var resize_callable: Callable = Callable(self, "_update_choice_card_sizes").bind(container)
	if not container.resized.is_connected(resize_callable):
		container.resized.connect(resize_callable)


func _get_choice_card_pool(container: BoxContainer) -> Array:
	if container == null:
		return []
	var key: int = int(container.get_instance_id())
	var pool_data: Dictionary = _get_dictionary(_choice_card_pools.get(key, {}))
	return pool_data.get("slots", []) as Array


func _activate_choice_card_pool(container: BoxContainer) -> void:
	var key: int = int(container.get_instance_id())
	var pool_data: Dictionary = _get_dictionary(_choice_card_pools.get(key, {}))
	_choice_card_cells.clear()
	_choice_card_buttons.clear()
	_choice_card_labels.clear()
	_choice_gap_spacers.clear()
	for cell: Control in pool_data.get("cells", []):
		_choice_card_cells.append(cell)
	for button: Button in pool_data.get("buttons", []):
		_choice_card_buttons.append(button)
	for label_info: Dictionary in pool_data.get("labels", []):
		_choice_card_labels.append(label_info)
	for spacer: Control in pool_data.get("gaps", []):
		_choice_gap_spacers.append(spacer)


func _hide_choice_card_pool(container: BoxContainer) -> void:
	for slot_variant: Variant in _get_choice_card_pool(container):
		if slot_variant is Dictionary:
			_set_choice_card_slot_visible(slot_variant as Dictionary, false)


func _create_choice_card_slot(parent: BoxContainer) -> Dictionary:
	var label_start: int = _choice_card_labels.size()
	var cell: CenterContainer = CenterContainer.new()
	cell.custom_minimum_size = CARD_DESIGN_SIZE
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(cell)

	var button: Button = Button.new()
	button.text = ""
	button.clip_contents = true
	button.custom_minimum_size = CARD_DESIGN_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.size_flags_stretch_ratio = 1.0
	button.add_theme_stylebox_override("normal", _create_card_style())
	button.add_theme_stylebox_override("hover", _create_card_style())
	button.add_theme_stylebox_override("pressed", _create_card_style())
	UIButtonSkin.apply_text_only(button)
	cell.add_child(button)
	_choice_card_cells.append(cell)
	_choice_card_buttons.append(button)

	var background: TextureRect = TextureRect.new()
	background.name = "SkillCardBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	button.add_child(background)

	var content_layer: Control = Control.new()
	content_layer.name = "SkillCardContentLayer"
	content_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content_layer)

	var title_label: Label = _add_card_label(content_layer, "", 23, VERTICAL_ALIGNMENT_CENTER)
	title_label.name = "SkillCardTitle"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38, 1.0))
	_set_card_slot(title_label, 0.14, 0.062, 0.86, 0.145)

	var icon_frame: Control = _create_card_icon_slot(content_layer)
	_set_card_slot(icon_frame, 0.285, 0.165, 0.715, 0.405)
	var icon_texture: TextureRect = icon_frame.get_meta("icon_texture") as TextureRect

	var description_label: Label = _add_card_label(content_layer, "", 15, VERTICAL_ALIGNMENT_CENTER)
	description_label.name = "SkillCardDescription"
	description_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70, 1.0))
	description_label.add_theme_constant_override("line_spacing", _get_line_spacing_for_font_size(15))
	_set_card_slot(description_label, 0.14, 0.472, 0.86, 0.626)

	var rarity_label: Label = _add_card_label(content_layer, "", 18, VERTICAL_ALIGNMENT_CENTER)
	rarity_label.name = "SkillCardRarity"
	rarity_label.add_theme_color_override("font_color", Color(0.74, 0.84, 1.0, 1.0))
	_set_card_slot(rarity_label, 0.27, 0.634, 0.73, 0.684)

	var values: VBoxContainer = VBoxContainer.new()
	values.name = "SkillCardValues"
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_theme_constant_override("separation", 4)
	content_layer.add_child(values)
	_set_card_slot(values, 0.14, 0.684, 0.86, 0.872)

	var value_rows: Array[HBoxContainer] = []
	var value_icons: Array[TextureRect] = []
	var value_names: Array[Label] = []
	var value_amounts: Array[Label] = []
	for index: int in range(SKILL_CARD_MAX_VALUE_ROWS):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "SkillCardValueRow%d" % (index + 1)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		values.add_child(row)
		value_rows.append(row)

		var icon: TextureRect = TextureRect.new()
		icon.name = "SkillCardValueIcon"
		icon.custom_minimum_size = Vector2(22, 22)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _load_texture(DEFAULT_SKILL_CARD_ICON_TEXTURE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.self_modulate = Color(1.0, 0.52, 0.12, 0.95)
		row.add_child(icon)
		value_icons.append(icon)

		var name_label: Label = _add_value_row_label(row, "", 14, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.name = "SkillCardValueName"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_names.append(name_label)

		var value_label: Label = _add_value_row_label(row, "", 14, HORIZONTAL_ALIGNMENT_RIGHT)
		value_label.name = "SkillCardValueAmount"
		value_label.custom_minimum_size = Vector2(64, 0)
		value_amounts.append(value_label)

	var slot_labels: Array[Dictionary] = []
	for index: int in range(label_start, _choice_card_labels.size()):
		slot_labels.append(_choice_card_labels[index])
	return {
		"cell": cell,
		"button": button,
		"background": background,
		"title": title_label,
		"icon": icon_texture,
		"description": description_label,
		"rarity": rarity_label,
		"value_rows": value_rows,
		"value_icons": value_icons,
		"value_names": value_names,
		"value_amounts": value_amounts,
		"labels": slot_labels
	}


func _create_card_icon_slot(parent: Node) -> Control:
	var frame: Control = Control.new()
	frame.name = "SkillCardIconFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)

	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.name = "SkillCardIconTexture"
	texture_rect.custom_minimum_size = Vector2(122, 122)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(texture_rect)
	frame.set_meta("icon_texture", texture_rect)
	return frame


func _bind_choice_card(slot: Dictionary, option: Dictionary, return_state: String, consumes_pending_level: bool) -> void:
	var button: Button = slot.get("button") as Button
	if button == null:
		return
	for connection: Dictionary in button.pressed.get_connections():
		var callable: Callable = connection.get("callable")
		if button.pressed.is_connected(callable):
			button.pressed.disconnect(callable)
	button.pressed.connect(Callable(self, "_select_upgrade_option").bind(option, return_state, consumes_pending_level))
	var background: TextureRect = slot.get("background") as TextureRect
	var background_texture: Texture2D = _load_texture(_get_choice_card_background_texture(option))
	if background != null:
		background.texture = background_texture
		background.visible = background_texture != null
	var title: Label = slot.get("title") as Label
	if title != null:
		title.text = _get_option_title(option)
	var icon: TextureRect = slot.get("icon") as TextureRect
	if icon != null:
		icon.texture = _load_texture(_get_option_icon_texture(option))
	var description: Label = slot.get("description") as Label
	if description != null:
		description.text = _get_option_description_text(option)
	var rarity: Label = slot.get("rarity") as Label
	if rarity != null:
		rarity.text = _get_option_rarity_text(option)
	_bind_value_rows(slot, option)
	_set_choice_card_slot_visible(slot, true)


func _bind_value_rows(slot: Dictionary, option: Dictionary) -> void:
	var lines: Array[String] = _get_option_value_lines(option)
	var rows: Array = slot.get("value_rows", []) as Array
	var names: Array = slot.get("value_names", []) as Array
	var amounts: Array = slot.get("value_amounts", []) as Array
	var icons: Array = slot.get("value_icons", []) as Array
	for index: int in range(rows.size()):
		var row: HBoxContainer = rows[index] as HBoxContainer
		var visible: bool = index < lines.size()
		if row != null:
			row.visible = visible
		if not visible:
			continue
		var parts: Dictionary = _split_value_line(lines[index])
		var name_label: Label = names[index] as Label
		if name_label != null:
			name_label.text = str(parts.get("name", ""))
		var value_label: Label = amounts[index] as Label
		if value_label != null:
			value_label.text = str(parts.get("value", ""))
		var icon: TextureRect = icons[index] as TextureRect
		if icon != null:
			icon.texture = _load_texture(DEFAULT_SKILL_CARD_ICON_TEXTURE)


func _set_choice_card_slot_visible(slot: Dictionary, visible: bool) -> void:
	var cell: Control = slot.get("cell") as Control
	if cell != null:
		cell.visible = visible
	var button: Button = slot.get("button") as Button
	if button != null:
		button.disabled = not visible


func _prepare_choice_card_layout(container: BoxContainer) -> void:
	if container == null:
		return
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 0)


func _finish_choice_card_layout(parent: BoxContainer) -> void:
	if parent == null or _choice_card_buttons.is_empty():
		return
	_add_choice_edge_spacer(parent)


func _add_choice_edge_spacer(parent: BoxContainer) -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spacer.size_flags_stretch_ratio = 1.0
	parent.add_child(spacer)


func _add_choice_inner_gap(parent: BoxContainer) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(CARD_INNER_GAP, 0)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(spacer)
	_choice_gap_spacers.append(spacer)


func _add_card_background(parent: Button, option: Dictionary) -> void:
	var texture_path: String = _get_choice_card_background_texture(option)
	var texture: Texture2D = _load_texture(texture_path)
	if texture == null:
		return

	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	parent.add_child(texture_rect)


func _add_card_icon(parent: Node, option: Dictionary) -> Control:
	var frame: Control = Control.new()
	frame.name = "SkillCardIconFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)

	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.name = "SkillCardIconTexture"
	texture_rect.custom_minimum_size = Vector2(122, 122)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = _load_texture(_get_option_icon_texture(option))
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(texture_rect)
	return frame


func _add_card_value_rows(parent: Node, option: Dictionary) -> VBoxContainer:
	var values: VBoxContainer = VBoxContainer.new()
	values.name = "SkillCardValues"
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_theme_constant_override("separation", 4)
	parent.add_child(values)

	var lines: Array[String] = _get_option_value_lines(option)
	for index: int in range(mini(lines.size(), SKILL_CARD_MAX_VALUE_ROWS)):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "SkillCardValueRow%d" % (index + 1)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		values.add_child(row)

		var icon: TextureRect = TextureRect.new()
		icon.name = "SkillCardValueIcon"
		icon.custom_minimum_size = Vector2(22, 22)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _load_texture(DEFAULT_SKILL_CARD_ICON_TEXTURE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.self_modulate = Color(1.0, 0.52, 0.12, 0.95)
		row.add_child(icon)

		var parts: Dictionary = _split_value_line(lines[index])
		var name_label: Label = _add_value_row_label(row, str(parts.get("name", "")), 14, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.name = "SkillCardValueName"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var value_label: Label = _add_value_row_label(row, str(parts.get("value", "")), 14, HORIZONTAL_ALIGNMENT_RIGHT)
		value_label.name = "SkillCardValueAmount"
		value_label.custom_minimum_size = Vector2(64, 0)
	return values


func _get_choice_card_background_texture(option: Dictionary) -> String:
	for key: String in ["background_texture", "card_background_texture"]:
		var option_path: String = String(option.get(key, ""))
		if option_path != "":
			return option_path

	return UIThemeServiceScript.get_string(["choice_cards", "default_background_texture"], "")


func _add_card_label(parent: Node, text: String, font_size: int, vertical_alignment_value: VerticalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = vertical_alignment_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("line_spacing", _get_line_spacing_for_font_size(font_size))
	parent.add_child(label)
	_register_card_label(label, font_size, true)
	return label


func _add_value_row_label(parent: Node, text: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.38, 1.0))
	parent.add_child(label)
	_register_card_label(label, font_size, false)
	return label


func _register_card_label(label: Label, font_size: int, uses_line_spacing: bool) -> void:
	_choice_card_labels.append({
		"label": label,
		"font_size": font_size,
		"line_spacing": uses_line_spacing
	})


func _set_card_slot(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	if control == null:
		return
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _update_choice_card_sizes(container: BoxContainer) -> void:
	if container == null:
		return

	var card_count: int = maxi(_choice_card_buttons.size(), 1)
	var viewport_size: Vector2 = container.get_viewport().get_visible_rect().size
	var ui_scale: float = float(_responsive_layout.call("get_fit_scale", viewport_size))
	var compact: bool = bool(_responsive_layout.call("is_compact", viewport_size))
	var base_size: Vector2 = CARD_COMPACT_SIZE if compact else CARD_DESIGN_SIZE
	var inner_gap: float = (CARD_COMPACT_INNER_GAP if compact else CARD_INNER_GAP) * ui_scale
	var fixed_gap_width: float = inner_gap * float(maxi(card_count - 1, 0))
	var max_card_width: float = maxf((container.size.x - fixed_gap_width) / float(card_count), 1.0)
	var card_size: Vector2 = base_size * ui_scale
	if card_size.x > max_card_width:
		card_size.x = max_card_width
		card_size.y = card_size.x * (base_size.y / base_size.x)
	card_size = Vector2(floor(card_size.x), floor(card_size.y))
	for spacer: Control in _choice_gap_spacers:
		if is_instance_valid(spacer):
			spacer.custom_minimum_size = Vector2(floor(inner_gap), 0)
	for cell: Control in _choice_card_cells:
		if is_instance_valid(cell):
			cell.custom_minimum_size = card_size
			cell.size = card_size
	for button: Button in _choice_card_buttons:
		if is_instance_valid(button):
			button.custom_minimum_size = card_size
			button.size = card_size
	for item: Dictionary in _choice_card_labels:
		var label := item.get("label", null) as Label
		if label == null:
			continue
		var base_font_size: int = int(item.get("font_size", 14))
		var scaled_font_size: int = maxi(10, roundi(float(base_font_size) * ui_scale))
		label.add_theme_font_size_override("font_size", scaled_font_size)
		if bool(item.get("line_spacing", false)):
			label.add_theme_constant_override("line_spacing", _get_line_spacing_for_font_size(scaled_font_size))


func _create_card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color.TRANSPARENT
	style.shadow_size = 0
	return style


func _get_line_spacing_for_font_size(font_size: int) -> int:
	return ceili(float(font_size) * maxf(CARD_TEXT_LINE_HEIGHT_MULTIPLIER - 1.0, 0.0))


func _load_texture(path: String) -> Texture2D:
	return UIThemeServiceScript.load_texture(path)


func _select_upgrade_option(option: Dictionary, return_state: String, consumes_pending_level: bool) -> void:
	var player: Node = _get_player()
	var command_result_variant: Variant = _command_dispatcher.call("dispatch", UICommandScript.apply_choice_option(option), {
		"player": player,
		"tree": _tree
	})
	var command_result: Dictionary = _get_dictionary(command_result_variant)
	if bool(command_result.get("consumed_reward", false)) and pending_reward_kinds.size() > 0:
		pending_reward_kinds.remove_at(0)

	if consumes_pending_level:
		pending_level_up_count = maxi(pending_level_up_count - 1, 0)
		if pending_level_up_count > 0:
			transition_requested.emit(STATE_LEVEL_UP_MODAL)
			return

	transition_requested.emit(return_state)


func _add_choice_button(parent: VBoxContainer, option: Dictionary, return_state: String) -> void:
	var button: Button = _add_button(parent, "%s\n%s" % [
		_get_option_title(option),
		String(option.get("description", ""))
	])
	button.custom_minimum_size = Vector2(0, 86)
	button.pressed.connect(Callable(self, "_emit_transition").bind(return_state))


func _emit_transition(state: String) -> void:
	transition_requested.emit(state)


func _get_option_title(option: Dictionary) -> String:
	if option.has("display_name"):
		return String(option.get("display_name", "选项"))
	return String(option.get("title", option.get("id", "选项")))


func _get_option_meta_text(option: Dictionary) -> String:
	return _get_option_rarity_text(option)


func _get_option_rarity_text(option: Dictionary) -> String:
	var rarity: String = _string_from_variant(option.get("rarity", "common")).to_lower()
	match rarity:
		"normal":
			return "普通"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传说"
		_:
			return rarity


func _get_option_description_text(option: Dictionary) -> String:
	var description: String = _string_from_variant(option.get("description", ""))
	if description != "":
		return description
	var skill_id: StringName = _get_option_skill_id(option)
	if skill_id == &"":
		return ""
	var skill: Dictionary = GameData.get_skill(skill_id)
	return _string_from_variant(skill.get("description", ""))


func _get_option_effect_text(option: Dictionary) -> String:
	var summary: String = _string_from_variant(SkillEffectSummaryBuilderScript.build_for_option(option))
	return summary if summary != "" else _get_option_description_text(option)


func _get_option_value_lines(option: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for line: String in _get_option_effect_text(option).split("\n", false):
		var trimmed: String = line.strip_edges()
		if trimmed != "":
			lines.append(trimmed)
	return _prioritize_card_value_lines(lines)


func _prioritize_card_value_lines(lines: Array[String]) -> Array[String]:
	var picked: Array[String] = []
	var before_damage_pick: int = picked.size()
	_pick_first_matching_value_line(lines, picked, ["%", "攻击伤害"])
	if picked.size() == before_damage_pick:
		_pick_first_matching_value_line(lines, picked, ["伤害"])
	_pick_first_matching_value_line(lines, picked, ["范围", "px"])
	_pick_first_matching_value_line(lines, picked, ["Burning", "Chilled", "Conductive", "Cursed", "Judgment", "Instability", "层"])
	for line: String in lines:
		if picked.size() >= SKILL_CARD_MAX_VALUE_ROWS:
			break
		if not picked.has(line):
			picked.append(line)
	return picked


func _pick_first_matching_value_line(lines: Array[String], picked: Array[String], tokens: Array[String]) -> void:
	if picked.size() >= SKILL_CARD_MAX_VALUE_ROWS:
		return
	for line: String in lines:
		if picked.has(line):
			continue
		for token: String in tokens:
			if line.contains(token):
				picked.append(line)
				return


func _split_value_line(line: String) -> Dictionary:
	var status_parts: PackedStringArray = line.strip_edges().split(" ", false)
	if status_parts.size() >= 3 and status_parts[0] == "施加":
		return {
			"name": "附加 %s %s" % [status_parts[2], status_parts[1]],
			"value": status_parts[3] if status_parts.size() >= 4 else ""
		}

	var words: PackedStringArray = line.strip_edges().split(" ", false)
	if words.size() <= 1:
		return {
			"name": _clean_value_name(line),
			"value": ""
		}

	var name_parts: Array[String] = []
	for index: int in range(words.size() - 1):
		name_parts.append(words[index])
	return {
		"name": _clean_value_name(" ".join(name_parts)),
		"value": words[words.size() - 1]
	}


func _clean_value_name(name: String) -> String:
	if name.contains("攻击伤害") or name == "伤害":
		return "伤害"
	if name.contains("范围"):
		return "范围"
	if name.contains("持续"):
		return "持续"
	if name.contains("CD"):
		return "冷却"
	return name


func _get_option_icon_texture(option: Dictionary) -> String:
	var option_path: String = _first_texture_path(option)
	if option_path != "":
		return option_path

	var skill_id: StringName = _get_option_skill_id(option)
	if skill_id != &"":
		var skill: Dictionary = GameData.get_skill(skill_id)
		var skill_path: String = _first_texture_path(skill)
		if skill_path != "":
			return skill_path
	return DEFAULT_SKILL_CARD_ICON_TEXTURE


func _get_option_skill_id(option: Dictionary) -> StringName:
	var payload: Dictionary = _get_dictionary(option.get("payload", {}))
	for key: String in ["learn_skill_id", "skill_id"]:
		var payload_value: String = _string_from_variant(payload.get(key, ""))
		if payload_value != "":
			return StringName(payload_value)
	var direct_value: String = _string_from_variant(option.get("skill_id", ""))
	if direct_value != "":
		return StringName(direct_value)
	var option_id: String = _string_from_variant(option.get("id", ""))
	if option_id.begins_with("skill_level_up:"):
		var parts: PackedStringArray = option_id.split(":")
		if parts.size() >= 2 and parts[1] != "":
			return StringName(parts[1])
	return &""


func _first_texture_path(definition: Dictionary) -> String:
	for key: String in ["icon", "icon_texture", "texture"]:
		var path: String = _string_from_variant(definition.get(key, ""))
		if path != "":
			return path
	var visual: Dictionary = _get_dictionary(definition.get("visual", {}))
	for key: String in ["icon", "icon_texture", "texture"]:
		var visual_path: String = _string_from_variant(visual.get(key, ""))
		if visual_path != "":
			return visual_path
	return ""


func _pick_dictionary_items(source: Array[Dictionary], count: int) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var pool: Array = source.duplicate()
	while picked.size() < count and not pool.is_empty():
		var index: int = _rng.randi_range(0, pool.size() - 1)
		var item_variant: Variant = pool[index]
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			picked.append(item)
		pool.remove_at(index)
	return picked


func _get_player() -> Node:
	if _tree == null:
		return null
	return _tree.get_first_node_in_group(&"player")


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		child.queue_free()


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _string_from_variant(value: Variant) -> String:
	if value == null:
		return ""
	return str(value)


func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result


func _add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button
