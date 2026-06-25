extends SceneTree

const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")


class PhysicsSpawnRunner:
	extends Node2D

	var spawned_projectile: Node2D

	func _physics_process(_delta: float) -> void:
		set_physics_process(false)
		spawned_projectile = CombatObjectFactoryScript.create_projectile({
			"parent": self,
			"position": Vector2(24, 0),
			"direction": Vector2.RIGHT,
			"damage": 1,
			"speed": 100.0
		})
		call_deferred("_finish")

	func _finish() -> void:
		if spawned_projectile == null:
			push_error("Projectile factory returned null during physics frame.")
			get_tree().quit(1)
			return
		if spawned_projectile.get_parent() != self:
			push_error("Projectile was not added through deferred add_child during physics frame.")
			get_tree().quit(1)
			return
		print("verify_projectile_factory_physics_frame: PASS")
		get_tree().quit(0)


func _init() -> void:
	var runner: PhysicsSpawnRunner = PhysicsSpawnRunner.new()
	root.add_child(runner)
