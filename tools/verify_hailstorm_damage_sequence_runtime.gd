extends SceneTree


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")


class TestCaster:
	extends Node2D

	var damage_multiplier: float = 1.08
	var attack_speed_multiplier: float = 1.0
	var skill_area_multiplier: float = 1.0
	var status_duration_multiplier: float = 1.0
	var crit_chance: float = 0.0
	var crit_damage: float = 1.5
	var selected_weapon_id: StringName = &"frost_staff"


class TestEnemy:
	extends Node2D

	var defense: int = 0
	var armor: int = 0
	var resistances: Dictionary = {}
	var damage_taken_multiplier: float = 1.0


var _failed: bool = false
var _lines: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_three_targets_no_decay()
	_clear_runtime_nodes()
	_verify_single_target_same_target_decay()
	_clear_runtime_nodes()
	_verify_lv4_single_target_decay_override()
	_write_result()
	quit(1 if _failed else 0)


func _verify_three_targets_no_decay() -> void:
	var caster: TestCaster = _add_caster()
	var enemies: Array[Node] = []
	for index: int in range(3):
		enemies.append(_add_enemy(Vector2(120 + index * 32, 40 + index * 24)))

	var spawned: bool = _spawn_hailstorm(caster)
	_expect(spawned, "Hailstorm spawns target-selected projectiles")
	var projectiles: Array[Node] = _hail_projectiles()
	_expect(projectiles.size() == 3, "Hailstorm creates three projectiles for three targets")
	_assert_projectiles(projectiles, enemies, [1.0, 1.0, 1.0], [11, 11, 11], "different-target")


func _verify_single_target_same_target_decay() -> void:
	var caster: TestCaster = _add_caster()
	var enemy: Node = _add_enemy(Vector2(120, 40))
	var spawned: bool = _spawn_hailstorm(caster)
	_expect(spawned, "Hailstorm spawns against a single target")
	var projectiles: Array[Node] = _hail_projectiles()
	_expect(projectiles.size() == 3, "Hailstorm still creates three projectiles for one target")
	_assert_projectiles(projectiles, [enemy, enemy, enemy], [1.0, 0.7, 0.5], [11, 8, 5], "same-target")
	if projectiles.size() >= 3:
		var first_start_position: Vector2 = projectiles[0].get("_curve_start_position")
		var second_start_position: Vector2 = projectiles[1].get("_curve_start_position")
		var third_start_position: Vector2 = projectiles[2].get("_curve_start_position")
		var first_target_position: Vector2 = projectiles[0].get("_curve_target_position")
		var second_target_position: Vector2 = projectiles[1].get("_curve_target_position")
		var third_target_position: Vector2 = projectiles[2].get("_curve_target_position")
		_expect(first_start_position.distance_to(second_start_position) > 1.0, "Hailstorm same-target projectile 2 uses a distinct curve start")
		_expect(first_start_position.distance_to(third_start_position) > 1.0, "Hailstorm same-target projectile 3 uses a distinct curve start")
		_expect(second_start_position.distance_to(third_start_position) > 1.0, "Hailstorm repeated same-target starts do not overlap")
		_expect(first_target_position.distance_to(second_target_position) > 1.0, "Hailstorm same-target projectile 2 uses a distinct curve endpoint")
		_expect(first_target_position.distance_to(third_target_position) > 1.0, "Hailstorm same-target projectile 3 uses a distinct curve endpoint")
		_expect(second_target_position.distance_to(third_target_position) > 1.0, "Hailstorm repeated same-target endpoints do not overlap")


func _verify_lv4_single_target_decay_override() -> void:
	var caster: TestCaster = _add_caster()
	var enemy: Node = _add_enemy(Vector2(120, 40))
	var skill_instance: RefCounted = _create_skill_instance({
		"hail_same_target_decay": {
			"second_hit_multiplier": 0.8,
			"third_hit_multiplier": 0.6
		}
	})
	var spawned: bool = _spawn_hailstorm(caster, skill_instance)
	_expect(spawned, "Hailstorm Lv4 spawns against a single target")
	var projectiles: Array[Node] = _hail_projectiles()
	_expect(projectiles.size() == 3, "Hailstorm Lv4 still creates three projectiles for one target")
	_assert_projectiles(projectiles, [enemy, enemy, enemy], [1.0, 0.8, 0.6], [11, 9, 6], "lv4 same-target")


