extends SceneTree


const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")
const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")


class TestCaster:
	extends Node2D

	var attack_power: float = 100.0
	var damage_multiplier: float = 1.0
	var attack_speed_multiplier: float = 1.0
	var skill_area_multiplier: float = 1.0
	var status_duration_multiplier: float = 1.0
	var crit_chance: float = 0.0
	var crit_damage: float = 1.5


class TestTarget:
	extends Node2D

	var damage_packets: Array[Dictionary] = []
	var damage_results: Array[Dictionary] = []
	var status_applications: Array[StringName] = []
	var armor: float = 0.0
	var defense: float = 0.0
	var resistances: Dictionary = {}
	var damage_taken_multiplier: float = 1.0

	func _init() -> void:
		add_to_group(&"enemies")

	func take_damage(packet: Dictionary, _damage_type: Variant = &"") -> void:
		damage_packets.append(packet.duplicate(true))
		damage_results.append(DamageSystemScript.calculate(packet, self))

	func apply_status(status_id: StringName, _params: Dictionary = {}) -> bool:
		status_applications.append(status_id)
		return true


class TestEventBus:
	extends Node

	var executor: RefCounted = SkillActionExecutorScript.new()

	func emit_skill_event(_event_name: StringName, _event_context: Dictionary = {}) -> Array:
		return []

	func execute_adapted_actions(actions: Array, context: Dictionary = {}) -> void:
		executor.call("execute_actions", actions, context)


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_single_target_decay()
	await _verify_distinct_target_priority()
	quit(1 if _failed else 0)


func _verify_single_target_decay() -> void:
	var caster: TestCaster = TestCaster.new()
	caster.global_position = Vector2.ZERO
	root.add_child(caster)
	var target: TestTarget = TestTarget.new()
	target.global_position = Vector2(240.0, 0.0)
	root.add_child(target)
	_register_enemy(target)
	var event_bus: TestEventBus = TestEventBus.new()
	root.add_child(event_bus)

	var executor: RefCounted = SkillActionExecutorScript.new()
	var ok: bool = bool(executor.call("execute_action", {
		"type": "spawn_projectiles_at_targets",
		"params": _meteor_params()
	}, {
		"caster": caster,
		"parent": root,
		"target_group": &"enemies",
		"skill_id": &"fire_cast_meteor_rain",
		"event_bus": event_bus
	}))
	_expect(ok, "meteor rain projectile burst action executes")
	await process_frame

	var projectiles: Array[Node2D] = _projectiles_for_source(&"meteor_rain_meteor")
	_expect(projectiles.size() == 1, "single-target meteor rain starts with one immediate meteor actual=%s" % projectiles.size())
	await create_timer(0.27).timeout
	projectiles = _projectiles_for_source(&"meteor_rain_meteor")
	_expect(projectiles.size() == 2, "single-target meteor rain drops second meteor after delay actual=%s" % projectiles.size())
	await create_timer(0.27).timeout
	projectiles = _projectiles_for_source(&"meteor_rain_meteor")
	_expect(projectiles.size() == 3, "single-target meteor rain drops third meteor after delay actual=%s" % projectiles.size())
	for index in range(projectiles.size()):
		var projectile: Node2D = projectiles[index]
		var actions: Array = projectile.get("actions_on_hit")
		_expect(_has_damage_action(actions, 2.2), "meteor projectile carries 2.2P impact damage action")
		if index == 0:
			_expect(_has_status_action(actions, &"burning"), "first meteor applies Burning on impact")
			_expect(_has_area_action(actions, &"meteor_burning_ground"), "first meteor spawns burning ground after impact")
		else:
			_expect(not _has_status_action(actions, &"burning"), "repeated same-target meteor does not apply Burning")
			_expect(not _has_area_action(actions, &"meteor_burning_ground"), "repeated same-target meteor does not spawn burning ground")
		projectile.call("_on_body_entered", target)

	_expect(target.damage_packets.size() == 3, "three meteor impacts each apply direct impact damage")
	var expected_amounts: Array[int] = [220, 110, 55]
	for index in range(mini(target.damage_results.size(), expected_amounts.size())):
		var packet: Dictionary = target.damage_packets[index]
		var result: Dictionary = target.damage_results[index]
		_expect(int(result.get("amount", 0)) == expected_amounts[index], "repeated meteor impact damage follows 100/50/25 sequence")
		_expect(StringName(String(packet.get("damage_origin", ""))) == &"field", "meteor impact uses field damage origin actual=%s" % String(packet.get("damage_origin", "")))
		_expect(StringName(String(packet.get("source_type", ""))) == &"cast", "meteor impact preserves cast source_type actual=%s" % String(packet.get("source_type", "")))
	_expect(target.status_applications.size() == 1 and target.status_applications.has(&"burning"), "only first same-target meteor applies Burning before ground ticks")

	_cleanup_projectiles()
	_unregister_enemy(target)
	caster.queue_free()
	target.queue_free()
	event_bus.queue_free()
	await process_frame


