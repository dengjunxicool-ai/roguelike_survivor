extends RefCounted
class_name TargetDamageProfileResolver


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileScript: Script = preload("res://scripts/combat/target_damage_profile.gd")


static func resolve(target: Node) -> RefCounted:
	var profile: RefCounted = TargetDamageProfileScript.new()
	var target_class: String = _target_class(target)
	profile.target_type = StringName(target_class)
	profile.armor = _get_float_property(target, "armor", 0.0)
	profile.defense = _get_float_property(target, "defense", profile.armor)
	var resistances_variant: Variant = _get_property(target, "resistances", {})
	if resistances_variant is Dictionary:
		profile.resistances = (resistances_variant as Dictionary).duplicate(true)
	var bounds: Dictionary = DamageRuleRegistryScript.vulnerability_bounds(target_class)
	profile.vulnerability_floor = float(bounds.get("floor", -0.60))
	profile.vulnerability_cap = float(bounds.get("cap", 0.30))
	profile.true_percent_cap = DamageRuleRegistryScript.true_percent_default_cap(target_class)
	profile.incoming_damage_reduction = clampf(_get_float_property(target, "player_damage_reduction_total", 0.0), 0.0, 0.95)
	profile.can_receive_reaction = target_class != "player"
	profile.origin_taken_modifiers = DamageRuleRegistryScript.target_origin_taken_modifiers(target_class)
	return profile


static func _target_class(target: Node) -> String:
	if target == null:
		return "normal"
	if target.is_in_group(&"player"):
		return "player"
	if target.is_in_group(&"bosses") or bool(target.get_meta("is_boss", false)) or String(target.get_meta("enemy_rank", "")) == "boss":
		return "boss"
	if target.is_in_group(&"elites") or bool(target.get_meta("is_elite", false)) or String(target.get_meta("enemy_rank", "")) == "elite":
		return "elite"
	return String(target.get_meta("enemy_rank", target.get_meta("enemy_type", "normal")))


static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	var value: Variant = _get_property(object, property, fallback)
	if value == null:
		return fallback
	return float(value)


static func _get_property(object: Object, property: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return object.get(property)
	return fallback
