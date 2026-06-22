extends RefCounted
class_name TruePercentCapStage


const DamageTruePercentResolverScript: Script = preload("res://scripts/combat/damage_true_percent_resolver.gd")

var stage_name: StringName = &"cap"


func apply_with_host(_host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	var target: Node = calculation_context.get("target") as Node
	var max_health: float = 0.0
	if target != null:
		max_health = maxf(float(target.get("max_health")), 0.0)
	return DamageTruePercentResolverScript.apply_true_percent_cap_stage(calculation_context, float(input_value), max_health)
