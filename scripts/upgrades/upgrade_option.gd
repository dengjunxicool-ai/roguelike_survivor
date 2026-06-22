extends RefCounted
class_name UpgradeOption


var id: StringName = &""
var type: String = ""
var display_name: String = ""
var description: String = ""
var rarity: String = "common"
var background_texture: String = ""
var payload: Dictionary = {}
var tags: Array[String] = []
var affected_origin: String = ""
var does_not_affect: String = ""
var recommended_reason: String = ""
var level_text: String = ""


func _init(data: Dictionary = {}) -> void:
	id = StringName(String(data.get("id", "")))
	type = String(data.get("type", ""))
	display_name = String(data.get("display_name", data.get("title", id)))
	description = String(data.get("description", ""))
	rarity = String(data.get("rarity", "common"))
	background_texture = String(data.get("background_texture", data.get("card_background_texture", "")))
	tags = _to_string_array(data.get("tags", []))
	affected_origin = String(data.get("affected_origin", ""))
	does_not_affect = String(data.get("does_not_affect", ""))
	recommended_reason = String(data.get("recommended_reason", ""))
	level_text = String(data.get("level_text", ""))

	var payload_variant: Variant = data.get("payload", {})
	if payload_variant is Dictionary:
		var payload_data: Dictionary = payload_variant
		payload = payload_data.duplicate(true)
	else:
		payload = {}


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"display_name": display_name,
		"description": description,
		"rarity": rarity,
		"background_texture": background_texture,
		"payload": payload.duplicate(true),
		"tags": tags.duplicate(),
		"affected_origin": affected_origin,
		"does_not_affect": does_not_affect,
		"recommended_reason": recommended_reason,
		"level_text": level_text
	}


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
