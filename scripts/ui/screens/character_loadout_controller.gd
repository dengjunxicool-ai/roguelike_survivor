extends RefCounted
class_name CharacterLoadoutController


signal loadout_confirmed(character_id: StringName, weapon_id: StringName)
signal back_requested


const UIDisplayHelperScript: Script = preload("res://scripts/ui/ui_display_helper.gd")
const CharacterLoadoutTextScript: Script = preload("res://scripts/ui/screens/character_loadout_text.gd")
const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")
const CharacterLoadoutViewModelBuilderScript: Script = preload("res://scripts/ui/screens/character_loadout_view_model_builder.gd")
const UICommandDispatcherScript: Script = preload("res://scripts/ui/ui_command_dispatcher.gd")
const UICommandScript: Script = preload("res://scripts/ui/ui_command.gd")
const NAV_HEIGHT: float = 72.0
const NAV_BUTTON_SIZE: Vector2 = Vector2(128, 64)
const CAROUSEL_SIZE: Vector2 = Vector2(300, 340)
const CARD_SIZE: Vector2 = Vector2(300, 340)
const PORTRAIT_SIZE: Vector2 = Vector2(224, 238)
const SIDE_BUTTON_SIZE: Vector2 = Vector2(44, 240)
const WEAPON_GRID_COLUMNS: int = 4
const WEAPON_GRID_GAP: int = 24
const WEAPON_CELL_ICON_INSET_RATIO: float = 0.125
const DETAIL_HEIGHTS: Dictionary = {
	"role": 56.0,
	"stats": 108.0,
	"trait": 150.0,
	"drawback": 64.0,
	"difficulty": 48.0,
	"weapon_name": 42.0,
	"weapon_description": 170.0,
	"weapon_branch": 132.0,
	"lock": 58.0
}

var selected_character_id: StringName = &"mage"
var selected_weapon_id: StringName = &"fire_staff"

var _screen: Control
var _carousel: HBoxContainer
var _weapon_grid: GridContainer
var _description_labels: Dictionary = {}
var _action_button: Button
var _carousel_index: int = 0
var _carousel_tween: Tween
var _layout_scale: float = 1.0
var _layout_controls: Dictionary = {}
var _command_dispatcher: RefCounted = UICommandDispatcherScript.new()
var _view_model_builder: RefCounted = CharacterLoadoutViewModelBuilderScript.new()
var _view_model: Dictionary = {}


func build() -> Control:
	_screen = Control.new()
	_screen.name = "CHARACTER_SELECT"
	_screen.visible = false
	_screen.z_index = 10
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.055, 0.06, 0.07, 0.96)
	_screen.add_child(background)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	_screen.add_child(root)

	_build_nav(root)
	_build_content(root)
	return _screen


func refresh(character_id: StringName = &"", weapon_id: StringName = &"") -> void:
	if character_id != &"":
		selected_character_id = character_id
	if weapon_id != &"":
		selected_weapon_id = weapon_id

	_refresh_current_character(character_id != &"")


func _refresh_current_character(sync_index_from_selected: bool) -> void:
	_view_model = _view_model_builder.call("build", selected_character_id, selected_weapon_id, _carousel_index, sync_index_from_selected)
	var characters: Array = _get_array(_view_model.get("characters", []))
	if characters.is_empty():
		return

	_carousel_index = int(_view_model.get("carousel_index", 0))
	var current_character: Dictionary = _get_dictionary(_view_model.get("character", {}))
	selected_character_id = StringName(String(_view_model.get("character_id", "")))
	selected_weapon_id = StringName(String(_view_model.get("weapon_id", "")))

	_clear_children(_carousel)
	_add_character_card(current_character)
	_refresh_weapon_grid(_get_array(_view_model.get("weapons", [])))
	_refresh_details(_view_model)
	if _screen != null and _screen.is_inside_tree():
		update_layout(_screen.get_viewport_rect().size)


