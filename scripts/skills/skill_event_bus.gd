extends Node
class_name SkillEventBus


const ConditionEvaluatorScript: Script = preload("res://scripts/skills/condition_evaluator.gd")
const HitEventResultScript: Script = preload("res://scripts/skills/hit_event_result.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const FireSkillRuntimeScript: Script = preload("res://scripts/skills/fire_skill_runtime.gd")
const SkillSpecialRuleExecutorScript: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

var _listeners: Dictionary = {}
var _action_executor: RefCounted = SkillActionExecutorScript.new()
var _special_rule_executor: RefCounted = SkillSpecialRuleExecutorScript.new()


func subscribe(event_name: StringName, listener: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []

	var listeners: Array = _listeners[event_name]
	if not listeners.has(listener):
		listeners.append(listener)
		_listeners[event_name] = listeners


func emit_skill_event(event_name: StringName, event_context: Dictionary = {}) -> Array:
	var context: Dictionary = DamageTraceContextScript.normalize_event_context(event_context, get_tree().root if get_tree() != null else null)
	context["event_name"] = event_name
	context["event_bus"] = self
	if event_name == &"on_cast":
		_special_rule_executor.call("execute_event", event_name, context)
		_execute_fire_passive_runtime(event_name, context)
		_execute_skill_events(event_name, context)
	else:
		_execute_skill_events(event_name, context)
		_execute_fire_passive_runtime(event_name, context)
		_special_rule_executor.call("execute_event", event_name, context)

	var results: Array = []
	var listeners: Array = _listeners.get(event_name, [])
	for listener_variant: Variant in listeners:
		var listener: Callable = listener_variant
		if listener.is_valid():
			results.append(HitEventResultScript.from_value(listener.call(context)).to_dictionary())

	return results


func _execute_fire_passive_runtime(event_name: StringName, context: Dictionary) -> void:
	var skill_manager: Node = context.get("skill_manager") as Node
	if skill_manager == null:
		var caster: Node = context.get("caster") as Node
		if caster != null:
			skill_manager = caster.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return
	FireSkillRuntimeScript.execute_passive_event(event_name, context, skill_manager, _action_executor)


func _execute_skill_events(event_name: StringName, context: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return

	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return

	var events: Array = _get_skill_events(skill_instance, definition)
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue

		var event: Dictionary = event_variant
		if StringName(String(event.get("trigger", ""))) != event_name:
			continue
		var source_id: StringName = StringName(String(event.get("source_id", "")))
		if source_id != &"" and source_id != StringName(String(context.get("source_id", ""))):
			continue

		var conditions: Array = _get_array(event.get("conditions", []))
		if not ConditionEvaluatorScript.evaluate_all(conditions, context):
			continue

		var actions: Array = _get_array(event.get("actions", []))
		_action_executor.call("execute_actions", actions, context)


func _get_skill_events(skill_instance: RefCounted, definition: RefCounted) -> Array:
	var events: Array = []
	var definition_events_variant: Variant = definition.get("events")
	if definition_events_variant is Array:
		events.append_array(definition_events_variant)

	var runtime_events_variant: Variant = skill_instance.get("runtime_events")
	if runtime_events_variant is Array:
		events.append_array(runtime_events_variant)

	return events


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
