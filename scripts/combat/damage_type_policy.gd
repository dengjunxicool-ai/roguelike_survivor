extends RefCounted
class_name DamageTypePolicy


var damage_type: StringName = &""
var defense_rate: float = 0.0
var ignores_resistance: bool = false
var ignores_vulnerability: bool = false
var can_crit_by_default: bool = false
var allowed_origins: Array[StringName] = []


static func from_dictionary(type_value: String, values: Dictionary) -> RefCounted:
	var policy: RefCounted = new()
	policy.damage_type = StringName(type_value)
	policy.defense_rate = float(values.get("defense_rate", 0.0))
	policy.ignores_resistance = bool(values.get("ignore_resistance", false))
	policy.ignores_vulnerability = bool(values.get("ignore_vulnerability", false))
	policy.can_crit_by_default = bool(values.get("can_crit_by_default", false))
	policy.allowed_origins = _string_name_array(values.get("allowed_origins", []))
	return policy


func allows_origin(origin: String) -> bool:
	return allowed_origins.has(StringName(origin))


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			var name: StringName = StringName(String(item))
			if name != &"" and not result.has(name):
				result.append(name)
	return result
