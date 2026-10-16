extends CanvasLayer
class_name SkillReplacementView
var _closed: bool = false
var _previous_focus: WeakRef

func cancel() -> void:
	_closed = true
	var previous: Control = _previous_focus.get_ref() as Control if _previous_focus != null else null
	if is_instance_valid(previous) and previous.is_visible_in_tree() and not previous.is_queued_for_deletion():
		previous.grab_focus()
	queue_free()

func open(player: Node, service: RefCounted, transaction: Dictionary, completed: Callable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var previous: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(previous) if previous != null else null
	var host: CanvasLayer = get_parent() as CanvasLayer
	layer = host.layer + 1 if host != null else 201
	var backdrop := ColorRect.new()
	backdrop.name = "ReplacementBackdrop"
	backdrop.color = Color(0, 0, 0, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var scroll := ScrollContainer.new()
	scroll.name = "ReplacementScroll"
	scroll.follow_focus = true
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_right = -24
	scroll.offset_top = 24
	scroll.offset_bottom = -24
	backdrop.add_child(scroll)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	var heading := Label.new()
	var data: Dictionary = GameData.get_skill(transaction.skill_id)
	heading.text = "普通主动替换（每局一次）\n新技能：%s  %s\n%s\n请选择替换目标" % [data.get("display_name", ""), preload("res://scripts/ui/skill_preview_service.gd").rarity_name(transaction.rarity), "\n".join(preload("res://scripts/ui/skill_preview_service.gd").build(player,transaction.skill_id,1,transaction.rarity).lines)]
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(heading)
	var manager: Node = player.get_node("SkillManager")
	var focus_buttons: Array[Button] = []
	for skill: RefCounted in manager.get_active_skills():
		var old_data: Dictionary = GameData.get_skill(skill.skill_id)
		if not preload("res://scripts/skills/skill_slot_policy.gd").counts_active_capacity(old_data): continue
		var button := Button.new()
		button.text = "%s Lv%d %s — %s" % [old_data.get("display_name", ""), skill.current_level, preload("res://scripts/ui/skill_preview_service.gd").rarity_name(skill.current_rarity), old_data.get("description", "")]
		var old_preview: Dictionary = preload("res://scripts/ui/skill_preview_service.gd").build(player,skill.skill_id,skill.current_level,skill.current_rarity)
		var comparison: String = "\n".join(old_preview.lines)
		button.text += "\n"+comparison
		button.tooltip_text = button.text
		button.custom_minimum_size.y = 90
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(button)
		focus_buttons.append(button)
		button.pressed.connect(func() -> void:
			if _closed or not is_instance_valid(player): return
			if service.confirm(player, str(transaction.id), skill.skill_id):
				_closed = true
				completed.call()
				queue_free())
	var cancel_button := Button.new()
	cancel_button.text = "取消，返回本次升级选择"
	panel.add_child(cancel_button)
	focus_buttons.append(cancel_button)
	# Explicit neighbors keep keyboard navigation on the active replacement layer.
	for index: int in focus_buttons.size():
		var button: Button = focus_buttons[index]
		var next: NodePath = button.get_path_to(focus_buttons[(index + 1) % focus_buttons.size()])
		var previous_path: NodePath = button.get_path_to(focus_buttons[(index - 1 + focus_buttons.size()) % focus_buttons.size()])
		button.focus_next = next
		button.focus_previous = previous_path
		button.focus_neighbor_bottom = next
		button.focus_neighbor_right = next
		button.focus_neighbor_top = previous_path
		button.focus_neighbor_left = previous_path
	focus_buttons[0].call_deferred("grab_focus")
	cancel_button.pressed.connect(func() -> void:
		service.cancel(str(transaction.id))
		cancel())
	tree_exiting.connect(func() -> void: service.cancel(str(transaction.id)), CONNECT_ONE_SHOT)
