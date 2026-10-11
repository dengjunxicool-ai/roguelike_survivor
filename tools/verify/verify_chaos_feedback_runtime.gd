## 真实应用与伤害执行器验证混沌反馈，所有展示只读取权威状态。
extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
var _bus: Node
var _view: Node
var _executor: RefCounted

func run() -> void:
	await setup_run()
	_bus = player.get_node("SkillEventBus")
	_executor = Executor.new()
	_view = _bus.get_node_or_null("ChaosCombatPresentation")
	check(_view != null, "production chaos presentation attaches to real app")
	if _view == null:
		await finish()
		return
	manager.clear_skills()
	_verify_hits()
	_verify_instability()
	_verify_entropy()
	_verify_counters()
	await _verify_echo_replay()
	await _verify_swap()
	await _verify_pools()
	await _verify_pause_reset()
	await finish()

func _context(target: Node2D = null, id: StringName = &"chaos_cast_mutation_pulse") -> Dictionary:
	var result: Dictionary = {"caster":player, "owner":player, "target":target, "event_bus":_bus, "skill_manager":manager, "skill_id":id, "origin_skill_id":id, "combat_seconds":_bus.combat_seconds(), "parent":player.get_parent()}
	if manager.has_skill(id): result["skill_instance"] = manager.get_skill(id)
	return result

func _enemy_at(offset: Vector2) -> Node2D:
	var enemy: Node2D = EnemyScene.instantiate()
	enemy.enemy_id = &"skeleton"
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + offset
	enemy.max_health = 10000
	enemy.current_health = 10000
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy

func _visible_count(items: Array) -> int:
	var count: int = 0
	for item: Node2D in items:
		if item.visible: count += 1
	return count

func _aura(key: String) -> Node2D:
	return _view._auras.get(key) as Node2D

func _aura_visible(key: String) -> bool:
	var aura: Node2D = _aura(key)
	return aura != null and aura.visible

func _verify_hits() -> void:
	_view.reset_presentation()
	var enemy: Node2D = _enemy_at(Vector2(110, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":0, "damage_type":"arcane"}}, _context(enemy))
	check(enemy.current_health == 10000 and _visible_count(_view._hits) == 0, "zero actual chaos damage has no impact")
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"arcane"}}, _context(enemy, &"arcane_cast_test"))
	check(enemy.current_health < 10000 and _visible_count(_view._hits) == 0, "unrelated arcane HP loss has no chaos impact")
	var chaos: Node2D = _enemy_at(Vector2(140, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"arcane"}}, _context(chaos))
	check(chaos.current_health < 10000 and _visible_count(_view._hits) == 1, "confirmed positive chaos-origin HP loss creates impact")
	var health_before: int = chaos.current_health
	for hit: Node2D in _view._hits: hit._process(1.0)
	check(chaos.current_health == health_before and _visible_count(_view._hits) == 0, "impact expiry causes no extra damage")
	var dot: Node2D = _enemy_at(Vector2(180, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"arcane", "damage_origin":"status_dot"}}, _context(dot))
	check(dot.current_health < 10000 and _visible_count(_view._hits) == 0, "real chaos DOT causes HP loss without duplicate direct impact")
	var primary: Node2D = _enemy_at(Vector2(190, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"physical", "damage_origin":"primary_attack"}}, _context(primary, &"fixture_primary"))
	check(primary.current_health < 10000 and _visible_count(_view._hits) == 0, "unowned primary attack has no chaos impact")
	_install(&"chaos_attack_chaotic")
	primary = _enemy_at(Vector2(210, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"physical", "damage_origin":"primary_attack"}}, _context(primary, &"fixture_primary"))
	check(primary.current_health < 10000 and _visible_count(_view._hits) == 1, "owned actual chaos primary attack creates confirmed impact")

func _verify_instability() -> void:
	manager.clear_skills()
	var enemy: Node2D = _enemy_at(Vector2(200, 70))
	var statuses: Node = enemy.get_node("StatusEffectManager")
	for stacks: int in range(1, 5):
		check(enemy.apply_status(&"instability", {"duration":3.0, "stacks":1}), "actual instability application %d succeeds" % stacks)
		statuses._flush_status_visual_refresh()
		var surface: Node2D = statuses._status_visual_overlay.get_node_or_null("ProceduralStatus") if statuses._status_visual_overlay != null else null
		check(surface != null and surface.visible and surface.profile == 0 and surface.status_stacks == stacks, "actual instability %d stacks selects matching fractured layer" % stacks)
	statuses.pause_status(&"instability", &"chaos_verify_pause")
	statuses._flush_status_visual_refresh()
	var surface: Node2D = statuses._status_visual_overlay.get_node_or_null("ProceduralStatus") if statuses._status_visual_overlay != null else null
	if surface == null: return
	statuses.update_status_effects(4.0)
	surface._process(4.0)
	check(enemy.get_status_stack(&"instability") == 4 and surface.visible and is_equal_approx(float(statuses.export_status(&"instability").duration_remaining), 3.0), "paused actual four-stack status retains duration and visible shell")
	statuses.resume_status(&"instability", &"chaos_verify_pause")
	statuses._flush_status_visual_refresh()
	surface._process(4.0)
	check(enemy.has_status(&"instability") and surface.visible, "host-controlled instability cannot expire before status manager")
	statuses.update_status_effects(3.1)
	statuses._flush_status_visual_refresh()
	check(not enemy.has_status(&"instability") and not surface.visible, "authoritative instability expiry hides shell")

