extends SceneTree


const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")


class TestEnemy:
	extends Node2D

	signal health_changed(current_health: int, max_health: int)

	var enemy_id: StringName = &"homing_sweep_target"
	var max_health: int = 100
	var current_health: int = 100
	var armor: int = 0
	var defense: int = 0
	var resistances: Dictionary = {}
	var damage_taken_multiplier: float = 1.0
	var _is_dead: bool = false
	var _reward_controller: Node = null
	var last_damage_amount: int = 0

	func take_damage(amount_or_packet: Variant, damage_type: Variant = &"") -> void:
		DamageApplicationServiceScript.apply_enemy_damage(self, amount_or_packet, damage_type)

	func _apply_damage_synergies(amount: int, _damage_type: Variant) -> int:
		return amount

	func _record_damage_done(amount: int, _damage_result: Dictionary, _source_packet: Variant) -> void:
		last_damage_amount = amount

	func _show_debug_damage_number(_amount: int, _damage_result: Dictionary) -> void:
		pass

	func _update_debug_health_display() -> void:
		pass

	func _get_damage_source_key(_source_packet: Variant, _damage_result: Dictionary) -> String:
		return "homing_sweep_projectile"

	func _die() -> void:
		pass


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var target: TestEnemy = TestEnemy.new()
	target.global_position = Vector2(80.0, 8.0)
	target.add_to_group(&"enemies")
	root.add_child(target)

	var projectile: Node2D = ProjectileScript.new() as Node2D
	projectile.global_position = Vector2.ZERO
	root.add_child(projectile)
	projectile.call("setup", {
		"damage": 12,
		"damage_type": &"direct_magical",
		"direction": Vector2.RIGHT,
		"speed": 420.0,
		"lifetime": 1.0,
		"pierce": 0,
		"radius": 10.0,
		"target_group": &"enemies",
		"source_id": &"mars_spark_missile_projectile",
		"homing_enabled": true,
		"homing_turn_rate": 8.5,
		"homing_seek_range": 620.0
	})

	projectile.call("_physics_process", 0.24)

	_expect(target.current_health < target.max_health, "homing projectile resolves a swept hit when it crosses near the enemy")
	_expect(target.last_damage_amount > 0, "swept homing hit applies projectile damage")
	_expect(projectile.global_position.distance_to(target.global_position) <= 12.0, "homing projectile impact point is on the enemy")

	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		_failed = true
		push_error("[FAIL] %s" % message)
