extends RefCounted
class_name CharacterLoadoutController


signal loadout_confirmed(character_id: StringName)
signal back_requested


const UIDisplayHelperScript: Script = preload("res://scripts/ui/ui_display_helper.gd")
const UICommandDispatcherScript: Script = preload("res://scripts/ui/ui_command_dispatcher.gd")
const UICommandScript: Script = preload("res://scripts/ui/ui_command.gd")

const NAV_HEIGHT: float = 64.0
const LIST_MIN_WIDTH: float = 260.0
const PREVIEW_MIN_WIDTH: float = 320.0
const DETAIL_MIN_WIDTH: float = 320.0
const ROLE_FALLBACKS: Dictionary = {
	"mage": "高爆发元素施法者",
	"ranger": "高速暴击与陷阱猎手",
	"paladin": "护盾与神圣前线",
	"alchemist": "异常状态与反应专家"
}
const DESCRIPTION_FALLBACKS: Dictionary = {
	"mage": "以初始技能伤害和元素状态推进节奏，但过载后更脆弱。",
	"ranger": "保持移动能进入猎手节奏，停顿、受击或硬控会中断节奏。",
	"paladin": "更稳定地承受伤害，并在护盾存在时强化神圣伤害。",
	"alchemist": "直接主攻击较弱，但持续伤害与状态反应更强。"
}

var selected_character_id: StringName = &"mage"

var _screen: Control
var _character_list: VBoxContainer
var _portrait_texture: TextureRect
var _name_label: Label
var _role_label: Label
var _description_label: Label
var _stats_list: GridContainer
var _trait_label: Label
var _starting_skill_label: Label
var _confirm_button: Button
var _layout_controls: Dictionary = {}
var _command_dispatcher: RefCounted = UICommandDispatcherScript.new()


func build() -> Control:
	_screen = Control.new()
	_screen.name = "CHARACTER_SELECT"
	_screen.visible = false
	_screen.z_index = 10
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.045, 0.05, 0.055, 0.98)
	_screen.add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	_screen.add_child(margin)
	_layout_controls["margin"] = margin

	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	_build_nav_bar(root)
	_build_body(root)
	refresh(selected_character_id)
	return _screen


func refresh(character_id: StringName = &"") -> void:
	if character_id != &"":
		selected_character_id = character_id
	_select_default_character_if_needed()
	_refresh_character_cards()
	_refresh_selected_character()


func update_layout(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_set_control_min_size("character_list_panel", Vector2(maxf(LIST_MIN_WIDTH, viewport_size.x * 0.22), 0))
	_set_control_min_size("character_preview_panel", Vector2(maxf(PREVIEW_MIN_WIDTH, viewport_size.x * 0.30), 0))
	_set_control_min_size("character_detail_panel", Vector2(maxf(DETAIL_MIN_WIDTH, viewport_size.x * 0.28), 0))
	_set_control_min_size("confirm_panel", Vector2(0, maxf(88.0, viewport_size.y * 0.12)))


func _build_nav_bar(root: VBoxContainer) -> void:
	var nav_bar: HBoxContainer = HBoxContainer.new()
	nav_bar.custom_minimum_size = Vector2(0, NAV_HEIGHT)
	nav_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_bar.add_theme_constant_override("separation", 16)
	root.add_child(nav_bar)

	var back_button: Button = _add_button(nav_bar, "返回")
	back_button.name = "CharacterBackButton"
	back_button.custom_minimum_size = Vector2(128, 56)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(Callable(self, "_emit_back_requested"))

	var title_label: Label = _add_label(nav_bar, "选择角色", HORIZONTAL_ALIGNMENT_CENTER, "CharacterTitleLabel")
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var soul_label: Label = _add_label(nav_bar, "灵魂石：0", HORIZONTAL_ALIGNMENT_RIGHT, "CharacterSoulLabel")
	soul_label.custom_minimum_size = Vector2(150, 0)
	soul_label.size_flags_horizontal = Control.SIZE_SHRINK_END


func _build_body(root: VBoxContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)

	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.custom_minimum_size = Vector2(0, 430)
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 16)
	body.add_child(content_row)

	_build_character_list(content_row)
	_build_preview_panel(content_row)
	_build_detail_panel(content_row)
	_build_confirm_panel(body)


