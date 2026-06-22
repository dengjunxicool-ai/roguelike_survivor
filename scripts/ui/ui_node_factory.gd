extends RefCounted
class_name UINodeFactory


## Params: parent 父节点；text 标签文本；alignment 水平对齐；node_name 可选节点名。
## Returns: 创建并挂到 parent 下的 Label。
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
static func add_scroll(parent: Node) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	return scroll


## Params: parent 父节点。
## Returns: 创建并挂到 parent 下的 VBoxContainer。
static func add_vbox(parent: Node) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)
	parent.add_child(container)
	return container


## Params: parent 父节点。
## Returns: 创建并挂到 parent 下的 HBoxContainer。
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
