extends RefCounted
class_name CodexScreenController


signal state_requested(state: String)


const STATE_TITLE: String = "TITLE"
const CodexViewModelBuilderScript: Script = preload("res://scripts/ui/screens/codex_view_model_builder.gd")

var _view_model_builder: RefCounted = CodexViewModelBuilderScript.new()


func build(body: VBoxContainer) -> void:
	_add_label(body, "图鉴", 1)
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)

	var view_model: Dictionary = _view_model_builder.call("build")
	for tab: Dictionary in view_model.get("tabs", []):
		_add_tab(tabs, String(tab.get("title", "")), _get_string_array(tab.get("rows", [])))
	_add_state_button(body, "返回主菜单", STATE_TITLE)


func _add_tab(tabs: TabContainer, title: String, rows: Array[String]) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for row: String in rows:
		_add_label(list, row)


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


func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
