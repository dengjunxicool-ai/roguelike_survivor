extends Node
class_name RelicManager
const GameDataScript: Script = preload("res://scripts/game/game_data.gd")


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")

signal relic_added(relic_id: StringName)
signal relics_changed

@export_range(1, 20, 1, "or_greater") var max_relics: int = 3

var owned_relics: Array[StringName] = []
var _relic_definitions: Dictionary = {}
var _trigger_counts: Dictionary = {}
var _cooldown_until: Dictionary = {}


func _ready() -> void:
	_load_relic_definitions()


func add_relic(relic_id: Variant) -> bool:
	var id: StringName = _to_relic_id(relic_id)
	if id == &"" or has_relic(id) or not can_add_relic():
		return false

	var definition: Dictionary = _get_relic_definition(id)
	if definition.is_empty():
		return false

	owned_relics.append(id)
	_register_modifier_block("relic:%s:negative" % String(id), _get_array(definition.get("negative_modifier", [])))
	relic_added.emit(id)
	relics_changed.emit()
	_notify_skill_manager_changed()
	return true


func has_relic(relic_id: Variant) -> bool:
	return owned_relics.has(_to_relic_id(relic_id))


func get_relic_modifiers_for_skill(skill_instance: RefCounted) -> Array:
	var modifiers: Array = []
	if skill_instance == null:
		return modifiers

	for relic_id: StringName in owned_relics:
		var relic: Dictionary = _get_relic_definition(relic_id)
		if relic.is_empty() or not _relic_applies_to_skill(relic, skill_instance):
			continue

		var relic_modifiers: Variant = relic.get("modifiers", [])
		if relic_modifiers is Array:
			modifiers.append_array((relic_modifiers as Array).duplicate(true))

	return modifiers


func can_add_relic() -> bool:
	return owned_relics.size() < max_relics


func get_owned_relic_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for relic_id: StringName in owned_relics:
		var definition: Dictionary = _get_relic_definition(relic_id)
		if not definition.is_empty():
			definitions.append(definition)
	return definitions


func get_relic_definition(relic_id: Variant) -> Dictionary:
	return _get_relic_definition(_to_relic_id(relic_id))


func reset_run_effect_state() -> void:
	_trigger_counts.clear()
	_cooldown_until.clear()


func handle_combat_event(event_name: Variant, payload: Dictionary = {}) -> void:
	var event_id: String = String(event_name)
	if event_id == "":
		return
	for relic_id: StringName in owned_relics:
		var relic: Dictionary = _get_relic_definition(relic_id)
		if relic.is_empty() or not _can_trigger_relic(relic_id, relic, event_id, payload):
			continue
		_trigger_relic(relic_id, relic, payload)


func _load_relic_definitions() -> void:
	_relic_definitions.clear()
	for relic: Dictionary in GameDataScript.get_relic_pool():
		var relic_id: StringName = _to_relic_id(relic.get("id", ""))
		if relic_id != &"":
			_relic_definitions[relic_id] = relic


func _get_relic_definition(relic_id: StringName) -> Dictionary:
	if _relic_definitions.is_empty():
		_load_relic_definitions()

	if not _relic_definitions.has(relic_id):
		var relic: Dictionary = GameDataScript.get_relic(relic_id)
		if not relic.is_empty():
			_relic_definitions[relic_id] = relic.duplicate(true)

	if not _relic_definitions.has(relic_id):
		return {}

	var definition: Dictionary = _relic_definitions[relic_id]
	return definition.duplicate(true)


func _relic_applies_to_skill(relic: Dictionary, skill_instance: RefCounted) -> bool:
	var required_tags: Array[String] = _get_string_array(relic.get("tags", []))
	if required_tags.is_empty():
		return true

	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null or not definition.has_method("has_tag"):
		return false

	for tag: String in required_tags:
		if bool(definition.call("has_tag", tag)):
			return true

	return false


func _notify_skill_manager_changed() -> void:
	var skill_manager: Node = get_parent().get_node_or_null("SkillManager") if get_parent() != null else null
	if skill_manager != null and skill_manager.has_signal("skill_changed"):
		skill_manager.emit_signal("skill_changed")


func _can_trigger_relic(relic_id: StringName, relic: Dictionary, event_id: String, payload: Dictionary) -> bool:
	var condition: Dictionary = _get_dictionary(relic.get("trigger_condition", {}))
	if condition.is_empty():
		return false
	if String(condition.get("event", "")) != event_id:
		return false
	if condition.has("status_id") and String(condition.get("status_id", "")) != String(payload.get("status_id", "")):
		return false
	if condition.has("map_variable") and String(condition.get("map_variable", "")) != String(payload.get("map_variable", "")):
		return false

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	if now_seconds < float(_cooldown_until.get(relic_id, 0.0)):
		return false

	var limit_rule: Dictionary = _get_dictionary(relic.get("limit_rule", {}))
	var max_triggers: int = int(limit_rule.get("max_triggers_per_run", 1))
	if max_triggers > 0 and int(_trigger_counts.get(relic_id, 0)) >= max_triggers:
		return false
	return true


func _trigger_relic(relic_id: StringName, relic: Dictionary, _payload: Dictionary) -> void:
	_register_modifier_block("relic:%s:trigger" % String(relic_id), relic.get("modifiers", []), true)
	_trigger_counts[relic_id] = int(_trigger_counts.get(relic_id, 0)) + 1
	var cooldown: float = maxf(float(relic.get("cooldown", 0.0)), 0.0)
	if cooldown > 0.0:
		_cooldown_until[relic_id] = float(Time.get_ticks_msec()) / 1000.0 + cooldown
	_notify_skill_manager_changed()


func _register_modifier_block(source_id: String, effects: Array, merge_existing: bool = false) -> void:
	if effects.is_empty():
		return
	var errors: Array[String] = ModifierSourceScript.validate_effects(effects)
	if not errors.is_empty():
		push_error("Invalid relic Modifier effects: " + "; ".join(errors))
		return
	var owning_node: Node = get_parent()
	if owning_node == null:
		return
	if merge_existing and owning_node.has_method("merge_run_modifier_source"):
		owning_node.call("merge_run_modifier_source", source_id, effects)
	elif owning_node.has_method("set_run_modifier_source"):
		owning_node.call("set_run_modifier_source", source_id, effects)


func _to_relic_id(relic_id: Variant) -> StringName:
	return StringName(String(relic_id))


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if not (value is Array):
		return strings

	var items: Array = value
	for item: Variant in items:
		strings.append(String(item))

	return strings
