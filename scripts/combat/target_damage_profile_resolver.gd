## 文件用途：从目标属性、player组和enemy_rank解析统一防御与规则快照。
## 使用方式：每次伤害计算建立上下文时调用 resolve；缺少目标也返回普通目标默认快照。
extends RefCounted
class_name TargetDamageProfileResolver


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileScript: Script = preload("res://scripts/combat/target_damage_profile.gd")
const OptionalCombatPropertyReaderScript: Script = preload("res://scripts/combat/optional_combat_property_reader.gd")


## 作用：仅查询当前目标阶级，不构建护甲、抗性或承伤快照。
## 使用：只判断普通、精英、Boss 或玩家的调用方使用；玩家组仍优先于 enemy_rank。
static func classify_target(target: Node) -> StringName:
	return StringName(_target_class(target))


## 作用：读取护甲、防御和复制抗性，按阶级补易伤边界、百分比上限及来源承伤表。
## 使用：target 可空；返回独立快照，can_receive_reaction 对玩家关闭。
static func resolve(target: Node) -> RefCounted:
	var profile: RefCounted = TargetDamageProfileScript.new()
	var target_class: String = _target_class(target)
	profile.target_type = StringName(target_class)
	profile.armor = OptionalCombatPropertyReaderScript.read_float(target, "armor", 0.0)
	profile.defense = OptionalCombatPropertyReaderScript.read_float(target, "defense", profile.armor)
	var resistances_variant: Variant = OptionalCombatPropertyReaderScript.read_value(target, "resistances", {})
	if resistances_variant is Dictionary:
		profile.resistances = (resistances_variant as Dictionary).duplicate(true)
	var bounds: Dictionary = DamageRuleRegistryScript.vulnerability_bounds(target_class)
	profile.vulnerability_floor = float(bounds.get("floor", -0.60))
	profile.vulnerability_cap = float(bounds.get("cap", 0.30))
	profile.true_percent_cap = DamageRuleRegistryScript.true_percent_default_cap(target_class)
	profile.incoming_damage_reduction = clampf(OptionalCombatPropertyReaderScript.read_float(target, "player_damage_reduction_total", 0.0), 0.0, 0.95)
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
