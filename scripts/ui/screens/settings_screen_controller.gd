extends RefCounted
class_name SettingsScreenController


signal state_requested(state: String)


const STATE_TITLE: String = "TITLE"
const UISettingsServiceScript: Script = preload("res://scripts/ui/ui_settings_service.gd")
const LocalizationServiceScript: Script = preload("res://scripts/ui/localization_service.gd")

var _languages: Array[Dictionary] = []
var _language_button: OptionButton
var _fullscreen_button: CheckBox
var _master_slider: HSlider


func build(body: VBoxContainer) -> void:
	_languages = LocalizationServiceScript.get_language_options()
	_add_label(body, _tr("settings.audio", "音频"), 1)
	_master_slider = HSlider.new()
	_master_slider.min_value = 0.0
	_master_slider.max_value = 100.0
	_master_slider.value = SaveManager.get_master_volume_percent()
	_master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISettingsServiceScript.apply_master_volume(_master_slider.value)
	_master_slider.value_changed.connect(Callable(self, "_on_master_volume_changed"))
	body.add_child(_master_slider)

	_add_label(body, _tr("settings.video", "画面"), 1)
	_fullscreen_button = CheckBox.new()
	_fullscreen_button.text = _tr("settings.fullscreen", "全屏")
	_fullscreen_button.button_pressed = SaveManager.get_fullscreen_enabled()
	UIButtonSkin.apply(_fullscreen_button)
	_fullscreen_button.toggled.connect(Callable(self, "_set_fullscreen"))
	body.add_child(_fullscreen_button)

	_add_label(body, _tr("settings.language", "语言"), 1)
	_language_button = OptionButton.new()
	for language: Dictionary in _languages:
		_language_button.add_item(String(language.get("label", "")))
	_language_button.selected = _get_language_index(SaveManager.get_language_id())
	UIButtonSkin.apply(_language_button)
	_language_button.item_selected.connect(Callable(self, "_on_language_selected"))
	body.add_child(_language_button)

	_add_label(body, _tr("settings.controls", "控制：WASD / 方向键移动，鼠标和键盘用于菜单。"))
	_add_state_button(body, _tr("settings.back", "返回主菜单"), STATE_TITLE)


func _set_fullscreen(enabled: bool) -> void:
	SaveManager.set_fullscreen_enabled(enabled)
	UISettingsServiceScript.apply_window_mode(enabled)


func _on_master_volume_changed(value: float) -> void:
	SaveManager.set_master_volume_percent(value)
	UISettingsServiceScript.apply_master_volume(value)


func _on_language_selected(index: int) -> void:
	if index < 0 or index >= _languages.size():
		return
	var language_id: String = String(_languages[index].get("id", "zh"))
	SaveManager.set_language_id(language_id)
	UISettingsServiceScript.apply_language(language_id)


func _get_language_index(language_id: String) -> int:
	for index: int in range(_languages.size()):
		if String(_languages[index].get("id", "")) == language_id:
			return index
	return 0


func _tr(key: String, fallback: String) -> String:
	return LocalizationServiceScript.translate(key, {}, fallback)


func _add_state_button(parent: Node, text: String, state: String) -> Button:
	var button: Button = _add_button(parent, text)
	button.pressed.connect(Callable(self, "_emit_state").bind(state))
	return button


func _emit_state(state: String) -> void:
	state_requested.emit(state)


func _add_label(parent: Node, text: String, alignment: int = 0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment as HorizontalAlignment
	parent.add_child(label)
	return label


func _add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button
