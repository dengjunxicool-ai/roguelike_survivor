extends RefCounted
class_name PlayerIncomingModifierStage


var stage_name: StringName = &"incoming_modifiers"


func apply_with_host(host: Object, calculation_context: RefCounted, _input_value: Variant) -> Variant:
	return host.call("_apply_player_incoming_modifier_stage", calculation_context)
