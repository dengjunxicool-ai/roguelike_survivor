## 文件用途：汇总目标元素抗性、状态易伤、控制加成及目标阶级来源承伤。
## 使用方式：普通伤害防御后应用抗性和易伤；来源承伤属于输出阶段且可能消耗Boss韧性窗口。
extends RefCounted
class_name DamageTargetMitigation


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")


## 作用：从目标快照计算元素承伤系数。
## 使用：neutral或空目标返回1；抗性限制在-75%至90%。
static func resistance_multiplier(target: Node, element: String) -> float:
	if element == "neutral" or target == null:
		return 1.0
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	return _resistance_multiplier_from_profile(profile, element)


## 作用：使用上下文目标快照计算元素抗性系数。
## 使用：不重新解析目标，neutral返回1。
static func resistance_multiplier_for_context(calculation_context: RefCounted) -> float:
	var target: Node = calculation_context.get("target") as Node
	var element: String = String(calculation_context.call("packet_value", "element", "neutral"))
	if element == "neutral" or target == null:
		return 1.0
	var profile: RefCounted = calculation_context.get("target_profile")
	return _resistance_multiplier_from_profile(profile, element)


## 作用：未忽略抗性时乘以元素系数并记录 after_resistance。
## 使用：输入防御后伤害，返回浮点值。
static func apply_resistance_stage(calculation_context: RefCounted, after_defense: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var after_resistance: float = after_defense
	if not bool(calculation_context.call("packet_value", "ignore_resistance", false)):
		after_resistance *= resistance_multiplier_for_context(calculation_context)
	stages["after_resistance"] = after_resistance
	return after_resistance


## 作用：累加包、状态管理器和目标承伤倍率后按阶级裁剪易伤。
## 使用：支持状态管理器的易伤接口或倍率接口；返回加法总量。
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
	total += _controlled_target_damage_taken_total(target, {})

	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	return clampf(total, float(profile.get("vulnerability_floor")), float(profile.get("vulnerability_cap")))


## 作用：用上下文合并易伤并加入攻击者对受控目标的modifier。
## 使用：返回按快照上下限裁剪的加法总量。
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
	total += _controlled_target_damage_taken_total(target, calculation_context.get("damage_modifiers"))

	var profile: RefCounted = calculation_context.get("target_profile")
	return clampf(total, float(profile.get("vulnerability_floor")), float(profile.get("vulnerability_cap")))


## 作用：未忽略易伤时乘以非负的1+易伤总量。
## 使用：输入抗性后伤害并记录 after_vulnerability。
static func apply_vulnerability_stage(calculation_context: RefCounted, after_resistance: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var after_vulnerability: float = after_resistance
	if not bool(calculation_context.call("packet_value", "ignore_vulnerability", false)):
		after_vulnerability *= maxf(1.0 + vulnerability_total_for_context(calculation_context), 0.0)
	stages["after_vulnerability"] = after_vulnerability
	return after_vulnerability


## 作用：查目标来源承伤系数并尝试消耗Boss重大反应韧性奖励。
## 使用：ignore开关返回1；此查询可能清除韧性奖励窗口。
static func target_class_origin_modifier(packet: Dictionary, target: Node) -> float:
	if bool(packet.get("ignore_target_class_origin_modifier", false)):
		return 1.0
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	var origin: String = String(packet.get("damage_origin", ""))
	var damage_type: String = String(packet.get("damage_type", ""))
	var modifier: float = DamageRuleRegistryScript.origin_taken_modifier_from_map(profile.get("origin_taken_modifiers"), origin, damage_type)
	modifier *= ReactionLimiterScript.consume_boss_poise_bonus(target, packet)
	return modifier


## 作用：用目标快照查询来源系数并消费符合条件的Boss韧性奖励。
## 使用：输出阶段每次伤害只应调用一次。
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


## 作用：按优先抗性键读取元素抗性并应用酸借毒缩放与上下限。
## 使用：返回1-抗性，空表返回1。
static func _resistance_multiplier_from_profile(profile: RefCounted, element: String) -> float:
	var resistances: Dictionary = profile.get("resistances")
	if resistances.is_empty():
		return 1.0
	var resistance: float = _read_resistance(resistances, DamageRuleRegistryScript.resistance_keys(element, resistances))
	resistance *= DamageRuleRegistryScript.resistance_scale(element, resistances)
	resistance = clampf(resistance, -0.75, 0.90)
	return 1.0 - resistance


## 作用：返回第一个存在的抗性键数值。
## 使用：keys 按优先级排列，均缺失返回0。
static func _read_resistance(resistances: Dictionary, keys: Array[String]) -> float:
	for key: String in keys:
		if resistances.has(key):
			return float(resistances.get(key, 0.0))
	return 0.0


## 作用：读取对象属性并转为浮点值，缺失对象或属性时使用默认值。
## 使用：object/property/fallback 指定对象、属性名和缺失值，供伤害或配置计算使用。
static func _get_float_property(node: Object, property_name: String, fallback: float = 0.0) -> float:
	if node == null:
		return fallback
	var value: Variant = node.get(property_name)
	if value == null:
		return fallback
	return float(value)


## 作用：目标具有冰冻、定身或眩晕时读取对应伤害加成。
## 使用：target和damage_modifiers必须有效，返回加法总量。
static func _controlled_target_damage_taken_total(target: Node, damage_modifiers: Dictionary) -> float:
	if target == null or damage_modifiers.is_empty():
		return 0.0
	var total: float = 0.0
	if _target_has_any_status(target, [&"frozen", &"root", &"stun"]):
		total += float(damage_modifiers.get("frozen_damage_taken_multiplier_add", 0.0))
	return total


## 作用：从目标公开接口或StatusEffectManager检查任一状态。
## 使用：status_ids 为候选列表，找到一个即返回true。
static func _target_has_any_status(target: Node, status_ids: Array) -> bool:
	if target == null:
		return false
	for status_variant: Variant in status_ids:
		var status_id: StringName = StringName(str(status_variant))
		if status_id == &"":
			continue
		if target.has_method("has_status") and bool(target.call("has_status", status_id)):
			return true
		var status_manager: Node = target.get_node_or_null("StatusEffectManager")
		if status_manager != null and status_manager.has_method("has_status") and bool(status_manager.call("has_status", status_id)):
			return true
	return false
