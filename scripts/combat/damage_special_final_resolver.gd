## 文件用途：组合反应针对Boss的倍率与受限来源的特殊最终倍率。
## 使用方式：在易伤之后、取整之前使用；特殊倍率必须有允许的来源标签。
extends RefCounted
class_name DamageSpecialFinalResolver


const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")

const ALLOWED_SPECIAL_MODIFIER_SOURCES: Array[String] = ["target_passive", "system_rule", "boss_phase", "map_rule"]


## 作用：把受限特殊最终系数乘到易伤后伤害并记录 after_special。
## 使用：返回浮点终值，后续仍需取整。
static func apply_special_stage(calculation_context: RefCounted, after_vulnerability: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var after_special: float = after_vulnerability * special_final_modifier_for_context(calculation_context)
	stages["after_special"] = after_special
	return after_special


## 作用：组合反应限制倍率并检查特殊倍率来源白名单。
## 使用：未知来源只警告并忽略额外倍率，基础反应倍率仍保留。
static func special_final_modifier(packet: Dictionary, target: Node) -> float:
	var modifier: float = ReactionLimiterScript.get_special_final_modifier(packet, target)
	if not packet.has("special_final_modifier"):
		return modifier

	var source: String = String(packet.get("special_final_modifier_source", ""))
	if ALLOWED_SPECIAL_MODIFIER_SOURCES.has(source):
		return modifier * maxf(float(packet.get("special_final_modifier", 1.0)), 0.0)

	push_warning("[DamageSystem] Ignoring special_final_modifier without allowed special_final_modifier_source.")
	return modifier


## 作用：通过上下文读取特殊最终倍率与来源白名单。
## 使用：返回非负系数，非法来源不会影响基础反应倍率。
static func special_final_modifier_for_context(calculation_context: RefCounted) -> float:
	var target: Node = calculation_context.get("target") as Node
	var modifier: float = ReactionLimiterScript.get_special_final_modifier_for_context(calculation_context, target)
	if not bool(calculation_context.call("packet_has", "special_final_modifier")):
		return modifier

	var source: String = String(calculation_context.call("packet_value", "special_final_modifier_source", ""))
	if ALLOWED_SPECIAL_MODIFIER_SOURCES.has(source):
		return modifier * maxf(float(calculation_context.call("packet_value", "special_final_modifier", 1.0)), 0.0)

	push_warning("[DamageSystem] Ignoring special_final_modifier without allowed special_final_modifier_source.")
	return modifier
