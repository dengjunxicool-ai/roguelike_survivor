## 文件用途：构建永久升级列表并派发购买命令。
## 使用方式：build 接收容器，refresh 读取货币与等级；成功购买后重绘列表。

extends RefCounted
class_name MetaUpgradeController


signal state_requested(state: String)


const STATE_TITLE: String = "TITLE"
const UICommandDispatcherScript: Script = preload("res://scripts/ui/ui_command_dispatcher.gd")
const UICommandScript: Script = preload("res://scripts/ui/ui_command.gd")
const MetaUpgradeViewModelBuilderScript: Script = preload("res://scripts/ui/screens/meta_upgrade_view_model_builder.gd")

var _soul_label: Label
var _upgrade_list: VBoxContainer
var _command_dispatcher: RefCounted = UICommandDispatcherScript.new()
var _view_model_builder: RefCounted = MetaUpgradeViewModelBuilderScript.new()


## 作用：构建永久升级列表并派发购买命令。
## 使用：由页面或局内编排的构建流程调用；结果按声明类型供后续展示/执行使用；输入 body（主体）。
func build(body: VBoxContainer) -> void:
	_soul_label = _add_label(body, "灵魂石：0", 1)
	if OS.is_debug_build():
		var add_souls_button: Button = _add_button(body, "DEV：获得 100 灵魂石")
		add_souls_button.pressed.connect(Callable(self, "_on_add_test_souls_pressed"))
	var scroll: ScrollContainer = _add_scroll(body)
	_upgrade_list = _add_vbox(scroll)
	_add_state_button(body, "返回欢迎页", STATE_TITLE)


## 作用：读取永久升级展示模型并重建货币、等级、费用和购买按钮列表。
## 使用：build 后及购买成功后调用；只刷新展示，实际购买由命令分派器完成。
func refresh() -> void:
	var view_model: Dictionary = _view_model_builder.call("build")
	if _soul_label != null:
		_soul_label.text = "灵魂石：%d" % int(view_model.get("souls", 0))

	_clear_children(_upgrade_list)
	var upgrades: Array = view_model.get("upgrades", [])
	for upgrade: Dictionary in upgrades:
		_add_upgrade_row(upgrade)


## 作用：添加升级行并配置节点/样式所需的属性。
## 使用：本文件由 refresh 调用；输入 upgrade（升级）。
func _add_upgrade_row(upgrade: Dictionary) -> void:
	var upgrade_id: StringName = StringName(String(upgrade.get("id", "")))
	if upgrade_id == &"":
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 48)
	row.add_theme_constant_override("separation", 10)
	_upgrade_list.add_child(row)

	_add_label(row, "%s  Lv.%d/%d" % [
		String(upgrade.get("display_name", upgrade_id)),
		int(upgrade.get("current_level", 0)),
		int(upgrade.get("max_level", 1))
	])
	var button: Button = _add_button(row, String(upgrade.get("button_text", "")))
	button.disabled = not bool(upgrade.get("can_purchase", false))
	button.pressed.connect(Callable(self, "_buy_upgrade").bind(upgrade_id))


## 作用：购买升级；具体处理委托给 _command_dispatcher.dispatch。
## 使用：本文件由 _add_upgrade_row 调用；输入 upgrade_id（升级ID）。
func _buy_upgrade(upgrade_id: StringName) -> void:
	_command_dispatcher.call("dispatch", UICommandScript.purchase_meta_upgrade(upgrade_id))
	refresh()


## 作用：响应添加测试灵魂石点击并衔接对应的事件处理流程；具体处理委托给 _command_dispatcher.dispatch。
## 使用：本文件由 build 调用。
func _on_add_test_souls_pressed() -> void:
	_command_dispatcher.call("dispatch", UICommandScript.add_soul_stones(100))
	refresh()


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
## 使用：本文件由 build、_add_upgrade_row 调用；输入 parent（父节点）、text（文本）、alignment（alignment）；返回 Label 对象/值。
func _add_label(parent: Node, text: String, alignment: int = 0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment as HorizontalAlignment
	parent.add_child(label)
	return label


## 作用：添加按钮并配置节点/样式所需的属性。
## 使用：本文件由 build、_add_upgrade_row、_add_state_button 调用；输入 parent（父节点）、text（文本）；返回 Button 对象/值。
func _add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button


## 作用：添加滚动区并配置节点/样式所需的属性。
## 使用：本文件由 build 调用；输入 parent（父节点）；返回 ScrollContainer 对象/值。
func _add_scroll(parent: Node) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return scroll


## 作用：添加纵向容器并配置节点/样式所需的属性。
## 使用：本文件由 build 调用；输入 parent（父节点）；返回 VBoxContainer 对象/值。
func _add_vbox(parent: Node) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)
	parent.add_child(container)
	return container


## 作用：从容器移除子节点并请求释放，供重建列表使用。
## 使用：本文件由 refresh 调用；输入 parent（父节点）。
func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
