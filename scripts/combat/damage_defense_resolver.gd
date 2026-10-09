## 文件用途：按伤害类型防御权重及减伤上限计算固定防御抵扣。
## 使用方式：普通伤害暴击后执行，结合目标防御快照、酸系Boss减防和反应限制。
extends RefCounted
class_name DamageDefenseResolver


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const DamageTargetRuntimeModifiersScript: Script = preload("res://scripts/combat/damage_target_runtime_modifiers.gd")

const DEFAULT_DEFENSE_REDUCTION_CAP: float = 0.45


## 作用：计算防御抵扣并把结果保存为 after_defense。
## 使用：pre_mitigation 为暴击后的浮点伤害，返回非负抵扣结果。
static func apply_defense_stage(calculation_context: RefCounted, pre_mitigation: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var after_defense: float = apply_defense_for_context(calculation_context, pre_mitigation)
	stages["after_defense"] = after_defense
	return after_defense


## 作用：从目标现场防御属性与字典包计算固定抵扣。
## 使用：忽略防御或无有效目标时原值返回；抵扣不超过包/规则规定比例。
static func apply_defense(pre_mitigation: float, packet: Dictionary, target: Node) -> float:
	if target == null or bool(packet.get("ignore_defense", false)):
		return pre_mitigation

	var rate: float = defense_rate(String(packet.get("damage_type", "")))
	if rate <= 0.0:
		return pre_mitigation

	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	var defense: float = maxf(float(profile.get("defense")), float(profile.get("armor")))
	defense = DamageTargetRuntimeModifiersScript.acid_boss_defense(target, defense)
	var def_flat: float = defense * rate
	var cap: float = ReactionLimiterScript.get_defense_reduction_cap(packet, target, DEFAULT_DEFENSE_REDUCTION_CAP)
	var actual_def_flat: float = minf(def_flat, pre_mitigation * cap)
	return maxf(pre_mitigation - actual_def_flat, 0.0)


## 作用：使用已解析目标快照及包字段计算防御抵扣。
## 使用：读取酸系Boss临时减防与反应限制，返回抵扣后的浮点伤害。
static func apply_defense_for_context(calculation_context: RefCounted, pre_mitigation: float) -> float:
	var target: Node = calculation_context.get("target") as Node
	if target == null or bool(calculation_context.call("packet_value", "ignore_defense", false)):
		return pre_mitigation

	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", ""))
	var rate: float = defense_rate(damage_type)
	if rate <= 0.0:
		return pre_mitigation

	var profile: RefCounted = calculation_context.get("target_profile")
	var defense: float = maxf(float(profile.get("defense")), float(profile.get("armor")))
	defense = DamageTargetRuntimeModifiersScript.acid_boss_defense(target, defense)
	var def_flat: float = defense * rate
	var cap: float = ReactionLimiterScript.get_defense_reduction_cap_for_context(calculation_context, DEFAULT_DEFENSE_REDUCTION_CAP, target)
	var actual_def_flat: float = minf(def_flat, pre_mitigation * cap)
	return maxf(pre_mitigation - actual_def_flat, 0.0)


## 作用：查询伤害类型使用的防御权重。
## 使用：来源为 DamageRuleRegistry，零权重表示不做固定防御抵扣。
static func defense_rate(damage_type: String) -> float:
	return DamageRuleRegistryScript.defense_rate(damage_type)
