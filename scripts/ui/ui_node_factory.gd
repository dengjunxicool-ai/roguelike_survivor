## 文件用途：复用标签、按钮、滚动区和布局容器的节点创建逻辑。
## 使用方式：页面构建时调用静态 add_*，传入 parent 及样式参数，返回已挂载控件。

extends RefCounted
class_name UINodeFactory


## Params: parent 父节点；text 标签文本；alignment 水平对齐；node_name 可选节点名。
## Returns: 创建并挂到 parent 下的 Label。
## 作用：添加标签并配置节点/样式所需的属性。
## 使用：本文件由 add_labeled_progress 调用；输入 parent（父节点）、text（文本）、alignment（alignment）、node_name（节点名称）；返回 Label 对象/值。
static func add_label(parent: Node, text: String, alignment: int = 0, node_name: String = "") -> Label:
	var label: Label = Label.new()
	if node_name != "":
		label.name = node_name
	label.text = text
	label.horizontal_alignment = alignment as HorizontalAlignment
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


## Params: parent 父节点；text 按钮文本。
## Returns: 创建并挂到 parent 下的 Button。
## 作用：添加按钮并配置节点/样式所需的属性。
## 使用：供本模块调用者使用；输入 parent（父节点）、text（文本）；返回 Button 对象/值。
static func add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button


## Params: parent 父节点。
## Returns: 创建并挂到 parent 下的 ScrollContainer。
## 作用：添加滚动区并配置节点/样式所需的属性。
## 使用：供本模块调用者使用；输入 parent（父节点）；返回 ScrollContainer 对象/值。
static func add_scroll(parent: Node) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	return scroll


## Params: parent 父节点。
## Returns: 创建并挂到 parent 下的 VBoxContainer。
## 作用：添加纵向容器并配置节点/样式所需的属性。
## 使用：供本模块调用者使用；输入 parent（父节点）；返回 VBoxContainer 对象/值。
static func add_vbox(parent: Node) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)
	parent.add_child(container)
	return container


## Params: parent 父节点。
## Returns: 创建并挂到 parent 下的 HBoxContainer。
## 作用：添加横向容器并配置节点/样式所需的属性。
## 使用：供本模块调用者使用；输入 parent（父节点）；返回 HBoxContainer 对象/值。
static func add_hbox(parent: Node) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 18)
	parent.add_child(container)
	return container


## Params: parent 父节点；label_text 进度条左侧文案；value 当前值；max_value 最大值。
## Returns: 创建并挂到 parent 下的 ProgressBar。
## 作用：添加带标签进度并配置节点/样式所需的属性。
## 使用：供本模块调用者使用；输入 parent（父节点）、label_text（标签文本）、value（值）、max_value（上限值）；返回 ProgressBar 对象/值。
static func add_labeled_progress(parent: Node, label_text: String, value: float, max_value: float) -> ProgressBar:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	add_label(row, label_text)
	var bar: ProgressBar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = max_value
	bar.value = value
	row.add_child(bar)
	return bar
