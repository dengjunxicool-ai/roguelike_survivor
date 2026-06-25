extends RefCounted
class_name CharacterDefinition


var id: StringName = &""
var display_name: String = ""
var description: String = ""
var role: String = ""
var base_stats: Dictionary = {}
var trait_data: Dictionary = {}
var starting_skill_id: StringName = &""
var unlock: Dictionary = {}
var visual: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	id = StringName(String(data.get("id", "")))
	display_name = String(data.get("display_name", id))
	description = String(data.get("description", ""))
	role = String(data.get("role", ""))
	base_stats = _get_dictionary(data.get("base_stats", {}))
	trait_data = _get_dictionary(data.get("trait", {}))
	starting_skill_id = StringName(String(data.get("starting_skill_id", "")))
	unlock = _get_dictionary(data.get("unlock", {"type": "default"}))
	visual = _get_dictionary(data.get("visual", {}))


func get_base_stat(stat_name: String, default_value: Variant = 0) -> Variant:
	return base_stats.get(stat_name, default_value)


func get_trait() -> Dictionary:
	return trait_data.duplicate(true)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}