func _spawn_hailstorm(caster: Node, skill_instance: RefCounted = null) -> bool:
	var executor: RefCounted = SkillActionExecutorScript.new()
	var action: Dictionary = {
		"type": "spawn_projectiles_at_targets",
		"params": {
			"projectile_id": "hailstorm_projectile",
			"count": 3,
			"range": 540,
			"targeting_mode": "around_player",
			"speed": 420,
			"trajectory_mode": "curve",
			"curve_height": 72,
			"lifetime": 2,
			"collision_radius": 10,
			"damage": 10,
			"damage_origin": "primary_attack",
			"damage_type": "direct_magical",
			"element": "ice",
			"uses_skill_level_coefficient": false,
			"damage_multiplier_sequence": [1.0, 0.7, 0.5]
		}
	}
	return bool(executor.call("execute_action", action, {
		"caster": caster,
		"skill_instance": skill_instance,
		"skill_id": &"hailstorm",
		"source_weapon_id": &"frost_staff",
		"target_group": &"enemies"
	}))


func _create_skill_instance(runtime_special_rules: Dictionary) -> RefCounted:
	var skill_instance: RefCounted = SkillInstanceScript.new(SkillDefinitionScript.new({
		"id": "hailstorm",
		"category": "active",
		"base": {
			"damage": 10
		}
	}))
	skill_instance.set("runtime_special_rules", runtime_special_rules)
	return skill_instance


func _assert_projectiles(projectiles: Array[Node], enemies: Array[Node], expected_multipliers: Array[float], expected_amounts: Array[int], label: String) -> void:
	for index: int in range(mini(projectiles.size(), expected_multipliers.size())):
		var projectile: Node = projectiles[index]
		var packet: Dictionary = projectile.get("damage_packet")
		var multiplier: float = float(packet.get("special_final_modifier", 1.0))
		_expect(_approx(multiplier, expected_multipliers[index]), "Hailstorm %s projectile %d stores multiplier" % [label, index + 1])
		if index < enemies.size():
			_expect(String(packet.get("target_id", "")) == str(enemies[index].get_instance_id()), "Hailstorm %s projectile %d targets expected enemy" % [label, index + 1])
		var result: Dictionary = DamageSystemScript.calculate(packet, enemies[index], &"", projectile.get("caster") as Node)
		_expect(int(result.get("amount", -1)) == expected_amounts[index], "Hailstorm %s projectile %d final damage" % [label, index + 1])


func _hail_projectiles() -> Array[Node]:
	var projectiles: Array[Node] = []
	for child: Node in root.get_children():
		if child.get("source_id") == &"hailstorm_projectile":
			projectiles.append(child)
	return projectiles


func _add_caster() -> TestCaster:
	var caster: TestCaster = TestCaster.new()
	caster.global_position = Vector2.ZERO
	root.add_child(caster)
	return caster


func _add_enemy(position: Vector2) -> TestEnemy:
	var enemy: TestEnemy = TestEnemy.new()
	enemy.global_position = position
	enemy.add_to_group(&"enemies")
	root.add_child(enemy)
	return enemy


func _clear_runtime_nodes() -> void:
	for child: Node in root.get_children():
		if child is TestCaster or child is TestEnemy or child.get("source_id") == &"hailstorm_projectile":
			child.free()


func _approx(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return absf(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if condition:
		_lines.append("[PASS] " + message)
	else:
		_failed = true
		_lines.append("[FAIL] " + message)


func _write_result() -> void:
	var output: String = "\n".join(_lines)
	print(output)
	var file: FileAccess = FileAccess.open("res://tools/verify_hailstorm_damage_sequence_runtime.out.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
