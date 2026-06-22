extends RefCounted
class_name RunHudController

signal pause_requested

const COLOR_PANEL := Color(0.045, 0.052, 0.075, 0.78)
const COLOR_PANEL_STRONG := Color(0.035, 0.04, 0.062, 0.88)
const COLOR_STROKE := Color(0.55, 0.68, 0.95, 0.28)
const COLOR_TEXT := Color(0.94, 0.97, 1.0, 1.0)
const COLOR_MUTED := Color(0.68, 0.74, 0.84, 1.0)
const COLOR_HP := Color(0.90, 0.18, 0.22, 1.0)
const COLOR_EXP := Color(0.25, 0.63, 1.0, 1.0)
const COLOR_BOSS := Color(0.88, 0.13, 0.35, 1.0)
const COLOR_WARN := Color(1.0, 0.63, 0.18, 1.0)
const COLOR_GOLD := Color(0.86, 0.66, 0.36, 1.0)
const HUD_EDGE_MARGIN: float = 16.0
const HUD_PANEL_GAP: float = 12.0
const HUD_CENTER_GAP: float = 8.0
const HUD_AVATAR_FRAME_TEXTURE: String = "res://assets/ui/hud/avatar_frame.png"
const HUD_SKILL_SLOT_TEXTURE: String = "res://assets/ui/hud/skill_slot.png"
const HUD_SKILL_SLOT_FEATURED_TEXTURE: String = "res://assets/ui/hud/skill_slot_featured.png"
const HUD_PAUSE_BUTTON_TEXTURE: String = "res://assets/ui/hud/pause_button_art.png"
const HUD_TIMER_PLAQUE_TEXTURE: String = "res://assets/ui/hud/timer_plaque.png"
const FIREBALL_ATTACK_ICON_TEXTURE: String = "res://assets/ui/hud/fireball_spell_icon.png"

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
var _last_layout_size: Vector2 = Vector2.ZERO


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

	_build_pause_button()

	return _screen


func get_screen() -> CanvasLayer:
	return _screen


func update_layout() -> void:
	if not is_instance_valid(_root):
		return
	if not _root.is_inside_tree():
		return
	var viewport_size := _root.get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	_last_layout_size = viewport_size
	for item in _layout_items:
		var control: Control = item.control
		if not is_instance_valid(control):
			continue
		var rect: Rect2 = item.rect
		var anchor: String = String(item.get("anchor", "top_left"))
		_apply_layout_rect(control, rect, anchor, viewport_size)
	for item in _font_items:
		var label: Label = item.label
		if not is_instance_valid(label):
			continue
		label.add_theme_font_size_override("font_size", int(item.size))
	_enforce_fixed_panel_spacing(viewport_size)


func update(first: Variant, second: Variant = null, current_wave: int = 0, wave_time_remaining: float = 0.0, run_seconds: float = 0.0) -> void:
	if not is_instance_valid(_screen) or not _screen.visible:
		return
	if is_instance_valid(_root):
		var viewport_size := _root.get_viewport_rect().size
		if viewport_size != _last_layout_size:
			update_layout()
	if first is SceneTree:
		_tree = first
	_enforce_fixed_panel_spacing(_last_layout_size)


func set_label(key: String, text: String) -> void:
	var label: Label = _get_label_for_external_key(key)
	if label != null:
		label.text = text


func show_announcement(text: String) -> void:
	set_label("announcement", text)


func _build_pause_button() -> void:
	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = ""
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	pause_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	pause_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_create_art_rect(pause_button, "PauseButtonArt", Rect2(0, 0, 54, 54), HUD_PAUSE_BUTTON_TEXTURE)
	pause_button.pressed.connect(_on_pause_pressed)
	_root.add_child(pause_button)
	_register_layout(pause_button, Rect2(HUD_EDGE_MARGIN, HUD_EDGE_MARGIN, 54, 54), "top_right")


