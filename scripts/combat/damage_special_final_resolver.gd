extends RefCounted
class_name DamageSpecialFinalResolver


const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")

const ALLOWED_SPECIAL_MODIFIER_SOURCES: Array[String] = ["target_passive", "system_rule", "boss_phase", "map_rule"]


static func apply_special_stage(calculation_context: RefCounted, after_vulnerability: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var after_special: float = after_vulnerability * special_final_modifier_for_context(calculation_context)
	stages["after_special"] = after_special
	return after_special


static func special_final_modifier(packet: Dictionary, target: Node) -> float:
	var modifier: float = ReactionLimiterScript.get_special_final_modifier(packet, target)
	if not packet.has("special_final_modifier"):
		return modifier

	var source: String = String(packet.get("special_final_modifier_source", ""))
	if ALLOWED_SPECIAL_MODIFIER_SOURCES.has(source):
		return modifier * maxf(float(packet.get("special_final_modifier", 1.0)), 0.0)

	push_warning("[DamageSystem] Ignoring special_final_modifier without allowed special_final_modifier_source.")
	return modifier


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