func _verify_distinct_target_priority() -> void:
	var caster: TestCaster = TestCaster.new()
	caster.global_position = Vector2.ZERO
	root.add_child(caster)
	var targets: Array[TestTarget] = []
	for index in range(3):
		var target: TestTarget = TestTarget.new()
		target.global_position = Vector2(180.0 + float(index) * 220.0, 0.0)
		root.add_child(target)
		_register_enemy(target)
		targets.append(target)
	var event_bus: TestEventBus = TestEventBus.new()
	root.add_child(event_bus)

	var executor: RefCounted = SkillActionExecutorScript.new()
	var ok: bool = bool(executor.call("execute_action", {
		"type": "spawn_projectiles_at_targets",
		"params": _meteor_params()
	}, {
		"caster": caster,
		"parent": root,
		"target_group": &"enemies",
		"skill_id": &"fire_cast_meteor_rain",
		"event_bus": event_bus
	}))
	_expect(ok, "meteor rain chooses targets when multiple enemies exist")
	await process_frame

	var projectiles: Array[Node2D] = _projectiles_for_source(&"meteor_rain_meteor")
	_expect(projectiles.size() == 3, "meteor rain still launches three meteors at multiple targets actual=%s" % projectiles.size())
	for index in range(mini(projectiles.size(), targets.size())):
		projectiles[index].call("_on_body_entered", targets[index])

	for target: TestTarget in targets:
		_expect(target.damage_packets.size() == 1, "meteor rain prioritizes different targets before repeats")
		if not target.damage_results.is_empty():
			_expect(int(target.damage_results[0].get("amount", 0)) == 220, "first meteor hit on each target keeps full 2.2P")

	_cleanup_projectiles()
	caster.queue_free()
	for target: TestTarget in targets:
		_unregister_enemy(target)
		target.queue_free()
	event_bus.queue_free()
	await process_frame


func _meteor_params() -> Dictionary:
	return {
		"projectile_id": "meteor_rain_meteor",
		"count": 3,
		"collision_radius": 18.0,
		"trajectory_mode": "linear",
		"speed": 640.0,
		"visual_start_relative_to": "target",
		"visual_start_offset": [-360.0, -360.0],
		"damage_multiplier_sequence": [1.0, 0.5, 0.25],
		"same_target_spawn_delay": 0.25,
		"same_target_repeat_damage_only": true,
		"on_hit": [
			{
				"type": "damage",
				"damage_type": "fire",
				"source_type": "cast",
				"power_scale": 2.2,
				"radius": 134.4
			},
			{
				"type": "apply_status",
				"status": "burning",
				"stacks": 1,
				"duration": 4.0
			},
			{
				"type": "spawn_area",
				"area_id": "meteor_burning_ground",
				"radius": 134.4,
				"duration": 3.0,
				"tick_interval": 1.0,
				"effects_on_tick": [
					{
						"type": "damage",
						"damage_type": "fire",
						"source_type": "area",
						"power_scale": 0.28
					}
				]
			}
		]
	}


func _projectiles_for_source(source_id: StringName) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child: Node in root.get_children():
		var node: Node2D = child as Node2D
		if node == null or not ("source_id" in node):
			continue
		if StringName(node.get("source_id")) == source_id:
			result.append(node)
	return result


func _cleanup_projectiles() -> void:
	for projectile: Node2D in _projectiles_for_source(&"meteor_rain_meteor"):
		projectile.queue_free()


func _register_enemy(target: Node) -> void:
	var registry: Node = CombatTargetRegistryScript.get_or_create(root)
	if registry != null and registry.has_method("register_target"):
		registry.call("register_target", target, &"enemies")


func _unregister_enemy(target: Node) -> void:
	var registry: Node = CombatTargetRegistryScript.get_or_create(root)
	if registry != null and registry.has_method("unregister_target"):
		registry.call("unregister_target", target, &"enemies")


func _has_damage_action(actions: Array, expected_scale: float) -> bool:
	for action_variant: Variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if String(action.get("type", "")) != "deal_damage":
			continue
		var params: Dictionary = action.get("params", {})
		var amount: Dictionary = params.get("amount", {})
		if String(amount.get("stat", "")) == "power" and absf(float(amount.get("scale", 0.0)) - expected_scale) <= 0.0001:
			return true
	return false


func _has_status_action(actions: Array, status_id: StringName) -> bool:
	for action_variant: Variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if String(action.get("type", "")) != "apply_status":
			continue
		var params: Dictionary = action.get("params", {})
		if StringName(String(params.get("status_id", ""))) == status_id:
			return true
	return false


func _has_area_action(actions: Array, area_id: StringName) -> bool:
	for action_variant: Variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if String(action.get("type", "")) != "spawn_area":
			continue
		var params: Dictionary = action.get("params", {})
		if StringName(String(params.get("area_id", ""))) == area_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		_failed = true
		push_error("[FAIL] %s" % message)
