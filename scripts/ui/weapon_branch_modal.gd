extends Control
class_name WeaponBranchModal


signal branch_selected(branch_id: StringName)
signal close_requested

var player: Node
var branch_system: Node
var _options_box: VBoxContainer
var _manages_pause: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_layout()


func open_for_player(target_player: Node, manages_pause: bool = true) -> void:
	player = target_player
	_manages_pause = manages_pause
	branch_system = player.get_node_or_null("WeaponBranchSystem") if player != null else null
	if branch_system == null or not branch_system.has_method("get_available_branches"):
		return

	_refresh_options()
	visible = true
	if _manages_pause:
		get_tree().paused = true


func close_modal() -> void:
	visible = false
	if _manages_pause:
		get_tree().paused = false
	close_requested.emit()


func _build_layout() -> void:
	var panel: Panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 520)
	add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "选择武器分支"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_options_box = VBoxContainer.new()
	_options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("separation", 8)
	box.add_child(_options_box)

	var cancel_button: Button = Button.new()
	cancel_button.text = "稍后再说"
	cancel_button.custom_minimum_size = Vector2(0, 44)
	UIButtonSkin.apply(cancel_button)
	cancel_button.pressed.connect(Callable(self, "close_modal"))
	box.add_child(cancel_button)


func _refresh_options() -> void:
	_clear_children(_options_box)
	for branch: Dictionary in branch_system.call("get_available_branches", player):
		_add_branch_button(branch)


func _add_branch_button(branch: Dictionary) -> void:
	var branch_id: StringName = StringName(String(branch.get("id", "")))
	if branch_id == &"":
		return

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0, 96)
	button.text = "%s\n%s\n优势：%s\n代价：%s\nLv5：%s" % [
		String(branch.get("display_name", branch_id)),
		String(branch.get("description", "")),
		" / ".join(_to_string_array(branch.get("pros", []))),
		" / ".join(_to_string_array(branch.get("cons", []))),
		_get_branch_level_description(branch, 5)
	]
	UIButtonSkin.apply(button)
	button.pressed.connect(Callable(self, "_select_branch").bind(branch_id))
	_options_box.add_child(button)


func _select_branch(branch_id: StringName) -> void:
	if branch_system != null and branch_system.has_method("apply_branch") and bool(branch_system.call("apply_branch", player, branch_id)):
		branch_selected.emit(branch_id)
		close_modal()


func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _to_string_array(value: Variant) -> Array[String]:
	var items: Array[String] = []
	if value is Array:
		for item: Variant in value:
			items.append(String(item))
	return items


func _get_branch_level_description(branch: Dictionary, target_level: int) -> String:
	var level_path: Dictionary = branch.get("level_path", {}) if branch.get("level_path", {}) is Dictionary else {}
	var level_config: Dictionary = level_path.get(str(target_level), {}) if level_path.get(str(target_level), {}) is Dictionary else {}
	return String(level_config.get("description", ""))
