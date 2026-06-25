extends RefCounted
class_name DamageSourceContext


var source_type: StringName = &""
var attacker: Node = null
var attacker_id: String = ""
var source_origin_id: StringName = &""
var source_skill_id: StringName = &""
var source_instance_id: String = ""
var source_action_id: StringName = &""
var source_slot_id: StringName = &""
var owner_character_id: StringName = &""
var tags: Array[StringName] = []


static func from_dictionary(packet: Dictionary) -> RefCounted:
	var context: RefCounted = new()
	context.source_type = StringName(String(packet.get("source_type", "")))
	context.attacker = packet.get("attacker") as Node
	context.attacker_id = String(packet.get("attacker_id", ""))
	context.source_origin_id = StringName(String(packet.get("source_origin_id", "")))
	context.source_skill_id = StringName(String(packet.get("source_skill_id", packet.get("source_id", ""))))
	context.source_instance_id = String(packet.get("source_instance_id", packet.get("source_id", context.source_skill_id)))
	context.source_action_id = StringName(String(packet.get("source_action_id", "")))
	context.source_slot_id = StringName(String(packet.get("source_slot_id", "")))
	context.owner_character_id = StringName(String(packet.get("owner_character_id", "")))
	context.tags = _string_name_array(packet.get("source_tags", []))
	return context


func apply_to_dictionary(packet: Dictionary) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	result["source_type"] = source_type
	result["attacker"] = attacker
	result["attacker_id"] = attacker_id
	result["source_origin_id"] = source_origin_id
	result["source_skill_id"] = source_skill_id
	result["source_instance_id"] = source_instance_id
	if source_action_id != &"":
		result["source_action_id"] = source_action_id
	if source_slot_id != &"":
		result["source_slot_id"] = source_slot_id
	if owner_character_id != &"":
		result["owner_character_id"] = owner_character_id
	if not tags.is_empty():
		result["source_tags"] = tags.duplicate()
	return result


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			var name: StringName = StringName(String(item))
			if name != &"" and not result.has(name):
				result.append(name)
	return result
