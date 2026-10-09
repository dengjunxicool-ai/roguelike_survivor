## 文件用途：按基础规则、受支持的运行属性键和运行特殊规则顺序构建当前有效规则。
## 使用方式：宿主调用 get_rules 传 SkillInstance；后加入的同名规则覆盖之前的值，空实例返回空字典。
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


## 作用：按基础规则、允许的运行属性和运行特殊规则顺序构建有效规则，同键后者覆盖。
## 使用：skill_instance 为技能运行实例；无适用数据时返回空字典。
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
