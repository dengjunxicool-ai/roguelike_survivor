extends RefCounted
class_name DamageCriticalResolver


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")


static func apply_critical_stage(calculation_context: RefCounted, outgoing: float) -> Dictionary:
	var source_attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var stages: Dictionary = calculation_context.get("stages")
	var critical: bool = false
	var crit_multiplier: float = 1.0
	if bool(calculation_context.call("packet_value", "critical_resolved", false)):
		critical = bool(calculation_context.call("packet_value", "is_critical", false))
		crit_multiplier = maxf(float(calculation_context.call("packet_value", "crit_multiplier", 1.0)), 1.0) if critical else 1.0
	elif can_crit_for_context(calculation_context) and source_attacker != null:
		var crit_chance: float = clampf(_get_float_property(source_attacker, "crit_chance", 0.0) + float(calculation_context.call("packet_value", "crit_chance_add", 0.0)) + _get_modifier_float(damage_modifiers, "crit_chance_add", 0.0), 0.0, 1.0)
		if randf() < crit_chance:
			critical = true
			crit_multiplier = maxf(_get_float_property(source_attacker, "crit_damage", 1.5) + float(calculation_context.call("packet_value", "crit_damage_add", 0.0)) + _get_modifier_float(damage_modifiers, "crit_damage_add", 0.0), 1.0)

	var pre_mitigation: float = outgoing * crit_multiplier
	stages["is_critical"] = critical
	stages["crit_multiplier"] = crit_multiplier
	stages["pre_mitigation_damage"] = pre_mitigation
	return {
		"is_critical": critical,
		"crit_multiplier": crit_multiplier,
		"pre_mitigation": pre_mitigation
	}


static func can_crit(packet: Dictionary) -> bool:
	return DamageRuleRegistryScript.can_crit(packet)


static func can_crit_for_context(calculation_context: RefCounted) -> bool:
	return DamageRuleRegistryScript.can_crit_for_context(calculation_context)


static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	var value: Variant = _get_property(object, property, fallback)
	if value == null:
		return fallback
	return float(value)


static func _get_modifier_float(modifiers: Dictionary, key: String, fallback: float) -> float:
	if modifiers.is_empty() or not modifiers.has(key):
		return fallback
	return float(modifiers.get(key, fallback))


static func _get_property(object: Object, property: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return object.get(property)
	return fallback
