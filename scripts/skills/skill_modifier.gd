extends RefCounted
class_name SkillModifierCalculator


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")


static func calculate(base_value: Variant, stat_name: String, modifiers: Dictionary) -> Variant:
	var flat_modifiers: Dictionary = ModifierSourceScript.flatten(modifiers)
	var override_key: String = "%s_override" % stat_name
	if flat_modifiers.has(override_key):
		return flat_modifiers[override_key]

	if not _is_number(base_value):
		return base_value

	var value: float = float(base_value)
	value += float(flat_modifiers.get("%s_add" % stat_name, 0.0))
	if stat_name != "cooldown":
		value *= 1.0 + float(flat_modifiers.get("%s_multiplier_add" % stat_name, 0.0))
		value *= float(flat_modifiers.get("%s_multiplier" % stat_name, 1.0))
	return _match_number_type(value, base_value)


static func merge_modifiers(target: Dictionary, source: Dictionary) -> Dictionary:
	return ModifierSourceScript.merge_flat_values(target, ModifierSourceScript.flatten(source))


static func run_tests() -> void:
	print("[SkillModifierCalculator] damage: ", calculate(100, "damage", {
		"damage_add": 20,
		"damage_multiplier_add": 0.5
	}))
	print("[SkillModifierCalculator] area_radius: ", calculate(48.0, "area_radius", {
		"area_radius_multiplier_add": 0.25
	}))
	print("[SkillModifierCalculator] projectile_count: ", calculate(1, "projectile_count", {
		"projectile_count_add": 2
	}))
	print("[SkillModifierCalculator] override: ", calculate(100, "damage", {
		"damage_add": 20,
		"damage_multiplier_add": 0.5,
		"damage_override": 7
	}))


static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


static func _match_number_type(value: float, original_value: Variant) -> Variant:
	if typeof(original_value) == TYPE_INT:
		return roundi(value)

	return value
