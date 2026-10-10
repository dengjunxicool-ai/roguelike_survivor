## 文件用途：构建并处理全屏、主音量和语言设置控件。
## 使用方式：build 接收容器；控件回调通过设置服务/SaveManager 应用与保存。

extends RefCounted
class_name SettingsScreenController


signal state_requested(state: String)
signal language_changed


const STATE_TITLE: String = "TITLE"
const UISettingsServiceScript: Script = preload("res://scripts/ui/ui_settings_service.gd")
const LocalizationServiceScript: Script = preload("res://scripts/ui/localization_service.gd")

var _languages: Array[Dictionary] = []
var _language_button: OptionButton
var _fullscreen_button: CheckBox
var _master_slider: HSlider
var _body: VBoxContainer
var _applied_master_volume: float = 70.0
var _applied_fullscreen: bool = false


## 作用：构建并处理全屏、主音量和语言设置控件。
## 使用：由页面或局内编排的构建流程调用；构建前应提供有效父容器；输入 body（主体）。
func build(body: VBoxContainer) -> void:
	_body = body
	_languages = LocalizationServiceScript.get_language_options()
	_add_localized_label(body, "settings.audio", "音频", 1)
	_master_slider = HSlider.new()
	_master_slider.min_value = 0.0
	_master_slider.max_value = 100.0
	_master_slider.value = SaveManager.get_master_volume_percent()
	_applied_master_volume = _master_slider.value
	_master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISettingsServiceScript.apply_master_volume(_master_slider.value)
	_master_slider.value_changed.connect(Callable(self, "_on_master_volume_changed"))
	body.add_child(_master_slider)

	_add_localized_label(body, "settings.video", "画面", 1)
	_fullscreen_button = CheckBox.new()
	LocalizationServiceScript.bind_text(_fullscreen_button, "settings.fullscreen", "全屏")
	_fullscreen_button.button_pressed = SaveManager.get_fullscreen_enabled()
	_applied_fullscreen = _fullscreen_button.button_pressed
	UIButtonSkin.apply(_fullscreen_button)
	_fullscreen_button.toggled.connect(Callable(self, "_set_fullscreen"))
	body.add_child(_fullscreen_button)

	_add_localized_label(body, "settings.language", "语言", 1)
	_language_button = OptionButton.new()
	for language: Dictionary in _languages:
		_language_button.add_item(String(language.get("label", "")))
	_language_button.selected = _get_language_index(SaveManager.get_language_id())
	UIButtonSkin.apply(_language_button)
	_language_button.item_selected.connect(Callable(self, "_on_language_selected"))
	body.add_child(_language_button)

	_add_localized_label(body, "settings.controls", "控制：WASD / 方向键移动，鼠标和键盘用于菜单。")
	var back: Button = _add_state_button(body, "", STATE_TITLE)
	LocalizationServiceScript.bind_text(back, "settings.back", "返回主菜单")

func _add_localized_label(body: Node, key: String, fallback: String, alignment: int = 0) -> void:
	var label: Label = _add_label(body, "", alignment)
	LocalizationServiceScript.bind_text(label, key, fallback)


## 作用：设置全屏。
## 使用：本文件由 build 调用；输入 enabled（启用）；可能写入 user:// 存档。
func _set_fullscreen(enabled: bool) -> void:
	if not SaveManager.set_fullscreen_enabled(enabled):
		_fullscreen_button.set_pressed_no_signal(_applied_fullscreen)
		return
	UISettingsServiceScript.apply_window_mode(enabled)
	_applied_fullscreen = enabled


## 作用：响应主音量变化并衔接对应的事件处理流程。
## 使用：本文件由 build 调用；输入 value（值）；可能写入 user:// 存档。
func _on_master_volume_changed(value: float) -> void:
	if not SaveManager.set_master_volume_percent(value):
		_master_slider.set_value_no_signal(_applied_master_volume)
		return
	UISettingsServiceScript.apply_master_volume(value)
	_applied_master_volume = value


## 作用：响应语言当前选择并衔接对应的事件处理流程。
## 使用：本文件由 build 调用；输入 index（索引）；可能写入 user:// 存档。
func _on_language_selected(index: int) -> void:
	if index < 0 or index >= _languages.size():
		return
	var language_id: String = String(_languages[index].get("id", "zh"))
	if not SaveManager.set_language_id(language_id):
		_language_button.select(_get_language_index(LocalizationServiceScript.get_language_id()))
		return
	UISettingsServiceScript.apply_language(language_id)
	_language_button.select(index)
	LocalizationServiceScript.refresh_tree(_body)
	language_changed.emit()


## 作用：获取语言索引，供当前模块后续逻辑使用。
## 使用：本文件由 build 调用；输入 language_id（语言ID）；返回计算或读取的数值。
func _get_language_index(language_id: String) -> int:
	for index: int in range(_languages.size()):
		if String(_languages[index].get("id", "")) == language_id:
			return index
	return 0


## 作用：本地化。
## 使用：本文件由 build 调用；输入 key（键）、fallback（回退）；返回 String 文本/标识。
func _tr(key: String, fallback: String) -> String:
	return LocalizationServiceScript.translate(key, {}, fallback)


## 作用：添加状态切换按钮。
## 使用：本文件由 build 调用；输入 parent（父节点）、text（文本）、state（状态）；返回 Button 对象/值。
func _add_state_button(parent: Node, text: String, state: String) -> Button:
	var button: Button = _add_button(parent, text)
	button.pressed.connect(Callable(self, "_emit_state").bind(state))
	return button


## 作用：发出状态并衔接对应的事件处理流程。
## 使用：本文件由 _add_state_button 调用；输入 state（状态）。
func _emit_state(state: String) -> void:
	state_requested.emit(state)


## 作用：添加标签并配置节点/样式所需的属性。
## 使用：本文件由 build 调用；输入 parent（父节点）、text（文本）、alignment（alignment）；返回 Label 对象/值。
func _add_label(parent: Node, text: String, alignment: int = 0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment as HorizontalAlignment
	parent.add_child(label)
	return label


## 作用：添加按钮并配置节点/样式所需的属性。
## 使用：本文件由 _add_state_button 调用；输入 parent（父节点）、text（文本）；返回 Button 对象/值。
func _add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button
