extends RefCounted
class_name DamageStage


var stage_name: StringName = &""
var processor_name: StringName = &""


static func create(name_value: Variant, processor_value: Variant) -> RefCounted:
	var stage: RefCounted = new()
	stage.stage_name = StringName(String(name_value))
	stage.processor_name = StringName(String(processor_value))
	return stage


func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	if host == null or processor_name == &"" or not host.has_method(processor_name):
		return input_value
	return host.call(processor_name, calculation_context, input_value)


func to_dictionary() -> Dictionary:
	return {
		"name": stage_name,
		"processor": processor_name
	}
