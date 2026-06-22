extends RefCounted
class_name RunLoadout


const CharacterDefinitionScript: Script = preload("res://scripts/characters/character_definition.gd")
const WeaponDefinitionScript: Script = preload("res://scripts/weapons/weapon_definition.gd")

var character_id: StringName = &""
var weapon_id: StringName = &""
var character_data: Dictionary = {}
var weapon_data: Dictionary = {}
var character_definition: RefCounted
var weapon_definition: RefCounted


func _init(character_config: Dictionary = {}, weapon_config: Dictionary = {}) -> void:
	character_data = character_config.duplicate(true)
	weapon_data = weapon_config.duplicate(true)
	character_id = StringName(String(character_data.get("id", "")))
	weapon_id = StringName(String(weapon_data.get("id", "")))
	if not character_data.is_empty():
		character_definition = CharacterDefinitionScript.new(character_data)
	if not weapon_data.is_empty():
		weapon_definition = WeaponDefinitionScript.new(weapon_data)


func is_valid() -> bool:
	return character_id != &"" and weapon_id != &"" and not character_data.is_empty() and not weapon_data.is_empty()
