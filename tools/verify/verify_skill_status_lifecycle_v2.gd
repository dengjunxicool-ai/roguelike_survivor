extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
var failed: bool = false
var resolved: Array[Dictionary] = []
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	c.event_bus.subscribe(&"cursed_resolved", func(event: Dictionary) -> void: resolved.append(event.duplicate()))
	for count: int in [1, 5]:
		c.statuses.clear_statuses()
		c.target.packets.clear()
		await physics_frame
		c.statuses.apply_status(&"burning", {"power": 100.0, "stacks": count})
		for second in range(4):
			c.statuses.update_status_effects(1.0)
			if second < 3:
				_expect(c.statuses.get_status_stack(&"burning") == count, "burn tick keeps stacks")
		_expect(is_equal_approx(F.damage_total(c.target), 144.0 * count), "four burn ticks total")
		_expect(not c.statuses.has_status(&"burning"), "final tick precedes expiration")
	c.target.packets.clear()
	c.statuses.apply_status(&"burning", {"power": 100.0, "stacks": 5})
	c.statuses.update_status_effects(1.5)
	await physics_frame
	c.statuses.apply_status(&"burning", {"power": 100.0, "stacks": 1})
	_expect(c.statuses.get_status_stack(&"burning") == 5 and is_equal_approx(float(c.statuses.get("_statuses")[&"burning"].duration_remaining), 4.0), "burn reapply caps stacks and refreshes duration")
	c.statuses.clear_statuses()
	c.target.packets.clear()
	await physics_frame
	c.statuses.apply_status(&"burning", {"power": 100.0, "stacks": 5})
	c.statuses.update_status_effects(10.0)
	_expect(is_equal_approx(F.damage_total(c.target), 720.0), "large delta cannot create ticks after the four-second lifetime")
	c.target.packets.clear()
	await physics_frame
	c.statuses.apply_status(&"cursed", {"power": 100.0, "stacks": 3})
	c.statuses.update_status_effects(2.0)
	await physics_frame
	c.statuses.apply_status(&"cursed", {"power": 100.0, "stacks": 3, "duration": 30.0})
	c.statuses.update_status_effects(1.0)
	_expect(is_equal_approx(F.damage_total(c.target), 225.0) and not c.statuses.has_status(&"cursed"), "full-stack reapplication keeps the first curse deadline")
	resolved.clear()
	c.target.packets.clear()
	c.statuses.apply_status(&"cursed", {"power": 100.0, "duration": 30.0})
	c.statuses.update_status_effects(2.0)
	await physics_frame
	c.statuses.apply_status(&"cursed", {"power": 100.0, "duration": 30.0})
	c.statuses.update_status_effects(1.0)
	_expect(is_equal_approx(F.damage_total(c.target), 150.0), "curse first deadline t3 with two stacks")
	_expect(not c.statuses.has_status(&"cursed"), "curse removed before resolution event")
	_expect(resolved.size() == 1, "one cursed_resolved event")
	if not resolved.is_empty():
		_expect(int(resolved[0].stacks) == 2 and float(resolved[0].resolved_damage) == 150.0, "resolution has actual stacks/damage")
	c.statuses.clear_statuses()
	c.target.packets.clear()
	await physics_frame
	Executor.new().execute_action({"type": "apply_status", "params": {"status_id": "burning", "duration": 4.0}}, {"caster": c.caster, "target": c.target, "amount": 1000.0, "damage_packet": {"raw_amount": 1000.0}})
	_expect(is_equal_approx(float(c.statuses.get("_statuses")[&"burning"].power), 100.0), "status power is effective attack, not final hit")
	c.owner.queue_free()
	c.target.queue_free()
	await process_frame
	if not failed: print("[verify_skill_status_lifecycle_v2] PASS")
	quit(1 if failed else 0)
func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[verify_skill_status_lifecycle_v2] FAIL " + label)
