## 文件用途：构建并刷新玩家、Boss、波次、经验和技能槽 HUD。
## 使用方式：先 build(tree)，再 update(tree,state)；展示数据由 RunHudStateProvider 提供。

extends RefCounted
class_name RunHudController

signal pause_requested

const COLOR_PANEL := Color(0.035, 0.031, 0.035, 0.76)
const COLOR_PANEL_STRONG := Color(0.025, 0.023, 0.030, 0.88)
const COLOR_STROKE := Color(0.58, 0.42, 0.22, 0.42)
const COLOR_TEXT := Color(0.94, 0.97, 1.0, 1.0)
const COLOR_MUTED := Color(0.74, 0.68, 0.60, 1.0)
const COLOR_HP := Color(0.76, 0.03, 0.04, 1.0)
const COLOR_EXP := Color(0.08, 0.30, 0.68, 1.0)
const COLOR_BOSS := Color(0.72, 0.02, 0.04, 1.0)
const COLOR_WARN := Color(1.0, 0.63, 0.18, 1.0)
const COLOR_GOLD := Color(0.86, 0.66, 0.36, 1.0)
const COLOR_BAR_TRACK := Color(0.018, 0.014, 0.014, 0.96)
const HUD_EDGE_MARGIN: float = 16.0
const HUD_PANEL_GAP: float = 12.0
const HUD_CENTER_GAP: float = 8.0
const HUD_MIN_SCALE: float = 0.45
const HUD_AVATAR_FRAME_TEXTURE: String = "res://assets/ui/hud/avatar_frame.png"
const HUD_SKILL_SLOT_TEXTURE: String = "res://assets/ui/hud/skill_slot.png"
const HUD_SKILL_SLOT_FEATURED_TEXTURE: String = "res://assets/ui/hud/skill_slot_featured.png"
const HUD_PAUSE_BUTTON_TEXTURE: String = "res://assets/ui/hud/pause_button_art.png"
const HUD_TIMER_PLAQUE_TEXTURE: String = "res://assets/ui/hud/timer_plaque.png"
const FIREBALL_ATTACK_ICON_TEXTURE: String = "res://assets/ui/hud/fireball_spell_icon.png"
const HUD_ACTIVE_SKILL_SLOT_COUNT: int = 5
const HUD_PASSIVE_SKILL_SLOT_COUNT: int = 3

var _tree: SceneTree
var _screen: CanvasLayer
var _root: Control
var _layout_items: Array[Dictionary] = []
var _font_items: Array[Dictionary] = []
var _labels: Dictionary = {}
var _bars: Dictionary = {}
var _panels: Dictionary = {}
var _textures: Dictionary = {}
var _debug_labels: Dictionary = {}
var _skill_slot_panel: Control
var _skill_slot_nodes: Array[Dictionary] = []
var _last_layout_size: Vector2 = Vector2.ZERO


## 作用：构建并刷新玩家、Boss、波次、经验和技能槽 HUD。
## 使用：由页面或局内编排的构建流程调用；构建前应提供有效父容器；输入 tree（场景树）；返回 CanvasLayer 对象/值。
func build(tree: SceneTree) -> CanvasLayer:
	_tree = tree
	_screen = CanvasLayer.new()
	_screen.name = "RunHUD"
	_screen.layer = 199
	_screen.visible = false

	_root = Control.new()
	_root.name = "BattleHUD"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_root)

	_build_player_status()
	_build_boss_status()
	_build_top_center()
	_build_skill_bar()
	_build_exp_bar()
	_build_pause_button()

	return _screen


## 作用：获取页面，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 CanvasLayer 对象/值。
func get_screen() -> CanvasLayer:
	return _screen


## 作用：更新布局。
## 使用：本文件由 update 调用。
func update_layout() -> void:
	if not is_instance_valid(_root):
		return
	if not _root.is_inside_tree():
		return
	var viewport_size := _root.get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	_last_layout_size = viewport_size
	var design_width: float = 1.0
	for item in _layout_items:
		var control: Control = item.control
		if is_instance_valid(control) and control.get_parent() == _root:
			var rect: Rect2 = item.rect
			design_width = maxf(design_width, rect.size.x + absf(rect.position.x) * 2.0)
	var hud_scale: float = clampf((viewport_size.x - HUD_EDGE_MARGIN * 2.0) / design_width, HUD_MIN_SCALE, 1.0)
	for item in _layout_items:
		var control: Control = item.control
		if not is_instance_valid(control):
			continue
		var rect: Rect2 = item.rect
		var anchor: String = String(item.get("anchor", "top_left"))
		_apply_layout_rect(control, rect, anchor, viewport_size, hud_scale if control.get_parent() == _root else 1.0)
	for item in _font_items:
		var label: Label = item.label
		if not is_instance_valid(label):
			continue
		label.add_theme_font_size_override("font_size", int(item.size))
	_ensure_fixed_skill_slots()
	_layout_skill_slots()
	_enforce_fixed_panel_spacing(viewport_size)


## 作用：在 HUD 可见时刷新血量经验、时间波次、Boss、技能槽与调试信息，并适配视口变化。
## 使用：支持 update(tree,state,...) 或 update(state,...)；state 为 HUD 字典，末尾参数提供默认波次与时间值。
func update(first: Variant, second: Variant = null, current_wave: int = 0, wave_time_remaining: float = 0.0, run_seconds: float = 0.0) -> void:
	if not is_instance_valid(_screen) or not _screen.visible:
		return
	if is_instance_valid(_root):
		var viewport_size := _root.get_viewport_rect().size
		if viewport_size != _last_layout_size:
			update_layout()
	if first is SceneTree:
		_tree = first
	var run_state: Dictionary = {}
	if second is Dictionary:
		run_state = second
	elif first is Dictionary:
		run_state = first
	if not run_state.is_empty():
		_update_player_bars(run_state)
		_update_runtime_labels(run_state, current_wave, wave_time_remaining, run_seconds)
		_update_boss_bar(run_state)
		_update_hud_visuals(run_state)
		_update_skill_slots(run_state)
		_update_debug_stats(run_state)
	_enforce_fixed_panel_spacing(_last_layout_size)


