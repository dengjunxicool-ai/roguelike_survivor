extends SceneTree


var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	await process_frame
	await _run_checks_impl()
	quit(1 if _failed else 0)


func _run_checks_impl() -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	if enemy_scene == null:
		_fail("enemy scene loads")
		return

	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		_fail("enemy scene instantiates as Node2D")
		return

	root.add_child(enemy)
	await process_frame

	if enemy.has_method("apply_status"):
		enemy.call("apply_status", &"burning", {
			"stacks": 2,
			"duration": 5.0,
			"tick_damage": 4.0,
			"tick_interval": 1.0
		})
	await process_frame

	if enemy.has_method("_update_enemy_runtime_tick"):
		enemy.call("_update_enemy_runtime_tick", 0.0)
	await process_frame

	_expect(int(enemy.call("get_status_stack", &"burning")) == 2, "burning remains active on enemy")

	var status_label: Label = enemy.get_node_or_null("StatusLabel") as Label
	_expect(status_label == null or not status_label.visible, "enemy status label stays hidden")

	var visual_state: String = ""
	if enemy.has_method("_get_priority_status_visual_state"):
		visual_state = String(enemy.call("_get_priority_status_visual_state"))
	_expect(visual_state == "", "enemy status visual state is suppressed", visual_state)


func _expect(condition: bool, message: String, actual: Variant = "") -> void:
	if condition:
		print("[verify_enemy_status_display_hidden] PASS %s" % message)
	else:
		_failed = true
		push_error("[verify_enemy_status_display_hidden] FAIL %s actual=%s" % [message, str(actual)])


func _fail(message: String) -> void:
	_failed = true
	push_error("[verify_enemy_status_display_hidden] FAIL %s" % message)
