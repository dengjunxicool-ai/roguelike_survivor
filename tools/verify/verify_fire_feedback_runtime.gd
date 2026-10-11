## 使用真实伤害和临时属性来源验证火焰表现的触发、暂停和回收。
extends "res://tools/verify/qa_app_fixture.gd"
const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
func run() -> void:
	await setup_run()
	var bus: Node = player.get_node("SkillEventBus")
	var view: Node = bus.get_node_or_null("FireCombatPresentation")
	check(view != null,"production fire presentation attached")
	if view == null:
		await finish()
		return
	var instant := preload("res://scripts/combat/instant_area_hit_visual.gd").new()
	player.get_parent().add_child(instant)
	instant.setup({"radius":72.0,"duration":0.2,"visual_style":"fire_burst","visual_effect_scene":"res://scenes/effects/fire_area_effect.tscn"})
	check(instant.get_node_or_null("InstantAreaVisualEffect")!=null,"instant real-area host attaches procedural fire burst")
	instant.queue_free()
	var enemy: Node2D = Enemy.instantiate()
	enemy.enemy_id = &"skeleton"
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position+Vector2(100,0)
	enemy.max_health = 1000
	enemy.current_health = 1000
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var context := {"caster":player,"owner":player,"target":enemy,"event_bus":bus,"skill_manager":manager,"skill_id":&"fire_power_ignite_core","origin_skill_id":&"fire_power_ignite_core"}
	var executor: RefCounted = Executor.new()
	executor.execute_action({"type":"deal_damage","params":{"amount":0,"damage_type":"fire"}},context)
	check(view._hits.is_empty(),"zero damage generates no fire impact")
	executor.execute_action({"type":"deal_damage","params":{"amount":12,"damage_type":"fire"}},context)
	check(enemy.current_health<1000,"real typed enemy loses health")
	check(not view._hits.is_empty(),"confirmed fire damage creates impact")
	var before: int = enemy.current_health
	executor.execute_action({"type":"deal_damage","params":{"amount":12,"radius":100.8,"damage_type":"fire"}},context)
	check(enemy.current_health<before,"ignite area action applies real damage")
	check(view._bursts.size()==1 and view._bursts[0].effect_radius==100.8 and view._bursts[0].global_position==enemy.global_position and view._bursts[0].get_meta("fire_burst_kind")=="ignite","actual ignite action shows one correctly centered burst")
	executor.execute_action({"type":"deal_damage","params":{"amount":0,"radius":100.8,"damage_type":"fire"}},context)
	check(view._bursts.size()==1,"zero area damage creates no ignite burst")
	var inferno_context: Dictionary = context.duplicate(true)
	inferno_context["origin_skill_id"]=&"fire_core_inferno_cycle"
	inferno_context["skill_id"]=&"fire_core_inferno_cycle"
	executor.execute_action({"type":"deal_damage","params":{"amount":12,"radius":117.6,"damage_type":"fire"}},inferno_context)
	check(view._bursts.size()==2 and view._bursts[1].effect_radius==117.6 and view._bursts[1].get_meta("fire_burst_kind")=="inferno","actual inferno damage action uses true burst radius")
	var combustion_context: Dictionary = context.duplicate(true)
	combustion_context["origin_skill_id"]=&"fire_power_combustion_chain"
	combustion_context["skill_id"]=&"fire_power_combustion_chain"
	combustion_context["position"]=enemy.global_position
	before=enemy.current_health
	executor.execute_action({"type":"combustion_explosion","params":{"power_scale":2.4,"radius":184.8}},combustion_context)
	check(enemy.current_health<before,"real combustion cycle explosion damages enemy")
	check(view._bursts.size()==3 and view._bursts[2].effect_radius==184.8 and view._bursts[2].global_position==enemy.global_position and view._bursts[2].get_meta("fire_burst_kind")=="combustion","actual cycle callback shows exactly one matching explosion")
	enemy.apply_status(&"burning",{"duration":4.0,"stacks":3})
	await settle()
	var statuses: Node = enemy.get_node("StatusEffectManager")
	var overlay: Node = statuses._status_visual_overlay.get_node_or_null("ProceduralStatus") if statuses._status_visual_overlay != null else null
	check(overlay != null and overlay.visible,"actual burning uses procedural flames")
	if overlay != null:
		check(overlay.status_stacks==enemy.get_status_stack(&"burning"),"burning presentation reads real stacks")
	check(Fixture.install_runtime_skill(manager,&"fire_passive_overheated_casting"),"learn overheated casting")
	var buff_context := {"caster":player,"owner":player,"target":player,"event_bus":bus,"skill_manager":manager,"skill_id":&"fire_passive_overheated_casting","skill_instance":manager.get_skill(&"fire_passive_overheated_casting")}
	bus.emit_skill_event(&"on_player_damaged",buff_context)
	view._process(0.11)
	check(view._heat != null and view._heat.visible,"confirmed timed overheat source shows aura")
	player.global_position+=Vector2(20,0)
	view._process(0.01)
	check(view._heat.global_position==player.global_position,"overheat follows each movement frame between source refreshes")
	player.get_node("ModifierStore").tick_timed_sources(5.1)
	view._process(0.11)
	check(view._heat != null and not view._heat.visible,"expired overheat source hides aura")
	for i: int in 40: bus.present_skill_effect("combustion",enemy.global_position,184.8)
	check(view._bursts.size()==8,"explosion bursts stay within fixed pool budget")
	bus.reset_run_state()
	check(not view._bursts[0].visible and not view._hits[0].visible,"run reset clears fire effects")
	await finish()
