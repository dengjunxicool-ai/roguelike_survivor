extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Adapter = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
var failed: bool = false
var order: Array[int] = []
var freed_received: bool = false
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	c.event_bus.subscribe(&"fixture_queue", func(event: Dictionary) -> void: order.append(int(event.index)))
	for i in range(65):
		c.event_bus.emit_skill_event(&"fixture_queue", {"index": i})
	_expect(order.size() == 64, "only 64 events execute in first frame")
	await physics_frame
	if c.event_bus.has_method("process_pending_events"):
		c.event_bus.process_pending_events()
	_expect(order.size() == 65 and order[64] == 64, "65th event deferred without loss")
	for i in order.size():
		_expect(order[i] == i, "queue keeps order")
	await physics_frame
	for i in range(64): c.event_bus.emit_skill_event(&"fixture_budget", {})
	var doomed := Node.new()
	root.add_child(doomed)
	var watcher: RefCounted = F.skill("power", "fixture_watcher", [{"trigger": "fixture_freed", "conditions": [{"type": "target_has_status", "status": "cursed"}], "effects": []}])
	c.skill_manager.active_skills[watcher.skill_id] = watcher
	c.event_bus.subscribe(&"fixture_freed", func(event: Dictionary) -> void:
		freed_received = true
		_expect(event.target == null, "deferred event replaces freed node with null"))
	c.event_bus.emit_skill_event(&"fixture_freed", {"target": doomed, "caster": c.owner, "skill_manager": c.skill_manager})
	doomed.free()
	await physics_frame
	c.event_bus.process_pending_events()
	_expect(freed_received, "deferred event still delivered after target disappears")
	var skill: RefCounted = F.skill()
	var event: Dictionary = {"trigger": &"fixture_cd", "cooldown": 6.0}
	var ctx: Dictionary = {"combat_seconds": 0.0}
	_expect(Adapter.can_execute_rule_event(event, ctx, skill), "first ICD allowed")
	ctx.combat_seconds = 5.99
	_expect(not Adapter.can_execute_rule_event(event, ctx, skill), "running time before 6s blocked")
	ctx.combat_seconds = 6.01
	_expect(Adapter.can_execute_rule_event(event, ctx, skill), "running time after 6s allowed")
	var second: Node = Node.new()
	root.add_child(second)
	event.cooldown_scope = "target"
	ctx.target = c.target
	_expect(Adapter.can_execute_rule_event(event, ctx, skill), "first target allowed")
	ctx.target = second
	_expect(Adapter.can_execute_rule_event(event, ctx, skill), "second target has independent ICD")
	event.cooldown_scope = "object_pair"
	ctx.source = c.target
	ctx.other_area = second
	_expect(Adapter.can_execute_rule_event(event, ctx, skill), "first object pair allowed")
	ctx.source = second
	ctx.other_area = c.target
	_expect(not Adapter.can_execute_rule_event(event, ctx, skill), "reversed object pair shares ICD")
	var third := Node.new()
	root.add_child(third)
	ctx.other_area = third
	_expect(Adapter.can_execute_rule_event(event, ctx, skill), "different object pair has independent ICD")
	var policy_path: String = "res://scripts/skills/skill_proc_policy.gd"
	if FileAccess.file_exists(policy_path):
		var policy: Script = load(policy_path)
		_expect(not policy.can_generate({"proc_depth": 1, "can_generate_secondary_proc": false}, &"double_lightning"), "secondary cannot make double lightning")
		_expect(not policy.can_generate({"is_copy": true}, &"copy"), "copy cannot copy")
		_expect(policy.can_generate({"proc_depth": 1, "can_generate_secondary_proc": false}, &"status_reaction"), "secondary may make base status reaction")
	else:
		_expect(false, "proc policy exists")
	var clock: Node = c.event_bus.get_node_or_null("RunCombatClock")
	if clock != null:
		clock.tick(2.0)
		clock.tick(0.0)
		_expect(is_equal_approx(clock.now_seconds(), 2.0), "pause consumes no time")
		clock.set_physics_process(true)
		paused = true
		clock.call("_physics_process", 10.0)
		await create_timer(0.05, true).timeout
		_expect(is_equal_approx(clock.now_seconds(), 2.0), "actual SceneTree pause ignores even ten seconds of physics delta")
		paused = false
		clock.set_physics_process(false)
		clock.reset()
		_expect(is_zero_approx(clock.now_seconds()), "restart resets clock")
	else:
		_expect(false, "unified clock attached")
	c.skill_manager.clear_skills()
	var lightning: RefCounted = F.skill("power", "fixture_shield_lightning", [{"trigger": "shield_gained", "effects": [{"type": "damage", "power_scale": 1.0}]}])
	var shield: RefCounted = F.skill("power", "fixture_lightning_shield", [{"trigger": "post_damage_hit", "effects": [{"type": "grant_shield", "amount": 5.0}]}])
	c.skill_manager.active_skills[lightning.skill_id] = lightning
	c.skill_manager.active_skills[shield.skill_id] = shield
	c.target.packets.clear()
	c.target.hit_event_bus = c.event_bus
	c.event_bus.emit_skill_event(&"shield_gained", c)
	c.event_bus.process_pending_events()
	_expect(c.target.packets.size() == 1 and c.event_bus.get("_pending_events").is_empty(), "real shield-lightning-shield chain stops after one derived output")
	var executor: RefCounted = preload("res://scripts/skills/skill_action_executor.gd").new()
	var projectile := Node.new()
	root.add_child(projectile)
	projectile.set_script(preload("res://tools/verify/skill_rebalance_packet_source.gd"))
	projectile.damage_packet = {"proc_depth": 0, "is_copy": false, "can_generate_secondary_proc": true, "origin_skill_id": "fixture_initial"}
	var derived: Dictionary = c.duplicate(true)
	derived.projectile = projectile
	derived.proc_depth = 1
	derived.is_copy = true
	derived.can_generate_secondary_proc = false
	derived.origin_skill_id = "fixture_derived"
	executor.execute_action({"type": "deal_damage", "params": {"amount": 1.0}}, derived)
	var last: Dictionary = c.target.packets.back()
	_expect(last.get("proc_depth", 0) == 1 and last.get("is_copy", false) and last.get("origin_skill_id", "") == "fixture_derived", "projectile inheritance preserves actual derived packet identity")
	projectile.queue_free()
	second.queue_free()
	third.queue_free()
	c.owner.queue_free()
	c.target.queue_free()
	await process_frame
	if not failed: print("[verify_skill_proc_chain_limits] PASS")
	quit(1 if failed else 0)
func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[verify_skill_proc_chain_limits] FAIL " + label)
