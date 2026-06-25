extends RefCounted
class_name CharacterTrait


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const DamageAbsorbResultScript: Script = preload("res://scripts/characters/events/damage_absorb_result.gd")

var config: Dictionary = {}
var context: RefCounted


func setup(trait_config: Dictionary, trait_context: RefCounted) -> void:
	config = trait_config.duplicate(true)
	context = trait_context


func process(_delta: float) -> void:
	pass


func handle_event(_event: RefCounted) -> void:
	pass


func get_modifiers(_query: RefCounted) -> Dictionary:
	return {}


func absorb_damage(amount: int, _event: RefCounted) -> RefCounted:
	return DamageAbsorbResultScript.unchanged(amount)


func get_debug_state() -> Dictionary:
	return {}


func _get_params() -> Dictionary:
	return _get_dictionary(config.get("params", {}))


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _get_modifier_values(value: Variant) -> Dictionary:
	return ModifierSourceScript.flatten(value, ModifierSourceScript.SOURCE_CHARACTER_TRAIT)


func _is_starting_skill(skill_id: Variant) -> bool:
	if context == null or not context.has_method("get_starting_skill_id"):
		return false
	return StringName(String(skill_id)) == StringName(String(context.call("get_starting_skill_id")))
