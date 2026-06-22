extends RefCounted
class_name SpecialFinalDamageStage


var stage_name: StringName = &"special"


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_special_stage", calculation_context, float(input_value))