func _build_character_list(parent: HBoxContainer) -> void:
	var panel: PanelContainer = _create_panel_container(Vector2(LIST_MIN_WIDTH, 0), 0.95)
	panel.name = "CharacterListPanel"
	parent.add_child(panel)
	_layout_controls["character_list_panel"] = panel

	var margin: MarginContainer = _create_margin_container(14, 14, 14, 14)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title: Label = _add_detail_label(layout, "角色")
	title.add_theme_font_size_override("font_size", 20)

	_character_list = VBoxContainer.new()
	_character_list.name = "CharacterCardList"
	_character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character_list.add_theme_constant_override("separation", 10)
	layout.add_child(_character_list)


func _build_preview_panel(parent: HBoxContainer) -> void:
	var panel: PanelContainer = _create_panel_container(Vector2(PREVIEW_MIN_WIDTH, 0), 1.35)
	panel.name = "CharacterPreviewPanel"
	panel.clip_contents = true
	parent.add_child(panel)
	_layout_controls["character_preview_panel"] = panel

	var margin: MarginContainer = _create_margin_container(18, 18, 18, 18)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	_name_label = _add_label(layout, "", HORIZONTAL_ALIGNMENT_CENTER, "CharacterNameLabel")
	_name_label.add_theme_font_size_override("font_size", 30)

	_portrait_texture = TextureRect.new()
	_portrait_texture.name = "CharacterPortraitTexture"
	_portrait_texture.custom_minimum_size = Vector2(0, 260)
	_portrait_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layout.add_child(_portrait_texture)

	_role_label = _add_detail_label(layout, "")
	_role_label.name = "CharacterRoleLabel"
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.add_theme_font_size_override("font_size", 18)

	_description_label = _add_detail_label(layout, "")
	_description_label.name = "CharacterDescriptionLabel"
	_description_label.custom_minimum_size = Vector2(0, 80)


func _build_detail_panel(parent: HBoxContainer) -> void:
	var panel: PanelContainer = _create_panel_container(Vector2(DETAIL_MIN_WIDTH, 0), 1.2)
	panel.name = "CharacterDetailPanel"
	parent.add_child(panel)
	_layout_controls["character_detail_panel"] = panel

	var margin: MarginContainer = _create_margin_container(18, 16, 18, 16)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var stats_title: Label = _add_detail_label(layout, "基础属性")
	stats_title.add_theme_font_size_override("font_size", 19)

	_stats_list = GridContainer.new()
	_stats_list.name = "CharacterStatsList"
	_stats_list.columns = 2
	_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_list.add_theme_constant_override("h_separation", 10)
	_stats_list.add_theme_constant_override("v_separation", 8)
	layout.add_child(_stats_list)

	_trait_label = _add_detail_label(layout, "")
	_trait_label.name = "CharacterTraitLabel"
	_trait_label.custom_minimum_size = Vector2(0, 150)

	_starting_skill_label = _add_detail_label(layout, "")
	_starting_skill_label.name = "CharacterStartingSkillLabel"
	_starting_skill_label.custom_minimum_size = Vector2(0, 120)


func _build_confirm_panel(parent: VBoxContainer) -> void:
	var panel: PanelContainer = _create_panel_container(Vector2(0, 104), 1.0)
	panel.name = "CharacterConfirmPanel"
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	_layout_controls["confirm_panel"] = panel

	var margin: MarginContainer = _create_margin_container(18, 14, 18, 14)
	panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var hint_label: Label = _add_detail_label(row, "当前角色会携带自己的初始技能进入地图选择。")
	hint_label.name = "CharacterConfirmHintLabel"
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_confirm_button = _add_button(row, "确认")
	_confirm_button.name = "CharacterConfirmButton"
	_confirm_button.custom_minimum_size = Vector2(220, 58)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_confirm_button.add_theme_stylebox_override("normal", _create_active_button_style(false))
	_confirm_button.add_theme_stylebox_override("hover", _create_active_button_style(true))
	UIButtonSkin.apply_text_only(_confirm_button)
	_confirm_button.pressed.connect(Callable(self, "_on_confirm_pressed"))


func _select_default_character_if_needed() -> void:
	if not GameData.get_character(selected_character_id).is_empty():
		return
	var characters: Array = GameData.get_character_pool()
	if characters.is_empty():
		selected_character_id = &""
		return
	selected_character_id = StringName(str(_get_dictionary(characters[0]).get("id", "")))


func _refresh_character_cards() -> void:
	_clear_children(_character_list)
	var characters: Array = GameData.get_character_pool()
	if characters.is_empty():
		_add_detail_label(_character_list, "暂无角色数据")
		return
	for character_variant: Variant in characters:
		var character: Dictionary = _get_dictionary(character_variant)
		var character_id: StringName = StringName(str(character.get("id", "")))
		if character_id != &"":
			_add_character_card(character, character_id)


