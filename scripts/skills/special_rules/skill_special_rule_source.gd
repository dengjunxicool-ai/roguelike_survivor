extends RefCounted
class_name SkillSpecialRuleSource


const RUNTIME_MODIFIER_RULE_KEYS: Array[String] = [
	"burn_damage_multiplier_add",
	"burn_duration_add",
	"burn_max_stacks_add",
	"boss_burn_max_stacks_add",
	"burn_move_speed_multiplier_add_per_stack",
	"lava_duration_add",
	"lava_radius_multiplier_add"
]


static func get_rules(skill_instance: RefCounted) -> Dictionary:
	if skill_instance == null:
		return {}
	var result: Dictionary = {}
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition != null:
		var base_rules_value: Variant = definition.get("base_special_rules")
		if base_rules_value is Dictionary:
			var base_rules: Dictionary = base_rules_value
			for key_variant: Variant in base_rules.keys():
				result[String(key_variant)] = base_rules[key_variant]
	var modifiers_variant: Variant = skill_instance.get("runtime_modifiers")
	if modifiers_variant is Dictionary:
		var modifiers: Dictionary = modifiers_variant
		for key: String in RUNTIME_MODIFIER_RULE_KEYS:
			if modifiers.has(key):
				result[key] = modifiers[key]
	var value: Variant = skill_instance.get("runtime_special_rules")
	if value is Dictionary:
		var special_rules: Dictionary = value
		for key_variant: Variant in special_rules.keys():
			result[String(key_variant)] = special_rules[key_variant]
	return result
