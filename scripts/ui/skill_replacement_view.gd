extends CanvasLayer
class_name SkillReplacementView
func open(player: Node, service: RefCounted, transaction: Dictionary, completed: Callable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := VBoxContainer.new()
	panel.position = Vector2(160, 70)
	panel.size = Vector2(960, 560)
	backdrop.add_child(panel)
	var heading := Label.new()
	var data: Dictionary = GameData.get_skill(transaction.skill_id)
	heading.text = "普通主动替换（每局一次）\n新技能：%s  %s\n%s\n请选择替换目标" % [data.get("display_name", ""), transaction.rarity, data.get("description", "")]
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(heading)
	var manager: Node = player.get_node("SkillManager")
	for skill: RefCounted in manager.get_active_skills():
		var old_data: Dictionary = GameData.get_skill(skill.skill_id)
		if not preload("res://scripts/skills/skill_slot_policy.gd").counts_active_capacity(old_data): continue
		var button := Button.new()
		button.text = "%s Lv%d %s — %s" % [old_data.get("display_name", ""), skill.current_level, skill.current_rarity, old_data.get("description", "")]
		button.custom_minimum_size.y = 60
		panel.add_child(button)
		button.pressed.connect(func() -> void:
			if service.confirm(player, str(transaction.id), skill.skill_id):
				completed.call()
				queue_free())
	var cancel_button := Button.new()
	cancel_button.text = "取消，返回本次升级选择"
	panel.add_child(cancel_button)
	cancel_button.pressed.connect(func() -> void:
		service.cancel(str(transaction.id))
		queue_free())
