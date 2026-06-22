extends RefCounted
class_name WeaponDefinition


var id: StringName = &""
var display_name: String = ""
var character_id: StringName = &""
var description: String = ""
var starting_skill_id: StringName = &""
var tags: Array[StringName] = []
var weapon_trait: Dictionary = {}
var branch_ids: Array[StringName] = []
var unlock: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	id = StringName(String(data.get("id", "")))
	display_name = String(data.get("display_name", id))
	character_id = StringName(String(data.get("character_id", "")))
	description = String(data.get("description", ""))
	starting_skill_id = StringName(String(data.get("starting_skill_id", "")))
	tags = _parse_string_name_array(data.get("tags", []))
	weapon_trait = _get_dictionary(data.get("weapon_trait", {}))
	branch_ids = _parse_string_name_array(data.get("branch_ids", []))
	unlock = _get_dictionary(data.get("unlock", {"type": "default"}))


func get_starting_skill_id() -> String:
	return String(starting_skill_id)


func get_weapon_trait() -> Dictionary:
	return weapon_trait.duplicate(true)


func get_branch_ids() -> Array:
	return branch_ids.duplicate()


func has_tag(tag: String) -> bool:
	return tags.has(StringName(tag))


func belongs_to_character(target_character_id: String) -> bool:
	return character_id == StringName(target_character_id)


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
