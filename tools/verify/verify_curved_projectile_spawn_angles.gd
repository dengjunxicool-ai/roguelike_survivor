extends SceneTree


const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")


class TestCaster:
	extends Node2D

	var damage_multiplier: float = 1.0
	var attack_speed_multiplier: float = 1.0
	var skill_area_multiplier: float = 1.0
	var status_duration_multiplier: float = 1.0
	var crit_chance: float = 0.0
	var crit_damage: float = 1.5


class TestTarget:
	extends Node2D


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster: TestCaster = TestCaster.new()
	caster.global_position = Vector2.ZERO
	root.add_child(caster)
	var target: TestTarget = TestTarget.new()
	target.global_position = Vector2(240.0, 0.0)
	root.add_child(target)

	var executor: RefCounted = SkillActionExecutorScript.new()
	var ok: bool = bool(executor.call("execute_action", {
		"type": "spawn_projectile",
		"params": {
			"projectile_id": &"angle_curve_test_projectile",
			"count": 3,
			"speed": 360.0,
			"spread_angle": 30.0,
			"trajectory_mode": "curve",
			"curve_height": 72.0,
			"spawn_offset": 34.0,
			"damage": 1,
			"damage_type": &"direct_magical",
			"uses_skill_level_coefficient": false
		}
	}, {
		"caster": caster,
		"target": target,
		"parent": root,
		"target_group": &"enemies"
	}))
	_expect(ok, "curved projectile action executes")
	await process_frame

	var projectiles: Array[Node2D] = _projectiles_for_source(&"angle_curve_test_projectile")
	_expect(projectiles.size() == 3, "curved projectile action spawns three projectiles")
	_expect(_distinct_position_count(projectiles) >= 3, "curved spread projectiles start from distinct launch angles")
	for projectile: Node2D in projectiles:
		_expect(projectile.global_position.distance_to(caster.global_position) >= 20.0, "curved projectile starts away from caster center")

	quit(1 if _failed else 0)


func _projectiles_for_source(source_id: StringName) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child: Node in root.get_children():
		var node: Node2D = child as Node2D
		if node == null or not ("source_id" in node):
			continue
		if StringName(node.get("source_id")) == source_id:
			result.append(node)
	return result


func _distinct_position_count(nodes: Array[Node2D]) -> int:
	var buckets: Dictionary = {}
	for node: Node2D in nodes:
		var key: String = "%d:%d" % [roundi(node.global_position.x), roundi(node.global_position.y)]
		buckets[key] = true
	return buckets.size()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		_failed = true
		push_error("[FAIL] %s" % message)
