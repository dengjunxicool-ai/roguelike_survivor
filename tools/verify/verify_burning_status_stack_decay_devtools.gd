extends SceneTree


const DevDebugPanelScript: Script = preload("res://scripts/debug/dev_debug_panel.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemy: Node = load("res://scenes/enemies/enemy.tscn").instantiate()
	root.add_child(enemy)
	await process_frame

	enemy.call("apply_status", &"burning", {
		"stacks": 5,
		"duration": 4.0,
		"power": 100.0
	})
	_expect(enemy.call("get_status_stack", &"burning") == 5, "burning starts at 5 stacks")

	var panel: CanvasLayer = DevDebugPanelScript.new()
	var initial_text: String = String(panel.call("_format_statuses", enemy.call("get_status_snapshot")))
	_expect(initial_text == "statuses:Brn(5, 36.0, 4.0s)", "dev tools status text includes stacks, tick damage, and duration", initial_text)

	enemy.call("_update_status_effects", 1.01)
	_expect(enemy.call("get_status_stack", &"burning") == 4, "burning consumes one stack after first tick", enemy.call("get_status_snapshot"))
	var first_tick_text: String = String(panel.call("_format_statuses", enemy.call("get_status_snapshot")))
	_expect(first_tick_text == "statuses:Brn(4, 36.0, 3.0s)", "dev tools status text updates remaining duration after first tick", first_tick_text)

	enemy.call("_update_status_effects", 1.01)
	_expect(enemy.call("get_status_stack", &"burning") == 3, "burning consumes one stack after second tick", enemy.call("get_status_snapshot"))

	enemy.call("apply_status", &"burning", {
		"stacks": 2,
		"duration": 4.0,
		"power": 100.0
	})
	_expect(enemy.call("get_status_stack", &"burning") == 5, "reapplying burning can replenish stacks", enemy.call("get_status_snapshot"))

	panel.free()
	enemy.queue_free()
	if not _failed:
		print("[verify_burning_status_stack_decay_devtools] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_burning_status_stack_decay_devtools] FAIL %s actual=%s" % [label, str(actual)])
