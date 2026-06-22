extends RefCounted
class_name HitEventResult


var consume_base_damage: bool = false
var appended_damage: Array = []
var side_effect_only: bool = true


static func from_value(value: Variant) -> RefCounted:
	if value is RefCounted and value.has_method("to_dictionary"):
		return value
	var result: RefCounted = new()
	if value is Dictionary:
		var dictionary: Dictionary = value
		result.consume_base_damage = bool(dictionary.get("consume_base_damage", false))
		result.appended_damage = _get_array(dictionary.get("appended_damage", []))
		result.side_effect_only = bool(dictionary.get("side_effect_only", not result.consume_base_damage and result.appended_damage.is_empty()))
	elif value is bool:
		result.consume_base_damage = bool(value)
		result.side_effect_only = not result.consume_base_damage
	return result


func to_dictionary() -> Dictionary:
	return {
		"consume_base_damage": consume_base_damage,
		"appended_damage": appended_damage.duplicate(true),
		"side_effect_only": side_effect_only
	}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
