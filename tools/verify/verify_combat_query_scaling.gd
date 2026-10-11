extends SceneTree

const Targeting = preload("res://scripts/skills/targeting_service.gd")

class Target extends Node2D:
	signal health_changed(current: int, maximum: int)
	signal died
	var current_health := 100:
		set(value):
			current_health = value
			health_changed.emit(value, 100)
	var _is_dead := false:
		set(value):
			_is_dead = value
			if value: died.emit()
	var statuses: Dictionary = {}
	func is_dead() -> bool: return _is_dead
	func get_runtime_state() -> String: return "dead" if _is_dead else "idle"
	func has_status(id: StringName) -> bool: return statuses.has(id)

class CountingRegistry extends "res://scripts/combat/combat_target_registry.gd":
	var visits := 0
	func _is_live_target(target: Node) -> bool:
		visits += 1
		return super._is_live_target(target)

var registry: CountingRegistry
var targets: Array[Target] = []
var failed := false

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: " + message)

func _add(position: Vector2, observable: bool = true) -> Target:
	var target := Target.new()
	root.add_child(target)
	target.position = position
	if observable: target.set_meta(&"combat_query_cache_safe", true)
	registry.register_enemy(target)
	targets.append(target)
	return target

func _clear() -> void:
	for target: Target in targets:
		registry.unregister_enemy(target)
		target.free()
	targets.clear()