func _build_player_status() -> void:
	var panel := _create_panel("PlayerStatusPanel", Rect2(18, 18, 320, 100), true)
	var avatar_frame := Control.new()
	avatar_frame.name = "AvatarFrame"
	panel.add_child(avatar_frame)
	_register_layout(avatar_frame, Rect2(0, -4, 96, 96))
	_create_art_rect(avatar_frame, "AvatarFrameArt", Rect2(0, 0, 96, 96), HUD_AVATAR_FRAME_TEXTURE)
	var avatar_clip := Control.new()
	avatar_clip.name = "AvatarClip"
	avatar_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_clip.clip_contents = true
	avatar_frame.add_child(avatar_clip)
	_register_layout(avatar_clip, Rect2(20, 18, 56, 56))
	var avatar := _create_icon_rect(avatar_clip, "avatar", Rect2(0, 0, 56, 56))
	avatar.self_modulate = Color.WHITE
	_labels.hp_title = _create_label(panel, "HPTitle", "HP", Rect2(102, 12, 32, 18), 12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, COLOR_MUTED)
	_bars.hp = _create_progress_bar(panel, "HPBar", Rect2(136, 12, 168, 22), COLOR_HP)
	_labels.hp_number = _create_label(panel, "HPNumber", "", Rect2(136, 11, 168, 24), 13, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_labels.level = _create_label(panel, "LevelBadge", "Lv 1", Rect2(102, 48, 54, 24), 14, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_labels.status = _create_label(panel, "StatusIconRow", "-", Rect2(164, 48, 140, 24), 12, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, COLOR_MUTED)


func _build_boss_status() -> void:
	var panel := _create_panel("BossStatusPanel", Rect2(0, 14, 640, 28), true, "top_center")
	_bars.boss = _create_progress_bar(panel, "BossHPBar", Rect2(0, 0, 640, 28), COLOR_BOSS)
	_labels.boss_name = _create_label(panel, "BossName", "Boss", Rect2(12, 0, 220, 28), 13, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	_bars.boss.visible = false
	panel.visible = false


func _build_top_center() -> void:
	var panel := _create_panel("TimerPanel", Rect2(0, 48, 126, 44), true, "top_center")
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_create_art_rect(panel, "TimerPlaqueArt", Rect2(-8, -4, 142, 54), HUD_TIMER_PLAQUE_TEXTURE)
	_labels.timer = _create_label(panel, "Timer", "00:00", Rect2(0, 0, 126, 44), 24, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_labels.center_warning = _create_label(_root, "CenterWarning", "", Rect2(0, 100, 360, 38), 18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, COLOR_WARN, "top_center")


func _build_skill_bar() -> void:
	var panel := _create_panel("SkillBar", Rect2(0, 28, 268, 88), false, "bottom_center")
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.022, 0.032, 0.18), Color(0, 0, 0, 0), 1))
	_create_skill_slot(panel, "SkillSlotWeapon", "skill_weapon_icon", Rect2(8, 6, 76, 76), "")
	_create_skill_slot(panel, "SkillSlotPrimary", "skill_primary_icon", Rect2(96, 0, 84, 84), "")
	_create_skill_slot(panel, "SkillSlotUltimate", "skill_ultimate_icon", Rect2(192, 6, 76, 76), "")


func _build_exp_bar() -> void:
	_bars.exp = _create_progress_bar(_root, "EXPBar", Rect2(0, 8, 520, 10), COLOR_EXP, "bottom_center")
	_labels.exp_number = _create_label(_root, "EXPNumber", "EXP 0/0", Rect2(0, 22, 520, 18), 12, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, COLOR_TEXT, "bottom_center")


func _create_panel(name: String, rect: Rect2, strong: bool, anchor: String = "top_left") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL_STRONG if strong else COLOR_PANEL, COLOR_STROKE, 10))
	_root.add_child(panel)
	_panels[name] = panel
	_register_layout(panel, rect, anchor)
	return panel


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


func _create_progress_bar(parent: Control, name: String, rect: Rect2, color: Color, anchor: String = "top_left") -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.name = name
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.texture_under = _make_rect_texture(Color(0.06, 0.07, 0.10, 0.9))
	bar.texture_progress = _make_rect_texture(color)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	_register_layout(bar, rect, anchor)
	return bar


func _register_layout(control: Control, rect: Rect2, anchor: String = "top_left") -> void:
	_layout_items.append({"control": control, "rect": rect, "anchor": anchor})


