extends RefCounted
class_name RunLoadout


const CharacterDefinitionScript: Script = preload("res://scripts/characters/character_definition.gd")

var character_id: StringName = &""
var character_data: Dictionary = {}
var character_definition: RefCounted


func _init(character_config: Dictionary = {}) -> void:
	character_data = character_config.duplicate(true)
	character_id = StringName(String(character_data.get("id", "")))
	if not character_data.is_empty():
		character_definition = CharacterDefinitionScript.new(character_data)


func is_valid() -> bool:
	return character_id != &"" and not character_data.is_empty()
