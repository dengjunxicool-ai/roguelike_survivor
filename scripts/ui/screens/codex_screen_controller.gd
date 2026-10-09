## 文件用途：构建角色、技能、敌人、状态和遗物的图鉴页。
## 使用方式：build 接收页面容器；内容来自 CodexViewModelBuilder，返回菜单用状态请求信号。

extends RefCounted
class_name CodexScreenController


signal state_requested(state: String)


const STATE_TITLE: String = "TITLE"
const CodexViewModelBuilderScript: Script = preload("res://scripts/ui/screens/codex_view_model_builder.gd")

var _view_model_builder: RefCounted = CodexViewModelBuilderScript.new()


## 作用：构建角色、技能、敌人、状态和遗物的图鉴页。
## 使用：由页面或局内编排的构建流程调用；构建前应提供有效父容器；输入 body（主体）。
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


## 作用：添加页签并配置节点/样式所需的属性。
## 使用：本文件由 build 调用；输入 tabs（tabs）、title（标题）、rows（行列表）。
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
## 使用：本文件由 build、_add_tab 调用；输入 parent（父节点）、text（文本）、alignment（alignment）；返回 Label 对象/值。
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


## 作用：获取字符串数组，为界面/配置读取提供类型和回退处理。
## 使用：本文件由 build 调用；输入 value（值）；返回 Array[String] 列表。
func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