func _add_character_card(character: Dictionary, character_id: StringName) -> void:
	var is_selected: bool = character_id == selected_character_id
	var is_unlocked: bool = SaveManager.is_character_unlocked(character_id)
	var button: Button = Button.new()
	button.name = "CharacterCard_%s" % str(character_id)
	var lock_text: String = ""
	if not is_unlocked:
		lock_text = "\n未解锁"
	button.text = "%s\n%s%s" % [
		_get_character_display_name(character, character_id),
		_get_character_role(character, character_id),
		lock_text
	]
	button.toggle_mode = true
	button.button_pressed = is_selected
	button.custom_minimum_size = Vector2(0, 82)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("normal", _create_card_style(is_selected, false, is_unlocked))
	button.add_theme_stylebox_override("hover", _create_card_style(is_selected, true, is_unlocked))
	button.add_theme_stylebox_override("pressed", _create_card_style(true, true, is_unlocked))
	UIButtonSkin.apply_text_only(button)
	button.pressed.connect(Callable(self, "_select_character").bind(character_id))
	_character_list.add_child(button)


func _refresh_selected_character() -> void:
	var character: Dictionary = GameData.get_character(selected_character_id)
	var is_configured: bool = not character.is_empty()
	if not is_configured:
		_name_label.text = "请选择角色"
		_role_label.text = ""
		_description_label.text = ""
		_portrait_texture.texture = null
		_clear_children(_stats_list)
		_trait_label.text = ""
		_starting_skill_label.text = ""
		_confirm_button.text = "请选择角色"
		_confirm_button.disabled = true
		return

	_name_label.text = _get_character_display_name(character, selected_character_id)
	_role_label.text = _get_character_role(character, selected_character_id)
	_description_label.text = str(character.get("description", DESCRIPTION_FALLBACKS.get(str(selected_character_id), "")))
	_portrait_texture.texture = UIDisplayHelperScript.visual_texture(character, "portrait")
	if _portrait_texture.texture != null:
		_portrait_texture.modulate = UIDisplayHelperScript.visual_modulate(character)
	else:
		_portrait_texture.modulate = Color(0.34, 0.36, 0.4, 1.0)

	_refresh_stats(_get_dictionary(character.get("base_stats", {})))
	_refresh_trait(character)
	_refresh_starting_skill(character)
	_refresh_confirm_button(character)
	_refresh_soul_label()


func _refresh_stats(stats: Dictionary) -> void:
	_clear_children(_stats_list)
	_add_stat_row("生命", _format_number(stats.get("max_hp", 0)))
	_add_stat_row("移速", _format_number(stats.get("move_speed", 0)))
	_add_stat_row("伤害", _format_multiplier(stats.get("damage_multiplier", 1.0)))
	_add_stat_row("攻速", _format_multiplier(stats.get("attack_speed_multiplier", 1.0)))
	_add_stat_row("暴击", _format_percent(stats.get("crit_chance", 0.0)))
	_add_stat_row("暴伤", _format_multiplier(stats.get("crit_damage", 1.0)))
	_add_stat_row("护甲", _format_number(stats.get("armor", 0)))
	_add_stat_row("拾取", _format_number(stats.get("pickup_radius", 0)))


func _add_stat_row(label_text: String, value_text: String) -> void:
	var name_label: Label = _add_detail_label(_stats_list, label_text)
	name_label.add_theme_font_size_override("font_size", 15)
	var value_label: Label = _add_detail_label(_stats_list, value_text)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 15)


func _refresh_trait(character: Dictionary) -> void:
	var trait_data: Dictionary = _get_dictionary(character.get("trait", {}))
	var trait_name: String = str(trait_data.get("display_name", trait_data.get("id", "未配置")))
	var trait_description: String = str(trait_data.get("description", ""))
	_trait_label.text = "角色特质\n%s\n%s" % [trait_name, trait_description]


func _refresh_starting_skill(character: Dictionary) -> void:
	var starting_skill_id: StringName = StringName(str(character.get("starting_skill_id", "")))
	var skill: Dictionary = GameData.get_skill(starting_skill_id)
	if starting_skill_id == &"" or skill.is_empty():
		_starting_skill_label.text = "初始技能\n未配置"
		return
	_starting_skill_label.text = "初始技能\n%s\n%s" % [
		str(skill.get("display_name", starting_skill_id)),
		str(skill.get("description", ""))
	]


