extends SceneTree
const Metrics=preload("res://scripts/runtime/skill_balance_metrics.gd")
const Packet=preload("res://scripts/combat/damage_packet.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var player: Node = load("res://scenes/characters/player.tscn").instantiate()
	root.add_child(player)
	player.attack_power=100
	player.max_health=1000
	player.current_health=1000
	player.get_node("SkillExecutor").set_physics_process(false)
	player.set_physics_process(false)
	var enemy: Node = load("res://scenes/enemies/enemy.tscn").instantiate()
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.max_health=1000
	enemy.current_health=1000
	var metrics: RefCounted=Metrics.new()
	root.set_meta(Metrics.META,metrics)
	enemy.take_damage(Packet.from_dictionary({"raw_amount":1600,"damage_origin":"status_dot","damage_type":"status_dot","element":"fire","source_type":"skill","source_skill_id":"fixture","can_crit":false,"uses_character_damage_multiplier":false,"source_instance_id":"m4_fixture"},player,enemy))
	assert(metrics.snapshot().actual_damage==1000 and metrics.snapshot().overkill==600 and metrics.snapshot().status_damage==1000)
	var c: Dictionary={"caster":player,"owner":player,"event_bus":player.get_node("SkillEventBus"),"skill_manager":player.get_node("SkillManager")}
	preload("res://scripts/skills/skill_action_executor.gd").new().execute_action({"type":"grant_shield","params":{"amount":25,"duration":10}},c)
	player.take_damage(Packet.from_dictionary({"raw_amount":10,"damage_origin":"special","damage_type":"direct_physical","element":"physical","source_type":"enemy","can_crit":false,"uses_character_damage_multiplier":false,"source_instance_id":"m4_fixture"},null,player))
	assert(metrics.snapshot().shield_generated==25 and metrics.snapshot().shield_absorbed==10)
	root.remove_meta(Metrics.META)
	Metrics.observe(player,{"kind":"damage","amount":999})
	assert(metrics.snapshot().actual_damage==1000)
	print("[verify_skill_balance_metrics_runtime] PASS real damage pipeline P100 HP1000 + actual shield absorb, disabled recorder silent")
	quit(0)