func update_layout(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_layout_scale = 1.0

	_set_control_min_size("nav_bar", Vector2(0, NAV_HEIGHT * _layout_scale))
	_set_control_min_size("back_button", NAV_BUTTON_SIZE * _layout_scale)
	_set_control_min_size("nav_spacer", NAV_BUTTON_SIZE * _layout_scale)
	_set_control_min_size("previous_button", SIDE_BUTTON_SIZE * _layout_scale)
	_set_control_min_size("next_button", SIDE_BUTTON_SIZE * _layout_scale)
	if _carousel != null:
		_carousel.custom_minimum_size = CAROUSEL_SIZE * _layout_scale
		_carousel.pivot_offset = _carousel.custom_minimum_size * 0.5
	if _action_button != null:
		_action_button.custom_minimum_size = Vector2(0, 56.0 * _layout_scale)

	for key: String in DETAIL_HEIGHTS.keys():
		_configure_detail_label(_description_labels.get(key, null) as Label, float(DETAIL_HEIGHTS[key]) * _layout_scale)
	_resize_weapon_grid_cells()


func _build_nav(root: VBoxContainer) -> void:
	var nav_bar: HBoxContainer = HBoxContainer.new()
	nav_bar.custom_minimum_size = Vector2(0, NAV_HEIGHT)
	nav_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_bar.add_theme_constant_override("separation", 16)
	root.add_child(nav_bar)

	var back_button: Button = _add_button(nav_bar, "返回")
	back_button.custom_minimum_size = NAV_BUTTON_SIZE
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(Callable(self, "_emit_back_requested"))

	var title_label: Label = _add_label(nav_bar, "选择人物", 1)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 30)

	var nav_spacer: Control = Control.new()
	nav_spacer.custom_minimum_size = NAV_BUTTON_SIZE
	nav_spacer.size_flags_horizontal = Control.SIZE_SHRINK_END
	nav_bar.add_child(nav_spacer)
	_layout_controls["nav_bar"] = nav_bar
	_layout_controls["back_button"] = back_button
	_layout_controls["nav_spacer"] = nav_spacer


func _build_content(root: VBoxContainer) -> void:
	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 18)
	root.add_child(content_row)
	_build_character_column(content_row)
	_build_weapon_panel(content_row)
	_build_details_panel(content_row)


func _build_character_column(parent: HBoxContainer) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 2.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	parent.add_child(column)

	var selector_row: HBoxContainer = HBoxContainer.new()
	selector_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_row.add_theme_constant_override("separation", 18)
	column.add_child(selector_row)

	var previous_button: Button = _add_button(selector_row, "<")
	previous_button.custom_minimum_size = SIDE_BUTTON_SIZE
	previous_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	previous_button.pressed.connect(Callable(self, "_shift_carousel").bind(-1))
	_layout_controls["previous_button"] = previous_button

	_carousel = HBoxContainer.new()
	_carousel.custom_minimum_size = CAROUSEL_SIZE
	_carousel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_row.add_child(_carousel)

	var next_button: Button = _add_button(selector_row, ">")
	next_button.custom_minimum_size = SIDE_BUTTON_SIZE
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.pressed.connect(Callable(self, "_shift_carousel").bind(1))
	_layout_controls["next_button"] = next_button


