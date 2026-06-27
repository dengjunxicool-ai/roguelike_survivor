extends SceneTree


const EnemyVisualControllerScript: Script = preload("res://scripts/enemies/enemy_visual_controller.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemy := Node2D.new()
	enemy.name = "EnemyBase"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.modulate = Color(0.9, 0.18, 0.12, 1.0)
	enemy.add_child(sprite)

	root.add_child(enemy)
	await process_frame

	var controller: RefCounted = EnemyVisualControllerScript.new()
	controller.call("setup", enemy)
	controller.call("update", {"is_hurt": true}, 0.016)
	_expect(sprite.modulate == Color.WHITE, "enemy hurt state flashes sprite white", sprite.modulate)

	enemy.queue_free()
	await process_frame
	if not _failed:
		print("[verify_enemy_hit_flash] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_enemy_hit_flash] FAIL %s actual=%s" % [label, str(actual)])