## 作用：设置标签。
## 使用：本文件由 show_announcement 调用；输入 key（键）、text（文本）。
func set_label(key: String, text: String) -> void:
	var label: Label = _get_label_for_external_key(key)
	if label != null:
		label.text = text


## 作用：显示公告。
## 使用：供本模块调用者使用；输入 text（文本）。
func show_announcement(text: String) -> void:
	set_label("announcement", text)


## 作用：构建暂停按钮并配置节点/样式所需的属性。
## 使用：本文件由 build 调用。
func _build_pause_button() -> void:
	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = ""
	pause_button.focus_mode = Control.FOCUS_ALL
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	pause_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	pause_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_create_art_rect(pause_button, "PauseButtonArt", Rect2(0, 0, 54, 54), HUD_PAUSE_BUTTON_TEXTURE)
	pause_button.pressed.connect(_on_pause_pressed)
	_root.add_child(pause_button)
	_register_layout(pause_button, Rect2(HUD_EDGE_MARGIN, HUD_EDGE_MARGIN, 54, 54), "top_right")


## 作用：构建玩家状态效果并配置节点/样式所需的属性。
## 使用：本文件由 build 调用。
func _build_player_status() -> void:
	var panel := _create_panel("PlayerStatusPanel", Rect2(18, 18, 392, 118), true)
	var avatar_frame := Control.new()
	avatar_frame.name = "AvatarFrame"
	panel.add_child(avatar_frame)
	_register_layout(avatar_frame, Rect2(0, 3, 112, 112))
	_create_art_rect(avatar_frame, "AvatarFrameArt", Rect2(0, 0, 112, 112), HUD_AVATAR_FRAME_TEXTURE)
	var avatar_clip := Control.new()
	avatar_clip.name = "AvatarClip"
	avatar_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_clip.clip_contents = true
	avatar_frame.add_child(avatar_clip)
	_register_layout(avatar_clip, Rect2(24, 22, 64, 64))
	var avatar := _create_icon_rect(avatar_clip, "avatar", Rect2(0, 0, 64, 64))
	avatar.self_modulate = Color.WHITE
	_bars.hp = _create_progress_bar(panel, "HPBar", Rect2(98, 22, 270, 28), COLOR_HP, "top_left", "ornate")
	_labels.hp_title = _create_label(panel, "HPTitle", "HP", Rect2(120, 24, 30, 24), 12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, COLOR_TEXT)
	_labels.hp_number = _create_label(panel, "HPNumber", "", Rect2(150, 21, 190, 30), 14, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_bars.exp = _create_progress_bar(panel, "EXPBar", Rect2(104, 56, 250, 24), COLOR_EXP, "top_left", "thin")
	_labels.exp_title = _create_label(panel, "EXPTitle", "EXP", Rect2(122, 58, 30, 20), 10, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, COLOR_MUTED)
	_labels.exp_number = _create_label(panel, "EXPNumber", "EXP 0/0", Rect2(154, 57, 174, 22), 11, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, COLOR_TEXT)
	_labels.level = _create_label(panel, "LevelBadge", "1", Rect2(0, 80, 46, 34), 15, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, COLOR_GOLD)
	_labels.status = _create_label(panel, "StatusIconRow", "-", Rect2(122, 90, 232, 22), 12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, COLOR_MUTED)


## 作用：构建Boss状态效果。
## 使用：本文件由 build 调用。
func _build_boss_status() -> void:
	var panel := _create_panel("BossStatusPanel", Rect2(0, 14, 660, 70), true, "top_center")
	_labels.boss_name = _create_label(panel, "BossName", "Boss", Rect2(0, 4, 660, 24), 19, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, COLOR_GOLD)
	_bars.boss = _create_progress_bar(panel, "BossHPBar", Rect2(34, 32, 592, 28), COLOR_BOSS, "top_left", "boss")
	_labels.boss_number = _create_label(panel, "BossHPNumber", "", Rect2(34, 31, 592, 30), 13, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_bars.boss.visible = false
	panel.visible = false


## 作用：构建顶部中心并配置节点/样式所需的属性。
## 使用：本文件由 build 调用。
func _build_top_center() -> void:
	var panel := _create_panel("TimerPanel", Rect2(0, 48, 126, 44), true, "top_center")
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_create_art_rect(panel, "TimerPlaqueArt", Rect2(-8, -4, 142, 54), HUD_TIMER_PLAQUE_TEXTURE)
	_labels.timer = _create_label(panel, "Timer", "00:00", Rect2(0, 0, 126, 44), 24, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_labels.center_warning = _create_label(_root, "CenterWarning", "", Rect2(0, 100, 360, 38), 18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, COLOR_WARN, "top_center")


## 作用：构建技能进度条。
## 使用：本文件由 build 调用。
func _build_skill_bar() -> void:
	var panel := _create_panel("SkillBar", Rect2(0, 30, 780, 112), false, "bottom_center")
	_skill_slot_panel = panel
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.018, 0.014, 0.018, 0.72), Color(0.58, 0.42, 0.22, 0.46), 6))
	_ensure_fixed_skill_slots()


## 作用：保留 _build_exp_bar 接口，当前实现不执行操作。
## 使用：本文件由 build 调用。
func _build_exp_bar() -> void:
	pass


## 作用：创建面板并配置节点/样式所需的属性。
## 使用：本文件由 _build_player_status、_build_boss_status、_build_top_center 调用；输入 name（名称）、rect（矩形）、strong（强化）、anchor（anchor）；返回 Panel 对象/值。
func _create_panel(name: String, rect: Rect2, strong: bool, anchor: String = "top_left") -> Panel:
	var panel := Panel.new()
	panel.name = name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL_STRONG if strong else COLOR_PANEL, COLOR_STROKE, 10))
	_root.add_child(panel)
	_panels[name] = panel
	_register_layout(panel, rect, anchor)
	return panel


## 作用：创建美术图矩形并配置节点/样式所需的属性。
## 使用：本文件由 _build_pause_button、_build_player_status、_build_top_center 调用；输入 parent（父节点）、name（名称）、rect（矩形）、texture_path（纹理路径）；返回 TextureRect 对象/值。
func _create_art_rect(parent: Control, name: String, rect: Rect2, texture_path: String) -> TextureRect:
	var art := TextureRect.new()
	art.name = name
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = _load_texture(texture_path)
	parent.add_child(art)
	_register_layout(art, rect)
	return art


