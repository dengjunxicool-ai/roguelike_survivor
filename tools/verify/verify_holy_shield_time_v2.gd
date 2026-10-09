extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Absorb = preload("res://scripts/combat/application_stages/player_absorb_application_stage.gd")
const Application = preload("res://scripts/combat/damage_application_context.gd")
const Pipeline = preload("res://scripts/combat/damage_application_pipeline.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	setup()
	Registry.get_or_create(root).unregister_enemy(enemy)
	enemy.remove_from_group(&"enemies")
	var barrier: RefCounted = install(&"holy_cast_divine_barrier")
	for population: int in [0,1,24]:
		var targets: Array = []
		for i: int in population: targets.append(make_enemy(Vector2(20+i,20)))
		player.set_meta("fire_passive_shield",0)
		bus.emit_skill_event(&"on_cast",ctx(null,barrier))
		await process_frame
		var area: Node = null
		for node: Node in get_nodes_in_group(&"areas"):
			if String(node.get("source_id")) == "divine_barrier_field": area=node
		expect(area != null,"barrier spawned")
		if area != null:
			area.set_physics_process(false)
			advance(1.0)
			area.call("_physics_process",1.0)
			expect(int(player.get_meta("fire_passive_shield",0)) == 10,"one percent shield per second with %d enemies" % population)
			player.position = Vector2(1000,0)
			advance(1.0)
			area.call("_physics_process",1.0)
			expect(int(player.get_meta("fire_passive_shield",0)) == 10,"outside barrier no shield")
			player.position = Vector2.ZERO
			area.queue_free()
		for target: Node in targets:
			Registry.get_or_create(root).unregister_enemy(target)
			target.queue_free()
		advance(10.0)
		await process_frame
	manager.clear_skills()
	var seal: RefCounted = install(&"holy_power_counter_seal")
	var count: int = get_nodes_in_group(&"areas").size()
	bus.emit_skill_event(&"shield_broken",ctx(null,seal))
	var heavy: Dictionary = ctx(null)
	heavy.amount = 100
	bus.emit_skill_event(&"on_player_damaged",heavy)
	await process_frame
	expect(get_nodes_in_group(&"areas").size() == count+1,"break and heavy hit share one counter")
	advance(8.0)
	heavy.amount = 99
	bus.emit_skill_event(&"on_player_damaged",heavy)
	await process_frame
	expect(get_nodes_in_group(&"areas").size() <= count+1,"light hit does not trigger seal")
	manager.clear_skills()
	var guardian: RefCounted = install(&"holy_summon_shield_guardian")
	bus.emit_skill_event(&"on_cast",ctx(null,guardian))
	await process_frame
	player.set_meta("fire_passive_shield",0)
	var stage: RefCounted = Absorb.new()
	var application: RefCounted = Application.create(player,DamagePacket.from_dictionary({"raw_amount":200,"amount":200,"element":"physical"}))
	application.incoming_amount = 200
	stage.apply_with_host(Pipeline,application)
	expect(application.absorbed_amount == 100,"live guardian absorbs ten percent maxHP before health")
	var second: RefCounted = Application.create(player,application.packet)
	second.incoming_amount = 200
	stage.apply_with_host(Pipeline,second)
	expect(second.absorbed_amount == 200,"guardian blocks once per two seconds")
	manager.clear_skills()
	advance(2.0)
	var removed: RefCounted = Application.create(player,application.packet)
	removed.incoming_amount = 200
	stage.apply_with_host(Pipeline,removed)
	expect(removed.absorbed_amount == 200,"removed guardian cannot absorb")
	var executor: RefCounted = Executor.new()
	install(&"holy_passive_devotion")
	var shield: Dictionary = {"type":"grant_shield","params":{"amount":5000,"duration":6.0,"respect_shield_cap":true}}
	executor.execute_action(shield,ctx(null))
	expect(int(player.get_meta("fire_passive_shield",0)) == 350,"large shield grant cannot exceed thirty-five percent cap")
	for i: int in 6: executor.execute_action(shield,ctx(null))
	var store: Node = player.get_node("ModifierStore")
	var query: RefCounted = preload("res://scripts/modifiers/modifier_query.gd").for_skill(install(&"holy_cast_holy_ray"),player)
	var values: Dictionary = store.collect(query)
	expect(is_equal_approx(float(values.get("damage_multiplier_add",0.0)),0.2),"overflow devotion refreshes one timed source")
	store.call("tick_timed_sources",4.1)
	expect(float(store.collect(query).get("damage_multiplier_add",0.0)) == 0.0,"devotion expires")
	finish()
