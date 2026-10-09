extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Runner = preload("res://scripts/skills/skill_component_runner.gd")
const Trace = preload("res://scripts/runtime/damage_trace_context.gd")
const Conditions = preload("res://scripts/skills/condition_evaluator.gd")
const Reward = preload("res://scripts/enemies/enemy_reward_controller.gd")
var failed: bool = false
var succeeded: Array[Dictionary] = []
var received: Array[Dictionary] = []
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	c.event_bus.subscribe(&"on_cast", func(event: Dictionary) -> void: received.append(event.duplicate()))
	c.event_bus.subscribe(&"skill_cast_succeeded", func(event: Dictionary) -> void: succeeded.append(event.duplicate()))
	var rules: Array = [{"trigger": "cast_skill", "effects": [{"type": "damage", "power_scale": 1.0}, {"type": "damage", "power_scale": 1.0}, {"type": "damage", "power_scale": 1.0}]}]
	var s: RefCounted = F.skill("cast", "holy_cast_sacred_hammer", rules)
	c.skill_instance = s
	c.skill_id = s.skill_id
	var runner := Runner.new()
	runner.tick(s, 0.1, c)
	_expect(succeeded.size() == 1, "three output actions count one cast")
	_expect(received.size() == 1 and String(received[0].get("origin_skill_id", "")) == "holy_cast_sacred_hammer", "original source preserved")
	var trace_packet: Dictionary = {"origin_skill_id": "holy_cast_sacred_hammer", "listener_skill_id": "fixture_listener", "event_id": 12, "parent_event_id": 10, "proc_depth": 1, "is_copy": true, "can_generate_secondary_proc": false, "combat_seconds": 2.5}
	var status_trace: Dictionary = Trace.apply_to_status_params({}, {"damage_packet": trace_packet})
	_expect(status_trace.get("is_copy", false) and int(status_trace.get("proc_depth", 0)) == 1 and not status_trace.get("can_generate_secondary_proc", true), "typed proc fields survive status forwarding")
	Trace.persist_last_damage_trace(c.target, trace_packet)
	var death_trace: Dictionary = Trace.get_last_damage_trace_context(c.target)
	_expect(death_trace.get("origin_skill_id", "") == "holy_cast_sacred_hammer" and int(death_trace.get("proc_depth", 0)) == 1 and death_trace.get("is_copy", false), "derived death preserves origin and proc limit")
	var death_events: Array[Dictionary] = []
	c.event_bus.subscribe(&"on_enemy_killed", func(event: Dictionary) -> void: death_events.append(event.duplicate(true)))
	var reward: RefCounted = Reward.new()
	reward.setup(c.target)
	reward.notify_enemy_killed_synergies()
	_expect(death_events.size() == 1 and death_events[0].get("origin_skill_id", "") == "holy_cast_sacred_hammer" and death_events[0].get("is_copy", false), "actual death service keeps derived kill provenance")
	c.skill_manager.add_skill(&"curse_power_soul_harvest")
	await physics_frame
	for index: int in range(12):
		var victim := F.Target.new()
		root.add_child(victim)
		var statuses := F.Statuses.new()
		statuses.name = "StatusEffectManager"
		victim.add_child(statuses)
		statuses.apply_status(&"cursed", {"power": 100.0})
		Trace.persist_last_damage_trace(victim, {"origin_skill_id": "fixture_primary", "proc_depth": 0, "is_copy": false, "can_generate_secondary_proc": true})
		victim.current_health = 0
		reward.setup(victim)
		reward.notify_enemy_killed_synergies()
		if index == 10: _expect(is_equal_approx(c.store.get_cast_charge_snapshot().multiplier, 1.0), "eleven cursed kills do not grant charge")
		victim.queue_free()
	c.event_bus.process_pending_events()
	_expect(is_equal_approx(c.store.get_cast_charge_snapshot().multiplier, 1.35), "twelve actual cursed death notifications grant one charge")
	c.skill_manager.clear_skills()
	var listener: RefCounted = F.skill("power", "fire_fixture_listener", [{"trigger": "skill_cast_succeeded", "conditions": [{"type": "skill_has_tag", "tag": "holy"}], "effects": [{"type": "damage", "power_scale": 0.1}]}])
	s.definition.tags.assign(["cast", "holy"])
	c.skill_manager.active_skills[s.skill_id] = s
	c.skill_manager.active_skills[listener.skill_id] = listener
	c.target.packets.clear()
	c.event_bus.emit_skill_event(&"skill_cast_succeeded", c)
	await physics_frame
	c.event_bus.process_pending_events()
	_expect(c.target.packets.size() == 1, "listener checks original holy source rather than its own fire tags")
	succeeded.clear()
	succeeded.append({}) # The remainder measures additional successful casts.
	c.skill_manager.active_skills.clear()
	_expect(not Conditions.evaluate({"type": "source_has_tag", "tag": "frost_area"}, {"source_id": "frost_field"}), "source name cannot invent an area tag")
	var delayed_times: Array[float] = []
	c.event_bus.subscribe(&"fixture_delayed_time", func(event: Dictionary) -> void: delayed_times.append(float(event.combat_seconds)))
	c.event_bus.get_node("RunCombatClock").tick(7.0)
	c.event_bus.emit_skill_event(&"fixture_delayed_time", Trace.normalize_event_context({"damage_packet": {"combat_seconds": 0.0}}))
	_expect(delayed_times.size() == 1 and is_equal_approx(delayed_times[0], 7.0), "delayed event uses current combat time rather than original cast time")
	c.target.packets.clear()
	s.cooldown_remaining = 0.0
	c.target = null
	# No caster/parent: an output action cannot create a fallback target.
	c.caster = null
	_runner_failed_cast(runner, s, c)
	_expect(succeeded.size() == 1, "failed output never emits success")
	if c.store.has_method("set_cast_charge"):
		c.store.set_cast_charge("skill:curse_power_soul_harvest:next_cast", 0.35)
		_runner_failed_cast(runner, s, c)
		_expect(is_equal_approx(c.store.get_cast_charge_snapshot().multiplier, 1.35), "failed cast preserves charge")
		c.caster = c.owner
		c.target = get_first_node_in_group(&"enemies")
		s.cooldown_remaining = 0.0
		runner.tick(s, 0.1, c)
		_expect(c.target.packets.size() == 3, "complete release produces three hits")
		for packet: Dictionary in c.target.packets:
			_expect(is_equal_approx(float(packet.raw_amount), 135.0), "all outputs share charge snapshot")
		_expect(is_equal_approx(c.store.get_cast_charge_snapshot().multiplier, 1.0), "charge consumed exactly once")
		c.store.set_cast_charge("skill:fixture:delayed", 0.35)
		c.parent = root
		c.target.global_position = Vector2(100.0, 0.0)
		var delayed: RefCounted = F.skill("cast", "fixture_delayed", [{"trigger": "cast_skill", "effects": [{"type": "spawn_projectile", "projectile_id": "fireball_projectile", "on_hit": [{"type": "damage", "power_scale": 1.0}]}]}])
		c.skill_instance = delayed
		c.skill_id = delayed.skill_id
		c.target.packets.clear()
		runner.tick(delayed, 0.1, c)
		await process_frame
		var projectile: Node = null
		for node: Node in root.get_children():
			if node.has_method("_emit_hit_event") and node.get("skill_instance") == delayed: projectile = node
		_expect(projectile != null, "charged cast creates real delayed projectile")
		if projectile != null:
			projectile.call("_emit_hit_event", c.target)
			_expect(is_equal_approx(F.damage_total(c.target), 135.0), "delayed on-hit damage retains one charge multiplier")
			projectile.queue_free()
		c.store.set_cast_charge("skill:fixture:area", 0.35)
		var area_skill: RefCounted = F.skill("cast", "fixture_area", [{"trigger": "cast_skill", "effects": [{"type": "spawn_area", "area_id": "fixture_area", "radius": 100.0, "duration": 2.0, "effects_on_tick": [{"type": "damage", "power_scale": 1.0}]}]}])
		c.skill_instance = area_skill
		c.skill_id = area_skill.skill_id
		c.target.packets.clear()
		runner.tick(area_skill, 0.1, c)
		await process_frame
		var area: Node = null
		for node: Node in root.get_children():
			if node.has_method("_execute_adapted_actions") and node.get("skill_instance") == area_skill: area = node
		_expect(area != null, "charged cast creates real tick area")
		if area != null:
			area.call("_execute_adapted_actions", area.actions_on_tick, c.target)
			_expect(is_equal_approx(F.damage_total(c.target), 135.0), "delayed area tick retains one charge multiplier")
			area.set_physics_process(false)
			var tick_listener: RefCounted = F.skill("power", "fixture_area_icd", [{"trigger": "area_tick", "cooldown": 0.4, "effects": [{"type": "damage", "power_scale": 0.1}]}])
			c.skill_manager.active_skills[tick_listener.skill_id] = tick_listener
			c.target.packets.clear()
			area.call("_emit_area_event", &"area_tick", c.target)
			c.event_bus.get_node("RunCombatClock").tick(0.2)
			area.call("_emit_area_event", &"area_tick", c.target)
			_expect(c.target.packets.size() == 1, "same real area event stays blocked before ICD")
			c.event_bus.get_node("RunCombatClock").tick(0.3)
			area.call("_emit_area_event", &"area_tick", c.target)
			_expect(c.target.packets.size() == 2, "same real area event reopens after current clock passes ICD")
			area.queue_free()
	c.owner.queue_free()
	get_first_node_in_group(&"enemies").queue_free()
	await process_frame
	if not failed: print("[verify_skill_event_provenance] PASS")
	quit(1 if failed else 0)
func _runner_failed_cast(runner: RefCounted, s: RefCounted, c: Dictionary) -> void:
	s.cooldown_remaining = 0.0
	runner.tick(s, 0.1, c)
func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[verify_skill_event_provenance] FAIL " + label)
