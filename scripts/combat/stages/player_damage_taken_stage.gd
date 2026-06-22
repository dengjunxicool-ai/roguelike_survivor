extends RefCounted
class_name PlayerDamageTakenStage


var stage_name: StringName = &"damage_taken"


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_player_damage_taken_stage", calculation_context, float(input_value))
