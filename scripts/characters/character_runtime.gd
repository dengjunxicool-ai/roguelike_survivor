extends Node
class_name CharacterRuntime


const CharacterDefinitionScript: Script = preload("res://scripts/characters/character_definition.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")

var character_definition: RefCounted
var trait_runtime_state: Dictionary = {}
var _runtime_modifiers: Dictionary = {}


func initialize(character_id: String) -> bool:
	_runtime_modifiers.clear()
	trait_runtime_state.clear()

	var character_data: Dictionary = _get_character_data(StringName(character_id))
	if character_data.is_empty():
		push_warning("[CharacterRuntime] Unknown character_id: %s" % character_id)
		return false

	character_definition = CharacterDefinitionScript.new(character_data)
	_sync_runtime_modifier_source()
	return true


func get_character_id() -> String:
	if character_definition == null:
		return ""
	return String(character_definition.get("id"))


func get_starting_skill_id() -> String:
	if character_definition == null:
		return ""
	return String(character_definition.get("starting_skill_id"))


func get_stat(stat_name: String, default_value: Variant = 0) -> Variant:
	if character_definition == null:
		return default_value

	var base_stats: Dictionary = character_definition.get("base_stats")
	var base_value: Variant = base_stats.get(stat_name, default_value)
	return SkillModifierCalculatorScript.calculate(base_value, stat_name, _runtime_modifiers)


func get_trait() -> Dictionary:
	if character_definition == null or not character_definition.has_method("get_trait"):
		return {}
	return character_definition.call("get_trait")


func add_runtime_modifier(key: Variant, value: Variant) -> void:
	var source: Dictionary = {String(key): value}
	SkillModifierCalculatorScript.merge_modifiers(_runtime_modifiers, source)
	_sync_runtime_modifier_source()


func add_runtime_modifiers(modifiers: Dictionary) -> void:
	SkillModifierCalculatorScript.merge_modifiers(_runtime_modifiers, modifiers)
	_sync_runtime_modifier_source()


func clear_temporary_modifiers() -> void:
	_runtime_modifiers.clear()
	_clear_runtime_modifier_source()


func _sync_runtime_modifier_source() -> void:
	var owner: Node = get_parent()
	if owner != null and owner.has_method("set_run_modifier_source"):
		owner.call("set_run_modifier_source", &"character_runtime", _runtime_modifiers)


func _clear_runtime_modifier_source() -> void:
	var owner: Node = get_parent()
	if owner != null and owner.has_method("clear_run_modifier_source"):
		owner.call("clear_run_modifier_source", &"character_runtime")


func _get_character_data(character_id: StringName) -> Dictionary:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_character_definition"):
		var data: Variant = data_manager.call("get_character_definition", character_id)
		if data is Dictionary:
			return data
	return GameData.get_character(character_id)
