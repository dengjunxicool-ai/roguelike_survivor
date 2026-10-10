extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Preview = preload("res://scripts/ui/skill_preview_service.gd")
const Runner = preload("res://scripts/skills/skill_component_runner.gd")
const Summon = preload("res://scripts/summons/summon_controller.gd")
const SummonDef = preload("res://scripts/summons/summon_definition.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	setup()
	enemy.get_node("StatusEffectManager").set_physics_process(false)
	var cast: RefCounted = install(&"holy_cast_divine_barrier")
	cast.current_level = 5
	cast.current_rarity = "legendary"
	var preview: Dictionary = Preview.build(player,cast.skill_id,5,"normal")
	bus.emit_skill_event(&"on_cast",ctx(enemy,cast))
	await process_frame
	var area: Node = null
	for node: Node in root.get_children():
		if node is AreaEffect and node.source_id == &"divine_barrier_field": area = node
	expect(area != null,"preview area is a real created region")
	if area != null:
		area.set_physics_process(false)
		enemy.packets.clear()
		area._damage_body(enemy)
		expect(not enemy.packets.is_empty() and absf(float(enemy.packets.back().raw_amount)-preview.damage)<=1,"area tick damage agrees within rounding")
		expect(absf(float(area.radius)-preview.radius)<=1,"radius uses runtime modifiers")
		expect(absf(Runner.new().get_cooldown(cast,ctx(enemy,cast))-preview.cooldown)<=.01,"runtime cooldown matches preview")
		area.queue_free()
	manager.active_skills.erase(cast.skill_id)
	var summon_skill: RefCounted = install(&"frost_summon_ice_crystal_guard")
	summon_skill.current_level = 3
	summon_skill.current_rarity = "epic"
	preview = Preview.build(player,summon_skill.skill_id,3,"epic")
	var summon: Node = Summon.new()
	root.add_child(summon)
	summon.setup({"definition":SummonDef.from_id(&"ice_crystal_guard"),"owner":player,"player_power":100.0,"skill_instance":summon_skill,"event_bus":bus,"skill_manager":manager})
	summon.set_physics_process(false)
	enemy.packets.clear()
	summon.get("_attack")._apply_melee(summon,enemy,100.0,{"owner":player,"skill_instance":summon_skill,"event_bus":bus,"skill_manager":manager})
	expect(not enemy.packets.is_empty() and absf(float(enemy.packets.back().raw_amount)-preview.damage)<=1,"actual summon hit agrees with preview")
	summon.queue_free()
	var pulse: RefCounted = install(&"chaos_cast_mutation_pulse")
	install(&"chaos_power_echo_cast")
	bus.emit_skill_event(&"on_cast",ctx(enemy,pulse))
	await process_frame
	preview = Preview.build(player,&"chaos_power_echo_cast",1,"normal")
	var snapshot: Dictionary = bus.get_cast_snapshot()
	expect(not snapshot.is_empty() and preview.damage > 0,"echo preview only from actual snapshot")
	enemy.packets.clear()
	bus.replay_cast(snapshot,ctx(enemy,pulse),.4)
	await process_frame
	for node: Node in root.get_children():
		if node is AreaEffect and node.damage_packet.get("is_copy",false):
			enemy.packets.clear()
			node._execute_apply_actions()
			expect(not enemy.packets.is_empty() and absf(float(enemy.packets.back().raw_amount)-preview.damage)<=1,"actual forty-percent copied pulse matches preview")
	if failed == 0: print("[verify_skill_preview_output_paths] PASS")
	finish()