func _apply_layout_rect(control: Control, rect: Rect2, anchor: String, viewport_size: Vector2) -> void:
	var position: Vector2 = rect.position
	match anchor:
		"top_center":
			position.x = (viewport_size.x - rect.size.x) * 0.5 + rect.position.x
		"top_right":
			position.x = viewport_size.x - rect.position.x - rect.size.x
		"bottom_left":
			position.y = viewport_size.y - rect.position.y - rect.size.y
		"bottom_center":
			position.x = (viewport_size.x - rect.size.x) * 0.5 + rect.position.x
			position.y = viewport_size.y - rect.position.y - rect.size.y
		"bottom_right":
			position.x = viewport_size.x - rect.position.x - rect.size.x
			position.y = viewport_size.y - rect.position.y - rect.size.y
		_:
			pass
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = position.x
	control.offset_top = position.y
	control.offset_right = position.x + rect.size.x
	control.offset_bottom = position.y + rect.size.y
	control.custom_minimum_size = rect.size


func _enforce_fixed_panel_spacing(viewport_size: Vector2) -> void:
	var boss_panel := _get_panel("BossStatusPanel")
	var timer_panel := _get_panel("TimerPanel")
	var timer_label := _get_label_control("Timer", "timer")
	var warning_label := _get_label_control("CenterWarning", "center_warning")
	if _is_visible_control(boss_panel):
		_place_below(timer_panel, boss_panel, HUD_CENTER_GAP)
	elif is_instance_valid(timer_panel) and viewport_size != Vector2.ZERO:
		var timer_rect := _get_control_rect(timer_panel)
		timer_rect.position.x = (viewport_size.x - timer_rect.size.x) * 0.5
		timer_rect.position.y = 48.0
		_set_control_rect(timer_panel, timer_rect)
	_place_below(warning_label, timer_panel if is_instance_valid(timer_panel) else timer_label, HUD_CENTER_GAP)


func _get_panel(name: String) -> Control:
	return _panels.get(name, null) as Control


func _get_label_control(primary_key: String, fallback_key: String = "") -> Control:
	var control := _labels.get(primary_key, null) as Control
	if control == null and fallback_key != "":
		control = _labels.get(fallback_key, null) as Control
	return control


func _is_visible_control(control: Control) -> bool:
	return is_instance_valid(control) and control.visible


func _place_below(control: Control, previous: Control, gap: float) -> void:
	if not is_instance_valid(control) or not is_instance_valid(previous):
		return
	if not previous.visible:
		return
	var previous_rect := _get_control_rect(previous)
	var control_rect := _get_control_rect(control)
	control_rect.position.y = previous_rect.position.y + previous_rect.size.y + gap
	_set_control_rect(control, control_rect)


func _get_control_rect(control: Control) -> Rect2:
	return Rect2(
		Vector2(control.offset_left, control.offset_top),
		Vector2(control.offset_right - control.offset_left, control.offset_bottom - control.offset_top)
	)


func _set_control_rect(control: Control, rect: Rect2) -> void:
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y
	control.custom_minimum_size = rect.size


func _register_font(label: Label, base_size: int) -> void:
	_font_items.append({"label": label, "size": base_size})


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


func _make_rect_texture(color: Color) -> ImageTexture:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


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
	_labels.level.text = "Lv %d" % level
	_labels.exp_number.text = "EXP %d/%d" % [int(round(exp_value)), exp_required]


func _update_runtime_labels(run_state: Dictionary, current_wave: int, wave_time_remaining: float, run_seconds: float) -> void:
	var duration: float = float(run_state.get("run_duration", 0.0))
	var remaining: float = maxf(0.0, duration - run_seconds) if duration > 0.0 else maxf(0.0, wave_time_remaining)
	_labels.timer.text = _format_time(remaining)
	var status_summary := String(run_state.get("status_summary", "-"))
	_labels.status.text = status_summary


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
	var boss_panel: Control = _panels.get("BossStatusPanel", null) as Control
	if is_instance_valid(boss_panel):
		boss_panel.visible = has_boss


func _update_hud_visuals(run_state: Dictionary) -> void:
	_update_character_visual(run_state)
	_update_weapon_visual(run_state)
	_update_primary_attack_visual(run_state)
	_update_ultimate_slot_visual()


func _update_character_visual(run_state: Dictionary) -> void:
	var character_id: StringName = StringName(String(run_state.get("character_id", "")))
	var character_data: Dictionary = GameData.get_character(character_id)
	var texture: Texture2D = _get_definition_texture(character_data, ["portrait", "icon", "texture"])
	var avatar: TextureRect = _textures.get("avatar", null) as TextureRect
	if is_instance_valid(avatar):
		avatar.texture = texture
		avatar.self_modulate = Color.WHITE if texture != null else Color(0.35, 0.30, 0.45, 1.0)


