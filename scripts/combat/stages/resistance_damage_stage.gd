extends RefCounted
class_name ResistanceDamageStage


var stage_name: StringName = &"resistance"


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_resistance_stage", calculation_context, float(input_value))
