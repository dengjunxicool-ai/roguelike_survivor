extends RefCounted
class_name TitleScreenController


signal state_requested(state: String)
signal quit_requested


const STATE_CHARACTER_SELECT: String = "CHARACTER_SELECT"
const STATE_META_UPGRADE: String = "META_UPGRADE"
const STATE_CODEX: String = "CODEX"
const STATE_SETTINGS: String = "SETTINGS"
const STATE_DEVELOPER_MODE: String = "DEVELOPER_MODE"
const DESIGN_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const MIN_LAYOUT_VIEWPORT_SIZE: Vector2 = Vector2(320.0, 240.0)
const TITLE_BACKGROUND_PATH: String = "res://assets/ui/title/title_screen_topdown_background.png"
const FALLBACK_BACKGROUND_PATH: String = "res://assets/ui/title/title_screen_background.png"
const MAP_FALLBACK_BACKGROUND_PATH: String = "res://assets/ui/maps/abandoned_dungeon.png"
const LocalizationServiceScript: Script = preload("res://scripts/ui/localization_service.gd")
const UI_FONT_CANDIDATES: PackedStringArray = [
	"Microsoft YaHei",
	"SimHei",
	"Microsoft JhengHei",
	"Noto Sans CJK SC",
	"Noto Sans SC",
	"Arial Unicode MS"
]

var actions_revealed: bool = false

var _ui_font: Font
var _screen: Control
var _title_panel: PanelContainer
var _title_margin: MarginContainer
var _title_stack: VBoxContainer
var _title_kicker_label: Label
var _title_label: Label
var _subtitle_label: Label
var _prompt_label: Label
var _title_accent: ColorRect
var _action_menu: PanelContainer
var _action_list: VBoxContainer
var _menu_margin: MarginContainer
var _menu_title_label: Label
var _footer_label: Label


func build() -> Control:
	_screen = Control.new()
	_screen.name = "TITLE"
	_screen.visible = false
	_screen.z_index = 10
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)

	_build_background(_screen)
	_build_title_stack(_screen)
	_build_action_menu(_screen)
	_build_footer(_screen)
	update_layout(DESIGN_VIEWPORT_SIZE)
	return _screen


func reset() -> void:
	actions_revealed = false
	if _prompt_label != null:
		_prompt_label.visible = true
	if _action_menu != null:
		_action_menu.visible = false


func handle_input(event: InputEvent) -> void:
	if actions_revealed:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		reveal_actions()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		reveal_actions()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		reveal_actions()


func reveal_actions() -> void:
	actions_revealed = true
	if _prompt_label != null:
		_prompt_label.visible = false
	if _action_menu != null:
		_action_menu.visible = true


func update_layout(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	viewport_size = _get_layout_viewport_size(viewport_size)
	var compact: bool = viewport_size.x < 920.0 or viewport_size.y < 620.0
	var ui_scale: float = clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.70, 1.18)
	_update_title_layout(viewport_size, compact, ui_scale)
	_update_menu_layout(viewport_size, compact, ui_scale)
	_update_footer_layout(viewport_size, compact, ui_scale)


func _build_background(parent: Control) -> void:
	var base: ColorRect = ColorRect.new()
	base.name = "BackgroundBase"
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.018, 0.020, 0.026, 1.0)
	parent.add_child(base)

	var background: TextureRect = TextureRect.new()
	background.name = "TopdownArenaBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.texture = _load_background_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	parent.add_child(background)