func _run() -> void:
	registry = CountingRegistry.new()
	registry.name = "CombatTargetRegistry"
	root.add_child(registry)
	var caster := Node2D.new()
	root.add_child(caster)
	# Reintroducing a full scan per local query fails this work budget, without
	# relying on timing differences between machines.
	for count: int in [100, 200, 400]:
		for i: int in range(count):
			_add(Vector2((i % 40) * 300.0, floori(float(i) / 40.0) * 300.0))
		await physics_frame
		registry.get_targets_in_radius(Vector2.ZERO, 64.0)
		registry.visits = 0
		for i: int in range(16):
			_expect(registry.get_targets_in_radius(Vector2.ZERO, 64.0) == [targets[0]], "local query returns exactly the nearby target")
		_expect(registry.visits <= 64, "warm local queries must not validate the entire population: N=%d visits=%d" % [count, registry.visits])
		registry.visits = 0
		_expect(Targeting.find_target(caster, "densest_enemy_cluster", {"cluster_radius": 64.0}) == targets[0], "equal density selects the nearest target")
		_expect(registry.visits <= count * 4, "density selection must not repeatedly validate the entire population: N=%d visits=%d" % [count, registry.visits])
		_clear()
	# Small-query insertion order and exact radius boundary are observable by
	# consumers including random selection and limited target counts.
	var far := _add(Vector2(30, 0))
	var near := _add(Vector2(5, 0))
	var edge := _add(Vector2(-32, 0))
	_expect(registry.get_targets_in_radius(Vector2.ZERO, 32.0) == [far, near, edge], "small radius query preserves registration order and boundary")
	_expect(registry.get_targets_in_radius(Vector2.ZERO, 32.0, &"enemy", 1) == [near], "alias query with a limit selects the closest target")
	_expect(registry.get_targets_in_radius(Vector2.ZERO, 0.0).is_empty(), "nonpositive radius remains empty")
	_clear()
	var left := _add(Vector2(-129, 0))
	var middle := _add(Vector2(-1, 0))
	var right := _add(Vector2(127, 0))
	for i: int in range(100): _add(Vector2(10000 + i * 300, 10000))
	await physics_frame
	_expect(registry.get_targets_in_radius(Vector2.ZERO, 130.0) == [left, middle, right], "grid query handles negative cells and preserves bucket order")
	right._is_dead = true
	_expect(registry.get_targets_in_radius(Vector2.ZERO, 130.0) == [left, middle], "cached buckets reject newly dead targets")
	var added := _add(Vector2(10, 0))
	_expect(registry.get_targets_in_radius(Vector2.ZERO, 130.0).has(added), "same-frame registration invalidates the grid")
	registry.unregister_enemy(added)
	_expect(not registry.get_targets_in_radius(Vector2.ZERO, 130.0).has(added), "same-frame removal invalidates the grid")
	var freed := _add(Vector2(15, 0))
	registry.get_targets_in_radius(Vector2.ZERO, 130.0)
	targets.erase(freed)
	freed.free()
	_expect(registry.get_targets_in_radius(Vector2.ZERO, 130.0) == [left, middle], "cached weak references safely reject freed nodes")
	left.position = Vector2(700, 0)
	await physics_frame
	_expect(registry.get_targets_in_radius(Vector2(700, 0), 10.0) == [left], "next physics frame rebuilds positions")
	_clear()
	# Silent state changes on generic targets must keep the original 96 -> 95
	# order transition; equal-distance nearest selection depends on it.
	var registered_first := _add(Vector2(10, 0), false)
	_add(Vector2(-10, 0), false)
	for i: int in range(94): _add(Vector2(10000 + i * 300, 10000), false)
	registry.get_targets_in_radius(Vector2.ZERO, 20.0)
	targets[95]._is_dead = true
	_expect(registry.find_nearest(Vector2.ZERO, 20.0) == registered_first, "silent death across grid threshold restores registration-order tie breaking")
	_clear()
	var observable_first := _add(Vector2(10, 0))
	_add(Vector2(-10, 0))
	for i: int in range(94): _add(Vector2(10000 + i * 300, 10000))
	registry.get_targets_in_radius(Vector2.ZERO, 20.0)
	targets[95].current_health = 0
	_expect(registry.find_nearest(Vector2.ZERO, 20.0) == observable_first, "health signal invalidates eligibility before same-frame selection")
	_clear()
	var mixed_first := _add(Vector2(10, 0))
	_add(Vector2(-10, 0))
	for i: int in range(93): _add(Vector2(10000 + i * 300, 10000))
	var generic := _add(Vector2(50000, 50000), false)
	registry.get_targets_in_radius(Vector2.ZERO, 20.0)
	# Metadata changes emit no lifecycle signal, even on this fake target.
	generic.set_meta("spawn_reveal_pending", true)
	_expect(registry.find_nearest(Vector2.ZERO, 20.0) == mixed_first, "mixed populations retain silent visibility-change semantics")
	generic.set_meta("spawn_reveal_pending", false)
	registry.get_targets_in_radius(Vector2.ZERO, 20.0)
	generic.queue_free()
	targets.erase(generic)
	_expect(registry.find_nearest(Vector2.ZERO, 20.0) == mixed_first, "queued generic targets immediately restore small-population ordering")
	_clear()
	await process_frame
	var reveal_first := _add(Vector2(10, 0))
	_add(Vector2(-10, 0))
	for i: int in range(94): _add(Vector2(10000 + i * 300, 10000))
	var revealing: Target = targets[95]
	revealing.set_meta("spawn_reveal_pending", true)
	registry.get_targets_in_radius(Vector2.ZERO, 20.0)
	_expect(registry.find_nearest(Vector2.ZERO, 20.0) == reveal_first, "pending reveal uses small-population order")
	revealing.set_meta("spawn_reveal_pending", false)
	registry.register_enemy(revealing)
	registry.register_enemy(revealing)
	_expect(registry.find_nearest(Vector2.ZERO, 20.0) == targets[1], "reveal immediately restores legacy large-population bucket order")
	var nested_selection: Array = []
	revealing.health_changed.connect(func(_current: int, _maximum: int) -> void:
		nested_selection.append(registry.find_nearest(Vector2.ZERO, 20.0)))
	revealing.current_health = 0
	_expect(nested_selection == [reveal_first], "synchronous health listeners see updated eligibility")
	_clear()
	for i: int in range(100): _add(Vector2(i * 300, 0))
	var temporary_generic := _add(Vector2(50000, 0), false)
	registry.unregister_enemy(temporary_generic)
	registry.get_targets_in_radius(Vector2.ZERO, 20.0)
	registry.visits = 0
	for i: int in range(16): registry.get_targets_in_radius(Vector2.ZERO, 20.0)
	_expect(registry.visits <= 64, "removing the generic target restores efficient cached queries")
	_clear()
	var a := _add(Vector2(0, 0))
	var b := _add(Vector2(20, 0))
	var c := _add(Vector2(40, 0))
	var d := _add(Vector2(500, 0))
	_add(Vector2(520, 0))
	d.statuses[&"conductive"] = true
	_expect(Targeting.find_target(caster, "densest_enemy_cluster", {"cluster_radius": 25.0}) == b, "densest center counts every eligible neighbor")
	_expect(Targeting.find_target(caster, "densest_conductive_or_enemy_cluster", {"cluster_radius": 25.0}) == d, "conductive priority remains stronger than raw density")
	c.set_meta("spawn_reveal_pending", true)
	_expect(Targeting.find_target(caster, "densest_enemy_cluster", {"cluster_radius": 25.0}) == a, "hidden targets do not influence density")
	a.current_health = 0
	_expect(Targeting.find_target(caster, "densest_enemy_cluster", {"cluster_radius": 25.0}) == d, "zero-health targets do not influence density")
	_expect(Targeting.find_target(caster, "densest_enemy_cluster", {"cluster_radius": 25.0, "range": 10.0}) == null, "cast range still restricts candidate centers")
	c.set_meta("spawn_reveal_pending", false)
	_expect(Targeting.find_target(caster, "densest_enemy_cluster", {"cluster_radius": 25.0}) == b, "revealed targets immediately participate in the next selection")
	_expect(Targeting.find_target(caster, "densest_enemy_cluster", {"cluster_radius": 0.0}) == b, "zero cluster radius retains nearest-center selection")
	var origin := Node2D.new()
	root.add_child(origin)
	origin.position = Vector2(500, 0)
	_expect(Targeting.find_target(caster, "densest_enemy_cluster", {"cluster_radius": 25.0, "origin": origin, "range": 30.0}) == d, "explicit origin restricts centers but not their neighbors")
	origin.free()
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	await process_frame
	_expect(Targeting.find_target(caster, "densest_conductive_or_enemy_cluster", {"cluster_radius": 25.0}) == b, "offscreen targets remain excluded from density and priority")
	camera.free()
	_clear()
	print("[verify_combat_query_scaling] " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
