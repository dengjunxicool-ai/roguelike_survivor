extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
var failed: bool = false
var resolutions: int = 0
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	c.event_bus.subscribe(&"cursed_resolved", func(_event: Dictionary) -> void:
		resolutions += 1
		c.statuses.consume_status_duration(&"cursed", 10.0))
	c.statuses.apply_status(&"cursed", {"power": 100.0, "stacks": 3})
	c.statuses.consume_status_duration(&"cursed", 10.0)
	c.statuses.consume_status_duration(&"cursed", 10.0)
	_expect(resolutions == 1 and is_equal_approx(F.damage_total(c.target), 225.0), "reentrant forced explosion resolves once")
	await physics_frame
	c.statuses.apply_status(&"cursed", {"power": 100.0})
	c.target.current_health = 0
	c.statuses.update_status_effects(4.0)
	_expect(resolutions == 1, "dead target never resolves")
	c.target.current_health = c.target.max_health
	for rank: String in ["normal", "elite", "boss"]:
		c.statuses.clear_statuses()
		c.target.set_meta("enemy_rank", rank)
		await physics_frame
		c.statuses.apply_status(&"chilled", {"stacks": 7})
		_expect(c.statuses.has_status(&"frozen") and not c.statuses.has_status(&"chilled"), rank + " consumes chilled at threshold")
		var expected: float = 1.2 if rank == "normal" else (0.5 if rank == "elite" else 0.15)
		if c.statuses.has_status(&"frozen"):
			_expect(is_equal_approx(float(c.statuses.get("_statuses")[&"frozen"].duration_remaining), expected), rank + " freeze duration")
		c.statuses.update_status_effects(expected)
		await physics_frame
		c.statuses.apply_status(&"chilled", {"stacks": 7})
		_expect(not c.statuses.has_status(&"frozen"), rank + " freeze immunity")
	c.statuses.clear_statuses()
	c.target.set_meta("enemy_rank", "normal")
	await physics_frame
	c.statuses.apply_status(&"frozen", {})
	c.statuses.consume_status_stack(&"frozen", 1)
	await physics_frame
	c.statuses.apply_status(&"chilled", {"stacks": 7})
	_expect(not c.statuses.has_status(&"frozen"), "shattering freeze also starts immunity")
	c.statuses.clear_statuses()
	await physics_frame
	c.statuses.apply_status(&"frozen", {})
	c.statuses.consume_status_duration(&"frozen", 10.0)
	await physics_frame
	c.statuses.apply_status(&"chilled", {"stacks": 7})
	_expect(not c.statuses.has_status(&"frozen"), "forced freeze ending also starts immunity")
	c.statuses.clear_statuses()
	F.install_runtime_skill(c.skill_manager, &"frost_core_absolute_zero")
	await physics_frame
	c.statuses.apply_status(&"chilled", {"stacks": 5})
	_expect(c.statuses.has_status(&"frozen"), "core lowers threshold to five")
	c.statuses.clear_statuses()
	await physics_frame
	c.statuses.apply_status(&"cursed", {"power": 100.0})
	c.statuses.update_status_effects(2.9)
	c.statuses.apply_status(&"frozen", {})
	c.statuses.update_status_effects(0.2)
	_expect(c.statuses.has_status(&"cursed"), "same frame freeze pauses curse deadline")
	if c.statuses.has_method("pause_status"):
		c.statuses.pause_status(&"cursed", &"fusion_a")
		c.statuses.pause_status(&"cursed", &"fusion_b")
		c.statuses.resume_status(&"cursed", &"fusion_a")
		c.statuses.update_status_effects(2.0)
		_expect(c.statuses.has_status(&"cursed"), "second pause source still holds")
		c.statuses.resume_status(&"cursed", &"fusion_b")
		c.statuses.update_status_effects(0.2)
		_expect(not c.statuses.has_status(&"cursed"), "last pause release resumes")
	else:
		_expect(false, "status supports independently owned pause sources")
	c.owner.queue_free()
	c.target.queue_free()
	await process_frame
	if not failed: print("[verify_skill_status_race_conditions] PASS")
	quit(1 if failed else 0)
func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[verify_skill_status_race_conditions] FAIL " + label)
