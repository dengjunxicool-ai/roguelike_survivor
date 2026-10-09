## 文件用途：解析预先确定或随机判定的暴击并记录暴击前后值。
## 使用方式：普通伤害管线输出倍率后使用，不能在同一次命中重复判定暴击。
extends RefCounted
class_name DamageCriticalResolver


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")


## 作用：优先沿用已确定暴击，否则合并攻击者和modifier暴击率随机判定并放大输出。
## 使用：outgoing 为未减伤输出；返回暴击标记、倍率和 pre_mitigation，并写入 stages。
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


## 作用：按伤害类型与包开关检查能否暴击。
## 使用：真伤、百分比伤害和状态DOT始终不允许。
static func can_crit(packet: Dictionary) -> bool:
	return DamageRuleRegistryScript.can_crit(packet)


## 作用：从计算上下文检查类型与 can_crit 开关。
## 使用：用于公式管线，查询本身不消耗随机数。
static func can_crit_for_context(calculation_context: RefCounted) -> bool:
	return DamageRuleRegistryScript.can_crit_for_context(calculation_context)


## 作用：读取对象属性并转为浮点值，缺失对象或属性时使用默认值。
## 使用：object/property/fallback 指定对象、属性名和缺失值，供伤害或配置计算使用。
static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	var value: Variant = _get_property(object, property, fallback)
	if value == null:
		return fallback
	return float(value)


## 作用：读取聚合 modifier 快照中的数值，缺少键时使用默认值。
## 使用：modifiers 是已聚合字典，key 指定属性，fallback 指定中性值。
static func _get_modifier_float(modifiers: Dictionary, key: String, fallback: float) -> float:
	if modifiers.is_empty() or not modifiers.has(key):
		return fallback
	return float(modifiers.get(key, fallback))


## 作用：查找对象属性列表中匹配的属性，找不到时返回默认值。
## 使用：用于可选属性访问，避免对没有该属性的对象直接读取。
static func _get_property(object: Object, property: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return object.get(property)
	return fallback
