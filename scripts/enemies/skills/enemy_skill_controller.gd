extends RefCounted
class_name EnemySkillController


const EnemySkillRepositoryScript: Script = preload("res://scripts/enemies/skills/enemy_skill_repository.gd")
const EnemyActionContextScript: Script = preload("res://scripts/enemies/actions/enemy_action_context.gd")
const EnemyActionRegistryScript: Script = preload("res://scripts/enemies/actions/enemy_action_registry.gd")

var _owner: Node
var _behavior_config: Dictionary = {}
var _repository: RefCounted = EnemySkillRepositoryScript.new()
var _action_registry: RefCounted = EnemyActionRegistryScript.new()
var _skill_entries: Array[Dictionary] = []


func setup(owner: Node, skill_refs: Array = [], behavior_config: Dictionary = {}) -> void:
	_owner = owner
	_behavior_config = behavior_config.duplicate(true)
	_skill_entries.clear()
	for ref_variant: Variant in skill_refs:
		var ref: Dictionary = _normalize_skill_ref(ref_variant)
		var skill_id: StringName = StringName(String(ref.get("skill_id", ref.get("id", ""))))
		if skill_id == &"":
			continue
		var definition: RefCounted = _repository.call("get_skill", skill_id) as RefCounted
		if definition == null:
			push_warning("[EnemySkillController] Missing enemy skill definition: %s" % String(skill_id))
			continue
		_skill_entries.append({
			"id": skill_id,
			"ref": ref,
			"definition": definition
		})


func tick(_delta: float) -> void:
	pass


func execute_action_type(action_type: String, runtime_params: Dictionary = {}) -> bool:
	for entry: Dictionary in _skill_entries:
		var definition: RefCounted = entry.get("definition") as RefCounted
		if definition == null or not bool(definition.call("has_action_type", action_type)):
			continue
		var actions: Array = definition.call("get_actions_by_type", action_type)
		var executed: bool = false
		for action_variant: Variant in actions:
			if not (action_variant is Dictionary):
				continue
			var action: Dictionary = action_variant
			var context: Dictionary = EnemyActionContextScript.create(
				_owner,
				definition.call("to_dictionary"),
				action,
				_build_runtime_params(entry, runtime_params)
			)
			executed = bool(_action_registry.call("execute", context)) or executed
		if executed:
			return true
	return false


func execute_skill_id(skill_id: Variant, runtime_params: Dictionary = {}) -> bool:
	var requested_id: StringName = StringName(String(skill_id))
	for entry: Dictionary in _skill_entries:
		if StringName(String(entry.get("id", ""))) != requested_id:
			continue
		var definition: RefCounted = entry.get("definition") as RefCounted
		if definition == null:
			return false
		var actions: Array = definition.get("actions")
		var executed: bool = false
		for action_variant: Variant in actions:
			if not (action_variant is Dictionary):
				continue
			var action: Dictionary = action_variant
			var context: Dictionary = EnemyActionContextScript.create(
				_owner,
				definition.call("to_dictionary"),
				action,
				_build_runtime_params(entry, runtime_params)
			)
			executed = bool(_action_registry.call("execute", context)) or executed
		return executed
	return false


func get_cooldown_for_action(action_type: String, fallback: float) -> float:
	for entry: Dictionary in _skill_entries:
		var definition: RefCounted = entry.get("definition") as RefCounted
		if definition == null or not bool(definition.call("has_action_type", action_type)):
			continue
		var ref: Dictionary = entry.get("ref", {})
		if ref.has("cooldown"):
			return maxf(float(ref.get("cooldown", fallback)), 0.1)
		var definition_cooldown: float = float(definition.get("cooldown"))
		if definition_cooldown > 0.0:
			return maxf(definition_cooldown, 0.1)
	return maxf(fallback, 0.1)


func _build_runtime_params(entry: Dictionary, runtime_params: Dictionary) -> Dictionary:
	var params: Dictionary = runtime_params.duplicate(true)
	params["skill_ref"] = (entry.get("ref", {}) as Dictionary).duplicate(true)
	params["behavior"] = _behavior_config.duplicate(true)
	return params


func _normalize_skill_ref(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	if String(value) != "":
		return {"skill_id": String(value)}
	return {}