## 作用：创建技能槽位并配置节点/样式所需的属性。
## 使用：内部辅助入口；输入 parent（父节点）、slot_name（槽位名称）、icon_name（图标名称）、rect（矩形）、placeholder（placeholder）。
func _create_skill_slot(parent: Control, slot_name: String, icon_name: String, rect: Rect2, placeholder: String) -> void:
	var slot := Control.new()
	slot.name = slot_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	_register_layout(slot, rect)
	var frame_path: String = HUD_SKILL_SLOT_FEATURED_TEXTURE if icon_name == "skill_primary_icon" else HUD_SKILL_SLOT_TEXTURE
	_create_art_rect(slot, "%sFrame" % slot_name, Rect2(0, 0, rect.size.x, rect.size.y), frame_path)
	var inset: float = 18.0 if icon_name == "skill_primary_icon" else 14.0
	var icon := _create_icon_rect(slot, icon_name, Rect2(inset, inset, rect.size.x - inset * 2.0, rect.size.y - inset * 2.0))
	icon.self_modulate = Color.WHITE if placeholder == "" else Color(1, 1, 1, 0.22)
	if placeholder != "":
		_create_label(slot, "%sPlaceholder" % slot_name, placeholder, Rect2(0, 0, rect.size.x, rect.size.y), 13, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, Color(1, 1, 1, 0.34))


## 作用：创建标签并配置节点/样式所需的属性。
## 使用：本文件由 _build_player_status、_build_boss_status、_build_top_center 调用；输入 parent（父节点）、name（名称）、text（文本）、rect（矩形）、font_size（字体尺寸）、h_align（halign）、v_align（valign）、color（颜色）、anchor（anchor）；返回 Label 对象/值。
func _create_label(parent: Control, name: String, text: String, rect: Rect2, font_size: int, h_align: HorizontalAlignment, v_align: VerticalAlignment, color: Color = COLOR_TEXT, anchor: String = "top_left") -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.horizontal_alignment = h_align
	label.vertical_alignment = v_align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	_labels[name] = label
	_register_layout(label, rect, anchor)
	_register_font(label, font_size)
	return label


## 作用：创建图标矩形并配置节点/样式所需的属性。
## 使用：本文件由 _build_player_status、_create_skill_slot 调用；输入 parent（父节点）、name（名称）、rect（矩形）；返回 TextureRect 对象/值。
func _create_icon_rect(parent: Control, name: String, rect: Rect2) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = name
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	_textures[name] = icon
	_register_layout(icon, rect)
	return icon


## 作用：创建直接标签并配置节点/样式所需的属性。
## 使用：本文件由 _create_dynamic_skill_slot 调用；输入 parent（父节点）、name（名称）、text（文本）、rect（矩形）、font_size（字体尺寸）、h_align（halign）、v_align（valign）、color（颜色）；返回 Label 对象/值。
func _create_direct_label(parent: Control, name: String, text: String, rect: Rect2, font_size: int, h_align: HorizontalAlignment, v_align: VerticalAlignment, color: Color = COLOR_TEXT) -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.horizontal_alignment = h_align
	label.vertical_alignment = v_align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	_set_control_rect(label, rect)
	return label


## 作用：创建直接纹理矩形并配置节点/样式所需的属性。
## 使用：本文件由 _create_dynamic_skill_slot 调用；输入 parent（父节点）、name（名称）、rect（矩形）、texture_path（纹理路径）；返回 TextureRect 对象/值。
func _create_direct_texture_rect(parent: Control, name: String, rect: Rect2, texture_path: String = "") -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.name = name
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = _load_texture(texture_path)
	parent.add_child(texture_rect)
	_set_control_rect(texture_rect, rect)
	return texture_rect


## 作用：创建进度进度条并配置节点/样式所需的属性。
## 使用：本文件由 _build_player_status、_build_boss_status 调用；输入 parent（父节点）、name（名称）、rect（矩形）、color（颜色）、anchor（anchor）、variant（变体）；返回 TextureProgressBar 对象/值。
func _create_progress_bar(parent: Control, name: String, rect: Rect2, color: Color, anchor: String = "top_left", variant: String = "default") -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.name = name
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	if variant == "default":
		bar.texture_under = _make_rect_texture(Color(0.06, 0.07, 0.10, 0.9))
		bar.texture_progress = _make_rect_texture(color)
	else:
		bar.texture_under = _make_bar_under_texture(rect.size, variant)
		bar.texture_progress = _make_bar_fill_texture(rect.size, color, variant)
		bar.texture_over = _make_bar_over_texture(rect.size, variant)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	_register_layout(bar, rect, anchor)
	return bar


## 作用：登记布局。
## 使用：本文件由 _build_pause_button、_build_player_status、_create_panel 调用；输入 control（控件）、rect（矩形）、anchor（anchor）。
func _register_layout(control: Control, rect: Rect2, anchor: String = "top_left") -> void:
	_layout_items.append({"control": control, "rect": rect, "anchor": anchor})


## 作用：应用布局矩形。
## 使用：本文件由 update_layout 调用；输入 control（控件）、rect（矩形）、anchor（anchor）、viewport_size（视口尺寸）、layout_scale（布局缩放）。
func _apply_layout_rect(control: Control, rect: Rect2, anchor: String, viewport_size: Vector2, layout_scale: float = 1.0) -> void:
	# Scale only root groups; descendants retain their design-space geometry.
	control.scale = Vector2.ONE * layout_scale
	var scaled_size: Vector2 = rect.size * layout_scale
	var position: Vector2 = rect.position * layout_scale
	match anchor:
		"top_center":
			position.x += (viewport_size.x - scaled_size.x) * 0.5
		"top_right":
			position.x = viewport_size.x - position.x - scaled_size.x
		"bottom_left":
			position.y = viewport_size.y - position.y - scaled_size.y
		"bottom_center":
			position.x += (viewport_size.x - scaled_size.x) * 0.5
			position.y = viewport_size.y - position.y - scaled_size.y
		"bottom_right":
			position.x = viewport_size.x - position.x - scaled_size.x
			position.y = viewport_size.y - position.y - scaled_size.y
		_:
			pass
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = position.x
	control.offset_top = position.y
	control.offset_right = position.x + rect.size.x
	control.offset_bottom = position.y + rect.size.y
	control.custom_minimum_size = rect.size