func _build_weapon_panel(parent: HBoxContainer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.0
	parent.add_child(panel)

	var margin: MarginContainer = _create_margin_container(18, 18, 18, 18)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var weapon_title: Label = _add_label(column, "武器", 1)
	weapon_title.add_theme_font_size_override("font_size", 24)
	_weapon_grid = GridContainer.new()
	_weapon_grid.columns = WEAPON_GRID_COLUMNS
	_weapon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_weapon_grid.add_theme_constant_override("h_separation", WEAPON_GRID_GAP)
	_weapon_grid.add_theme_constant_override("v_separation", WEAPON_GRID_GAP)
	_weapon_grid.resized.connect(Callable(self, "_resize_weapon_grid_cells"))
	column.add_child(_weapon_grid)


func _build_details_panel(parent: HBoxContainer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)

	var margin: MarginContainer = _create_margin_container(28, 18, 28, 18)
	panel.add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var details_text: VBoxContainer = VBoxContainer.new()
	details_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_text.add_theme_constant_override("separation", 8)
	layout.add_child(details_text)

	for key: String in ["role", "stats", "trait", "drawback", "difficulty", "weapon_name", "weapon_description", "weapon_branch", "lock"]:
		_description_labels[key] = _add_label(details_text, "")

	_action_button = _add_button(layout, "立刻出发")
	_action_button.custom_minimum_size = Vector2(0, 56)
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.add_theme_stylebox_override("normal", _create_active_button_style(false))
	_action_button.add_theme_stylebox_override("hover", _create_active_button_style(true))
	UIButtonSkin.apply_text_only(_action_button)
	_action_button.pressed.connect(Callable(self, "_on_action_button_pressed"))


func _create_active_button_style(is_hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var base_color: Color = Color(0.30, 0.38, 0.28, 0.98)
	if is_hovered:
		base_color = Color(0.38, 0.48, 0.34, 1.0)
	style.bg_color = base_color
	style.border_color = Color(0.74, 0.68, 0.42, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32 if is_hovered else 0.18)
	style.shadow_size = 10 if is_hovered else 4
	return style



func _refresh_weapon_grid(weapons: Array) -> void:
	_clear_children(_weapon_grid)
	for weapon_variant: Variant in weapons:
		_add_weapon_cell(_get_dictionary(weapon_variant))
	call_deferred("_resize_weapon_grid_cells")


func _add_weapon_cell(weapon: Dictionary) -> void:
	var weapon_id: StringName = StringName(String(weapon.get("id", "")))
	var is_selected: bool = weapon_id == selected_weapon_id
	var button: Button = Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2.ZERO
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.add_theme_stylebox_override("normal", _create_weapon_cell_style(is_selected, false))
	button.add_theme_stylebox_override("hover", _create_weapon_cell_style(is_selected, true))
	button.add_theme_stylebox_override("pressed", _create_weapon_cell_style(true, true))
	UIButtonSkin.apply_text_only(button)
	button.pressed.connect(Callable(self, "_toggle_weapon_selection").bind(weapon_id))
	button.mouse_entered.connect(Callable(self, "_show_weapon_details").bind(weapon_id))
	button.mouse_exited.connect(Callable(self, "_restore_character_details"))
	_weapon_grid.add_child(button)
	_add_weapon_cell_art(button, weapon)


func _refresh_details(view_model: Dictionary) -> void:
	var labels: Dictionary = _get_dictionary(view_model.get("details", {}))
	for key: String in DETAIL_HEIGHTS.keys():
		_set_detail_label(key, String(labels.get(key, "")))
	var action: Dictionary = _get_dictionary(view_model.get("action", {}))
	_action_button.disabled = bool(action.get("disabled", true))
	_action_button.text = String(action.get("text", "请选择角色"))


func _on_action_button_pressed() -> void:
	if _action_button == null or _action_button.disabled:
		return
	var character: Dictionary = GameData.get_character(selected_character_id)
	if character.is_empty():
		return
	if SaveManager.is_character_unlocked(selected_character_id):
		_confirm_loadout()
	else:
		_purchase_character(selected_character_id)


func _toggle_weapon_selection(weapon_id: StringName) -> void:
	selected_weapon_id = &"" if selected_weapon_id == weapon_id else weapon_id
	_refresh_current_character(false)


func _show_weapon_details(weapon_id: StringName) -> void:
	var labels: Dictionary = _get_dictionary(_view_model_builder.call("build_weapon_focus", weapon_id, selected_character_id))
	_set_detail_label("weapon_name", String(labels.get("weapon_name", "")))
	_set_detail_label("weapon_description", String(labels.get("weapon_description", "")))
	_set_detail_label("weapon_branch", String(labels.get("weapon_branch", "")))
	_set_detail_label("lock", String(labels.get("lock", "")))


func _restore_character_details() -> void:
	_refresh_details(_view_model)


func _confirm_loadout() -> void:
	var character: Dictionary = GameData.get_character(selected_character_id)
	if character.is_empty() or not SaveManager.is_character_unlocked(selected_character_id):
		return
	if selected_weapon_id == &"" or not _is_weapon_allowed_for_character(selected_weapon_id, character):
		return
	loadout_confirmed.emit(selected_character_id, selected_weapon_id)


func _purchase_character(character_id: StringName) -> void:
	var result_variant: Variant = _command_dispatcher.call("dispatch", UICommandScript.purchase_character(character_id))
	var result: Dictionary = _get_dictionary(result_variant)
	if bool(result.get("purchased", false)):
		refresh(character_id, _get_first_weapon_for_character(character_id))


func _shift_carousel(direction: int) -> void:
	var characters: Array = GameData.get_character_pool()
	if characters.is_empty():
		return
	var source_card: Control = _carousel.get_child(0) as Control if _carousel != null and _carousel.get_child_count() > 0 else null
	var exit_card: Control = _create_character_exit_card(source_card)
	_carousel_index = posmod(_carousel_index + direction, characters.size())
	_refresh_current_character(false)
	_play_transition(direction, exit_card)


func _play_transition(direction: int, exit_card: Control = null) -> void:
	if _carousel == null:
		return
	if _carousel_tween != null and _carousel_tween.is_valid():
		_carousel_tween.kill()

	_carousel.modulate.a = 1.0
	var card: Control = null
	if _carousel.get_child_count() > 0:
		card = _carousel.get_child(0) as Control
	if card == null:
		return

	var direction_sign: float = _direction_sign(direction)
	var travel: float = 150.0 * _layout_scale * direction_sign
	card.modulate.a = 0.0
	card.scale = Vector2(0.74, 0.74)
	card.rotation_degrees = 7.0 * direction_sign
	card.position.x += travel
	card.pivot_offset = CARD_SIZE * _layout_scale * 0.5
	_carousel_tween = _screen.create_tween()
	_carousel_tween.set_parallel(true)
	_carousel_tween.tween_property(card, "modulate:a", 1.0, 0.36)
	_carousel_tween.tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_carousel_tween.tween_property(card, "rotation_degrees", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_carousel_tween.tween_property(card, "position:x", card.position.x - travel, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animate_character_exit_card(exit_card, direction)


func _create_character_exit_card(source_card: Control) -> Control:
	if source_card == null or _screen == null:
		return null
	var exit_card: Control = source_card.duplicate() as Control
	if exit_card == null:
		return null
	var source_global_position: Vector2 = source_card.global_position
	exit_card.name = "CharacterWheelExitCard"
	exit_card.size = source_card.size
	exit_card.custom_minimum_size = source_card.size
	exit_card.pivot_offset = source_card.size * 0.5
	exit_card.z_index = 80
	exit_card.modulate = Color(1.0, 1.0, 1.0, 0.58)
	_set_mouse_filter_recursive(exit_card, Control.MOUSE_FILTER_IGNORE)
	_screen.add_child(exit_card)
	exit_card.set_as_top_level(true)
	exit_card.global_position = source_global_position
	return exit_card


func _animate_character_exit_card(exit_card: Control, direction: int) -> void:
	if exit_card == null or _screen == null:
		return
	var direction_sign: float = _direction_sign(direction)
	var end_position: Vector2 = exit_card.global_position + Vector2(-170.0 * _layout_scale * direction_sign, 0.0)
	var tween: Tween = _screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(exit_card, "global_position", end_position, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(exit_card, "modulate:a", 0.0, 0.36)
	tween.tween_property(exit_card, "scale", Vector2(0.74, 0.74), 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(exit_card, "rotation_degrees", -8.0 * direction_sign, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(Callable(exit_card, "queue_free"))


func _direction_sign(direction: int) -> float:
	return 1.0 if direction >= 0 else -1.0


func _set_mouse_filter_recursive(node: Node, mouse_filter_value: int) -> void:
	var control: Control = node as Control
	if control != null:
		control.mouse_filter = mouse_filter_value
	for child: Node in node.get_children():
		_set_mouse_filter_recursive(child, mouse_filter_value)


func _add_character_card(character: Dictionary) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE * _layout_scale
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _create_character_card_style())
	_carousel.add_child(card)

	var margin: MarginContainer = _create_margin_container(16, 14, 16, 14)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var name_label: Label = _add_label(content, _get_character_display_name(character), 1)
	name_label.add_theme_font_size_override("font_size", 24)
	content.add_child(_create_character_art_block(character, PORTRAIT_SIZE * _layout_scale))


func _resize_weapon_grid_cells() -> void:
	if _weapon_grid == null:
		return
	var available_width: float = _weapon_grid.size.x
	if available_width <= 0.0:
		return
	var total_gap: float = float(WEAPON_GRID_GAP * maxi(WEAPON_GRID_COLUMNS - 1, 0))
	var side: float = maxf(floorf((available_width - total_gap) / float(WEAPON_GRID_COLUMNS)), 1.0)
	for child: Node in _weapon_grid.get_children():
		var control: Control = child as Control
		if control != null:
			control.custom_minimum_size = Vector2(side, side)
			_resize_weapon_cell_art(control, side)
	_weapon_grid.queue_sort()


func _add_weapon_cell_art(parent: Button, weapon: Dictionary) -> void:
	var texture: Texture2D = _get_weapon_visual_texture(weapon)
	if texture == null:
		var fallback_label: Label = _add_label(parent, _get_weapon_display_name(weapon, StringName(String(weapon.get("id", "")))), 1)
		fallback_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fallback_label.clip_text = true
		return
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.name = "WeaponIcon"
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.modulate = _get_visual_modulate(weapon)
	parent.add_child(texture_rect)


func _resize_weapon_cell_art(cell: Control, side: float) -> void:
	var inset: float = floorf(side * WEAPON_CELL_ICON_INSET_RATIO)
	for child: Node in cell.get_children():
		var control: Control = child as Control
		if control != null:
			control.offset_left = inset
			control.offset_top = inset
			control.offset_right = -inset
			control.offset_bottom = -inset


func _set_weapon_detail_labels(weapon: Dictionary, weapon_id: StringName) -> void:
	if weapon.is_empty():
		_set_detail_label("weapon_name", "武器：未选择")
		_set_detail_label("weapon_description", "")
		_set_detail_label("weapon_branch", "")
		return
	_set_detail_label("weapon_name", "武器：%s" % _get_weapon_display_name(weapon, weapon_id))
	_set_detail_label("weapon_description", _get_weapon_description_text(weapon))
	_set_detail_label("weapon_branch", _get_weapon_branch_preview_text(weapon))


func _get_allowed_weapons_for_character(character: Dictionary) -> Array[Dictionary]:
	return CharacterLoadoutServiceScript.get_allowed_weapons(StringName(String(character.get("id", ""))))


func _get_first_weapon_for_character(character_id: StringName) -> StringName:
	return CharacterLoadoutServiceScript.resolve_weapon_id(character_id, &"")


func _is_weapon_allowed_for_character(weapon_id: StringName, character: Dictionary) -> bool:
	return CharacterLoadoutServiceScript.is_weapon_allowed(StringName(String(character.get("id", ""))), weapon_id)


func _update_index_from_selected(characters: Array) -> void:
	for index: int in range(characters.size()):
		var character: Dictionary = characters[index]
		if StringName(String(character.get("id", ""))) == selected_character_id:
			_carousel_index = index
			return
	_carousel_index = clampi(_carousel_index, 0, characters.size() - 1)


func _get_character_at_offset(characters: Array, offset: int) -> Dictionary:
	if characters.is_empty():
		return {}
	return characters[posmod(_carousel_index + offset, characters.size())]


func _get_character_selection_status_text(character: Dictionary, is_unlocked: bool) -> String:
	return CharacterLoadoutTextScript.selection_status_text(character, is_unlocked)


func _get_character_lock_detail(character: Dictionary) -> String:
	return CharacterLoadoutTextScript.lock_detail(character)


func _get_character_action_text(character: Dictionary, is_unlocked: bool) -> String:
	return CharacterLoadoutTextScript.action_text(character, is_unlocked)


func _get_character_role_text(character: Dictionary) -> String:
	return CharacterLoadoutTextScript.role_text(character)


func _get_character_trait_text(character: Dictionary) -> String:
	return CharacterLoadoutTextScript.trait_text(character)


func _get_character_difficulty_text(character: Dictionary) -> String:
	return CharacterLoadoutTextScript.difficulty_text(character)


func _get_character_display_name(character: Dictionary) -> String:
	return UIDisplayHelperScript.character_name(character, character.get("id", ""))

func _get_character_stats_text(character: Dictionary) -> String:
	return CharacterLoadoutTextScript.stats_text(character)


func _get_character_drawback_text(character: Dictionary) -> String:
	return CharacterLoadoutTextScript.drawback_text(character)


func _get_trait_display_name(character_id: String, trait_data: Dictionary) -> String:
	return CharacterLoadoutTextScript.call("_trait_display_name", character_id, trait_data)


func _get_trait_description(character_id: String) -> String:
	return CharacterLoadoutTextScript.call("_trait_description", character_id)


func _get_weapon_display_name(weapon: Dictionary, fallback_id: StringName) -> String:
	return UIDisplayHelperScript.weapon_name(weapon, fallback_id)

func _get_weapon_description_text(weapon: Dictionary) -> String:
	return CharacterLoadoutTextScript.weapon_description_text(weapon)


func _get_weapon_role_text(weapon_id: String) -> String:
	return CharacterLoadoutTextScript.weapon_role_text(weapon_id)


func _get_weapon_branch_preview_text(weapon: Dictionary) -> String:
	return CharacterLoadoutTextScript.branch_preview_text(weapon)


func _get_branch_display_name(branch: Dictionary) -> String:
	return UIDisplayHelperScript.branch_name(branch, branch.get("id", ""))

func _get_skill_display_name(skill_id: StringName) -> String:
	return UIDisplayHelperScript.skill_name(skill_id)

func _get_string_list_text(value: Variant, fallback: String) -> String:
	return CharacterLoadoutTextScript.string_list_text(value, fallback)


func _create_character_art_block(character: Dictionary, min_size: Vector2) -> Control:
	var texture: Texture2D = _get_visual_texture(character, "portrait")
	if texture != null:
		var texture_rect: TextureRect = TextureRect.new()
		texture_rect.custom_minimum_size = min_size
		texture_rect.texture = texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.modulate = _get_visual_modulate(character)
		return texture_rect
	var placeholder: ColorRect = ColorRect.new()
	placeholder.custom_minimum_size = min_size
	placeholder.color = Color(0.18, 0.2, 0.24, 1.0)
	return placeholder


func _get_weapon_visual_texture(weapon: Dictionary) -> Texture2D:
	return _get_visual_texture(weapon, "icon")


func _get_visual_texture(definition: Dictionary, preferred_key: String) -> Texture2D:
	return UIDisplayHelperScript.visual_texture(definition, preferred_key)

func _get_visual_modulate(definition: Dictionary) -> Color:
	return UIDisplayHelperScript.visual_modulate(definition)

func _create_character_card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	## Color(0.13, 0.145, 0.17, 0.96)
	style.border_color = Color(0.72, 0.68, 0.46, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 16
	return style


func _create_weapon_cell_style(is_selected: bool, is_hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var base_color: Color = Color.WHITE
	## Color(0.14, 0.155, 0.18, 0.96)
	if is_selected:
		base_color = Color(0.26, 0.34, 0.25, 0.98)
	elif is_hovered:
		base_color = Color(0.19, 0.215, 0.25, 0.98)
	style.bg_color = base_color
	style.border_color = Color(0.74, 0.68, 0.42, 0.95) if is_selected else Color(0.28, 0.31, 0.36, 0.9)
	style.border_width_left = 2 if is_selected else 1
	style.border_width_top = 2 if is_selected else 1
	style.border_width_right = 2 if is_selected else 1
	style.border_width_bottom = 2 if is_selected else 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32 if is_hovered else 0.18)
	style.shadow_size = 10 if is_hovered else 4
	return style


func _configure_detail_label(label: Label, height: float) -> void:
	if label == null:
		return
	label.custom_minimum_size = Vector2(0, height)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false


func _set_detail_label(key: String, text: String) -> void:
	var label: Label = _description_labels.get(key, null) as Label
	if label != null:
		label.text = text


func _set_control_min_size(key: String, min_size: Vector2) -> void:
	var control: Control = _layout_controls.get(key, null) as Control
	if control != null:
		control.custom_minimum_size = min_size


func _emit_back_requested() -> void:
	back_requested.emit()


func _add_label(parent: Node, text: String, alignment: int = 0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment as HorizontalAlignment
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button


func _create_margin_container(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _clear_children(parent: Node) -> void:
	UIDisplayHelperScript.clear_children(parent)

func _get_array(value: Variant) -> Array:
	return UIDisplayHelperScript.array(value)

func _get_dictionary(value: Variant) -> Dictionary:
	return UIDisplayHelperScript.dictionary(value)
