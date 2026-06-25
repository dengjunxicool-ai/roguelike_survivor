extends SceneTree


const EnemyDebugDisplayControllerScript: Script = preload("res://scripts/enemies/enemy_debug_display_controller.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemy: Node2D = Node2D.new()
	root.add_child(enemy)
	var controller: RefCounted = EnemyDebugDisplayControllerScript.new()
	controller.call("setup", enemy)

	controller.call("update_health", 100, 100)
	controller.call("update_health", 60, 100)

	var hp_bar: ProgressBar = enemy.get_node_or_null("DebugHpBar") as ProgressBar
	var lag_bar: ProgressBar = enemy.get_node_or_null("DebugHpLagBar") as ProgressBar
	_expect(hp_bar != null, "enemy current HP bar exists")
	_expect(lag_bar != null, "enemy lighter delayed HP bar exists")
	if hp_bar != null and lag_bar != null:
		_expect(is_equal_approx(float(hp_bar.value), 60.0), "current HP bar updates to new health immediately")
		_expect(float(lag_bar.value) > float(hp_bar.value), "delayed HP bar keeps the previous health before easing")
		await create_timer(2.15).timeout
		_expect(absf(float(lag_bar.value) - 60.0) <= 1.0, "delayed HP bar eases down to the new health")

	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		_failed = true
		push_error("[FAIL] %s" % message)
