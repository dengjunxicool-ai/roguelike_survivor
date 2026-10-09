## 文件用途：按覆盖、加法及倍率规则计算属性，并合并平铺 Modifier 快照。
## 使用方式：静态 calculate 接收基础值和属性名；cooldown 在这里仅处理覆盖和加法，速度换算由 SkillStatService 完成。
extends RefCounted
class_name SkillModifierCalculator


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")


## 作用：对基础数值先处理覆盖再加法与倍率，并保持整数或浮点类型。
## 使用：base_value 为修饰前数值；stat_name 为待查询属性键。
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


## 作用：展开来源快照并按统一加法、倍率和覆盖语义原地合并。
## 使用：target 为本次命中目标；source 为来源数据或对象。
static func merge_modifiers(target: Dictionary, source: Dictionary) -> Dictionary:
	return ModifierSourceScript.merge_flat_values(target, ModifierSourceScript.flatten(source))


## 作用：打印属性计算示例结果，供手工检查加法、范围、弹数和覆盖行为。
## 使用：静态 calculate 接收基础值和属性名；cooldown 在这里仅处理覆盖和加法，速度换算由 SkillStatService 完成。
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


## 作用：严格判断 Variant 是否为 int 或 float，不把布尔或字符串当数值。
## 使用：由本文件 calculate 调用。
static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


## 作用：以原始数值类型决定返回浮点或四舍五入后的整数。
## 使用：由本文件 calculate 调用。
static func _match_number_type(value: float, original_value: Variant) -> Variant:
	if typeof(original_value) == TYPE_INT:
		return roundi(value)

	return value
