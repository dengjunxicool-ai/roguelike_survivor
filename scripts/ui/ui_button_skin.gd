## 文件用途：按 UI 主题为按钮应用文字颜色、边框和内容边距。
## 使用方式：创建按钮后调用 apply；纯文字按钮调用 apply_text_only。

extends RefCounted
class_name UIButtonSkin


const DEFAULT_VARIANT: String = "default"
const UIThemeServiceScript: Script = preload("res://scripts/ui/ui_theme_service.gd")


## 作用：应用。
## 使用：供本模块调用者使用；输入 button（按钮）、variant（变体）、force_style（强制样式）。
static func apply(button: Button, variant: String = DEFAULT_VARIANT, force_style: bool = true) -> void:
	if button == null:
		return

	var config: Dictionary = _get_button_config(variant)
	_apply_text_colors(button, config)
	if force_style or not _has_button_style(button):
		_apply_styleboxes(button, config)


## 作用：应用文本仅。
## 使用：供本模块调用者使用；输入 button（按钮）、variant（变体）。
static func apply_text_only(button: Button, variant: String = DEFAULT_VARIANT) -> void:
	if button == null:
		return
	_apply_text_colors(button, _get_button_config(variant))


## 作用：应用文本颜色组。
## 使用：本文件由 apply、apply_text_only 调用；输入 button（按钮）、config（配置）。
static func _apply_text_colors(button: Button, config: Dictionary) -> void:
	var font_color: Color = UIThemeServiceScript.get_color(config, "font_color", Color.WHITE)
	var disabled_color: Color = UIThemeServiceScript.get_color(config, "font_disabled_color", Color(1, 1, 1, 0.6))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_disabled_color", disabled_color)


## 作用：应用样式盒组。
## 使用：本文件由 apply 调用；输入 button（按钮）、config（配置）。
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


## 作用：创建样式盒并配置节点/样式所需的属性。
## 使用：本文件由 _apply_styleboxes 调用；输入 state_config（状态配置）、config（配置）；返回 StyleBox 对象/值。
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


## 作用：应用内容边距。
## 使用：本文件由 _create_stylebox 调用；输入 style（样式）、config（配置）。
static func _apply_content_margin(style: StyleBox, config: Dictionary) -> void:
	var margins: Dictionary = UIThemeServiceScript.get_dictionary(config.get("content_margin", {}))
	style.content_margin_left = float(margins.get("left", 14))
	style.content_margin_top = float(margins.get("top", 8))
	style.content_margin_right = float(margins.get("right", 14))
	style.content_margin_bottom = float(margins.get("bottom", 8))


## 作用：是否包含按钮样式，返回布尔判断结果。
## 使用：本文件由 apply 调用；输入 button（按钮）。
static func _has_button_style(button: Button) -> bool:
	return button.has_theme_stylebox_override("normal") or button.has_theme_stylebox_override("hover") or button.has_theme_stylebox_override("pressed")


## 作用：获取按钮配置，供当前模块后续逻辑使用。
## 使用：本文件由 apply、apply_text_only 调用；输入 variant（变体）；返回结果字典。
static func _get_button_config(variant: String) -> Dictionary:
	var buttons: Dictionary = UIThemeServiceScript.get_section(["buttons"])
	var config: Dictionary = UIThemeServiceScript.get_dictionary(buttons.get(variant, {}))
	if config.is_empty() and variant != DEFAULT_VARIANT:
		config = UIThemeServiceScript.get_dictionary(buttons.get(DEFAULT_VARIANT, {}))
	return config
