extends RefCounted
class_name PlayerDefenseStage


var stage_name: StringName = &"player_defense"


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_player_defense_stage", calculation_context, float(input_value))