## 作用：强制固定面板间距。
## 使用：本文件由 update_layout、update 调用；输入 viewport_size（视口尺寸）。
func _enforce_fixed_panel_spacing(viewport_size: Vector2) -> void:
	var boss_panel := _get_panel("BossStatusPanel")
	var timer_panel := _get_panel("TimerPanel")
	var timer_label := _get_label_control("Timer", "timer")
	var warning_label := _get_label_control("CenterWarning", "center_warning")
	if _is_visible_control(boss_panel):
		_place_below(timer_panel, boss_panel, HUD_CENTER_GAP)
	elif is_instance_valid(timer_panel) and viewport_size != Vector2.ZERO:
		var timer_rect := _get_control_rect(timer_panel)
		timer_rect.position.x = (viewport_size.x - timer_rect.size.x * timer_panel.scale.x) * 0.5
		timer_rect.position.y = 48.0 * timer_panel.scale.y
		_set_control_rect(timer_panel, timer_rect)
	_place_below(warning_label, timer_panel if is_instance_valid(timer_panel) else timer_label, HUD_CENTER_GAP)


## 作用：获取面板，供当前模块后续逻辑使用。
## 使用：本文件由 _enforce_fixed_panel_spacing 调用；输入 name（名称）；返回 Control 对象/值。
func _get_panel(name: String) -> Control:
	return _panels.get(name, null) as Control


## 作用：获取标签控件，供当前模块后续逻辑使用。
## 使用：本文件由 _enforce_fixed_panel_spacing 调用；输入 primary_key（主要键）、fallback_key（回退键）；返回 Control 对象/值。
func _get_label_control(primary_key: String, fallback_key: String = "") -> Control:
	var control := _labels.get(primary_key, null) as Control
	if control == null and fallback_key != "":
		control = _labels.get(fallback_key, null) as Control
	return control


## 作用：判断可见控件，返回布尔判断结果。
## 使用：本文件由 _enforce_fixed_panel_spacing 调用；输入 control（控件）。
func _is_visible_control(control: Control) -> bool:
	return is_instance_valid(control) and control.visible


## 作用：放置下方。
## 使用：本文件由 _enforce_fixed_panel_spacing 调用；输入 control（控件）、previous（previous）、gap（间隔）。
func _place_below(control: Control, previous: Control, gap: float) -> void:
	if not is_instance_valid(control) or not is_instance_valid(previous):
		return
	if not previous.visible:
		return
	var previous_rect := _get_control_rect(previous)
	var control_rect := _get_control_rect(control)
	control_rect.position.y = previous_rect.position.y + (previous_rect.size.y + gap) * previous.scale.y
	_set_control_rect(control, control_rect)


## 作用：获取控件矩形，供当前模块后续逻辑使用。
## 使用：本文件由 _enforce_fixed_panel_spacing、_place_below 调用；输入 control（控件）；返回 Rect2 对象/值。
func _get_control_rect(control: Control) -> Rect2:
	return Rect2(
		Vector2(control.offset_left, control.offset_top),
		Vector2(control.offset_right - control.offset_left, control.offset_bottom - control.offset_top)
	)


## 作用：设置控件矩形。
## 使用：本文件由 _create_direct_label、_create_direct_texture_rect、_enforce_fixed_panel_spacing 调用；输入 control（控件）、rect（矩形）。
func _set_control_rect(control: Control, rect: Rect2) -> void:
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y
	control.custom_minimum_size = rect.size


## 作用：登记字体。
## 使用：本文件由 _create_label 调用；输入 label（标签）、base_size（基础尺寸）。
func _register_font(label: Label, base_size: int) -> void:
	_font_items.append({"label": label, "size": base_size})


