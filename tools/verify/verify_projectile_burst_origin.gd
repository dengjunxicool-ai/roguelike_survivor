## Verifies hit-origin bursts emit actual radial projectiles rather than zero-direction cancellation.
extends "res://tools/verify/skill_m2_combat_fixture.gd"

const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	await process_frame
	setup()
	var skill: RefCounted = install(&"frost_cast_glacial_lance")
	var action_context: Dictionary = ctx(enemy, skill)
	var executor := Executor.new()
	var radial: Dictionary = {"type": "spawn_projectile_burst", "params": {"projectile_id": "frostburn_shards", "count": 8, "spread_angle": 360.0, "spawn_position": enemy.global_position, "spawn_offset": 0.0, "damage": 22, "speed": 420, "range": 336}}
	var result: Variant = executor.execute_action(radial, action_context)
	var projectiles := emitted()
	expect(result == true and projectiles.size() == 8, "same-point hit burst emits all eight real projectiles")
	var octants: Dictionary = {}
	for projectile: Node2D in projectiles:
		var direction: Vector2 = projectile.get("direction")
		var degrees: int = posmod(roundi(rad_to_deg(direction.angle())), 360)
		octants[degrees] = true
		expect(projectile.global_position.is_equal_approx(enemy.global_position), "hit-origin burst retains its specified origin")
		expect(direction.is_normalized(), "each emitted projectile has a usable unit direction")
	expect(octants.size() == 8, "360-degree burst covers eight distinct directions instead of stacking one ray")
	for degrees: int in [0, 45, 90, 135, 180, 225, 270, 315]:
		expect(octants.has(degrees), "radial burst covers literal %d-degree octant" % degrees)
	expect(action_context.get("position") == Vector2(30, 0) and action_context.get("target") == enemy and action_context.get("caster") == player, "burst launch preserves caller hit position and source/target identities")
	clear_projectiles()
	var ordinary: Dictionary = {"type": "spawn_projectile", "params": {"projectile_id": "ice_shard_projectile", "count": 3, "spread_angle": 10.0, "spawn_offset": 0.0, "damage": 10, "speed": 420, "range": 336}}
	result = executor.execute_action(ordinary, ctx(enemy, skill))
	projectiles = emitted()
	var fan_angles: Array[int] = []
	for projectile: Node2D in projectiles:
		var direction: Vector2 = projectile.get("direction")
		fan_angles.append(roundi(rad_to_deg(direction.angle())))
	fan_angles.sort()
	expect(result == true and fan_angles == [-10, 0, 10], "ordinary spread retains its per-projectile spacing")
	clear_projectiles()
	var colocated: Dictionary = ctx(enemy, skill)
	player.global_position = enemy.global_position
	result = executor.execute_action(radial, colocated)
	expect(result == true and emitted().size() == 8, "radial burst still works when caster and target also coincide")
	clear_projectiles()
	finish()

func emitted() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node: Node in root.get_children():
		if node.get_script() == Projectile and not node.is_queued_for_deletion():
			result.append(node)
	return result

func clear_projectiles() -> void:
	for node: Node2D in emitted():
		node.free()
