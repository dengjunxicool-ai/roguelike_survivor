extends CanvasLayer
class_name SkillReplacementView
func open(player: Node, service: RefCounted, transaction: Dictionary, completed: Callable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	var backdrop := ColorRect.new()
	backdrop.name = "ReplacementBackdrop"
	backdrop.color = Color(0, 0, 0, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var scroll := ScrollContainer.new()
	scroll.name = "ReplacementScroll"
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
