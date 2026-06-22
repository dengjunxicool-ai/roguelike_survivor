extends RefCounted
class_name CharacterDefinition


var id: StringName = &""
var display_name: String = ""
var description: String = ""
var role: String = ""
var base_stats: Dictionary = {}
var trait_data: Dictionary = {}
var allowed_weapon_ids: Array[StringName] = []
var unlock: Dictionary = {}
var visual: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	id = StringName(String(data.get("id", "")))
	display_name = String(data.get("display_name", id))
	description = String(data.get("description", ""))
	role = String(data.get("role", ""))
	base_stats = _get_dictionary(data.get("base_stats", {}))
	trait_data = _get_dictionary(data.get("trait", {}))
	allowed_weapon_ids = _parse_string_name_array(data.get("allowed_weapon_ids", []))
	unlock = _get_dictionary(data.get("unlock", {"type": "default"}))
	visual = _get_dictionary(data.get("visual", {}))


func get_base_stat(stat_name: String, default_value: Variant = 0) -> Variant:
	return base_stats.get(stat_name, default_value)


func get_trait() -> Dictionary:
	return trait_data.duplicate(true)


func get_allowed_weapon_ids() -> Array:
	return allowed_weapon_ids.duplicate()


func can_equip_weapon(weapon_id: String) -> bool:
	var target_id: StringName = StringName(weapon_id)
	if target_id == &"":
		return false
	return allowed_weapon_ids.has(target_id)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _parse_string_name_array(value: Variant) -> Array[StringName]:
	var parsed: Array[StringName] = []
	if not (value is Array):
		return parsed

	for item: Variant in value:
		var item_id: StringName = StringName(String(item))
		if item_id != &"" and not parsed.has(item_id):
			parsed.append(item_id)
	return parsed
