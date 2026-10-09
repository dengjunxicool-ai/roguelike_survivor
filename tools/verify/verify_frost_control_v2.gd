extends "res://tools/verify/skill_m2_combat_fixture.gd"
func _init() -> void:
	call_deferred("run")
func run() -> void:
	setup()
	var cold: RefCounted = install(&"frost_attack_frostbite")
	expect(cold != null, "cold attack installed")
	if cold == null:
		finish()
		return
	bus.emit_skill_event(&"attack_hit", ctx(enemy, cold))
	expect(enemy.get_status_stack(&"chilled") == 1, "first hit chills once")
	await physics_frame
	bus.emit_skill_event(&"attack_hit", ctx(enemy,cold))
	expect(enemy.get_status_stack(&"chilled") == 3, "pre-chilled hit adds two")
	manager.clear_skills()
	enemy.get_node("StatusEffectManager").clear_statuses()
	var ring: RefCounted = install(&"frost_power_frost_ring_counter")
	for i: int in 7: make_enemy(Vector2(40+i*2,0))
	bus.emit_skill_event(&"crowd_check", ctx(null))
	await process_frame
	expect(enemy.has_status(&"frozen"), "crowded ring directly freezes ordinary enemies")
	var count: int = get_nodes_in_group(&"areas").size()
	bus.emit_skill_event(&"dash_end", ctx(null,ring))
	await process_frame
	expect(get_nodes_in_group(&"areas").size() == count, "crowd and dash share cooldown")
	var boss: Enemy = make_enemy(Vector2(80,0), "boss")
	boss.apply_status(&"frozen")
	var statuses: Node = boss.get_node("StatusEffectManager")
	var bonus: float = statuses.get_vulnerability_total(&"direct_magical", &"frost")
	expect(bonus >= 0.1, "Boss freeze attempt exposes frost weakness")
	statuses.update_status_effects(0.6)
	expect(statuses.get_vulnerability_total(&"direct_magical", &"frost") < 0.1, "freeze weakness lasts half a second")
	boss.apply_status(&"frozen")
	expect(statuses.get_vulnerability_total(&"direct_magical", &"frost") < 0.1, "freeze weakness has two second ICD")
	expect(statuses.get_move_speed_multiplier() >= 0.7, "Boss slow capped at thirty percent")
	manager.clear_skills()
	enemy.get_node("StatusEffectManager").clear_statuses()
	var lance: RefCounted = install(&"frost_cast_glacial_lance")
	bus.emit_skill_event(&"on_cast",ctx(enemy,lance))
	await process_frame
	var projectile: Node = null
	for node: Node in root.get_children():
		if node.get_script() == preload("res://scripts/combat/projectile.gd") and String(node.get("source_id")) == "glacial_lance_projectile": projectile = node
	expect(projectile != null, "real lance projectile created")
	if projectile != null:
		var before: int = get_nodes_in_group(&"areas").size()
		projectile.call("_emit_hit_event",enemy)
		await process_frame
		expect(get_nodes_in_group(&"areas").size() == before, "lance has no splash on unfrozen pre-hit target")
		enemy.apply_status(&"frozen")
		projectile.call("_emit_hit_event",enemy)
		await process_frame
		expect(get_nodes_in_group(&"areas").size() > before, "lance splashes pre-frozen target")
	manager.clear_skills()
	install(&"frost_core_absolute_zero")
	var chilled: Enemy = make_enemy(Vector2(60,60))
	chilled.apply_status(&"chilled",{"stacks":5})
	expect(chilled.has_status(&"frozen"), "core freeze threshold five consumed by status manager")
	finish()
