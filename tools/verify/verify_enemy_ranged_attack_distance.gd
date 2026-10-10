extends SceneTree

var _failed: bool = false

class DamageTarget:
	extends Node2D
	var received_hits: int = 0
	func take_damage(_packet: DamagePacket) -> void:
		received_hits += 1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var player := DamageTarget.new()
	player.add_to_group(&"player")
	owner.add_child(player)
	var scene: PackedScene = load("res://scenes/enemies/enemy.tscn")
	var enemy: CharacterBody2D = scene.instantiate()
	enemy.set("enemy_id", &"archer_skeleton")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	owner.add_child(enemy)
	enemy.set("target", player)
	var controller: RefCounted = enemy.get("_behavior_controller")
	enemy.position = Vector2(300, 0)
	enemy.call("_apply_contact_damage")
	_expect(player.received_hits == 0, "ranged distance causes no direct contact damage")
	controller.call("tick", 0.01)
	_expect(enemy.velocity == Vector2.ZERO, "archer stops at ranged distance")
	_expect(float(enemy.get("_ranged_warning_timer")) > 0.0, "archer starts warning without approaching melee range")
	_expect(get_nodes_in_group(&"enemy_projectile").is_empty(), "warning precedes the projectile")
	for _index: int in range(5):
		controller.call("tick", 0.1)
	await process_frame
	_expect(get_nodes_in_group(&"enemy_projectile").size() == 1, "completed warning fires a real arrow from ranged distance")
	controller.call("tick", 0.1)
	_expect(get_nodes_in_group(&"enemy_projectile").size() == 1, "cooldown prevents repeated arrows")
	enemy.set("_shoot_cooldown", 0.0)
	enemy.position = Vector2(420, 0)
	controller.call("tick", 0.01)
	_expect(enemy.velocity == Vector2.ZERO and float(enemy.get("_ranged_warning_timer")) > 0.0, "archer can attack at the displayed range boundary")
	enemy.position = Vector2(461, 0)
	controller.call("tick", 0.1)
	_expect(enemy.velocity.x < 0.0 and is_zero_approx(float(enemy.get("_ranged_warning_timer"))), "outside range archer cancels warning and approaches")
	_expect(get_nodes_in_group(&"enemy_projectile").size() == 1, "cancelled warning fires no extra arrow")
	enemy.position = Vector2(300, 0)
	controller.call("tick", 0.01)
	_expect(float(enemy.get("_ranged_warning_timer")) > 0.0, "reentering ranged distance restarts warning")
	enemy.position = Vector2(32, 0)
	enemy.set("_damage_cooldown", 0.0)
	enemy.call("_apply_contact_damage")
	_expect(player.received_hits == 1, "close contact still damages the player")
	owner.queue_free()
	await process_frame
	print("[EnemyRangedAttackDistance] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[EnemyRangedAttackDistance] PASS " + message)
	else:
		_failed = true
		push_error("[EnemyRangedAttackDistance] FAIL " + message)