func _build_title_stack(parent: Control) -> void:
	_title_panel = PanelContainer.new()
	_title_panel.name = "TitlePanel"
	_title_panel.add_theme_stylebox_override("panel", _create_title_panel_style())
	parent.add_child(_title_panel)

	_title_margin = MarginContainer.new()
	_title_margin.add_theme_constant_override("margin_left", 22)
	_title_margin.add_theme_constant_override("margin_top", 18)
	_title_margin.add_theme_constant_override("margin_right", 22)
	_title_margin.add_theme_constant_override("margin_bottom", 18)
	_title_panel.add_child(_title_margin)

	_title_stack = VBoxContainer.new()
	_title_stack.name = "TitleStack"
	_title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_stack.add_theme_constant_override("separation", 9)
	_title_margin.add_child(_title_stack)

	_title_kicker_label = _add_label(_title_stack, "DUNGEON HEART: SURVIVOR")
	_title_kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label_font_size(_title_kicker_label, 17)
	_title_kicker_label.add_theme_color_override("font_color", Color(0.78, 0.62, 0.36, 1.0))
	_title_kicker_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	_title_kicker_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_kicker_label.add_theme_constant_override("shadow_offset_y", 2)



	_title_label = _add_label(_title_stack, "Survivor")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label_font_size(_title_label, 84)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.010, 0.96))
	_title_label.add_theme_constant_override("shadow_offset_x", 4)
	_title_label.add_theme_constant_override("shadow_offset_y", 5)

	_title_accent = ColorRect.new()
	_title_accent.name = "TitleAccent"
	_title_accent.custom_minimum_size = Vector2(310, 3)
	_title_accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_accent.color = Color(0.92, 0.58, 0.20, 0.96)
	_title_stack.add_child(_title_accent)

	_subtitle_label = _add_label(_title_stack, _tr("title.subtitle", "暗黑俯瞰幸存者冒险"))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label_font_size(_subtitle_label, 23)
	_subtitle_label.add_theme_color_override("font_color", Color(0.70, 0.90, 0.93, 1.0))
	_subtitle_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	_subtitle_label.add_theme_constant_override("shadow_offset_x", 2)
	_subtitle_label.add_theme_constant_override("shadow_offset_y", 2)

	_prompt_label = _add_label(_title_stack, _tr("title.prompt", "按任意键继续"))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label_font_size(_prompt_label, 19)
	_prompt_label.add_theme_color_override("font_color", Color(0.97, 0.70, 0.33, 1.0))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)


func _build_action_menu(parent: Control) -> void:
	_action_menu = PanelContainer.new()
	_action_menu.name = "ActionMenu"
	_action_menu.visible = false
	_action_menu.add_theme_stylebox_override("panel", _create_menu_panel_style())
	parent.add_child(_action_menu)

	_menu_margin = MarginContainer.new()
	_menu_margin.add_theme_constant_override("margin_left", 20)
	_menu_margin.add_theme_constant_override("margin_top", 20)
	_menu_margin.add_theme_constant_override("margin_right", 20)
	_menu_margin.add_theme_constant_override("margin_bottom", 20)
	_action_menu.add_child(_menu_margin)

	_action_list = VBoxContainer.new()
	_action_list.add_theme_constant_override("separation", 9)
	_menu_margin.add_child(_action_list)

	_menu_title_label = _add_label(_action_list, _tr("title.menu", "主菜单"))
	_menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label_font_size(_menu_title_label, 18)
	_menu_title_label.add_theme_color_override("font_color", Color(0.88, 0.75, 0.48, 1.0))
	_menu_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_menu_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_menu_title_label.add_theme_constant_override("shadow_offset_y", 2)

	_add_menu_button(_tr("title.developer_mode", "开发者模式"), Callable(self, "_emit_state").bind(STATE_DEVELOPER_MODE))
	_add_menu_button(_tr("title.continue", "继续游戏"), Callable(self, "_emit_state").bind(STATE_CHARACTER_SELECT), false, _tr("title.continue.tooltip", "当前版本直接进入角色选择"))
	_add_menu_button(_tr("title.start", "开始冒险"), Callable(self, "_emit_state").bind(STATE_CHARACTER_SELECT))
	_add_menu_button(_tr("title.meta_upgrade", "局外强化"), Callable(self, "_emit_state").bind(STATE_META_UPGRADE))
	_add_menu_button(_tr("title.codex", "图鉴"), Callable(self, "_emit_state").bind(STATE_CODEX))
	_add_menu_button(_tr("title.settings", "设置"), Callable(self, "_emit_state").bind(STATE_SETTINGS))
	_add_menu_button(_tr("title.quit", "退出游戏"), Callable(self, "_emit_quit"))
	_action_menu.visible = false