func _install(id: StringName) -> void:
	check(Fixture.install_runtime_skill(manager, id), "install actual %s runtime" % id)

func _fission(target: Node2D) -> void:
	var context: Dictionary = _context(target)
	context["status_id"] = "instability"
	_bus.emit_skill_event(&"status_max_stack_reached", context)

func _verify_entropy() -> void:
	manager.clear_skills()
	_install(&"chaos_passive_entropy_growth")
	_install(&"chaos_power_fission_burst")
	var target: Node2D = _enemy_at(Vector2(500, 0))
	var store: Node = player.get_node("ModifierStore")
	store.set_timed_source("skill:unrelated:damage", [{"stat":"damage", "op":"multiplier_add", "value":0.12, "scope":{}, "source":"skill"}], [], 5.0)
	_view._process(0.11)
	check(not _aura_visible("entropy_0"), "unrelated timed buff cannot depict entropy")
	store.clear_source("skill:unrelated:damage")
	for branch: int in range(4):
		_fission(target)
		_view._process(0.11)
		var aura: Node2D = _aura("entropy_%d" % branch)
		check(_bus.chaos_state().entropy.size() == mini(branch + 1, 2) and aura != null and aura.visible, "actual entropy branch %d displays with at most two live sources" % branch)
		var stats: Array[String] = ["damage_multiplier_add", "range_multiplier_add", "cooldown_multiplier_add", "move_speed_multiplier_add"]
		var modifier: float = store.get_source_modifier_value("skill:chaos_passive_entropy_growth:branch:%d" % branch, stats[branch])
		check(is_equal_approx(modifier, -0.12 if branch == 2 else 0.12), "actual entropy branch %d applies its canonical gameplay modifier" % branch)
		if aura != null:
			check(int(aura._material.get_shader_parameter("branch")) == branch, "entropy ornament identifies actual branch %d" % branch)
		if branch >= 2: check(not _aura_visible("entropy_%d" % (branch - 2)), "evicted exact source immediately hides old entropy branch")
	var cooldown_source: String = "skill:chaos_passive_entropy_growth:branch:2"
	check(store.get_source_modifier_value(cooldown_source, "cooldown_multiplier_add") < 0.0 and _aura_visible("entropy_2"), "actual negative cooldown modifier displays beneficial entropy")
	store.set_timed_source(cooldown_source, [{"stat":"cooldown", "op":"multiplier_add", "value":0.12, "scope":{}, "source":"skill"}], [], 5.0)
	_view._process(0.11)
	check(not _aura_visible("entropy_2"), "positive cooldown penalty cannot display entropy benefit")
	store.set_timed_source("skill:chaos_passive_entropy_growth:branch:3", [{"stat":"move_speed", "op":"multiplier_add", "value":-0.12, "scope":{}, "source":"skill"}], [], 5.0)
	_view._process(0.11)
	check(not _aura_visible("entropy_3"), "negative exact move-speed penalty cannot display entropy benefit")
	store.set_timed_source("skill:chaos_passive_entropy_growth:branch:3", [{"stat":"move_speed", "op":"multiplier_add", "value":0.12, "scope":{}, "source":"skill"}], [], 5.0)
	_view._process(0.11)
	check(_aura_visible("entropy_3"), "restored exact beneficial live source restores actual entropy ornament")
	store.clear_source("skill:chaos_passive_entropy_growth:branch:3")
	_view._process(0.11)
	check(not _aura_visible("entropy_3"), "exact live-state source removal hides entropy immediately")
	store.tick_timed_sources(5.1)
	_bus._clock.tick(5.1)
	_bus.update_skill_cycles()
	_view._process(0.11)
	check(_bus.chaos_state().entropy.is_empty() and not _aura_visible("entropy_2") and not _aura_visible("entropy_3"), "combat-clock entropy expiry hides all remaining branches")

