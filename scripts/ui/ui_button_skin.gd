extends RefCounted
class_name UIButtonSkin


const DEFAULT_VARIANT: String = "default"
const UIThemeServiceScript: Script = preload("res://scripts/ui/ui_theme_service.gd")


static func apply(button: Button, variant: String = DEFAULT_VARIANT, force_style: bool = true) -> void:
	if button == null:
		return

	var config: Dictionary = _get_button_config(variant)
	_apply_text_colors(button, config)
	if force_style or not _has_button_style(button):
		_apply_styleboxes(button, config)


static func apply_text_only(button: Button, variant: String = DEFAULT_VARIANT) -> void:
	if button == null:
		return
	_apply_text_colors(button, _get_button_config(variant))


static func _apply_text_colors(button: Button, config: Dictionary) -> void:
	var font_color: Color = UIThemeServiceScript.get_color(config, "font_color", Color.WHITE)
	var disabled_color: Color = UIThemeServiceScript.get_color(config, "font_disabled_color", Color(1, 1, 1, 0.6))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_disabled_color", disabled_color)


static func _apply_styleboxes(button: Button, config: Dictionary) -> void:
	var normal_style: StyleBox = _create_stylebox(UIThemeServiceScript.get_dictionary(config.get("normal", {})), config)
	var hover_style: StyleBox = _create_stylebox(UIThemeServiceScript.get_dictionary(config.get("hover", {})), config)
	var pressed_style: StyleBox = _create_stylebox(UIThemeServiceScript.get_dictionary(config.get("pressed", {})), config)
	var disabled_style: StyleBox = _create_stylebox(UIThemeServiceScript.get_dictionary(config.get("disabled", {})), config)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("disabled", disabled_style)


static func _create_stylebox(state_config: Dictionary, config: Dictionary) -> StyleBox:
	var texture: Texture2D = UIThemeServiceScript.load_texture(String(state_config.get("background_texture", "")))
	if texture != null:
		var texture_style: StyleBoxTexture = StyleBoxTexture.new()
		texture_style.texture = texture
		_apply_content_margin(texture_style, config)
		return texture_style

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UIThemeServiceScript.get_color(state_config, "background_color", Color(0.15, 0.19, 0.27, 0.95))
	style.border_color = UIThemeServiceScript.get_color(state_config, "border_color", Color(0.36, 0.42, 0.52, 0.9))
	style.set_border_width_all(maxi(int(config.get("border_width", 1)), 0))
	var corner_radius: int = maxi(int(config.get("corner_radius", 6)), 0)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	_apply_content_margin(style, config)
	return style


static func _apply_content_margin(style: StyleBox, config: Dictionary) -> void:
	var margins: Dictionary = UIThemeServiceScript.get_dictionary(config.get("content_margin", {}))
	style.content_margin_left = float(margins.get("left", 14))
	style.content_margin_top = float(margins.get("top", 8))
	style.content_margin_right = float(margins.get("right", 14))
	style.content_margin_bottom = float(margins.get("bottom", 8))


static func _has_button_style(button: Button) -> bool:
	return button.has_theme_stylebox_override("normal") or button.has_theme_stylebox_override("hover") or button.has_theme_stylebox_override("pressed")


static func _get_button_config(variant: String) -> Dictionary:
	var buttons: Dictionary = UIThemeServiceScript.get_section(["buttons"])
	var config: Dictionary = UIThemeServiceScript.get_dictionary(buttons.get(variant, {}))
	if config.is_empty() and variant != DEFAULT_VARIANT:
		config = UIThemeServiceScript.get_dictionary(buttons.get(DEFAULT_VARIANT, {}))
	return config