func _refresh_confirm_button(character: Dictionary) -> void:
	var starting_skill_id: StringName = StringName(str(character.get("starting_skill_id", "")))
	var has_skill: bool = starting_skill_id != &"" and not GameData.get_skill(starting_skill_id).is_empty()
	var is_unlocked: bool = SaveManager.is_character_unlocked(selected_character_id)
	_confirm_button.disabled = not has_skill
	if not has_skill:
		_confirm_button.text = "缺少初始技能"
	elif is_unlocked:
		_confirm_button.text = "确认"
	else:
		_confirm_button.text = _get_unlock_button_text(character)


func _refresh_soul_label() -> void:
	var soul_label: Label = _screen.find_child("CharacterSoulLabel", true, false) as Label
	if soul_label != null:
		soul_label.text = "灵魂石：%d" % SaveManager.get_soul_stones()


func _select_character(character_id: StringName) -> void:
	selected_character_id = character_id
	_refresh_character_cards()
	_refresh_selected_character()


func _on_confirm_pressed() -> void:
	var character: Dictionary = GameData.get_character(selected_character_id)
	if character.is_empty():
		return
	if SaveManager.is_character_unlocked(selected_character_id):
		loadout_confirmed.emit(selected_character_id)
		return
	var result_variant: Variant = _command_dispatcher.call("dispatch", UICommandScript.purchase_character(selected_character_id))
	var result: Dictionary = _get_dictionary(result_variant)
	if bool(result.get("purchased", false)):
		refresh(selected_character_id)


func _get_unlock_button_text(character: Dictionary) -> String:
	var unlock: Dictionary = _get_dictionary(character.get("unlock", {}))
	var cost: int = int(unlock.get("cost", 0))
	if cost > 0:
		return "解锁（%d 灵魂石）" % cost
	return "解锁"


func _get_character_display_name(character: Dictionary, fallback_id: StringName) -> String:
	return UIDisplayHelperScript.character_name(character, fallback_id)


func _get_character_role(character: Dictionary, fallback_id: StringName) -> String:
	return str(character.get("role", ROLE_FALLBACKS.get(str(fallback_id), "")))


func _format_number(value: Variant) -> String:
	if value is float:
		return "%.1f" % float(value)
	return "%d" % int(value)


func _format_multiplier(value: Variant) -> String:
	var multiplier: float = float(value)
	var delta_percent: int = roundi((multiplier - 1.0) * 100.0)
	if delta_percent == 0:
		return "标准"
	if delta_percent > 0:
		return "+%d%%" % delta_percent
	return "%d%%" % delta_percent


func _format_percent(value: Variant) -> String:
	return "%d%%" % roundi(float(value) * 100.0)


func _emit_back_requested() -> void:
	back_requested.emit()


func _add_label(parent: Node, text: String, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, node_name: String = "") -> Label:
	var label: Label = Label.new()
	if node_name != "":
		label.name = node_name
	label.text = text
	label.horizontal_alignment = alignment
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _add_detail_label(parent: Node, text: String) -> Label:
	var label: Label = _add_label(parent, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


func _add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button


func _create_panel_container(min_size: Vector2, stretch_ratio: float) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch_ratio
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	return panel


func _create_margin_container(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _create_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.115, 0.13, 0.94)
	style.border_color = Color(0.24, 0.265, 0.31, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _create_card_style(is_selected: bool, is_hovered: bool, is_unlocked: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var color: Color = Color(0.135, 0.15, 0.18, 0.96)
	if not is_unlocked:
		color = Color(0.095, 0.1, 0.11, 0.78)
	elif is_selected:
		color = Color(0.26, 0.31, 0.25, 0.98)
	elif is_hovered:
		color = Color(0.18, 0.205, 0.24, 0.98)
	style.bg_color = color
	if is_selected:
		style.border_color = Color(0.76, 0.68, 0.42, 0.95)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.border_color = Color(0.26, 0.29, 0.33, 0.82)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _create_active_button_style(is_hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if is_hovered:
		style.bg_color = Color(0.38, 0.48, 0.34, 1.0)
	else:
		style.bg_color = Color(0.30, 0.38, 0.28, 0.98)
	style.border_color = Color(0.74, 0.68, 0.42, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _set_control_min_size(key: String, size: Vector2) -> void:
	var control: Control = _layout_controls.get(key, null) as Control
	if control != null:
		control.custom_minimum_size = size


func _clear_children(parent: Node) -> void:
	UIDisplayHelperScript.clear_children(parent)


func _get_dictionary(value: Variant) -> Dictionary:
	return UIDisplayHelperScript.dictionary(value)