func _verify_counters() -> void:
	manager.clear_skills()
	_install(&"chaos_passive_anomalous_stability")
	_install(&"chaos_power_echo_cast")
	_install(&"chaos_core_chaos_singularity")
	_install(&"chaos_power_fission_burst")
	_install(&"chaos_cast_mutation_pulse")
	var context: Dictionary = _context()
	var before: Dictionary = _bus.chaos_state()
	_bus.emit_skill_event(&"skill_cast_failed", context)
	var copied: Dictionary = context.duplicate()
	copied["is_copy"] = true
	copied["can_generate_secondary_proc"] = false
	copied["proc_depth"] = 1
	_bus.emit_skill_event(&"skill_cast_succeeded", copied)
	_view._process(0.11)
	check(_bus.chaos_state() == before and not _aura_visible("stability") and not _aura_visible("echo"), "failed and copied casts cannot advance actual counters or halos")
	_bus.emit_skill_event(&"skill_cast_succeeded", context)
	_view._process(0.11)
	check(int(_bus.chaos_state().stability_count) == 1 and int(_bus.chaos_state().echo_count) == 1 and _aura_visible("stability") and _aura_visible("echo"), "successful normal cast displays real partial stability and echo counters")
	check(is_equal_approx(float(_aura("stability")._material.get_shader_parameter("charge_fraction")), 0.2) and is_equal_approx(float(_aura("echo")._material.get_shader_parameter("charge_fraction")), 0.25), "charge fractions derive from actual five and four cast thresholds")
	for index: int in range(4): _bus.emit_skill_event(&"skill_cast_succeeded", context)
	_view._process(0.11)
	check(_bus.chaos_state().stability_ready and bool(_aura("stability")._material.get_shader_parameter("ready")), "five successful normal casts show actual stability readiness")
	var target: Node2D = _enemy_at(Vector2(550, 50))
	_fission(target)
	_view._process(0.11)
	check(int(_bus.chaos_state().fissions) == 1 and _aura_visible("singularity") and is_equal_approx(float(_aura("singularity")._material.get_shader_parameter("charge_fraction")), 0.04), "one actual fission displays one-of-twenty-five singularity charge")
	before = _bus.chaos_state()
	var sources_before: Dictionary = player.get_node("ModifierStore")._sources.duplicate(true)
	var budget_before: int = _bus._frame_events
	var queue_before: int = _bus._pending_events.size()
	for frame: int in range(5): _view._process(0.11)
	check(_bus.chaos_state() == before and player.get_node("ModifierStore")._sources == sources_before and _bus._frame_events == budget_before and _bus._pending_events.size() == queue_before, "presentation refresh preserves counters modifiers and gameplay event budget")
	var bursts_before: int = _visible_count(_view._bursts)
	check(not _bus.replay_cast({}, context, 0.4) and _visible_count(_view._bursts) == bursts_before, "empty original replay cannot create false replay burst")
	_bus.clear_origin(&"chaos_passive_anomalous_stability")
	_bus.clear_origin(&"chaos_power_echo_cast")
	_view._process(0.11)
	check(not _aura_visible("stability") and not _aura_visible("echo"), "actual origin removal clears counter halos")

func _verify_swap() -> void:
	manager.clear_skills()
	_view.reset_presentation()
	var first: Node2D = _enemy_at(Vector2(120, -100))
	var second: Node2D = _enemy_at(Vector2(280, -100))
	first.apply_status(&"instability", {"duration":5.0, "stacks":3})
	second.apply_status(&"instability", {"duration":5.0, "stacks":2})
	await physics_frame
	_bus.process_pending_events()
	var a: Vector2 = first.global_position
	var b: Vector2 = second.global_position
	var result: bool = bool(_executor.execute_action({"type":"swap_targets", "params":{"targeting":"instability_stack_highest", "count":2, "area_id":"chaos_exchange_line", "radius":20.0, "damage_type":"arcane", "power_scale":0.8}}, _context(first, &"chaos_power_chaos_exchange")))
	check(result and first.global_position == b and second.global_position == a, "actual chaos exchange swaps two real target positions (%s / %s, expected %s / %s)" % [first.global_position, second.global_position, b, a])
	check(_visible_count(_view._links) == 1, "successful actual swap creates one bounded tearing thread")
	if not _view._links.is_empty():
		var thread: Node2D = _view._links[0]
		check(thread.global_position.is_equal_approx((a + b) * 0.5) and is_equal_approx(absf(thread._surface.scale.x), 80.0) and is_equal_approx(thread.global_rotation, (b - a).angle()), "swap thread follows exact actual endpoint midpoint direction and span")
	await settle(1)
	var area: Node2D = _find_area(player.get_parent(), &"chaos_exchange_line")
	check(area != null and area.global_position.is_equal_approx((a + b) * 0.5) and String(area.geometry_shape().get("shape", "")) == "circle", "exchange damage keeps actual midpoint circle footprint")
	if area != null:
		check(is_equal_approx(float(area.get("radius")), 80.0), "actual exchange radius covers half endpoint distance")
	var count_before: int = _visible_count(_view._links)
	first.set_meta("immovable", true)
	second.set_meta("immovable", true)
	check(not bool(_executor.execute_action({"type":"swap_targets", "params":{"targeting":"instability_stack_highest", "count":2}}, _context(first, &"chaos_power_chaos_exchange"))) and _visible_count(_view._links) == count_before, "failed actual swap has no false tearing thread")

