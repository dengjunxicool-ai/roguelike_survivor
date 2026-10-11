extends SceneTree
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player := Node2D.new()
	world.add_child(player)
	var drum: Node2D = EnemyScene.instantiate()
	drum.enemy_id = &"war_drum_goblin"
	world.add_child(drum)
	drum.target = player
	var ally: Node2D = EnemyScene.instantiate()
	ally.enemy_id = &"skeleton"
	world.add_child(ally)
	ally.position = Vector2(100,0)
	var speed: float = ally.move_speed
	var behavior: RefCounted = drum._behavior_controller._behavior
	player.position = Vector2(300,0)
	drum._update_behavior(0.01)
	expect(is_equal_approx(ally._get_effective_move_speed(), speed), "outside range does not buff allies")
	expect(not drum._state_controller.get_snapshot().is_attacking, "outside range does not play attack")
	expect(drum.velocity.x > 0, "drummer approaches from 300 instead of stopping outside 220")
	expect(not is_instance_valid(behavior._marker), "outside range does not pulse drum marker")
	player.position = Vector2(220,0)
	drum._update_behavior(0.5)
	expect(is_equal_approx(ally._get_effective_move_speed(), speed * 1.15), "range boundary activates support")
	expect(drum._state_controller.get_snapshot().is_attacking, "range boundary starts drum animation")
	expect(drum.velocity == Vector2.ZERO, "drummer stops inside skill range")
	player.position = Vector2(221,0)
	drum._state_controller.update(0.21)
	drum._update_behavior(0.5)
	ally._support_buff_controller.tick(0.61)
	expect(is_equal_approx(ally._get_effective_move_speed(), speed), "leaving range stops refreshing support")
	expect(not drum._state_controller.get_snapshot().is_attacking, "leaving range starts no new attack")
	expect(drum.velocity.x > 0, "leaving range resumes chase")
	expect(not behavior._marker.visible, "leaving range hides drum aura")
	drum.target = null
	drum._update_behavior(0.5)
	expect(drum.velocity == Vector2.ZERO, "missing target stops movement")
	drum.target = player
	player.position = Vector2(200,0)
	drum._update_behavior(0.5)
	expect(is_equal_approx(ally._get_effective_move_speed(), speed * 1.15), "reentering range resumes support")
	drum._behavior_controller.cancel_pending_attack()
	expect(not behavior._marker.visible, "runtime cancellation hides existing drum marker")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)

func expect(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	failed = failed or not ok
