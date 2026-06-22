extends RefCounted
class_name DamageTrace


var stages: Dictionary = {}


static func create(stage_values: Dictionary = {}) -> RefCounted:
	var trace: RefCounted = new()
	trace.call("sync_from_dictionary", stage_values)
	return trace


func sync_from_dictionary(stage_values: Dictionary) -> RefCounted:
	stages = stage_values.duplicate(true)
	return self


func set_stage(key: Variant, value: Variant) -> void:
	stages[key] = value


func get_stage(key: Variant, fallback: Variant = null) -> Variant:
	return stages.get(key, fallback)


func set_stage_order(order: Array) -> void:
	stages["stage_order"] = order.duplicate()


func to_dictionary() -> Dictionary:
	return stages.duplicate(true)