func _verify_echo_replay() -> void:
	manager.clear_skills()
	_install(&"chaos_power_echo_cast")
	_install(&"chaos_cast_mutation_pulse")
	var enemy: Node2D = _enemy_at(Vector2(70, 75))
	var context: Dictionary = _context(enemy)
	_bus.emit_skill_event(&"on_cast", context)
	_bus.process_pending_events()
	await physics_frame
	check(not _bus.get_cast_snapshot().is_empty(), "successful actual pulse records original output for echo")
	var bursts_before: int = _visible_count(_view._bursts)
	for index: int in range(3):
		_bus.emit_skill_event(&"skill_cast_succeeded", context)
		_bus.process_pending_events()
	_view._process(0.11)
	check(int(_bus.chaos_state().echo_count) == 0 and _visible_count(_view._bursts) == bursts_before + 1 and not _aura_visible("echo"), "fourth successful normal cast replays real original output and clears actual echo charge")
	await settle(1)
	var copies: Array[Node2D] = []
	_collect_copied_pulses(player.get_parent(), copies)
	check(copies.size() == 1, "real echo creates exactly one copied original pulse instead of substitute orb")
	if not copies.is_empty():
		check(bool(copies[0].damage_packet.get("is_copy", false)) and not bool(copies[0].damage_packet.get("can_generate_secondary_proc", true)), "actual copied output carries secondary-proc prohibition")

func _collect_copied_pulses(parent: Node, found: Array[Node2D]) -> void:
	for child: Node in parent.get_children():
		if child is AreaEffect and child.source_id == &"mutation_pulse_area" and bool(child.damage_packet.get("is_copy", false)): found.append(child)
		_collect_copied_pulses(child, found)

func _find_area(parent: Node, id: StringName) -> Node2D:
	for child: Node in parent.get_children():
		if child is AreaEffect and child.source_id == id: return child
		var found: Node2D = _find_area(child, id)
		if found != null: return found
	return null

func _verify_pools() -> void:
	manager.clear_skills()
	_view.reset_presentation()
	for index: int in range(30):
		await physics_frame
		var enemy: Node2D = _enemy_at(Vector2(100 + index * 2, 100))
		_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"arcane"}}, _context(enemy))
		check(enemy.current_health < 10000, "pool saturation hit %d is actual damage to its live visible target" % index)
	check(_view._hits.size() == 24 and _visible_count(_view._hits) == 24, "thirty confirmed hits saturate bounded twenty-four impact nodes (%d / %d)" % [_view._hits.size(), _visible_count(_view._hits)])
	for index: int in range(16):
		_view.play_replay(player.global_position)
		_view.play_swap(player.global_position, player.global_position + Vector2(40 + index, 0))
	check(_view._bursts.size() == 12 and _view._links.size() == 12 and _visible_count(_view._bursts) == 12 and _visible_count(_view._links) == 12, "confirmed-notification burst and thread pools stop at twelve nodes each")
	var hit: Node2D = _view._hits[0]
	var material: ShaderMaterial = hit._material
	var count: int = _view.get_child_count()
	_view.reset_presentation()
	var enemy: Node2D = _enemy_at(Vector2(100, -130))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"arcane"}}, _context(enemy))
	check(_view._hits[0] == hit and hit._material == material and hit.visible and _view.get_child_count() == count, "confirmed hit reuses pooled node material and reset age")

func _verify_pause_reset() -> void:
	var hit: Node2D = _view._hits[0]
	_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	var age: float = hit.effect_age
	var counters: Dictionary = _bus.chaos_state()
	paused = true
	await settle(3)
	check(is_equal_approx(hit.effect_age, age) and _bus.chaos_state() == counters, "scene pause freezes actual feedback age and chaos resources")
	paused = false
	_bus.reset_run_state()
	check(_visible_count(_view._hits) == 0 and _visible_count(_view._bursts) == 0 and _visible_count(_view._links) == 0, "actual run reset hides every transient chaos pool")
	for key: String in _view._auras: check(not _aura_visible(key), "actual run reset hides %s aura" % key)