## 作用：生成面板样式并配置节点/样式所需的属性。
## 使用：本文件由 _build_skill_bar、_create_panel 调用；输入 fill（填充）、stroke（stroke）、radius（半径）；返回 StyleBoxFlat 对象/值。
func _make_panel_style(fill: Color, stroke: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = stroke
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


## 作用：生成矩形纹理。
## 使用：本文件由 _create_progress_bar 调用；输入 color（颜色）；返回 ImageTexture 对象/值。
func _make_rect_texture(color: Color) -> ImageTexture:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


## 作用：生成进度条底图纹理。
## 使用：本文件由 _create_progress_bar 调用；输入 size（尺寸）、_variant（变体）；返回 ImageTexture 对象/值。
func _make_bar_under_texture(size: Vector2, _variant: String) -> ImageTexture:
	var width: int = maxi(16, int(round(size.x)))
	var height: int = maxi(8, int(round(size.y)))
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		for x: int in range(width):
			if _is_bar_corner_cutout(x, y, width, height):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var edge: bool = x < 2 or y < 2 or x >= width - 2 or y >= height - 2
			var color := COLOR_BAR_TRACK
			if edge:
				color = Color(0.25, 0.17, 0.09, 0.98)
			elif y < 5:
				color = Color(0.09, 0.055, 0.035, 0.96)
			elif y > height - 5:
				color = Color(0.0, 0.0, 0.0, 0.98)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## 作用：生成进度条填充纹理。
## 使用：本文件由 _create_progress_bar 调用；输入 size（尺寸）、color（颜色）、_variant（变体）；返回 ImageTexture 对象/值。
func _make_bar_fill_texture(size: Vector2, color: Color, _variant: String) -> ImageTexture:
	var width: int = maxi(16, int(round(size.x)))
	var height: int = maxi(8, int(round(size.y)))
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var dark := color.darkened(0.42)
	var bright := color.lightened(0.28)
	for y: int in range(height):
		var t: float = float(y) / float(maxi(1, height - 1))
		var row_color: Color = bright.lerp(dark, t)
		for x: int in range(width):
			if _is_bar_corner_cutout(x, y, width, height):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var color_out := row_color
			if y < 2:
				color_out = Color(1.0, 0.82, 0.60, 0.40).lerp(row_color, 0.45)
			elif y > height - 4:
				color_out = row_color.darkened(0.34)
			if x < 3:
				color_out = color_out.lightened(0.18)
			image.set_pixel(x, y, color_out)
	return ImageTexture.create_from_image(image)


## 作用：生成进度条前景纹理。
## 使用：本文件由 _create_progress_bar 调用；输入 size（尺寸）、_variant（变体）；返回 ImageTexture 对象/值。
func _make_bar_over_texture(size: Vector2, _variant: String) -> ImageTexture:
	var width: int = maxi(16, int(round(size.x)))
	var height: int = maxi(8, int(round(size.y)))
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y: int in range(height):
		for x: int in range(width):
			if _is_bar_corner_cutout(x, y, width, height):
				continue
			if _is_bar_outline_pixel(x, y, width, height, 5):
				image.set_pixel(x, y, Color(0.72, 0.52, 0.26, 0.88))
			elif _is_bar_outline_pixel(x, y, width, height, 7):
				image.set_pixel(x, y, Color(0.05, 0.03, 0.015, 0.82))
	return ImageTexture.create_from_image(image)


## 作用：判断进度条拐角镂空，返回布尔判断结果。
## 使用：本文件由 _make_bar_under_texture、_make_bar_fill_texture、_make_bar_over_texture 调用；输入 x（x）、y（y）、width（宽度）、height（height）。
func _is_bar_corner_cutout(x: int, y: int, width: int, height: int) -> bool:
	return not _is_inside_bar_shape(x, y, width, height)


## 作用：判断内部进度条形状，返回布尔判断结果。
## 使用：本文件由 _is_bar_corner_cutout、_is_bar_outline_pixel 调用；输入 x（x）、y（y）、width（宽度）、height（height）。
func _is_inside_bar_shape(x: int, y: int, width: int, height: int) -> bool:
	var radius: float = maxf(5.0, float(height) * 0.45)
	var left_center := Vector2(radius, float(height) * 0.5)
	var right_center := Vector2(float(width) - radius - 1.0, float(height) * 0.5)
	if float(x) < radius:
		return Vector2(float(x), float(y)).distance_to(left_center) <= radius
	if float(x) > float(width) - radius - 1.0:
		return Vector2(float(x), float(y)).distance_to(right_center) <= radius
	return true


## 作用：判断进度条描边像素，返回布尔判断结果。
## 使用：本文件由 _make_bar_over_texture 调用；输入 x（x）、y（y）、width（宽度）、height（height）、thickness（thickness）。
func _is_bar_outline_pixel(x: int, y: int, width: int, height: int, thickness: int) -> bool:
	if not _is_inside_bar_shape(x, y, width, height):
		return false
	if x < thickness or y < thickness or x >= width - thickness or y >= height - thickness:
		return true
	for offset_y: int in range(-thickness, thickness + 1):
		for offset_x: int in range(-thickness, thickness + 1):
			if absi(offset_x) + absi(offset_y) > thickness:
				continue
			var sample_x: int = x + offset_x
			var sample_y: int = y + offset_y
			if sample_x < 0 or sample_y < 0 or sample_x >= width or sample_y >= height:
				return true
			if not _is_inside_bar_shape(sample_x, sample_y, width, height):
				return true
	return false


## 作用：更新玩家进度条组。
## 使用：本文件由 update 调用；输入 run_state（单局状态）。
func _update_player_bars(run_state: Dictionary) -> void:
	var max_health: float = maxf(1.0, float(run_state.get("max_health", 100.0)))
	var health: float = clampf(float(run_state.get("health", max_health)), 0.0, max_health)
	_bars.hp.max_value = max_health
	_bars.hp.value = health
	_labels.hp_number.text = "%d/%d" % [int(round(health)), int(round(max_health))]
	var level: int = int(run_state.get("level", 1))
	var exp_required: int = maxi(1, int(run_state.get("exp_required", 1)))
	var exp_value: float = clampf(float(run_state.get("exp", 0)), 0.0, float(exp_required))
	_bars.exp.max_value = float(exp_required)
	_bars.exp.value = exp_value
	_labels.level.text = "%d" % level
	_labels.exp_number.text = "%d/%d" % [int(round(exp_value)), exp_required]


## 作用：更新运行时标签组。
## 使用：本文件由 update 调用；输入 run_state（单局状态）、current_wave（当前波次）、wave_time_remaining（波次时间剩余）、run_seconds（单局秒）。
func _update_runtime_labels(run_state: Dictionary, current_wave: int, wave_time_remaining: float, run_seconds: float) -> void:
	var duration: float = float(run_state.get("run_duration", 0.0))
	var remaining: float = maxf(0.0, duration - run_seconds) if duration > 0.0 else maxf(0.0, wave_time_remaining)
	_labels.timer.text = _format_time(remaining)
	var status_summary := String(run_state.get("status_summary", "-"))
	_labels.status.text = status_summary


## 作用：更新Boss进度条。
## 使用：本文件由 update 调用；输入 run_state（单局状态）。
func _update_boss_bar(run_state: Dictionary) -> void:
	if not _bars.has("boss"):
		return
	var boss_state: Dictionary = _variant_to_dictionary(run_state.get("boss", {}))
	var has_boss: bool = bool(boss_state.get("visible", false))
	_bars.boss.visible = has_boss
	_labels.boss_name.visible = has_boss
	if has_boss:
		var max_health: float = maxf(1.0, float(boss_state.get("max_health", 1.0)))
		var health: float = clampf(float(boss_state.get("health", 0.0)), 0.0, max_health)
		_bars.boss.max_value = max_health
		_bars.boss.value = health
		_labels.boss_name.text = String(boss_state.get("name", "Boss"))
		if _labels.has("boss_number"):
			_labels.boss_number.text = "%d/%d" % [int(round(health)), int(round(max_health))]
	var boss_panel: Control = _panels.get("BossStatusPanel", null) as Control
	if is_instance_valid(boss_panel):
		boss_panel.visible = has_boss


## 作用：更新HUD视觉组。
## 使用：本文件由 update 调用；输入 run_state（单局状态）。
func _update_hud_visuals(run_state: Dictionary) -> void:
	_update_character_visual(run_state)
	_update_starting_skill_visual(run_state)
	_update_primary_attack_visual(run_state)
	_update_ultimate_slot_visual()


## 作用：更新技能槽位组。
## 使用：本文件由 update 调用；输入 run_state（单局状态）。
func _update_skill_slots(run_state: Dictionary) -> void:
	_ensure_fixed_skill_slots()
	var active_skills: Array = _get_array(run_state.get("active_skills", []))
	if active_skills.is_empty() and run_state.has("skills"):
		active_skills = _get_array(run_state.get("skills", []))
	var passive_skills: Array = _get_array(run_state.get("passive_skills", []))
	var primary_skill: Dictionary = _variant_to_dictionary(run_state.get("primary_skill", {}))
	var dash_skill: Dictionary = _variant_to_dictionary(run_state.get("dash_skill", {}))
	_layout_skill_slots()
	for index: int in range(_skill_slot_nodes.size()):
		var nodes: Dictionary = _skill_slot_nodes[index]
		var slot_kind: String = String(nodes.get("kind", "active"))
		var slot_index: int = int(nodes.get("slot_index", 0))
		var skill: Dictionary = {}
		match slot_kind:
			"primary":
				skill = primary_skill
			"dash":
				skill = dash_skill
			"passive":
				if slot_index < passive_skills.size() and passive_skills[slot_index] is Dictionary:
					skill = passive_skills[slot_index]
			_:
				if slot_index < active_skills.size() and active_skills[slot_index] is Dictionary:
					skill = active_skills[slot_index]
		_update_skill_slot_nodes(nodes, skill)


## 作用：更新技能槽位节点组。
## 使用：本文件由 _update_skill_slots 调用；输入 nodes（节点组）、skill（技能）。
func _update_skill_slot_nodes(nodes: Dictionary, skill: Dictionary) -> void:
	var slot: Control = nodes.get("slot", null) as Control
	if not is_instance_valid(slot):
		return
	slot.visible = true
	var has_skill: bool = not skill.is_empty()
	slot.modulate = Color(1, 1, 1, 1.0) if has_skill else Color(1, 1, 1, 0.34)
	var name_label: Label = nodes.get("name_label", null) as Label
	var key_label: Label = nodes.get("key_label", null) as Label
	var icon: TextureRect = nodes.get("icon", null) as TextureRect
	var cooldown_label: Label = nodes.get("cooldown_label", null) as Label
	var cooldown_mask: ColorRect = nodes.get("cooldown_mask", null) as ColorRect
	if not has_skill:
		if is_instance_valid(name_label):
			name_label.text = ""
		if is_instance_valid(icon):
			icon.texture = null
			icon.self_modulate = Color(1.0, 1.0, 1.0, 0.10)
		if is_instance_valid(cooldown_label):
			cooldown_label.visible = false
		if is_instance_valid(cooldown_mask):
			cooldown_mask.visible = false
		return
	if has_skill:
		var display_name: String = String(skill.get("display_name", skill.get("id", "")))
		if display_name == "":
			display_name = "-"
		if is_instance_valid(name_label):
			name_label.text = display_name
		if is_instance_valid(icon):
			var texture: Texture2D = _load_texture(String(skill.get("icon", "")))
			icon.texture = texture
			icon.self_modulate = Color.WHITE if texture != null else Color(1.0, 1.0, 1.0, 0.12)
		var cooldown_remaining: float = maxf(float(skill.get("cooldown_remaining", 0.0)), 0.0)
		var cooldown_total: float = maxf(float(skill.get("cooldown_total", 0.0)), cooldown_remaining)
		var show_cooldown: bool = cooldown_remaining > 0.05 and cooldown_total > 0.0
		if is_instance_valid(cooldown_label):
			cooldown_label.visible = show_cooldown
			cooldown_label.text = _format_cooldown(cooldown_remaining)
		if is_instance_valid(key_label):
			key_label.visible = true
		if is_instance_valid(cooldown_mask):
			cooldown_mask.visible = show_cooldown
			var slot_size: Vector2 = slot.size
			var progress: float = clampf(cooldown_remaining / cooldown_total, 0.0, 1.0) if cooldown_total > 0.0 else 0.0
			_set_control_rect(cooldown_mask, Rect2(0.0, slot_size.y * (1.0 - progress), slot_size.x, slot_size.y * progress))


## 作用：确保技能槽位数量。
## 使用：内部辅助入口；输入 count（数量）。
func _ensure_skill_slot_count(count: int) -> void:
	if not is_instance_valid(_skill_slot_panel):
		return
	while _skill_slot_nodes.size() < count:
		_skill_slot_nodes.append(_create_dynamic_skill_slot(_skill_slot_nodes.size(), "SkillSlot%d" % _skill_slot_nodes.size(), "%d" % (_skill_slot_nodes.size() + 1), "active", _skill_slot_nodes.size()))
	for index: int in range(_skill_slot_nodes.size()):
		var nodes: Dictionary = _skill_slot_nodes[index]
		var slot: Control = nodes.get("slot", null) as Control
		if is_instance_valid(slot):
			slot.visible = index < count


## 作用：确保固定技能槽位组。
## 使用：本文件由 update_layout、_build_skill_bar、_update_skill_slots 调用。
func _ensure_fixed_skill_slots() -> void:
	if not is_instance_valid(_skill_slot_panel):
		return
	if not _skill_slot_nodes.is_empty():
		return
	_skill_slot_nodes.append(_create_dynamic_skill_slot(0, "SkillSlotPrimary", "A", "primary", 0, true))
	_skill_slot_nodes.append(_create_dynamic_skill_slot(1, "SkillSlotDash", "D", "dash", 0, true))
	for index: int in range(HUD_ACTIVE_SKILL_SLOT_COUNT):
		_skill_slot_nodes.append(_create_dynamic_skill_slot(_skill_slot_nodes.size(), "SkillSlotActive%d" % index, "%d" % (index + 1), "active", index))
	for index: int in range(HUD_PASSIVE_SKILL_SLOT_COUNT):
		_skill_slot_nodes.append(_create_dynamic_skill_slot(_skill_slot_nodes.size(), "SkillSlotPassive%d" % index, "P%d" % (index + 1), "passive", index))


## 作用：创建动态技能槽位并配置节点/样式所需的属性。
## 使用：本文件由 _ensure_skill_slot_count、_ensure_fixed_skill_slots 调用；输入 index（索引）、slot_name（槽位名称）、key_text（键文本）、kind（类型）、slot_index（槽位索引）、featured（featured）；返回字典包含 slot/frame/icon/cooldown_mask/name_label/key_label/cooldown_label/kind 等字段。
func _create_dynamic_skill_slot(index: int, slot_name: String = "", key_text: String = "", kind: String = "active", slot_index: int = 0, featured: bool = false) -> Dictionary:
	var slot := Control.new()
	slot.name = slot_name if slot_name != "" else "SkillSlot%d" % index
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_slot_panel.add_child(slot)

	var frame_texture: String = HUD_SKILL_SLOT_FEATURED_TEXTURE if featured else HUD_SKILL_SLOT_TEXTURE
	var frame := _create_direct_texture_rect(slot, "%sFrame" % slot.name, Rect2(0, 0, 72, 72), frame_texture)
	var icon := _create_direct_texture_rect(slot, "%sIcon" % slot.name, Rect2(14, 10, 44, 44))
	var cooldown_mask := ColorRect.new()
	cooldown_mask.name = "%sCooldownMask" % slot.name
	cooldown_mask.color = Color(0.02, 0.025, 0.035, 0.68)
	cooldown_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_mask.visible = false
	slot.add_child(cooldown_mask)
	_set_control_rect(cooldown_mask, Rect2(0, 0, 72, 72))
	var name_label := _create_direct_label(slot, "%sName" % slot.name, "", Rect2(4, 50, 64, 20), 11, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	name_label.visible = false
	var key_label := _create_direct_label(slot, "%sKey" % slot.name, key_text if key_text != "" else "%d" % (index + 1), Rect2(24, 54, 24, 18), 12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, COLOR_GOLD)
	var cooldown_label := _create_direct_label(slot, "%sCooldown" % slot.name, "", Rect2(0, 0, 72, 72), 18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	cooldown_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	cooldown_label.add_theme_constant_override("shadow_offset_x", 1)
	cooldown_label.add_theme_constant_override("shadow_offset_y", 1)
	cooldown_label.visible = false
	return {
		"slot": slot,
		"frame": frame,
		"icon": icon,
		"cooldown_mask": cooldown_mask,
		"name_label": name_label,
		"key_label": key_label,
		"cooldown_label": cooldown_label,
		"kind": kind,
		"slot_index": slot_index
	}


## 作用：布局技能槽位组。
## 使用：本文件由 update_layout、_update_skill_slots 调用；输入 count（数量）。
func _layout_skill_slots(count: int = -1) -> void:
	if not is_instance_valid(_skill_slot_panel):
		return
	_ensure_fixed_skill_slots()
	var visible_count: int = _skill_slot_nodes.size() if count < 0 else maxi(count, 0)
	if visible_count <= 0:
		return
	var panel_size: Vector2 = _skill_slot_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(780.0, 112.0)
	var gap: float = 6.0
	var max_slot_size: float = 68.0
	var slot_size: float = minf(max_slot_size, floorf((panel_size.x - gap * float(maxi(visible_count - 1, 0)) - 16.0) / float(visible_count)))
	slot_size = clampf(slot_size, 44.0, max_slot_size)
	var total_width: float = slot_size * float(visible_count) + gap * float(maxi(visible_count - 1, 0))
	var start_x: float = (panel_size.x - total_width) * 0.5
	var top: float = (panel_size.y - slot_size) * 0.5
	for index: int in range(_skill_slot_nodes.size()):
		var nodes: Dictionary = _skill_slot_nodes[index]
		var slot: Control = nodes.get("slot", null) as Control
		if not is_instance_valid(slot):
			continue
		var should_show: bool = index < visible_count
		slot.visible = should_show
		if not should_show:
			continue
		_set_control_rect(slot, Rect2(start_x + float(index) * (slot_size + gap), top, slot_size, slot_size))
		_set_control_rect(nodes.get("frame", null) as Control, Rect2(0, 0, slot_size, slot_size))
		var icon_inset: float = maxf(8.0, slot_size * 0.18)
		_set_control_rect(nodes.get("icon", null) as Control, Rect2(icon_inset, icon_inset * 0.75, slot_size - icon_inset * 2.0, slot_size - icon_inset * 2.2))
		_set_control_rect(nodes.get("name_label", null) as Control, Rect2(3, slot_size - 27.0, slot_size - 6.0, 16.0))
		_set_control_rect(nodes.get("key_label", null) as Control, Rect2((slot_size - 24.0) * 0.5, slot_size - 18.0, 24.0, 18.0))
		_set_control_rect(nodes.get("cooldown_label", null) as Control, Rect2(0, 0, slot_size, slot_size))
		var cooldown_mask: ColorRect = nodes.get("cooldown_mask", null) as ColorRect
		if is_instance_valid(cooldown_mask) and not cooldown_mask.visible:
			_set_control_rect(cooldown_mask, Rect2(0, 0, slot_size, slot_size))


## 作用：获取当前技能数量，供当前模块后续逻辑使用。
## 使用：内部辅助入口；返回计算或读取的数值。
func _get_current_skill_count() -> int:
	var count: int = 0
	for nodes: Dictionary in _skill_slot_nodes:
		var slot: Control = nodes.get("slot", null) as Control
		if is_instance_valid(slot) and slot.visible:
			count += 1
	return count


## 作用：更新角色视觉。
## 使用：本文件由 _update_hud_visuals 调用；输入 run_state（单局状态）。
func _update_character_visual(run_state: Dictionary) -> void:
	var character_id: StringName = StringName(String(run_state.get("character_id", "")))
	var character_data: Dictionary = GameData.get_character(character_id)
	var texture: Texture2D = _get_definition_texture(character_data, ["portrait", "icon", "texture"])
	var avatar: TextureRect = _textures.get("avatar", null) as TextureRect
	if is_instance_valid(avatar):
		avatar.texture = texture
		avatar.self_modulate = Color.WHITE if texture != null else Color(0.35, 0.30, 0.45, 1.0)


## 作用：更新起始技能视觉。
## 使用：本文件由 _update_hud_visuals 调用；输入 run_state（单局状态）。
func _update_starting_skill_visual(run_state: Dictionary) -> void:
	var skill_data := _get_primary_attack_data(run_state)
	var texture: Texture2D = _get_definition_texture(skill_data, ["icon", "texture", "background_texture"])
	var icon: TextureRect = _textures.get("skill_starting_icon", null) as TextureRect
	if is_instance_valid(icon):
		icon.texture = texture
		icon.self_modulate = Color.WHITE if texture != null else Color(1, 1, 1, 0.18)


## 作用：更新主要攻击技能视觉。
## 使用：本文件由 _update_hud_visuals 调用；输入 run_state（单局状态）。
func _update_primary_attack_visual(run_state: Dictionary) -> void:
	var attack_data := _get_primary_attack_data(run_state)
	var texture: Texture2D = _get_primary_attack_texture(attack_data, run_state)
	var icon: TextureRect = _textures.get("skill_primary_icon", null) as TextureRect
	if is_instance_valid(icon):
		icon.texture = texture
		icon.self_modulate = Color.WHITE if texture != null else Color(1, 1, 1, 0.18)


## 作用：更新终极槽位视觉。
## 使用：本文件由 _update_hud_visuals 调用。
func _update_ultimate_slot_visual() -> void:
	var icon: TextureRect = _textures.get("skill_ultimate_icon", null) as TextureRect
	if is_instance_valid(icon):
		icon.texture = null
		icon.self_modulate = Color(1, 1, 1, 0.18)


## 作用：更新调试属性统计。
## 使用：本文件由 update 调用；输入 run_state（单局状态）。
func _update_debug_stats(run_state: Dictionary) -> void:
	if _debug_labels.is_empty() or not OS.is_debug_build():
		return
	var debug_stats: Dictionary = _variant_to_dictionary(run_state.get("debug_stats", {}))
	_debug_labels.fps.text = "FPS: %d" % int(debug_stats.get("fps", 0))
	_debug_labels.enemy_count.text = "Enemies: %d" % int(debug_stats.get("enemy_count", 0))
	_debug_labels.projectile_count.text = "Projectiles: %d" % int(debug_stats.get("projectile_count", 0))
	_debug_labels.pickup_count.text = "Pickups: %d" % int(debug_stats.get("pickup_count", 0))


## 作用：获取主要攻击技能数据，供当前模块后续逻辑使用。
## 使用：本文件由 _update_starting_skill_visual、_update_primary_attack_visual 调用；输入 run_state（单局状态）；返回结果字典。
func _get_primary_attack_data(run_state: Dictionary) -> Dictionary:
	var attack_id: StringName = StringName(String(run_state.get("main_attack", "")))
	if attack_id != &"":
		var attack: Dictionary = GameData.get_skill(attack_id)
		if not attack.is_empty():
			return attack
	return {}


## 作用：获取主要攻击技能纹理，供当前模块后续逻辑使用。
## 使用：本文件由 _update_primary_attack_visual 调用；输入 attack_data（攻击数据）、run_state（单局状态）；返回 Texture2D 对象/值。
func _get_primary_attack_texture(attack_data: Dictionary, run_state: Dictionary) -> Texture2D:
	var attack_id: String = String(attack_data.get("id", ""))
	if attack_id == "fireball":
		return _load_texture(FIREBALL_ATTACK_ICON_TEXTURE)
	var texture: Texture2D = _get_definition_texture(attack_data, ["icon", "texture", "background_texture"])
	if texture != null:
		return texture
	return null


## 作用：获取定义纹理，供当前模块后续逻辑使用。
## 使用：本文件由 _update_character_visual、_update_starting_skill_visual、_get_primary_attack_texture 调用；输入 definition（定义）、visual_keys（视觉keys）；返回 Texture2D 对象/值。
func _get_definition_texture(definition: Dictionary, visual_keys: Array[String]) -> Texture2D:
	if definition.is_empty():
		return null
	for key: String in visual_keys:
		var direct_path: String = String(definition.get(key, ""))
		var texture: Texture2D = _load_texture(direct_path)
		if texture != null:
			return texture
	var visual_data: Dictionary = _variant_to_dictionary(definition.get("visual", {}))
	for key: String in visual_keys:
		var visual_path: String = String(visual_data.get(key, ""))
		var texture: Texture2D = _load_texture(visual_path)
		if texture != null:
			return texture
	return null


## 作用：加载纹理。
## 使用：本文件由 _create_art_rect、_create_direct_texture_rect、_update_skill_slot_nodes 调用；输入 texture_path（纹理路径）；返回 Texture2D 对象/值。
func _load_texture(texture_path: String) -> Texture2D:
	if texture_path == "":
		return null
	if not ResourceLoader.exists(texture_path):
		return null
	return load(texture_path) as Texture2D


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _update_boss_bar、_update_skill_slots、_update_debug_stats 调用；输入 value（值）。
func _variant_to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 _update_skill_slots 调用；输入 value（值）。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：格式化时间。
## 使用：本文件由 _update_runtime_labels 调用；输入 seconds（秒）；返回 String 文本/标识。
func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%02d:%02d" % [int(total / 60), total % 60]


## 作用：格式化冷却。
## 使用：本文件由 _update_skill_slot_nodes 调用；输入 seconds（秒）；返回 String 文本/标识。
func _format_cooldown(seconds: float) -> String:
	if seconds >= 10.0:
		return "%d" % int(ceilf(seconds))
	return "%.1f" % seconds


## 作用：获取标签对应外部键，供当前模块后续逻辑使用。
## 使用：本文件由 set_label 调用；输入 key（键）；返回 Label 对象/值。
func _get_label_for_external_key(key: String) -> Label:
	var label_key: String = key
	match key:
		"announcement":
			label_key = "CenterWarning"
		_:
			pass
	var label: Label = _labels.get(label_key, null) as Label
	if label == null:
		label = _labels.get(key, null) as Label
	return label


## 作用：响应暂停点击并衔接对应的事件处理流程。
## 使用：内部辅助入口。
func _on_pause_pressed() -> void:
	pause_requested.emit()


## 作用：获取节点或空引用，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 path（路径）；返回 Node 对象/值。
func get_node_or_null(path: NodePath) -> Node:
	if not is_instance_valid(_tree) or not is_instance_valid(_tree.root):
		return null
	return _tree.root.get_node_or_null(path)
