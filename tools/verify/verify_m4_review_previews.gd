extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Preview = preload("res://scripts/ui/skill_preview_service.gd")
const Effect = preload("res://scripts/skills/skill_effect_adapter.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Replace = preload("res://scripts/ui/skill_replacement_view.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	setup()
	player.get_node("ModifierStore").set_physics_process(false)
	enemy.get_node("StatusEffectManager").set_physics_process(false)
	for id: StringName in [&"fire_core_inferno_cycle",&"fire_passive_burning_focus",&"fire_power_ember_attachment",&"fusion_fire_frost_steam_mist"]:
		expect(not GameData.get_skill(id).is_empty(),"R1 tested event skill exists")
		var p: Dictionary = Preview.build(player,id,1,"normal")
		expect(is_zero_approx(float(p.cooldown)) and not "\n".join(p.lines).contains("冷却 1.00s"),"R1 event skill has no fictional cast CD "+str(id))
	var holder: HBoxContainer=HBoxContainer.new();root.add_child(holder)
	var curses: VBoxContainer=VBoxContainer.new();root.add_child(curses)
	var modal: RefCounted=preload("res://scripts/ui/modals/run_choice_modal_controller.gd").new();modal.setup(self,holder,curses)
	var core_option: Dictionary={"rarity":"normal","payload":{"skill_id":&"fire_core_inferno_cycle","level":1}}
	expect(not modal._get_option_description_text(core_option).contains("冷却"),"R1 event card excludes fallback cooldown")
	var dash_option: Dictionary={"rarity":"normal","payload":{"skill_id":&"fire_dash_blazing_run","level":1}}
	expect(modal._get_option_description_text(dash_option).contains("冲刺冷却 2.60s"),"R1 dash card reads actual cooldown")
	var dash: Dictionary = Preview.build(player,&"fire_dash_blazing_run",1,"normal")
	expect(absf(float(dash.cooldown)-2.6)<.01,"R1 dash reads actual player CD")
	var passive: RefCounted = install(&"fire_passive_burning_focus")
	manager._refresh_skill_modifier_payload(passive)
	var pp: Dictionary = Preview.build(player,passive.skill_id,1,"normal")
	expect("\n".join(pp.lines).contains("25.00%") and "\n".join(pp.lines).contains("20.00%"),"R2 learned passive effects retained")
	pp=Preview.build(player,passive.skill_id,2,"normal")
	expect("\n".join(pp.lines).contains("30.00%") and "\n".join(pp.lines).contains("24.00%"),"R2 prospective passive upgrade uses runtime source scaling")
	var fusion: RefCounted=install(&"fusion_fire_frost_steam_mist")
	var fp: Dictionary=Preview.build(player,fusion.skill_id,1,"normal")
	var runtime: RefCounted=preload("res://scripts/skills/fusion_runtime.gd").new()
	runtime.effects(bus,fusion.definition.fusion_rules[0].effects,ctx(enemy,fusion),fusion)
	await process_frame
	var area: Node=null
	for node: Node in root.get_children():
		if node is AreaEffect and node.source_id==&"steam_mist": area=node
	expect(area!=null and fp.damage>0 and fp.radius>0 and not fp.statuses.is_empty(),"R2 native fusion output exists in preview")
	if area!=null:
		area.set_physics_process(false)
		expect(absf(fp.radius-area.radius)<1 and absf(fp.duration-area.duration)<.01,"R2 native fusion geometry matches actual area")
		enemy.packets.clear();area._damage_body(enemy)
		expect(not enemy.packets.is_empty() and absf(fp.damage-enemy.packets[0].raw_amount)<=1,"R2 native fusion actual tick matches preview")
		area.queue_free()
	var utility: Dictionary=Preview.build(player,&"fusion_curse_fire_ash_soul_pact",1,"normal")
	expect("\n".join(utility.lines).contains("8.00%") and "\n".join(utility.lines).contains("40.00%"),"R2 utility fusion exposes actual bonus and cap")
	var utility_skill: RefCounted=install(&"fusion_curse_fire_ash_soul_pact")
	enemy.apply_status(&"cursed",{"stacks":1,"power":100})
	for hit: int in 10: runtime.perform(bus,utility_skill.definition.fusion_rules[0],ctx(enemy,utility_skill),utility_skill)
	expect(absf(float(enemy.get_node("StatusEffectManager").export_status(&"cursed").get("fusion_resolve_bonus",0))-.4)<.001,"R2 actual utility reaches displayed forty-percent cap")
	manager.clear_skills()
	var emp: RefCounted=install(&"thunder_cast_emp_ring")
	var ep: Dictionary=Preview.build(player,emp.skill_id,1,"normal")
	expect(ep.conditional and "\n".join(ep.lines).contains("导电目标") and "\n".join(ep.lines).contains("额外"),"R3 nested conditional damage labeled")
	var emp_option: Dictionary={"display_name":GameData.get_skill(emp.skill_id).display_name,"rarity":"normal","payload":{"skill_id":emp.skill_id,"level":1}}
	var emp_options: Array[Dictionary]=[emp_option]
	modal._refresh_choice_card_modal(holder,emp_options,"RUNNING",false)
	expect(modal.get("_choice_card_buttons")[0].tooltip_text.contains("导电目标额外"),"R3 full card tooltip preserves condition label")
	var actions: Array=preload("res://scripts/skills/skill_trigger_rule_adapter.gd").to_event(emp.definition.trigger_rules[0],emp).actions[0].params.actions_on_apply
	enemy.get_node("StatusEffectManager").clear_statuses();enemy.packets.clear()
	Executor.new().execute_actions(actions,ctx(enemy,emp))
	var base: float=packet_total()
	enemy.apply_status(&"conductive",{"stacks":1});enemy.packets.clear()
	Executor.new().execute_actions(actions,ctx(enemy,emp))
	expect(absf(base-120)<=1 and absf(packet_total()-180)<=1,"R3 actual conductive condition distinguishes 120/180")
	var lava: RefCounted=install(&"fire_cast_lava_rift")
	var status_action: Dictionary=preload("res://scripts/skills/skill_trigger_rule_adapter.gd").to_event(lava.definition.trigger_rules[0],lava).actions[0].params.actions_on_tick[1]
	for bonus: bool in [false,true,false]:
		if bonus:
			passive=install(&"fire_passive_burning_focus");manager._refresh_skill_modifier_payload(passive)
		else:
			manager.active_skills.erase(&"fire_passive_burning_focus");manager.passive_skills.erase(&"fire_passive_burning_focus")
			manager._remove_skill_effect_modifier_source(&"fire_passive_burning_focus");manager._remove_passive_modifiers_for_skill(&"fire_passive_burning_focus")
		enemy.get_node("StatusEffectManager").clear_statuses()
		Executor.new().execute_action(status_action,ctx(enemy,lava))
		var actual: float=enemy.get_node("StatusEffectManager").export_status(&"burning").duration_remaining
		var lp: Dictionary=Preview.build(player,lava.skill_id,1,"normal")
		var shown: float=0
		for s: Dictionary in lp.statuses:
			if s.name=="燃烧": shown=s.duration;break
		expect(absf(shown-actual)<.01,"R4 preview equals actual status duration bonus="+str(bonus)+" shown="+str(shown)+" actual="+str(actual))
	manager.clear_skills()
	for id: StringName in [&"fire_cast_meteor_rain",&"fire_cast_lava_rift",&"fire_cast_scorching_vortex",&"fire_summon_crimson_dragon",&"fire_summon_ember_fox_pack"]: manager.add_skill(id)
	var old: RefCounted=manager.get_skill(&"fire_cast_meteor_rain");old.current_level=5;old.current_rarity="legendary"
	var service: RefCounted=preload("res://scripts/skills/skill_replacement_service.gd").new()
	var tx: Dictionary=service.begin(player,&"frost_cast_glacial_lance","rare")
	var view: CanvasLayer=Replace.new();root.add_child(view);view.open(player,service,tx,func()->void:pass)
	var new_preview: Dictionary=Preview.build(player,&"frost_cast_glacial_lance",1,"rare")
	var labels: Array[Node]=view.find_children("*","Label",true,false)
	expect(not labels.is_empty() and labels[0].text.contains("单次命中伤害 "+str(int(new_preview.damage))),"R5 new Lv1 replacement has actual comparison")
	var buttons: Array[Node]=view.find_children("*","Button",true,false)
	var op: Dictionary=Preview.build(player,old.skill_id,5,"legendary")
	expect(buttons[0].text.contains("Lv5") and buttons[0].tooltip_text.contains("单次命中伤害 "+str(int(op.damage))) and buttons[0].tooltip_text.contains("冷却"),"R5 old legendary Lv5 replacement has actual comparison")
	buttons.back().emit_signal("pressed");await process_frame
	expect(not player.get_meta("ordinary_replacement_used",false) and manager.has_skill(old.skill_id),"R5 comparison cancel preserves old skill and chance")
	for s: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/skills.json")).skills:
		if not s.has("level_overrides"): continue
		for level: int in [1,2,3,4,5]:
			var next: Dictionary=Preview.build(player,StringName(s.id),level,"normal").next_milestone
			expect((next.is_empty() if level==5 else not str(next.description).contains("机制强化") and int(next.level)==(3 if level<3 else 5)),"R6 concrete next milestone "+str(s.id)+" Lv"+str(level))
	finish()
func packet_total() -> float:
	var value: float=0
	for packet: Dictionary in enemy.packets: value+=float(packet.raw_amount)
	return value
