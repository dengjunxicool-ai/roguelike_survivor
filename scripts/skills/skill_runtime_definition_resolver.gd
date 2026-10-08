extends RefCounted
class_name SkillRuntimeDefinitionResolver


const INHERITED_RUNTIME_FIELDS: Array[String] = ["base", "components", "events", "damage_scaling", "runtime_family", "particle"]


static func inherit_attack(definition: Dictionary, source: Dictionary) -> Dictionary:
	var result: Dictionary = definition.duplicate(true)
	for key: String in INHERITED_RUNTIME_FIELDS:
		if source.has(key) and _is_empty(result.get(key, null)):
			var value: Variant = source[key]
			result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


static func _is_empty(value: Variant) -> bool:
	if value == null:
		return true
	if value is Dictionary or value is Array or value is String:
		return value.is_empty()
	if value is StringName:
		return value == &""
	return false
