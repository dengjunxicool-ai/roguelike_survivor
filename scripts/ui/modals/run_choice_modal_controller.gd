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
const CARD_DESIGN_SIZE: Vector2 = Vector2(342.0, 608.0)
const CARD_COMPACT_SIZE: Vector2 = Vector2(300.0, 533.3333)
const CARD_INNER_GAP: float = 36.0
const CARD_COMPACT_INNER_GAP: float = 36.0
const CARD_TEXT_LINE_HEIGHT_MULTIPLIER: float = 1.2

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
	_clear_children(_level_up_options)
	_choice_card_cells.clear()
	_choice_card_buttons.clear()
	_choice_card_labels.clear()
	_choice_gap_spacers.clear()
	_prepare_choice_card_layout(_level_up_options)
	var options: Array[Dictionary] = _get_level_up_options_from_pool(LEVEL_UP_OPTION_COUNT)
	if options.is_empty():
		pending_level_up_count = 0
		call_deferred("_emit_transition", STATE_RUNNING)
		return

	for option: Dictionary in options:
		_add_upgrade_choice_card(_level_up_options, option, STATE_RUNNING, true)
	_finish_choice_card_layout(_level_up_options)


func refresh_curse_choice_modal() -> void:
	_clear_children(_curse_options)
	for option: Dictionary in _pick_dictionary_items(GameData.get_curse_choice_pool(), 3):
		_add_upgrade_choice_button(_curse_options, option, STATE_RUNNING, false)



func refresh_reward_modal() -> void:
	_clear_children(_reward_options)
	_choice_card_cells.clear()
	_choice_card_buttons.clear()
	_choice_card_labels.clear()
	_choice_gap_spacers.clear()
	_prepare_choice_card_layout(_reward_options)
	if pending_reward_kinds.is_empty():
		call_deferred("_emit_transition", STATE_RUNNING)
		return
	var reward_kind: String = pending_reward_kinds[0]
	var player: Node = _get_player()
	var options: Array[Dictionary] = _reward_pool.call("generate_reward_options", player, reward_kind)
	if options.is_empty():
		pending_reward_kinds.remove_at(0)
		call_deferred("_emit_transition", STATE_RUNNING)
		return
	for option: Dictionary in options:
		_add_upgrade_choice_card(_reward_options, option, STATE_RUNNING, false)
	_finish_choice_card_layout(_reward_options)


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

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	button.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title_label: Label = _add_card_label(column, _get_option_title(option), 22, VERTICAL_ALIGNMENT_CENTER)
	title_label.custom_minimum_size = Vector2(0, 48)

	var meta_label: Label = _add_card_label(column, _get_option_meta_text(option), 13, VERTICAL_ALIGNMENT_TOP)
	meta_label.custom_minimum_size = Vector2(0, 44)

	var effect_label: Label = _add_card_label(column, _get_option_effect_text(option), 14, VERTICAL_ALIGNMENT_CENTER)
	effect_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	effect_label.add_theme_constant_override("line_spacing", _get_line_spacing_for_font_size(14))

	var resize_callable: Callable = Callable(self, "_update_choice_card_sizes").bind(parent)
	if not parent.resized.is_connected(resize_callable):
		parent.resized.connect(resize_callable)
	call_deferred("_update_choice_card_sizes", parent)


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
	_choice_card_labels.append({
		"label": label,
		"font_size": font_size,
		"line_spacing": true
	})
	return label


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
	var parts: Array[String] = ["稀有度：%s" % String(option.get("rarity", "common")).to_upper()]
	var payload: Dictionary = _get_dictionary(option.get("payload", {}))
	var current_rarity: String = String(payload.get("current_rarity", ""))
	if current_rarity != "":
		parts.append("当前：%s" % current_rarity)
	var level_text: String = String(option.get("level_text", ""))
	if level_text != "":
		parts.append(level_text)
	var tags: Array[String] = _get_string_array(option.get("tags", []))
	if not tags.is_empty():
		parts.append("标签：%s" % " / ".join(tags.slice(0, mini(tags.size(), 4))))
	return "  |  ".join(parts)


func _get_option_effect_text(option: Dictionary) -> String:
	var summary: String = String(SkillEffectSummaryBuilderScript.build_for_option(option))
	var lines: Array[String] = [summary if summary != "" else "%s" % String(option.get("description", ""))]
	return "\n".join(lines)


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
