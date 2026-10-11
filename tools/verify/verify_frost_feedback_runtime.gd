## 真正敌人伤害管线与授盾动作驱动反馈；不以假事件代替实际斩杀。
extends "res://tools/verify/qa_app_fixture.gd"
const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")

func run() -> void:
	await setup_run()
	for id: StringName in [&"frost_attack_frostbite",&"frost_passive_frozen_vulnerability",&"frost_power_shatter_execute"]:
		check(Fixture.install_runtime_skill(manager,id),"learn "+String(id))
	var enemy: Node2D = Enemy.instantiate()
	enemy.enemy_id = &"skeleton"
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position+Vector2(80,0)
	enemy.max_health = 1000
	enemy.current_health = 1000
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var bus: Node = player.get_node("SkillEventBus")
	var presentation: Node2D = bus.get_node("FrostCombatPresentation")
	var executor: RefCounted = Executor.new()
	var context := {"caster":player,"owner":player,"target":enemy,"event_bus":bus,"skill_manager":manager,"skill_id":&"frost_power_shatter_execute","origin_skill_id":&"frost_power_shatter_execute","skill_instance":manager.get_skill(&"frost_power_shatter_execute")}
	var action := {"type":"deal_damage","params":{"amount":0,"low_hp_execute_threshold":0.1,"damage_type":"frost"}}
	check(not executor.execute_action(action,context),"ineligible high HP execute rejected")
	check(presentation._hits.is_empty(),"rejected execute creates no shatter")
	enemy.current_health = 80
	check(executor.execute_action(action,context),"eligible execute applies real damage")
	check(enemy.current_health==0,"real enemy is executed")
	check(presentation._hits.size()==1 and presentation._hits[0].profile==2,"actual post-damage execute packet creates shatter")
	var target: Node2D = Enemy.instantiate()
	target.enemy_id = &"skeleton"
	player.get_parent().add_child(target)
	target.global_position = player.global_position+Vector2(130,0)
	target.max_health = 1000
	target.current_health = 1000
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.apply_status(&"frozen",{"duration":1.0})
	var packet: DamagePacket = DamagePacket.from_dictionary({"raw_amount":10,"amount":10,"damage_origin":"primary_attack","damage_type":"direct_physical","element":"physical","attacker":player,"source_skill_id":"test_primary_attack","source_id":"test_primary_attack","source_instance_id":"frost_visual_primary_hit"})
	target.take_damage(packet)
	check(target.current_health<1000,"actual controlled target takes damage")
	check(presentation._hits.size()==2 and presentation._hits[1].profile==1,"actual controlled-hit snapshot creates vulnerability cracks")
	var shield_context := {"caster":player,"owner":player,"event_bus":bus,"skill_manager":manager,"skill_id":&"frost_power_ice_mist_guard","origin_skill_id":&"frost_power_ice_mist_guard"}
	check(executor.execute_action({"type":"grant_shield","params":{"amount":20,"shield_type":"ice_mist","duration":6.0}},shield_context),"actual shield action succeeds")
	check(int(player.get_meta("fire_passive_shield",0))>0 and presentation._shield.visible,"actual granted protection shows shield")
	check(presentation._shield.global_position.is_equal_approx(player.global_position),"shield follows real player world position")
	await finish()
