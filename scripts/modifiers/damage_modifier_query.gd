extends RefCounted
class_name DamageModifierQuery


const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")

var query: ModifierQuery


static func make(packet: DamagePacket, attacker: Node = null, target_profile: TargetDamageProfile = null) -> DamageModifierQuery:
	var result: DamageModifierQuery = new()
	result.query = ModifierQueryScript.for_damage(packet, attacker)
	if result.query.target_type == &"" and target_profile != null:
		result.query.target_type = target_profile.target_type
	return result


func to_modifier_query() -> ModifierQuery:
	return query


func get_query_value(key: String, fallback: Variant = null) -> Variant:
	if query == null:
		return fallback
	return query.get(key)
