extends RefCounted
class_name DamageTargetMitigation


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")


static func resistance_multiplier(target: Node, element: String) -> float:
	if element == "neutral" or target == null:
		return 1.0
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	return _resistance_multiplier_from_profile(profile, element)


static func resistance_multiplier_for_context(calculation_context: RefCounted) -> float:
	var target: Node = calculation_context.get("target") as Node
	var element: String = String(calculation_context.call("packet_value", "element", "neutral"))
	if element == "neutral" or target == null:
		return 1.0
	var profile: RefCounted = calculation_context.get("target_profile")
	return _resistance_multiplier_from_profile(profile, element)


static func apply_resistance_stage(calculation_context: RefCounted, after_defense: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var after_resistance: float = after_defense
	if not bool(calculation_context.call("packet_value", "ignore_resistance", false)):
		after_resistance *= resistance_multiplier_for_context(calculation_context)
	stages["after_resistance"] = after_resistance
	return after_resistance


static func vulnerability_total(target: Node, packet: Dictionary) -> float:
	var total: float = float(packet.get("vulnerability_total", 0.0))
	var manager: Node = target.get_node_or_null("StatusEffectManager") if target != null else null
	if manager != null:
		if manager.has_method("get_vulnerability_total"):
			total += float(manager.call("get_vulnerability_total", packet.get("element", &""), packet.get("damage_type", &""), packet))
		elif manager.has_method("get_damage_taken_multiplier"):
			total += float(manager.call("get_damage_taken_multiplier", packet.get("element", &""), packet.get("damage_type", &""))) - 1.0

	var damage_taken_multiplier: float = _get_float_property(target, "damage_taken_multiplier", 1.0)
	if damage_taken_multiplier > 0.0:
		total += damage_taken_multiplier - 1.0

	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	return clampf(total, float(profile.get("vulnerability_floor")), float(profile.get("vulnerability_cap")))


static func vulnerability_total_for_context(calculation_context: RefCounted) -> float:
	var target: Node = calculation_context.get("target") as Node
	var total: float = float(calculation_context.call("packet_value", "vulnerability_total", 0.0))
	var manager: Node = target.get_node_or_null("StatusEffectManager") if target != null else null
	if manager != null:
		var element: Variant = calculation_context.call("packet_value", "element", &"")
		var damage_type: Variant = calculation_context.call("packet_value", "damage_type", &"")
		if manager.has_method("get_vulnerability_total"):
			total += float(manager.call("get_vulnerability_total", element, damage_type, calculation_context))
		elif manager.has_method("get_damage_taken_multiplier"):
			total += float(manager.call("get_damage_taken_multiplier", element, damage_type)) - 1.0

	var damage_taken_multiplier: float = _get_float_property(target, "damage_taken_multiplier", 1.0)
	if damage_taken_multiplier > 0.0:
		total += damage_taken_multiplier - 1.0

	var profile: RefCounted = calculation_context.get("target_profile")
	return clampf(total, float(profile.get("vulnerability_floor")), float(profile.get("vulnerability_cap")))


static func apply_vulnerability_stage(calculation_context: RefCounted, after_resistance: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var after_vulnerability: float = after_resistance
	if not bool(calculation_context.call("packet_value", "ignore_vulnerability", false)):
		after_vulnerability *= maxf(1.0 + vulnerability_total_for_context(calculation_context), 0.0)
	stages["after_vulnerability"] = after_vulnerability
	return after_vulnerability


static func target_class_origin_modifier(packet: Dictionary, target: Node) -> float:
	if bool(packet.get("ignore_target_class_origin_modifier", false)):
		return 1.0
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	var origin: String = String(packet.get("damage_origin", ""))
	var damage_type: String = String(packet.get("damage_type", ""))
	var modifier: float = DamageRuleRegistryScript.origin_taken_modifier_from_map(profile.get("origin_taken_modifiers"), origin, damage_type)
	modifier *= ReactionLimiterScript.consume_boss_poise_bonus(target, packet)
	return modifier


static func target_class_origin_modifier_for_context(calculation_context: RefCounted) -> float:
	if bool(calculation_context.call("packet_value", "ignore_target_class_origin_modifier", false)):
		return 1.0
	var target: Node = calculation_context.get("target") as Node
	var profile: RefCounted = calculation_context.get("target_profile")
	var origin: String = String(calculation_context.call("packet_value", "damage_origin", ""))
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", ""))
	var modifier: float = DamageRuleRegistryScript.origin_taken_modifier_from_map(profile.get("origin_taken_modifiers"), origin, damage_type)
	modifier *= ReactionLimiterScript.consume_boss_poise_bonus_for_context(calculation_context, target)
	return modifier


static func _resistance_multiplier_from_profile(profile: RefCounted, element: String) -> float:
	var resistances: Dictionary = profile.get("resistances")
	if resistances.is_empty():
		return 1.0
	var resistance: float = _read_resistance(resistances, DamageRuleRegistryScript.resistance_keys(element, resistances))
	resistance *= DamageRuleRegistryScript.resistance_scale(element, resistances)
	resistance = clampf(resistance, -0.75, 0.90)
	return 1.0 - resistance


static func _read_resistance(resistances: Dictionary, keys: Array[String]) -> float:
	for key: String in keys:
		if resistances.has(key):
			return float(resistances.get(key, 0.0))
	return 0.0


static func _get_float_property(node: Object, property_name: String, fallback: float = 0.0) -> float:
	if node == null:
		return fallback
	var value: Variant = node.get(property_name)
	if value == null:
		return fallback
	return float(value)
