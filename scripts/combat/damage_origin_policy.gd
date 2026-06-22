extends RefCounted
class_name DamageOriginPolicy


var origin: StringName = &""
var default_damage_type: StringName = &"direct_physical"
var bonus_keys: Array[String] = []
var uses_skill_level: bool = false
var uses_character_damage: bool = true


static func from_dictionary(origin_value: String, values: Dictionary) -> RefCounted:
	var policy: RefCounted = new()
	policy.origin = StringName(origin_value)
	policy.default_damage_type = StringName(String(values.get("default_damage_type", "direct_physical")))
	policy.bonus_keys = _string_array(values.get("bonus_keys", []))
	policy.uses_skill_level = bool(values.get("uses_skill_level", false))
	policy.uses_character_damage = bool(values.get("uses_character_damage", true))
	return policy


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
