extends RefCounted
class_name EnemySkillRepository


const EnemySkillDefinitionScript: Script = preload("res://scripts/enemies/skills/enemy_skill_definition.gd")
const GameDataScript: Script = preload("res://scripts/game/game_data.gd")

var _definitions: Dictionary = {}
var _loaded: bool = false


func get_skill(skill_id: Variant) -> RefCounted:
	_ensure_loaded()
	var id: StringName = StringName(String(skill_id))
	if not _definitions.has(id):
		return null
	return _definitions[id] as RefCounted


func get_all_skills() -> Array[RefCounted]:
	_ensure_loaded()
	var result: Array[RefCounted] = []
	for definition: Variant in _definitions.values():
		if definition is RefCounted:
			result.append(definition)
	return result


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_definitions.clear()
	for data: Dictionary in _load_skill_data():
		var definition: RefCounted = EnemySkillDefinitionScript.new(data)
		var id: StringName = StringName(String(definition.get("id")))
		if id != &"":
			_definitions[id] = definition


func _load_skill_data() -> Array[Dictionary]:
	return GameDataScript.get_enemy_skill_pool()
