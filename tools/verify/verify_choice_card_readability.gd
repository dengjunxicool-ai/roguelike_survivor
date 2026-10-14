extends "res://tools/verify/qa_app_fixture.gd"
const Builder = preload("res://scripts/upgrades/upgrade_option_builder.gd")
const Preview = preload("res://scripts/ui/skill_preview_service.gd")

func skill_option(id: StringName, level: int = 1) -> Dictionary:
	var data: Dictionary = GameData.get_skill(id)
	return Builder.build_skill_level_up_data(id,level,str(data.display_name),"normal","normal",int(data.max_level))

func run() -> void:
	await setup_run()
	var choice: RefCounted = ui._run_choice_modal_controller
	check(manager.add_skill(&"frost_cast_glacial_lance","normal"),"install actual skill for upgrade comparison")
	var owned: RefCounted = manager.get_skill(&"frost_cast_glacial_lance")
	var before: Dictionary = Preview.build(player,owned.skill_id,owned.current_level,owned.current_rarity)
	var after: Dictionary = Preview.build(player,owned.skill_id,2,owned.current_rarity)
	var option: Dictionary = skill_option(owned.skill_id,2)
	var summary: String = choice._get_option_effect_text(option)
	check(summary.contains("%d→%d" % [int(before.damage),int(after.damage)]),"upgrade card compares actual current and next damage")
	check(summary.contains("%d→%d" % [int(before.hits[1].damage),int(after.hits[1].damage)]),"conditional hit keeps its own current and next damage")
	check(summary.contains("命中时：对冻结目标额外：生成时："),"upgrade comparison keeps the complete conditional hit context")
	check(owned.current_level == 1,"reading upgrade never changes owned level")
	var summon_option: Dictionary = skill_option(&"fire_summon_crimson_dragon")
	var summon_lines: Array[String] = choice._get_option_value_lines(summon_option)
	var summon_card_text: String = ""
	for line: String in summon_lines: summon_card_text += choice._format_card_value_line(line) + "\n"
	var summon_preview: Dictionary = Preview.build(player,&"fire_summon_crimson_dragon",1,"normal")
	check(summon_card_text.contains("单次伤害 %d" % int(summon_preview.damage)),"summon card preserves real per-hit damage")
	check(summon_card_text.contains("%.2fs" % float(summon_preview.duration)) or summon_card_text.contains("%ss" % str(int(summon_preview.duration))),"summon card preserves duration and seconds unit")
	check(summon_card_text.contains(" · 每 "),"summon card preserves its attack interval")
	check(summon_card_text.contains("伤害/秒"),"summon DPS keeps its damage-per-second unit")
	var options: Array[Dictionary] = [option,skill_option(&"fire_attack_searing"),skill_option(&"frost_cast_blizzard_cloud")]
	if "--complex" in OS.get_cmdline_user_args():
		options = [skill_option(&"fusion_chaos_frost_zero_rift",5),skill_option(&"frost_cast_glacial_lance",5),skill_option(&"chaos_cast_mutation_pulse",5)]
	if "--summons" in OS.get_cmdline_user_args():
		options = [summon_option,skill_option(&"fire_summon_ember_fox_pack"),skill_option(&"frost_summon_ice_crystal_guard")]
	choice.add_pending_level(2)
	ui.transition_to("LEVEL_UP_MODAL")
	for resolution: Vector2i in [Vector2i(1152,648),Vector2i(800,600),Vector2i(1280,720)]:
		root.size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		for count: int in [3,4]:
			var candidates: Array[Dictionary] = options.duplicate(true)
			if count == 4: candidates.append(skill_option(&"holy_cast_divine_barrier"))
			choice._refresh_choice_card_modal(ui._level_up_options,candidates,"RUNNING",true)
			await settle(12)
			for button: Button in choice._choice_card_buttons:
				check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()),"%dx%d/%d card stays inside viewport" % [resolution.x,resolution.y,count])
				var description: Label = button.find_child("SkillCardDescription",true,false)
				check(description.get_theme_font_size("font_size") >= (14 if resolution.x >= 1152 else 12),"card purpose font stays readable")
				check(description.get_line_count() <= description.max_lines_visible,"card purpose fits without ellipsis")
				print("purpose-layout ",resolution,"/",count," ",description.size," lines=",description.get_line_count()," line-height=",description.get_line_height(0))
				var values: VBoxContainer = button.find_child("SkillCardValues",true,false)
				check(button.get_global_rect().encloses(values.get_global_rect()),"value rows fit card bounds")
			await capture("skill-cards-%dx%d-%d" % [resolution.x,resolution.y,count])
	await finish()