func _build_footer(parent: Control) -> void:
	_footer_label = Label.new()
	_footer_label.name = "FooterLabel"
	_footer_label.text = "v0.1"
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer_label.add_theme_font_override("font", _get_ui_font())
	_set_label_font_size(_footer_label, 13)
	_footer_label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.78, 0.66))
	_footer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.70))
	_footer_label.add_theme_constant_override("shadow_offset_x", 1)
	_footer_label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(_footer_label)


func _add_menu_button(text: String, callable: Callable, enabled: bool = true, tooltip: String = "") -> void:
	var button: Button = Button.new()
	button.text = text
	button.disabled = not enabled
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(230, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_font_override("font", _get_ui_font())
	_apply_menu_button_style(button)
	button.pressed.connect(callable)
	_action_list.add_child(button)


func _update_title_layout(viewport_size: Vector2, compact: bool, ui_scale: float) -> void:
	if _title_panel == null:
		return

	if compact:
		var title_width: float = minf(maxf(viewport_size.x - 36.0, 260.0), 560.0)
		_set_control_rect(_title_panel, Rect2(Vector2((viewport_size.x - title_width) * 0.5, 24.0), Vector2(title_width, 204.0)))
	else:
		var title_width_desktop: float = clampf(viewport_size.x * 0.46, 560.0, 760.0)
		var title_height_desktop: float = 238.0 * ui_scale
		var title_left: float = (viewport_size.x - title_width_desktop) * 0.5
		var title_top: float = maxf(viewport_size.y * 0.075, 44.0)
		_set_control_rect(_title_panel, Rect2(Vector2(title_left, title_top), Vector2(title_width_desktop, title_height_desktop)))

	var margin_horizontal: int = maxi(16, roundi(24.0 * ui_scale))
	var margin_vertical: int = maxi(14, roundi(18.0 * ui_scale))
	_title_margin.add_theme_constant_override("margin_left", margin_horizontal)
	_title_margin.add_theme_constant_override("margin_top", margin_vertical)
	_title_margin.add_theme_constant_override("margin_right", margin_horizontal)
	_title_margin.add_theme_constant_override("margin_bottom", margin_vertical)
	_title_stack.add_theme_constant_override("separation", maxi(7, roundi(9.0 * ui_scale)))
	_set_label_font_size(_title_kicker_label, maxi(13, roundi(17.0 * ui_scale)))
	_set_label_font_size(_title_label, maxi(46, roundi(84.0 * ui_scale)))
	_set_label_font_size(_subtitle_label, maxi(17, roundi(22.0 * ui_scale)))
	_set_label_font_size(_prompt_label, maxi(15, roundi(19.0 * ui_scale)))
	_title_accent.custom_minimum_size = Vector2(maxf(260.0 * ui_scale, 190.0), maxf(3.0 * ui_scale, 2.0))


func _update_menu_layout(viewport_size: Vector2, compact: bool, ui_scale: float) -> void:
	if _action_menu == null:
		return

	var menu_width: float = clampf(viewport_size.x * 0.235, 276.0, 348.0)
	var menu_height: float = 424.0 * ui_scale
	if compact:
		menu_width = minf(viewport_size.x - 40.0, 360.0)
		menu_height = minf(viewport_size.y - 252.0, 402.0)
		var compact_left: float = maxf((viewport_size.x - menu_width) * 0.5, 20.0)
		var compact_top: float = maxf(viewport_size.y - menu_height - 30.0, 246.0)
		_set_control_rect(_action_menu, Rect2(Vector2(compact_left, compact_top), Vector2(menu_width, menu_height)))
	else:
		var right_margin: float = maxf(viewport_size.x * 0.055, 58.0)
		var bottom_margin: float = maxf(viewport_size.y * 0.05, 36.0)
		var top: float = maxf(viewport_size.y - menu_height - bottom_margin, maxf(viewport_size.y * 0.34, 220.0))
		_set_control_rect(_action_menu, Rect2(Vector2(viewport_size.x - right_margin - menu_width, top), Vector2(menu_width, menu_height)))

	var margin_value: int = maxi(13, roundi(20.0 * ui_scale))
	_menu_margin.add_theme_constant_override("margin_left", margin_value)
	_menu_margin.add_theme_constant_override("margin_top", margin_value)
	_menu_margin.add_theme_constant_override("margin_right", margin_value)
	_menu_margin.add_theme_constant_override("margin_bottom", margin_value)
	_action_list.add_theme_constant_override("separation", maxi(7, roundi(9.0 * ui_scale)))
	_set_label_font_size(_menu_title_label, maxi(15, roundi(18.0 * ui_scale)))
	for child: Node in _action_list.get_children():
		var button: Button = child as Button
		if button != null:
			button.custom_minimum_size = Vector2(220.0 * ui_scale, 42.0 * ui_scale)
			button.add_theme_font_size_override("font_size", maxi(14, roundi(17.0 * ui_scale)))


func _update_footer_layout(viewport_size: Vector2, compact: bool, ui_scale: float) -> void:
	if _footer_label == null:
		return
	var width: float = minf(viewport_size.x - 48.0, 260.0 * ui_scale)
	var height: float = 26.0 * ui_scale
	var margin: float = 22.0
	_footer_label.visible = not compact
	_set_control_rect(_footer_label, Rect2(Vector2(viewport_size.x - width - margin, viewport_size.y - height - 16.0), Vector2(width, height)))
	_set_label_font_size(_footer_label, maxi(11, roundi(13.0 * ui_scale)))


func _apply_menu_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.60, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.98, 0.78, 0.36, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.60, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.74, 0.74, 0.74, 0.45))
	button.add_theme_stylebox_override("normal", _create_button_style(Color(0.055, 0.060, 0.074, 0.88), Color(0.56, 0.43, 0.24, 0.58), 0))
	button.add_theme_stylebox_override("hover", _create_button_style(Color(0.090, 0.078, 0.055, 0.94), Color(0.92, 0.64, 0.28, 0.92), 10))
	button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.12, 0.085, 0.040, 0.96), Color(1.0, 0.72, 0.30, 1.0), 4))
	button.add_theme_stylebox_override("focus", _create_button_style(Color(0.090, 0.078, 0.055, 0.94), Color(0.92, 0.64, 0.28, 0.92), 10))
	button.add_theme_stylebox_override("disabled", _create_button_style(Color(0.035, 0.038, 0.044, 0.62), Color(0.30, 0.30, 0.30, 0.44), 0))


