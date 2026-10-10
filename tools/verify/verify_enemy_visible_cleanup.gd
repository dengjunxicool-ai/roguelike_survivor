extends SceneTree

const SpawnService: Script = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
const CleanupService: Script = preload("res://scripts/enemies/timeline/enemy_cleanup_service.gd")
var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var owner := Node2D.new()
	root.add_child(owner)
	var player := Node2D.new()
	player.add_to_group(&"player")
	owner.add_child(player)
	var camera := Camera2D.new()
	camera.zoom = Vector2(0.4, 0.4)
	player.add_child(camera)
	await process_frame
	await process_frame
	var service: RefCounted = SpawnService.new()
	service.call("setup", owner, load("res://scenes/enemies/enemy.tscn"))
	service.call("set_visible_spawn_rules", true, 64.0, 120.0, 0.05)
	var cleanup: RefCounted = CleanupService.new()
	cleanup.call("setup", owner)
	var enemy: Node2D = service.call("spawn", {
		"enemy_id": &"small_slime", "parent": owner,
		"position": Vector2(1300, 0), "spawn_clearance": 0.0,
		"source_type": "wave", "visible_spawn_warning": true
	})
	_expect(enemy.global_position.distance_to(player.global_position) > 1100.0, "fixture is beyond the cleanup radius")
	_expect(root.get_visible_rect().grow(-64.0).has_point(root.get_canvas_transform() * enemy.global_position), "warning is inside the large visible world")
	cleanup.call("despawn_far_enemies", 1100.0)
	_expect(not enemy.is_queued_for_deletion(), "warning enemy survives distance cleanup")
	var deadline: int = Time.get_ticks_msec() + 2000
	while bool(enemy.get_meta("spawn_reveal_pending", false)) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not bool(enemy.get_meta("spawn_reveal_pending", false)), "warning completes and enemy activates")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for _index: int in range(3):
		cleanup.call("despawn_far_enemies", 1100.0)
	_expect(not enemy.is_queued_for_deletion(), "revealed visible enemy survives repeated cleanup")
	# A shifted camera models the player near a map edge: visibility cannot be
	# inferred from a radius centered on the player.
	camera.offset = Vector2(1200, 0)
	camera.zoom = Vector2.ONE
	camera.force_update_scroll()
	_expect(root.get_visible_rect().has_point(root.get_canvas_transform() * enemy.global_position), "offset camera keeps distant enemy visible")
	cleanup.call("despawn_far_enemies", 1100.0)
	_expect(not enemy.is_queued_for_deletion(), "offset camera protects visible enemies")
	var near_enemy: Node2D = service.call("spawn", {"enemy_id": &"small_slime", "parent": owner, "position": Vector2(100, 0), "spawn_clearance": 0.0})
	near_enemy.process_mode = Node.PROCESS_MODE_DISABLED
	cleanup.call("despawn_far_enemies", 1100.0)
	_expect(not near_enemy.is_queued_for_deletion(), "nearby offscreen enemy retains the distance policy")
	camera.offset = Vector2.ZERO
	camera.force_update_scroll()
	cleanup.call("despawn_far_enemies", 1100.0)
	_expect(enemy.is_queued_for_deletion(), "distant enemy is recycled after leaving the viewport")
	owner.queue_free()
	await process_frame
	print("[EnemyVisibleCleanup] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[EnemyVisibleCleanup] PASS " + message)
	else:
		_failed = true
		push_error("[EnemyVisibleCleanup] FAIL " + message)
