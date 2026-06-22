extends RefCounted
class_name PlayerReductionStage


var stage_name: StringName = &"player_reduction"


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_player_reduction_stage", calculation_context, float(input_value))
