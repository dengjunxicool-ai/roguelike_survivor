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


func build(body: VBoxContainer) -> void:
	_soul_label = _add_label(body, "灵魂石：0", 1)
	if OS.is_debug_build():
		var add_souls_button: Button = _add_button(body, "DEV：获得 100 灵魂石")
		add_souls_button.pressed.connect(Callable(self, "_on_add_test_souls_pressed"))
	var scroll: ScrollContainer = _add_scroll(body)
	_upgrade_list = _add_vbox(scroll)
	_add_state_button(body, "返回欢迎页", STATE_TITLE)


func refresh() -> void:
	var view_model: Dictionary = _view_model_builder.call("build")
	if _soul_label != null:
		_soul_label.text = "灵魂石：%d" % int(view_model.get("souls", 0))

	_clear_children(_upgrade_list)
	var upgrades: Array = view_model.get("upgrades", [])
	for upgrade: Dictionary in upgrades:
		_add_upgrade_row(upgrade)


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


func _buy_upgrade(upgrade_id: StringName) -> void:
	_command_dispatcher.call("dispatch", UICommandScript.purchase_meta_upgrade(upgrade_id))
	refresh()


func _on_add_test_souls_pressed() -> void:
	_command_dispatcher.call("dispatch", UICommandScript.add_soul_stones(100))
	refresh()


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


func _add_scroll(parent: Node) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return scroll


func _add_vbox(parent: Node) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)
	parent.add_child(container)
	return container


func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
