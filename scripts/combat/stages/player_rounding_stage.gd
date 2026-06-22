extends RefCounted
class_name PlayerRoundingStage


var stage_name: StringName = &"rounding"


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_player_rounding_stage", calculation_context, float(input_value))
