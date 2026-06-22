extends RefCounted
class_name CriticalDamageStage


var stage_name: StringName = &"critical"


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	var critical_result: Dictionary = host.call("_apply_critical_stage", calculation_context, float(input_value))
	calculation_context.set("critical", bool(critical_result.get("is_critical", false)))
	return float(critical_result.get("pre_mitigation", input_value))
