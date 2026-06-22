extends RefCounted
class_name TruePercentDamageStage


const DamageTruePercentResolverScript: Script = preload("res://scripts/combat/damage_true_percent_resolver.gd")

var stage_name: StringName = &"true_percent"


func apply_with_host(_host: Object, calculation_context: RefCounted, _input_value: Variant) -> Variant:
	var target: Node = calculation_context.get("target") as Node
	var max_health: float = 0.0
	if target != null:
		max_health = maxf(float(target.get("max_health")), 0.0)
	var percent: float = DamageTruePercentResolverScript.resolve_true_percent(calculation_context)
	return DamageTruePercentResolverScript.apply_true_percent_stage(calculation_context, max_health, percent)
