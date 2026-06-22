extends RefCounted
class_name DamagePipeline


var stages: Array[RefCounted] = []


static func create(stage_list: Array = []) -> RefCounted:
	var pipeline: RefCounted = new()
	pipeline.set("stages", [])
	for stage: Variant in stage_list:
		if stage is RefCounted:
			pipeline.get("stages").append(stage)
	return pipeline


func execute_with_host(host: Object, calculation_context: RefCounted, initial_value: Variant) -> Variant:
	var value: Variant = initial_value
	for stage: RefCounted in stages:
		value = stage.call("apply_with_host", host, calculation_context, value)
	return value


func stage_names() -> Array:
	var names: Array = []
	for stage: RefCounted in stages:
		names.append(stage.get("stage_name"))
	return names
