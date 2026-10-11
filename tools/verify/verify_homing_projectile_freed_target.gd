## 文件用途：验证追踪目标释放后，在重选冷却内立即换目标或清空缓存并继续飞行。
## 使用方式：通过run_isolated_godot.ps1以headless模式执行。
extends SceneTree

const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

class TestEnemy:
	extends Node2D
	var current_health: int = 100
	var _is_dead: bool = false

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry: Node = CombatTargetRegistryScript.get_or_create(root)
	var first: Node2D = _spawn_enemy(Vector2(100.0, 0.0), registry)
	var replacement: Node2D = _spawn_enemy(Vector2(0.0, 180.0), registry)
	var projectile: Node2D = ProjectileScript.new() as Node2D
	root.add_child(projectile)
	projectile.set_physics_process(false)
	projectile.call("setup", {
		"homing_enabled": true,
		"homing_turn_rate": 20.0,
		"homing_seek_range": 620.0,
		"speed": 100.0,
		"lifetime": 5.0,
		"direction": Vector2.RIGHT,
	})
	projectile.call("_physics_process", 0.01)
	_expect(projectile.get("_homing_target") == first, "projectile initially caches the nearest enemy")
	_expect(float(projectile.get("_homing_retarget_timer")) > 0.01, "target expires before the periodic retarget is due")

	# 保留投射物中的旧引用，让真实释放触发下一帧的目标重选。
	first.free()
	projectile.call("_physics_process", 0.01)
	_expect(projectile.get("_homing_target") == replacement, "freed target is replaced immediately within retarget cooldown")
	var direction: Vector2 = projectile.get("direction")
	_expect(direction.y > 0.0, "projectile turns towards the live replacement")

	replacement.free()
	var previous_position: Vector2 = projectile.global_position
	var previous_direction: Vector2 = projectile.get("direction")
	projectile.call("_physics_process", 0.01)
	_expect(projectile.get("_homing_target") == null, "freed target is cleared when no replacement exists")
	_expect(projectile.global_position.is_equal_approx(previous_position + previous_direction * 1.0), "projectile continues flying without a target")

	var queued: Node2D = _spawn_enemy(Vector2(100.0, 0.0), registry)
	projectile.call("_physics_process", 0.11)
	_expect(projectile.get("_homing_target") == queued, "projectile reacquires a newly spawned enemy")
	queued.queue_free()
	projectile.call("_physics_process", 0.01)
	_expect(projectile.get("_homing_target") == null, "queued deletion still rejects the cached target")
	projectile.free()
	await process_frame
	quit(1 if _failed else 0)

func _spawn_enemy(position: Vector2, registry: Node) -> Node2D:
	var enemy: Node2D = TestEnemy.new()
	root.add_child(enemy)
	enemy.global_position = position
	enemy.add_to_group(&"enemies")
	registry.call("register_enemy", enemy)
	return enemy

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		_failed = true
		push_error("[FAIL] %s" % message)
