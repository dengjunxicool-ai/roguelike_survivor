extends RefCounted
class_name OutgoingDamageStage


var stage_name: StringName = &"outgoing"


func apply_with_host(host: Object, calculation_context: RefCounted, _input_value: Variant) -> Variant:
	return host.call("_apply_outgoing_stage", calculation_context)
