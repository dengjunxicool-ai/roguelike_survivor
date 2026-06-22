extends RefCounted
class_name DamageModifierQuery


const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")

var query: RefCounted


static func make(packet_source: Variant, attacker: Node = null) -> RefCounted:
	var result: RefCounted = new()
	result.query = ModifierQueryScript.for_damage_any(packet_source, attacker)
	return result


func to_modifier_query() -> RefCounted:
	return query


func get_query_value(key: String, fallback: Variant = null) -> Variant:
	if query == null:
		return fallback
	return query.get(key)
