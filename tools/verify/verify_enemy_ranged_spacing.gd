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
	var archer: CharacterBody2D = EnemyScene.instantiate()
	archer.set("enemy_id", &"archer_skeleton")
	world.add_child(archer)
	archer.set("target", player)
	archer.position = Vector2(210, 0)
	archer.call("_update_behavior", 0.1)
	expect(archer.velocity.x > 0 and is_zero_approx(float(archer.get("_ranged_warning_timer"))), "210 distance retreats without firing")
	archer.position.x = 270
	archer.call("_update_behavior", 0.1)
	expect(archer.velocity.x > 0, "retreat persists until 280")
	archer.position.x = 280
	archer.call("_update_behavior", 0.01)
	expect(archer.velocity == Vector2.ZERO and float(archer.get("_ranged_warning_timer")) > 0, "280 holds and begins a full warning")
	archer.position.x = 415
	archer.call("_update_behavior", 0.1)
	var remaining := float(archer.get("_ranged_warning_timer"))
	archer.position.x = 425
	archer.call("_update_behavior", 0.1)
	expect(float(archer.get("_ranged_warning_timer")) > 0 and float(archer.get("_ranged_warning_timer")) < remaining, "415/425 oscillation preserves warning")
	archer.position.x = 461
	archer.call("_update_behavior", 0.1)
	expect(archer.velocity.x < 0 and is_zero_approx(float(archer.get("_ranged_warning_timer"))), "beyond 460 chases and cancels warning")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
func expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[RangedSpacing] FAIL " + message)
	else:
		print("[RangedSpacing] PASS " + message)