func _update_weapon_visual(run_state: Dictionary) -> void:
	var weapon_data := _get_weapon_data(run_state)
	var texture: Texture2D = _get_definition_texture(weapon_data, ["icon", "texture"])
	var icon: TextureRect = _textures.get("skill_weapon_icon", null) as TextureRect
	if is_instance_valid(icon):
		icon.texture = texture
		icon.self_modulate = Color.WHITE if texture != null else Color(1, 1, 1, 0.18)


func _update_primary_attack_visual(run_state: Dictionary) -> void:
	var attack_data := _get_primary_attack_data(run_state)
	var texture: Texture2D = _get_primary_attack_texture(attack_data, run_state)
	var icon: TextureRect = _textures.get("skill_primary_icon", null) as TextureRect
	if is_instance_valid(icon):
		icon.texture = texture
		icon.self_modulate = Color.WHITE if texture != null else Color(1, 1, 1, 0.18)


func _update_ultimate_slot_visual() -> void:
	var icon: TextureRect = _textures.get("skill_ultimate_icon", null) as TextureRect
	if is_instance_valid(icon):
		icon.texture = null
		icon.self_modulate = Color(1, 1, 1, 0.18)


func _update_debug_stats(run_state: Dictionary) -> void:
	if _debug_labels.is_empty() or not OS.is_debug_build():
		return
	var debug_stats: Dictionary = _variant_to_dictionary(run_state.get("debug_stats", {}))
	_debug_labels.fps.text = "FPS: %d" % int(debug_stats.get("fps", 0))
	_debug_labels.enemy_count.text = "Enemies: %d" % int(debug_stats.get("enemy_count", 0))
	_debug_labels.projectile_count.text = "Projectiles: %d" % int(debug_stats.get("projectile_count", 0))
	_debug_labels.pickup_count.text = "Pickups: %d" % int(debug_stats.get("pickup_count", 0))


func _get_weapon_data(run_state: Dictionary) -> Dictionary:
	var weapon_id: String = str(run_state.get("current_weapon", run_state.get("main_attack", "basic_shot")))
	var data: Dictionary = GameData.get_weapon(StringName(weapon_id))
	if not data.is_empty():
		return data
	var main_attack: Variant = run_state.get("main_attack_data", {})
	if main_attack is Dictionary and not main_attack.is_empty():
		return main_attack
	return {"name": "鍩虹姝﹀櫒"}


func _get_primary_attack_data(run_state: Dictionary) -> Dictionary:
	var attack_id: StringName = StringName(String(run_state.get("main_attack", "")))
	if attack_id != &"":
		var attack: Dictionary = GameData.get_primary_attack(attack_id)
		if not attack.is_empty():
			return attack
	var weapon: Dictionary = _get_weapon_data(run_state)
	var starting_skill_id: StringName = StringName(String(weapon.get("starting_skill_id", "")))
	if starting_skill_id != &"":
		return GameData.get_primary_attack(starting_skill_id)
	return {}


func _get_primary_attack_texture(attack_data: Dictionary, run_state: Dictionary) -> Texture2D:
	var attack_id: String = String(attack_data.get("id", ""))
	if attack_id == "fireball":
		return _load_texture(FIREBALL_ATTACK_ICON_TEXTURE)
	var texture: Texture2D = _get_definition_texture(attack_data, ["icon", "texture", "background_texture"])
	if texture != null:
		return texture
	return _get_definition_texture(_get_weapon_data(run_state), ["icon", "texture"])


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


func _load_texture(texture_path: String) -> Texture2D:
	if texture_path == "":
		return null
	if not ResourceLoader.exists(texture_path):
		return null
	return load(texture_path) as Texture2D


func _variant_to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%02d:%02d" % [int(total / 60), total % 60]


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


func _on_pause_pressed() -> void:
	pause_requested.emit()


func get_node_or_null(path: NodePath) -> Node:
	if not is_instance_valid(_tree) or not is_instance_valid(_tree.root):
		return null
	return _tree.root.get_node_or_null(path)
