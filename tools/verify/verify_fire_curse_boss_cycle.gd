extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Adapter = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	setup()
	var counter: Script = load("res://scripts/skills/skill_resource_counter.gd") if ResourceLoader.exists("res://scripts/skills/skill_resource_counter.gd") else null
	expect(counter != null, "resource counter exists")
	if counter == null:
		finish()
		return
	var skill: RefCounted = install(&"fire_power_combustion_chain")
	expect(counter.add(skill, &"test", 25.5, 12.0) == 2, "two crossings retained")
	expect(is_equal_approx(float(skill.get_meta("test", 0.0)), 1.5), "fractional remainder")
	counter.clear(skill)
	expect(not skill.has_meta("test"), "clear resource state")
	enemy.set_meta("enemy_rank", "boss")
	var rule: Dictionary = {"counter_key": "cycle", "threshold": 12, "resource_kind": "burning"}
	for i: int in 5:
		var context: Dictionary = ctx(enemy)
		context.merge({"event_name": &"status_tick", "status_id": &"burning", "event_id": i+1})
		Adapter.can_execute_rule_event(rule, context, skill)
		Adapter.can_execute_rule_event(rule, context, skill)
	expect(is_equal_approx(float(skill.get_meta("cycle", 0.0)), 1.0), "five strong ticks grant one point without duplicates")
	for i: int in 2:
		var context: Dictionary = ctx(enemy)
		context.merge({"event_name": &"cursed_resolved", "resolution_id": str(i), "event_id": 10+i})
		Adapter.can_execute_rule_event({"counter_key": "debt", "threshold": 12, "resource_kind": "cursed"}, context, skill)
		Adapter.can_execute_rule_event({"counter_key": "debt", "threshold": 12, "resource_kind": "cursed"}, context, skill)
	expect(is_equal_approx(float(skill.get_meta("debt", 0.0)), 1.0), "two curse resolutions grant one point")
	enemy.current_health = 0
	var death: Dictionary = ctx(enemy)
	death.merge({"event_name": &"on_enemy_killed", "event_id": 20})
	Adapter.can_execute_rule_event(rule, death, skill)
	Adapter.can_execute_rule_event(rule, death, skill)
	expect(is_equal_approx(float(skill.get_meta("cycle", 0.0)), 2.0), "one point per corpse")
	death.event_name = &"status_tick"
	death.status_id = &"burning"
	death.event_id = 21
	Adapter.can_execute_rule_event(rule, death, skill)
	expect(is_equal_approx(float(skill.get_meta("cycle", 0.0)), 2.0), "dead tick cannot double charge")
	death.event_name = &"on_enemy_killed"
	death.origin_skill_id = &"fire_core_inferno_cycle"
	death.proc_depth = 1
	var before: float = float(skill.get_meta("cycle", 0.0))
	Adapter.can_execute_rule_event(rule, death, skill)
	expect(is_equal_approx(float(skill.get_meta("cycle", 0.0)), before), "derived inferno cannot charge")
	manager.clear_skills()
	var real: RefCounted = install(&"fire_power_combustion_chain")
	var source: RefCounted = install(&"fire_cast_lava_rift")
	enemy.current_health = 10000
	for i: int in 5:
		var tick: Dictionary = ctx(enemy,source)
		tick.status_id = &"burning"
		bus.emit_skill_event(&"status_tick",tick)
	expect(is_equal_approx(float(real.get_meta("combustion_burning_deaths",0)),1.0), "actual rules charge on Boss ticks")
	var cycle: RefCounted = bus.get("_cycles")
	var test_chain: Dictionary = {"remaining":2,"multiplier":1.0,"seen":{},"context":ctx(enemy,real)}
	var low_seed: int = 0
	for candidate: int in 100:
		seed(candidate)
		if randf() < 0.25:
			low_seed = candidate
			break
	var explosions: int = int(cycle.combustion_explosions)
	for i: int in 4:
		var corpse: Enemy = make_enemy(Vector2(30,0))
		corpse.current_health = 0
		corpse.set_meta("combustion_pending",test_chain)
		seed(low_seed)
		bus.emit_skill_event(&"on_enemy_killed",ctx(corpse))
	expect(int(cycle.combustion_explosions)-explosions == 2, "chain permits exactly two continuations at most")
	expect(is_equal_approx(float(test_chain.multiplier),0.36), "continuations decay by sixty percent each")
	finish()
