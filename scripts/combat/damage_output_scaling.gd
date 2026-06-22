extends RefCounted
class_name DamageOutputScaling


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const ModifierKeyRegistryScript: Script = preload("res://scripts/modifiers/modifier_key_registry.gd")


static func character_damage_multiplier(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	if not bool(packet.get("uses_character_damage_multiplier", false)):
		return 1.0
	if packet.has("character_damage_multiplier"):
		return maxf(float(packet["character_damage_multiplier"]), 0.0)
	var multiplier: float = 1.0
	if attacker != null:
		multiplier = _get_float_property(attacker, "damage_multiplier", 1.0)
	multiplier *= maxf(_get_modifier_float(damage_modifiers, "damage_multiplier", 1.0), 0.0)
	multiplier += _get_modifier_float(damage_modifiers, "damage_multiplier_add", 0.0)
	return maxf(multiplier, 0.0)


static func character_damage_multiplier_for_context(calculation_context: RefCounted) -> float:
	if not bool(calculation_context.call("packet_value", "uses_character_damage_multiplier", false)):
		return 1.0
	if bool(calculation_context.call("packet_has", "character_damage_multiplier")):
		return maxf(float(calculation_context.call("packet_value", "character_damage_multiplier", 0.0)), 0.0)
	var attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var multiplier: float = 1.0
	if attacker != null:
		multiplier = _get_float_property(attacker, "damage_multiplier", 1.0)
	multiplier *= maxf(_get_modifier_float(damage_modifiers, "damage_multiplier", 1.0), 0.0)
	multiplier += _get_modifier_float(damage_modifiers, "damage_multiplier_add", 0.0)
	return maxf(multiplier, 0.0)


static func skill_level_coefficient(packet: Dictionary) -> float:
	if not bool(packet.get("uses_skill_level_coefficient", false)):
		return 1.0
	if not packet.has("skill_level_coefficient"):
		push_warning("[DamageSystem] DamagePacket missing skill_level_coefficient; defaulting to 1.0 for %s." % String(packet.get("source_skill_id", packet.get("source_id", ""))))
		return 1.0
	return maxf(float(packet.get("skill_level_coefficient", 1.0)), 0.0)


static func skill_level_coefficient_for_context(calculation_context: RefCounted) -> float:
	if not bool(calculation_context.call("packet_value", "uses_skill_level_coefficient", false)):
		return 1.0
	if not bool(calculation_context.call("packet_has", "skill_level_coefficient")):
		push_warning("[DamageSystem] DamagePacket missing skill_level_coefficient; defaulting to 1.0 for %s." % String(calculation_context.call("packet_value", "source_skill_id", calculation_context.call("packet_value", "source_id", ""))))
		return 1.0
	return maxf(float(calculation_context.call("packet_value", "skill_level_coefficient", 1.0)), 0.0)


static func origin_bonus_total(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	var origin: String = String(packet.get("damage_origin", ""))
	var total: float = float(packet.get("origin_bonus_total", 0.0))
	for key: String in DamageRuleRegistryScript.origin_bonus_keys(origin):
		total += float(packet.get(key, 0.0))
		total += _get_modifier_float(damage_modifiers, key, 0.0)
		if attacker != null:
			total += _get_float_property(attacker, key, 0.0)
	return total


static func origin_bonus_total_for_context(calculation_context: RefCounted) -> float:
	var attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var origin: String = String(calculation_context.call("packet_value", "damage_origin", ""))
	var total: float = float(calculation_context.call("packet_value", "origin_bonus_total", 0.0))
	for key: String in DamageRuleRegistryScript.origin_bonus_keys(origin):
		total += float(calculation_context.call("packet_value", key, 0.0))
		total += _get_modifier_float(damage_modifiers, key, 0.0)
		if attacker != null:
			total += _get_float_property(attacker, key, 0.0)
	return total


static func element_bonus_total(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	var element: String = String(packet.get("element", ""))
	var total: float = float(packet.get("element_bonus_total", 0.0))
	var key: String = ModifierKeyRegistryScript.element_bonus_key(element)
	total += float(packet.get(key, 0.0))
	total += _get_modifier_float(damage_modifiers, key, 0.0)
	if attacker != null and element != "" and element != "neutral":
		total += _get_float_property(attacker, key, 0.0)
	return total


static func element_bonus_total_for_context(calculation_context: RefCounted) -> float:
	var attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var element: String = String(calculation_context.call("packet_value", "element", ""))
	var total: float = float(calculation_context.call("packet_value", "element_bonus_total", 0.0))
	var key: String = ModifierKeyRegistryScript.element_bonus_key(element)
	total += float(calculation_context.call("packet_value", key, 0.0))
	total += _get_modifier_float(damage_modifiers, key, 0.0)
	if attacker != null and element != "" and element != "neutral":
		total += _get_float_property(attacker, key, 0.0)
	return total


static func enemy_type_bonus_total(packet: Dictionary, attacker: Node, target: Node, damage_modifiers: Dictionary = {}) -> float:
	var rank: String = _get_target_class(target)
	var total: float = float(packet.get("enemy_type_bonus_total", 0.0))
	var key: String = DamageRuleRegistryScript.enemy_type_bonus_key(rank)
	if key != "":
		total += float(packet.get(key, 0.0))
		total += _get_modifier_float(damage_modifiers, key, 0.0)
		if attacker != null:
			total += _get_float_property(attacker, key, 0.0)
	return total


static func enemy_type_bonus_total_for_context(calculation_context: RefCounted) -> float:
	var attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var profile: RefCounted = calculation_context.get("target_profile")
	var rank: String = String(profile.get("target_type"))
	var total: float = float(calculation_context.call("packet_value", "enemy_type_bonus_total", 0.0))
	var key: String = DamageRuleRegistryScript.enemy_type_bonus_key(rank)
	if key != "":
		total += float(calculation_context.call("packet_value", key, 0.0))
		total += _get_modifier_float(damage_modifiers, key, 0.0)
		if attacker != null:
			total += _get_float_property(attacker, key, 0.0)
	return total


static func _get_target_class(target: Node) -> String:
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	return String(profile.get("target_type"))


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
