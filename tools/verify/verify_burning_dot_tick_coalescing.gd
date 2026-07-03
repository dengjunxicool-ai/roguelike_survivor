extends SceneTree


const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")

class RecordingSkillEventBus:
	extends Node

	var emitted_events: Array[Dictionary] = []
	var executed_actions: Array[Dictionary] = []

	func emit_skill_event(event_name: StringName, context: Dictionary) -> void:
		emitted_events.append({
			"event_name": event_name,
			"context": context.duplicate(true)
		})

	func execute_adapted_actions(actions: Array, context: Dictionary) -> void:
		executed_actions.append({
			"actions": actions.duplicate(true),
			"context": context.duplicate(true)
		})


var _profiler_events: Array[Dictionary] = []
var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta(&"real_full_run_profiler_enabled", true)
	root.set_meta(&"real_full_run_profiler_status_event", Callable(self, "_record_status_event"))

	var enemy: Node2D = Node2D.new()
	root.add_child(enemy)
	var event_bus: RecordingSkillEventBus = RecordingSkillEventBus.new()
	event_bus.name = "SkillEventBus"
	enemy.add_child(event_bus)
	var manager: Node = StatusEffectManagerScript.new()
	enemy.add_child(manager)
	await process_frame

	manager.call("apply_status", &"burning", {
		"stacks": 5,
		"duration": 4.0,
		"power": 100.0
	})
	_profiler_events.clear()
	event_bus.emitted_events.clear()
	event_bus.executed_actions.clear()

	manager.call("update_status_effects", 1.51)

	_expect(_count_profiler_events(&"status_tick_due") == 1, "coalesced burning emits one tick_due profiler event", _count_profiler_events(&"status_tick_due"))
	_expect(_count_profiler_events(&"status_tick_applied") == 1, "coalesced burning emits one tick_applied profiler event", _count_profiler_events(&"status_tick_applied"))
	_expect(_first_tick_applied_count() == 3, "coalesced burning records three effective ticks", _first_tick_applied_count())
	_expect(event_bus.executed_actions.size() == 1, "coalesced burning executes one adapted action batch", event_bus.executed_actions.size())
	_expect(_first_damage_power_scale(event_bus) == 0.54, "coalesced burning damage action keeps total tick power", _first_damage_power_scale(event_bus))
	_expect(int(manager.call("get_status_stack", &"burning")) == 2, "coalesced burning consumes three stacks", manager.call("get_status_snapshot"))

	enemy.queue_free()
	if not _failed:
		print("[verify_burning_dot_tick_coalescing] PASS")
	quit(1 if _failed else 0)


func _record_status_event(event_name: StringName, payload: Dictionary) -> void:
	_profiler_events.append({
		"event_name": event_name,
		"payload": payload.duplicate(true)
	})


func _count_profiler_events(event_name: StringName) -> int:
	var count: int = 0
	for event: Dictionary in _profiler_events:
		if StringName(String(event.get("event_name", ""))) == event_name:
			count += 1
	return count


func _first_tick_applied_count() -> int:
	for event: Dictionary in _profiler_events:
		if StringName(String(event.get("event_name", ""))) != &"status_tick_applied":
			continue
		var payload: Dictionary = event.get("payload", {})
		return int(payload.get("coalesced_tick_count", 1))
	return 0


func _first_damage_power_scale(event_bus: RecordingSkillEventBus) -> float:
	if event_bus.executed_actions.is_empty():
		return -1.0
	var batch: Dictionary = event_bus.executed_actions[0]
	var actions: Array = batch.get("actions", [])
	if actions.is_empty() or not (actions[0] is Dictionary):
		return -1.0
	var action: Dictionary = actions[0]
	var params: Dictionary = action.get("params", {})
	var amount: Dictionary = params.get("amount", {})
	return snappedf(float(amount.get("scale", -1.0)), 0.001)


func _expect(condition: bool, message: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_burning_dot_tick_coalescing] FAIL %s actual=%s" % [message, str(actual)])
