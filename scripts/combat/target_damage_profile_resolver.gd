## 文件用途：从目标属性、player组和enemy_rank解析统一防御与规则快照。
## 使用方式：每次伤害计算建立上下文时调用 resolve；缺少目标也返回普通目标默认快照。
extends RefCounted
class_name TargetDamageProfileResolver


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileScript: Script = preload("res://scripts/combat/target_damage_profile.gd")


## 作用：读取护甲、防御和复制抗性，按阶级补易伤边界、百分比上限及来源承伤表。
## 使用：target 可空；返回独立快照，can_receive_reaction 对玩家关闭。
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


## 作用：优先按player组识别玩家，否则读取enemy_rank元数据。
## 使用：空目标返回 normal。
static func _target_class(target: Node) -> String:
	if target == null:
		return "normal"
	if target.is_in_group(&"player"):
		return "player"
	return String(target.get_meta("enemy_rank", "normal"))


## 作用：读取对象属性并转为浮点值，缺失对象或属性时使用默认值。
## 使用：object/property/fallback 指定对象、属性名和缺失值，供伤害或配置计算使用。
static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	var value: Variant = _get_property(object, property, fallback)
	if value == null:
		return fallback
	return float(value)


## 作用：查找对象属性列表中匹配的属性，找不到时返回默认值。
## 使用：用于可选属性访问，避免对没有该属性的对象直接读取。
static func _get_property(object: Object, property: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return object.get(property)
	return fallback
