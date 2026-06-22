extends RefCounted
class_name DamageApplicationContext


var target: Node = null
var amount_or_packet: Variant = null
var legacy_damage_type: Variant = &""
var damage_result: Dictionary = {}
var final_amount: int = 0
var reason: StringName = &""
var incoming_amount: int = 0
var absorbed_amount: int = 0
var damage_payload: Variant = null
var trait_system: Node = null
var display_damage_type: StringName = &""
var result_object: RefCounted = null


static func create(target_node: Node, damage_source: Variant, damage_type: Variant = &"") -> RefCounted:
	var context: RefCounted = new()
	context.target = target_node
	context.amount_or_packet = damage_source
	context.legacy_damage_type = damage_type
	context.damage_payload = damage_source
	return context


func has_result() -> bool:
	return result_object != null


func set_result(result: RefCounted) -> void:
	result_object = result
	if result == null:
		return
	final_amount = int(result.get("amount"))
	damage_result = result.get("damage_result")
	reason = result.get("reason")
