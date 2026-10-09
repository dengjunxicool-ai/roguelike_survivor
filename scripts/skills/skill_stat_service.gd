## 文件用途：汇总技能属性来源并在基础计算后应用范围别名及玩家速度、范围、状态时长修正。
## 使用方式：get_effective_stat 从定义读取基础值，calculate_value 修饰指定值；标签查询同时考虑定义和运行标签。
extends RefCounted
class_name SkillStatService


const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")


## 作用：从定义基础值计算实例属性，合并运行属性；缺定义返回零。
## 使用：skill_instance 为技能运行实例；stat_name 为待查询属性键；default_value 为缺值备用结果。
static func get_effective_stat(
	skill_instance: RefCounted,
	stat_name: String,
	default_value: Variant = 0,
	skill_manager: Node = null,
	relic_manager: Node = null,
	caster: Node = null
) -> Variant:
	var definition: RefCounted = _get_definition(skill_instance)
	if definition == null:
		return default_value

	var base_value: Variant = definition.call("get_base_stat", stat_name, default_value)
	return calculate_value(skill_instance, stat_name, base_value, skill_manager, relic_manager, caster)


## 作用：先应用统一属性计算，再处理数值别名和玩家攻速、范围与时长修正。
## 使用：skill_instance 为技能运行实例；stat_name 为待查询属性键；base_value 为修饰前数值。
static func calculate_value(
	skill_instance: RefCounted,
	stat_name: String,
	base_value: Variant,
	skill_manager: Node = null,
	relic_manager: Node = null,
	caster: Node = null
) -> Variant:
	var modifiers: Dictionary = get_combined_modifiers(skill_instance, skill_manager, relic_manager, caster)
	var value: Variant = SkillModifierCalculatorScript.calculate(base_value, stat_name, modifiers)

	if _is_number(value):
		value = _apply_alias_modifiers(value, stat_name, modifiers)
		value = _apply_caster_modifiers(value, stat_name, modifiers, skill_instance, caster)

	return value


## 作用：构建技能查询并汇总运行、被动、特性与遗物属性。
## 使用：skill_instance 为技能运行实例；skill_manager 为技能管理器；relic_manager 为遗物管理器。
static func get_combined_modifiers(skill_instance: RefCounted, skill_manager: Node = null, relic_manager: Node = null, caster: Node = null) -> Dictionary:
	return ModifierAggregatorScript.collect(ModifierQueryScript.for_skill(skill_instance, caster), skill_manager, relic_manager)


## 作用：优先读定义基础 damage_type，缺失时按元素标签查找伤害类型。
## 使用：skill_instance 为技能运行实例。
static func get_damage_type(skill_instance: RefCounted) -> StringName:
	var definition: RefCounted = _get_definition(skill_instance)
	if definition == null or not definition.has_method("has_tag"):
		return &""

	if definition.has_method("get_base_stat"):
		var configured_damage_type: String = String(definition.call("get_base_stat", "damage_type", ""))
		if configured_damage_type != "":
			return StringName(configured_damage_type)

	for damage_type: String in ["physical", "poison", "fire", "ice", "lightning"]:
		if bool(definition.call("has_tag", damage_type)):
			return StringName(damage_type)

	return &""


## 作用：先检查定义标签，再检查实例运行标签，兼容 String 与 StringName。
## 使用：skill_instance 为技能运行实例；返回布尔判断或执行是否成功。
static func skill_has_tag(skill_instance: RefCounted, tag: String) -> bool:
	var definition: RefCounted = _get_definition(skill_instance)
	if definition != null and definition.has_method("has_tag") and bool(definition.call("has_tag", tag)):
		return true

	var runtime_tags_variant: Variant = skill_instance.get("runtime_tags") if skill_instance != null else []
	if runtime_tags_variant is Array:
		var runtime_tags: Array = runtime_tags_variant
		return runtime_tags.has(tag) or runtime_tags.has(StringName(tag))

	return false


## 作用：将 area_radius 的旧运行别名倍率合并到最终范围值，并保持数字类型。
## 使用：stat_name 为待查询属性键。
static func _apply_alias_modifiers(value: Variant, stat_name: String, modifiers: Dictionary) -> Variant:
	var adjusted_value: float = float(value)
	if stat_name == "area_radius":
		adjusted_value *= float(modifiers.get("area_multiplier", 1.0))
		adjusted_value *= maxf(1.0 + float(modifiers.get("area_multiplier_add", 0.0)), 0.05)

	return _match_number_type(adjusted_value, value)


## 作用：按玩家攻速换算冷却，并应用陷阱间隔、技能范围或状态时长系数。
## 使用：stat_name 为待查询属性键；skill_instance 为技能运行实例；caster 为施法者节点。
static func _apply_caster_modifiers(value: Variant, stat_name: String, modifiers: Dictionary, skill_instance: RefCounted, caster: Node) -> Variant:
	if caster == null:
		return value

	var adjusted_value: float = float(value)
	match stat_name:
		"cooldown":
			var attack_speed_multiplier: float = _get_effective_attack_speed_multiplier(caster, modifiers)
			adjusted_value /= attack_speed_multiplier
			if skill_has_tag(skill_instance, "trap"):
				adjusted_value *= maxf(1.0 + float(modifiers.get("trap_interval_multiplier_add", 0.0)), 0.05)
		"area_radius":
			adjusted_value *= maxf(_get_float_property(caster, "skill_area_multiplier", 1.0), 0.05)
		"status_duration":
			adjusted_value *= maxf(_get_float_property(caster, "status_duration_multiplier", 1.0), 0.05)

	return _match_number_type(adjusted_value, value)


## 作用：组合玩家攻速和查询快照的乘法、加法攻速修正，并保留最低倍率。
## 使用：caster 为施法者节点。
static func _get_effective_attack_speed_multiplier(caster: Node, modifiers: Dictionary) -> float:
	var attack_speed_multiplier: float = maxf(_get_float_property(caster, "attack_speed_multiplier", 1.0), 0.05)
	attack_speed_multiplier *= maxf(float(modifiers.get("attack_speed_multiplier", 1.0)), 0.05)
	attack_speed_multiplier += float(modifiers.get("attack_speed_multiplier_add", 0.0))
	return maxf(attack_speed_multiplier, 0.1)


## 作用：读取对象浮点属性，空对象或缺值时使用默认值。
## 使用：fallback 为缺值备用结果。
static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	if object == null:
		return fallback
	var value: Variant = object.get(property)
	if value == null:
		return fallback
	return float(value)


## 作用：从技能实例读取定义引用，空实例返回 null。
## 使用：skill_instance 为技能运行实例；无法解析或创建时返回 null。
static func _get_definition(skill_instance: RefCounted) -> RefCounted:
	if skill_instance == null:
		return null

	return skill_instance.get("definition") as RefCounted


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：get_effective_stat 从定义读取基础值，calculate_value 修饰指定值；标签查询同时考虑定义和运行标签；无适用数据时返回空字典。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary

	return {}


## 作用：严格判断 Variant 是否为 int 或 float，不把布尔或字符串当数值。
## 使用：由本文件 calculate_value 调用。
static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


## 作用：以原始数值类型决定返回浮点或四舍五入后的整数。
## 使用：由本文件 _apply_alias_modifiers/_apply_caster_modifiers 调用。
static func _match_number_type(value: float, original_value: Variant) -> Variant:
	if typeof(original_value) == TYPE_INT:
		return roundi(value)

	return value
