## 文件用途：汇总角色、技能等级、来源、元素和目标阶级输出系数。
## 使用方式：DamageSystem 的 outgoing 阶段读取；只计算倍率/加成，不扣血。
extends RefCounted
class_name DamageOutputScaling


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const ModifierKeyRegistryScript: Script = preload("res://scripts/modifiers/modifier_key_registry.gd")


## 作用：按开关优先使用包内倍率，否则合并攻击者属性与modifier倍率和加法。
## 使用：返回非负系数，未启用角色倍率时返回1。
static func character_damage_multiplier(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	if not bool(packet.get("uses_character_damage_multiplier", false)):
		return 1.0
	if packet.has("character_damage_multiplier"):
		return maxf(float(packet["character_damage_multiplier"]), 0.0)
	var multiplier: float = 1.0
	if attacker != null:
		multiplier = _get_float_property(attacker, "damage_multiplier", 1.0)
	multiplier *= maxf(_get_modifier_float(damage_modifiers, "damage_multiplier", 1.0), 0.0)
	multiplier += _get_modifier_float(damage_modifiers, "damage_multiplier_add", 0.0)
	return maxf(multiplier, 0.0)


## 作用：从上下文读取角色倍率开关、攻击者及聚合modifier快照。
## 使用：返回与字典入口一致的输出系数，不刷新modifier。
static func character_damage_multiplier_for_context(calculation_context: RefCounted) -> float:
	if not bool(calculation_context.call("packet_value", "uses_character_damage_multiplier", false)):
		return 1.0
	if bool(calculation_context.call("packet_has", "character_damage_multiplier")):
		return maxf(float(calculation_context.call("packet_value", "character_damage_multiplier", 0.0)), 0.0)
	var attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var multiplier: float = 1.0
	if attacker != null:
		multiplier = _get_float_property(attacker, "damage_multiplier", 1.0)
	multiplier *= maxf(_get_modifier_float(damage_modifiers, "damage_multiplier", 1.0), 0.0)
	multiplier += _get_modifier_float(damage_modifiers, "damage_multiplier_add", 0.0)
	return maxf(multiplier, 0.0)


## 作用：读取启用后的技能等级系数，缺失时警告并返回1。
## 使用：包未启用等级缩放时返回1，显式值限制为非负。
static func skill_level_coefficient(packet: Dictionary) -> float:
	if not bool(packet.get("uses_skill_level_coefficient", false)):
		return 1.0
	if not packet.has("skill_level_coefficient"):
		push_warning("[DamageSystem] DamagePacket missing skill_level_coefficient; defaulting to 1.0 for %s." % String(packet.get("source_skill_id", packet.get("source_id", ""))))
		return 1.0
	return maxf(float(packet.get("skill_level_coefficient", 1.0)), 0.0)


## 作用：从上下文查询技能等级缩放并诊断缺失系数。
## 使用：返回非负倍率，未启用时返回1。
static func skill_level_coefficient_for_context(calculation_context: RefCounted) -> float:
	if not bool(calculation_context.call("packet_value", "uses_skill_level_coefficient", false)):
		return 1.0
	if not bool(calculation_context.call("packet_has", "skill_level_coefficient")):
		push_warning("[DamageSystem] DamagePacket missing skill_level_coefficient; defaulting to 1.0 for %s." % String(calculation_context.call("packet_value", "source_skill_id", calculation_context.call("packet_value", "source_id", ""))))
		return 1.0
	return maxf(float(calculation_context.call("packet_value", "skill_level_coefficient", 1.0)), 0.0)


## 作用：累加来源专属键在包、modifier和攻击者中的加成。
## 使用：packet 决定 damage_origin；返回加法总量，调用方再转为1+总量。
static func origin_bonus_total(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	var origin: String = String(packet.get("damage_origin", ""))
	var total: float = float(packet.get("origin_bonus_total", 0.0))
	for key: String in DamageRuleRegistryScript.origin_bonus_keys(origin):
		total += float(packet.get(key, 0.0))
		total += _get_modifier_float(damage_modifiers, key, 0.0)
		if attacker != null:
			total += _get_float_property(attacker, key, 0.0)
	return total


## 作用：使用上下文的来源、攻击者与modifier累加来源伤害加成。
## 使用：返回加法总量，不直接乘以伤害。
static func origin_bonus_total_for_context(calculation_context: RefCounted) -> float:
	var attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var origin: String = String(calculation_context.call("packet_value", "damage_origin", ""))
	var total: float = float(calculation_context.call("packet_value", "origin_bonus_total", 0.0))
	for key: String in DamageRuleRegistryScript.origin_bonus_keys(origin):
		total += float(calculation_context.call("packet_value", key, 0.0))
		total += _get_modifier_float(damage_modifiers, key, 0.0)
		if attacker != null:
			total += _get_float_property(attacker, key, 0.0)
	return total


## 作用：汇总元素对应键在包、modifier和攻击者中的加成。
## 使用：中性或空元素不读取攻击者元素属性；返回加法总量。
static func element_bonus_total(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	var element: String = String(packet.get("element", ""))
	var total: float = float(packet.get("element_bonus_total", 0.0))
	var key: String = ModifierKeyRegistryScript.element_bonus_key(element)
	total += float(packet.get(key, 0.0))
	total += _get_modifier_float(damage_modifiers, key, 0.0)
	if attacker != null and element != "" and element != "neutral":
		total += _get_float_property(attacker, key, 0.0)
	return total


## 作用：按上下文元素汇总元素加成。
## 使用：使用 ModifierKeyRegistry 的元素键，返回加法总量。
static func element_bonus_total_for_context(calculation_context: RefCounted) -> float:
	var attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var element: String = String(calculation_context.call("packet_value", "element", ""))
	var total: float = float(calculation_context.call("packet_value", "element_bonus_total", 0.0))
	var key: String = ModifierKeyRegistryScript.element_bonus_key(element)
	total += float(calculation_context.call("packet_value", key, 0.0))
	total += _get_modifier_float(damage_modifiers, key, 0.0)
	if attacker != null and element != "" and element != "neutral":
		total += _get_float_property(attacker, key, 0.0)
	return total


## 作用：按目标 enemy_rank 选择普通/精英/Boss加成键并累加。
## 使用：target 为受击节点，返回包、modifier和攻击者的加法总量。
static func enemy_type_bonus_total(packet: Dictionary, attacker: Node, target: Node, damage_modifiers: Dictionary = {}) -> float:
	var rank: String = _get_target_class(target)
	var total: float = float(packet.get("enemy_type_bonus_total", 0.0))
	var key: String = DamageRuleRegistryScript.enemy_type_bonus_key(rank)
	if key != "":
		total += float(packet.get(key, 0.0))
		total += _get_modifier_float(damage_modifiers, key, 0.0)
		if attacker != null:
			total += _get_float_property(attacker, key, 0.0)
	return total


## 作用：依据目标快照分类汇总目标阶级伤害加成。
## 使用：不重新查询目标分类；返回加法总量。
static func enemy_type_bonus_total_for_context(calculation_context: RefCounted) -> float:
	var attacker: Node = calculation_context.get("attacker") as Node
	var damage_modifiers: Dictionary = calculation_context.get("damage_modifiers")
	var profile: RefCounted = calculation_context.get("target_profile")
	var rank: String = String(profile.get("target_type"))
	var total: float = float(calculation_context.call("packet_value", "enemy_type_bonus_total", 0.0))
	var key: String = DamageRuleRegistryScript.enemy_type_bonus_key(rank)
	if key != "":
		total += float(calculation_context.call("packet_value", key, 0.0))
		total += _get_modifier_float(damage_modifiers, key, 0.0)
		if attacker != null:
			total += _get_float_property(attacker, key, 0.0)
	return total


## 作用：解析目标伤害快照并返回目标分类字符串。
## 使用：玩家按组识别，敌人按 enemy_rank 元数据识别。
static func _get_target_class(target: Node) -> String:
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	return String(profile.get("target_type"))


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