func _create_menu_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.033, 0.041, 0.84)
	style.border_color = Color(0.70, 0.50, 0.26, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _create_title_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.044, 0.032, 0.68)
	style.border_color = Color(0.92, 0.60, 0.24, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _create_button_style(bg_color: Color, border_color: Color, shadow_size: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 15.0
	style.content_margin_top = 8.0
	style.content_margin_right = 15.0
	style.content_margin_bottom = 8.0
	return style


func _load_background_texture() -> Texture2D:
	var texture: Texture2D = load(TITLE_BACKGROUND_PATH) as Texture2D
	if texture != null:
		return texture
	texture = load(FALLBACK_BACKGROUND_PATH) as Texture2D
	if texture != null:
		return texture
	return load(MAP_FALLBACK_BACKGROUND_PATH) as Texture2D


func _set_control_rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y
	control.custom_minimum_size = rect.size


func _get_layout_viewport_size(viewport_size: Vector2) -> Vector2:
	if viewport_size.x < MIN_LAYOUT_VIEWPORT_SIZE.x or viewport_size.y < MIN_LAYOUT_VIEWPORT_SIZE.y:
		return DESIGN_VIEWPORT_SIZE
	return viewport_size


func _get_ui_font() -> Font:
	if _ui_font != null:
		return _ui_font
	var system_font: SystemFont = SystemFont.new()
	system_font.font_names = UI_FONT_CANDIDATES
	_ui_font = system_font
	return _ui_font


func _set_label_font_size(label: Label, font_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.custom_minimum_size.y = ceilf(float(font_size) * 1.24)


func _emit_state(state: String) -> void:
	state_requested.emit(state)


func _emit_quit() -> void:
	quit_requested.emit()


func _add_label(parent: Node, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size = Vector2(200, 300)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# label.clip_text = true
	label.add_theme_font_override("font", _get_ui_font())
	parent.add_child(label)
	return label


func _tr(key: String, fallback: String) -> String:
	return LocalizationServiceScript.translate(key, {}, fallback)
