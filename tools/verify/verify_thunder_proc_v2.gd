extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Runner = preload("res://scripts/skills/skill_component_runner.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	setup()
	var double: RefCounted = install(&"thunder_power_double_strike")
	var source: RefCounted = install(&"thunder_cast_chain_lightning")
	var hit: Dictionary = ctx(enemy,source)
	hit.damage_packet = {"element":"lightning"}
	hit.damage_amount = 0
	bus.emit_skill_event(&"post_damage_hit",hit)
	expect(int(double.get_meta("double_strike_lightning_hits",0)) == 0, "zero damage not counted")
	hit.damage_amount = 100
	hit.proc_depth = 1
	hit.can_generate_secondary_proc = false
	bus.emit_skill_event(&"post_damage_hit",hit)
	expect(int(double.get_meta("double_strike_lightning_hits",0)) == 0, "derived lightning not counted")
	hit.proc_depth = 0
	hit.can_generate_secondary_proc = true
	for i: int in 3: bus.emit_skill_event(&"post_damage_hit",hit)
	await process_frame
	expect(int(double.get_meta("double_strike_lightning_hits",0)) == 0, "three initial hits cross threshold and derived hit cannot loop")
	expect(enemy.packets.size() == 1, "one double strike output")
	var runner: RefCounted = Runner.new()
	var before: float = runner.get_cooldown(source,ctx(enemy,source))
	install(&"thunder_passive_high_frequency_discharge")
	expect(runner.get_cooldown(source,ctx(enemy,source)) < before, "high frequency lowers actual cast CD")
	install(&"thunder_passive_static_charge")
	for i: int in 18: bus.emit_skill_event(&"post_damage_hit",hit)
	expect(runner.get_cooldown(source,ctx(enemy,source)) < before*0.85, "static lowers actual CD after eighteen hits")
	manager.clear_skills()
	install(&"thunder_power_overload_burst")
	var neighbors: Array = []
	for i: int in 7: neighbors.append(make_enemy(Vector2(35+i*2,0)))
	enemy.apply_status(&"conductive",{"stacks":5})
	await process_frame
	var charged: int = 0
	for target: Enemy in neighbors:
		if target.get_status_stack(&"conductive") > 0: charged += 1
	expect(charged == 4, "overload spreads to at most four neighbors")
	expect(enemy.get_status_stack(&"conductive") == 0, "overload excludes original from spread")
	finish()
