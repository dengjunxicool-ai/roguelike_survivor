extends SceneTree


const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")

var _events: Array[Dictionary] = []
var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta(&"real_full_run_profiler_enabled", true)
	root.set_meta(&"real_full_run_profiler_status_event", Callable(self, "_record_status_event"))

	var enemy: Node2D = Node2D.new()
	root.add_child(enemy)
	var manager: Node = StatusEffectManagerScript.new()
	enemy.add_child(manager)
	await process_frame

	manager.call("apply_status", &"burning", {"stacks": 1, "duration": 4.0, "tick_damage": 1.0})
	manager.call("consume_status_stack", &"burning", 1)
	manager.call("apply_status", &"burning", {"stacks": 1, "duration": 4.0, "tick_damage": 1.0})

	_expect(_count_visual_updates() == 0, "status visual updates are deferred during same-frame churn", _count_visual_updates())

	await process_frame
	_expect(_count_visual_updates() == 1, "same-frame status visual churn flushes once", _count_visual_updates())
	_expect(enemy.get_node_or_null("StatusVisualOverlay") != null, "status visual overlay exists after flush")

	enemy.queue_free()
	if not _failed:
		print("[verify_status_visual_refresh_coalescing] PASS")
	quit(1 if _failed else 0)


func _record_status_event(event_name: StringName, payload: Dictionary) -> void:
	_events.append({
		"event_name": event_name,
		"payload": payload.duplicate(true)
	})


func _count_visual_updates() -> int:
	var count: int = 0
	for event: Dictionary in _events:
		if StringName(String(event.get("event_name", ""))) == &"status_visual_update":
			count += 1
	return count


func _expect(condition: bool, message: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_status_visual_refresh_coalescing] FAIL %s actual=%s" % [message, str(actual)])
