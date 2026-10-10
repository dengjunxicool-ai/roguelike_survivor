extends SceneTree

var _failed := false
class FailingRegistry:
	extends "res://scripts/enemies/actions/enemy_action_registry.gd"
	var created_count := 0
	func _create_projectile(context: Dictionary) -> Node2D:
		created_count += 1
		if created_count == 3:
			return null
		return super._create_projectile(context)
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.canvas_transform=Transform2D(0.0,Vector2(640,360))
	var world := Node2D.new()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var boss: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate()
	boss.set("enemy_id", &"dungeon_heart")
	world.add_child(boss)
	var skill := {"skill_id": "ring_bullets", "type": "ring_projectiles", "projectile_count": 12, "safe_gap_count": 2, "safe_gap_start": 11, "warning_time": 0.6}
	_expect(boss.call("_execute_boss_skill", skill), "ring starts successfully")
	_expect(_projectiles(world).is_empty(), "ring creates no bullets before its warning")
	var warning: Node = _warning(world)
	_expect(warning != null, "ring has a visible warning controller")
	if warning != null:
		warning.call("_physics_process", 0.59)
		_expect(_projectiles(world).is_empty(), "ring warning lasts full 0.6 seconds")
		warning.call("_physics_process", 0.02)
	await process_frame
	var bullets := _projectiles(world)
	_expect(bullets.size() == 10, "wrapped gap skips indices eleven and zero")
	for bullet in bullets:
		var direction: Vector2 = bullet.get("direction")
		_expect(absf(direction.angle()) > 0.01 and absf(direction.angle() + TAU / 12.0) > 0.01, "safe sector contains no projectile")
		_expect(bullet.has_signal("enemy_attack_finished"), "projectile has pool generation lifecycle")
	_expect(boss.call("_spawn_corrupted_cores", 2, 120), "first core summon succeeds")
	_expect(not boss.call("_spawn_corrupted_cores", 2, 120), "two live cores prevent further summon")
	_expect(get_nodes_in_group(&"boss_cores").size() == 2, "core count is capped at two")
	for bullet in bullets:
		bullet.call("despawn_or_free")
	var scheduler: RefCounted = boss.get("_boss_mechanic_scheduler")
	scheduler.call("reset")
	var token: int = scheduler.call("try_reserve", &"ring_bullets", &"projectiles", 2)
	var registry := FailingRegistry.new()
	boss.set("_boss_skill_cooldowns", {"ring_bullets": 6.0})
	var failed_context := {"owner": boss, "skill": {"id": "ring_bullets"}, "action": {"type": "ring_projectiles"}, "runtime_params": {"mechanic_scheduler": scheduler, "mechanic_token": token}}
	_expect(not registry.call("_spawn_ring_projectiles", failed_context, {"projectile_count": 12, "safe_gap_count": 2, "safe_gap_start": 11}), "partial ring failure is reported")
	await process_frame
	_expect(_projectiles(world).is_empty() and scheduler.get("_tokens").is_empty() and boss.get("_boss_skill_cooldowns").is_empty(), "partial ring failure rolls back all bullets, cooldown and token")
	var rng: RandomNumberGenerator = boss.get("_boss_ring_rng")
	rng.seed = 618
	skill.erase("safe_gap_start")
	boss.call("_execute_boss_skill", skill)
	var first: Node = _warning(world)
	var gap: int = first.get("_telegraph").get("_params").safe_gap_start
	first.call("despawn_or_free")
	await process_frame
	rng.seed = 618
	boss.call("_execute_boss_skill", skill)
	var repeated: Node = _warning(world)
	_expect(repeated.get("_telegraph").get("_params").safe_gap_start == gap, "fixed seed repeats the same safe sector")
	repeated.call("despawn_or_free")
	await process_frame
	scheduler.call("reset")
	var ring_token: int = scheduler.call("try_reserve", &"ring_bullets", &"projectiles", 1)
	boss.call("_execute_boss_skill", skill, ring_token)
	scheduler.call("commit", ring_token)
	var tracked: Node = _warning(world)
	tracked.call("_physics_process", 0.6)
	await process_frame
	var tracked_bullets := _projectiles(world)
	_expect(tracked_bullets.size() == 10 and scheduler.get("_tokens").size() == 1, "warning transfers its slot to all released bullets")
	for index in range(tracked_bullets.size() - 1):
		tracked_bullets[index].call("despawn_or_free")
	_expect(scheduler.get("_tokens").size() == 1, "remaining last bullet keeps the slot")
	tracked_bullets.back().call("prepare_for_pool_despawn")
	_expect(scheduler.get("_tokens").is_empty(), "last bullet pool return releases the slot")
	world.queue_free()
	await process_frame
	print("[BossAttackFairness] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _projectiles(world: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in world.get_children():
		if child is Projectile and not child.is_queued_for_deletion() and child.get("_generation_finished") == false:
			found.append(child)
		found.append_array(_projectiles(child))
	return found

func _warning(world: Node) -> Node:
	for child in world.get_children():
		if child.has_method("_release_ring") and not child.is_queued_for_deletion():
			return child
	return null

func _expect(ok: bool, message: String) -> void:
	if ok:
		print("[BossAttackFairness] PASS " + message)
	else:
		_failed = true
		push_error("[BossAttackFairness] FAIL " + message)
