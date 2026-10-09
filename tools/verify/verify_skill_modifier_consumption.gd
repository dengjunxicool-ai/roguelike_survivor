extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Runner = preload("res://scripts/skills/skill_component_runner.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Query = preload("res://scripts/modifiers/modifier_query.gd")
const Aggregator = preload("res://scripts/modifiers/modifier_aggregator.gd")
var failed: bool = false
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	c.skill_manager.add_skill(&"thunder_passive_high_frequency_discharge")
	var s: RefCounted = F.skill("cast", "thunder_fixture", [{"trigger": "cast_skill", "cooldown": 10.0}])
	s.definition.tags.assign(["cast", "thunder", "lightning"])
	c.skill_instance = s
	_close(Runner.new().get_cooldown(s, c), 8.5, "thunder cooldown actually reduced")
	c.skill_manager.clear_skills()
	c.skill_manager.add_skill(&"frost_passive_chill_extension", "legendary")
	Executor.new().execute_action({"type": "apply_status", "params": {"status_id": "chilled", "duration": 6.0}}, c)
	_close(float(c.statuses.get("_statuses")[&"chilled"].duration_remaining), 7.2, "chilled duration consumed")
	Executor.new().execute_action({"type": "apply_status", "params": {"status_id": "frozen", "duration": 1.2}}, c)
	_close(float(c.statuses.get("_statuses")[&"frozen"].duration_remaining), 1.44, "frozen duration consumed")
	c.statuses.clear_statuses()
	await physics_frame
	c.statuses.apply_status(&"chilled", {"stacks": 7})
	_close(float(c.statuses.get("_statuses")[&"frozen"].duration_remaining), 1.44, "naturally converted freeze consumes duration bonus once")
	c.skill_manager.clear_skills()
	c.skill_manager.add_skill(&"holy_passive_sanctuary")
	var packet := DamagePacket.from_dictionary({"raw_amount": 100, "source_instance_id": "fixture:holy", "element": "holy"})
	var q: RefCounted = Query.for_damage(packet, c.caster)
	_close(float(Aggregator.collect(q).get("holy_damage_multiplier_add", 0.0)), 0.0, "sanctuary inactive without shield")
	c.caster.set_meta("fire_passive_shield", 5)
	_close(float(Aggregator.collect(q).get("holy_damage_multiplier_add", 0.0)), 0.15, "sanctuary active with shield")
	c.caster.queue_free()
	c.target.queue_free()
	await process_frame
	if not failed: print("[verify_skill_modifier_consumption] PASS")
	quit(1 if failed else 0)
func _close(a: float, b: float, label: String) -> void:
	if absf(a-b)>0.0001:
		failed = true
		push_error("[verify_skill_modifier_consumption] FAIL %s actual=%s expected=%s" % [label,a,b])
