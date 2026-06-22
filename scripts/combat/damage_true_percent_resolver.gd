extends RefCounted
class_name DamageTruePercentResolver


static func resolve_true_percent(calculation_context: RefCounted) -> float:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	var percent: float = float(calculation_context.call("packet_value", "percent", calculation_context.call("packet_value", "percent_of_max_health", raw_amount)))
	if percent > 1.0:
		percent *= 0.01
	stages["percent"] = percent
	return percent


static func apply_true_percent_stage(calculation_context: RefCounted, max_health: float, percent: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var damage: float = max_health * maxf(percent, 0.0)
	stages["max_health"] = max_health
	stages["after_true_percent"] = damage
	return damage


static func apply_true_percent_cap_stage(calculation_context: RefCounted, damage: float, max_health: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var profile: RefCounted = calculation_context.get("target_profile")
	var default_cap: float = float(profile.get("true_percent_cap"))
	var cap: float = float(calculation_context.call("packet_value", "true_percent_damage_cap", default_cap))
	if cap > 0.0:
		damage = minf(damage, max_health * cap)
	stages["true_percent_cap"] = cap
	stages["after_special"] = damage
	return damage
