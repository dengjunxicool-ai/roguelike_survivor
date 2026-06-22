extends RefCounted
class_name DefenseDamageStage


var stage_name: StringName = &"defense"


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_defense_stage", calculation_context, float(input_value))
