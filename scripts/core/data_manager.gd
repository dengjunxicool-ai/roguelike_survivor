extends Node


const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const DataDefinitionIndexScript: Script = preload("res://scripts/core/data_definition_index.gd")
const SKILLS_PATH: String = DataPathsScript.SKILLS_PATH
const ENEMIES_PATH: String = DataPathsScript.ENEMIES_PATH
const ENEMY_SKILLS_PATH: String = DataPathsScript.ENEMY_SKILLS_PATH
const UPGRADES_PATH: String = DataPathsScript.UPGRADES_PATH
const STATUS_EFFECTS_PATH: String = DataPathsScript.STATUS_EFFECTS_PATH
const RELICS_PATH: String = DataPathsScript.RELICS_PATH
const SYNERGIES_PATH: String = DataPathsScript.SYNERGIES_PATH
const COMBAT_OBJECTS_PATH: String = DataPathsScript.COMBAT_OBJECTS_PATH
const CHARACTERS_PATH: String = DataPathsScript.CHARACTERS_PATH
const WAVES_PATH: String = DataPathsScript.WAVES_PATH
const MAPS_PATH: String = DataPathsScript.MAPS_PATH

const STARTING_SKILLS_KEY: String = "starting_skills"
const SKILLS_KEY: String = "skills"
const ENEMIES_KEY: String = "monsters"
const ENEMY_SKILLS_KEY: String = "enemy_skills"
const CHARACTERS_KEY: String = "characters"
const STATUS_EFFECTS_KEY: String = "statuses"
const RELICS_KEY: String = "relics"
const SYNERGIES_KEY: String = "synergies"
const COMBAT_OBJECTS_KEY: String = "combat_objects"
const MAPS_KEY: String = "maps"
const UPGRADE_KEYS: Array[String] = [
	"curse_choices",
	"level_up_upgrades",
	"permanent_upgrades"
]

var _skill_definitions: Dictionary = {}
var _enemy_definitions: Dictionary = {}
var _enemy_skill_definitions: Dictionary = {}
var _upgrade_definitions: Dictionary = {}
var _level_up_upgrade_definitions: Dictionary = {}
var _status_definitions: Dictionary = {}
var _relic_definitions: Dictionary = {}
var _combat_object_definitions: Dictionary = {}
var _character_definitions: Dictionary = {}
var _map_definitions: Dictionary = {}
var _synergy_definitions: Array[Dictionary] = []
var _wave_config: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	_skill_definitions.clear()
	_enemy_definitions.clear()
	_enemy_skill_definitions.clear()
	_upgrade_definitions.clear()
	_level_up_upgrade_definitions.clear()
	_status_definitions.clear()
	_relic_definitions.clear()
	_combat_object_definitions.clear()
	_character_definitions.clear()
	_map_definitions.clear()
	_synergy_definitions.clear()
	_wave_config.clear()

	var enemies_document: Dictionary = _load_json_document(ENEMIES_PATH)
	_index_definitions(enemies_document, ENEMIES_KEY, "id", _enemy_definitions, ENEMIES_PATH)

	var enemy_skills_document: Dictionary = _load_json_document(ENEMY_SKILLS_PATH)
	_index_definitions(enemy_skills_document, ENEMY_SKILLS_KEY, "id", _enemy_skill_definitions, ENEMY_SKILLS_PATH)

	var upgrades_document: Dictionary = _load_json_document(UPGRADES_PATH)
	for upgrade_key: String in UPGRADE_KEYS:
		_index_upgrade_definitions(upgrades_document, upgrade_key, UPGRADES_PATH)

	var status_document: Dictionary = _load_json_document(STATUS_EFFECTS_PATH)
	_index_definitions(status_document, STATUS_EFFECTS_KEY, "id", _status_definitions, STATUS_EFFECTS_PATH)

	var relics_document: Dictionary = _load_json_document(RELICS_PATH)
	_index_definitions(relics_document, RELICS_KEY, "id", _relic_definitions, RELICS_PATH)

	var combat_objects_document: Dictionary = _load_json_document(COMBAT_OBJECTS_PATH)
	_index_definitions(combat_objects_document, COMBAT_OBJECTS_KEY, "id", _combat_object_definitions, COMBAT_OBJECTS_PATH)

	var skills_document: Dictionary = _load_json_document(SKILLS_PATH)
	_index_definitions(skills_document, STARTING_SKILLS_KEY, "id", _skill_definitions, SKILLS_PATH)
	_index_definitions(skills_document, SKILLS_KEY, "id", _skill_definitions, SKILLS_PATH)

	var characters_document: Dictionary = _load_json_document(CHARACTERS_PATH)
	_index_definitions(characters_document, CHARACTERS_KEY, "id", _character_definitions, CHARACTERS_PATH)

	var maps_document: Dictionary = _load_json_document(MAPS_PATH)
	_index_definitions(maps_document, MAPS_KEY, "id", _map_definitions, MAPS_PATH)

	var synergies_document: Dictionary = _load_json_document(SYNERGIES_PATH)
	_synergy_definitions = _get_dictionary_array(synergies_document, SYNERGIES_KEY, SYNERGIES_PATH)

	_wave_config = _load_json_document(WAVES_PATH)


func get_skill_definition(skill_id: Variant) -> Dictionary:
	return _get_definition(_skill_definitions, skill_id)


func get_enemy_definition(enemy_id: Variant) -> Dictionary:
	return _get_definition(_enemy_definitions, enemy_id)


func get_enemy_skill_definition(skill_id: Variant) -> Dictionary:
	return _get_definition(_enemy_skill_definitions, skill_id)


func get_upgrade_definition(upgrade_id: Variant) -> Dictionary:
	return _get_definition(_upgrade_definitions, upgrade_id)


func get_status_definition(status_id: Variant) -> Dictionary:
	return _get_definition(_status_definitions, status_id)


func get_relic_definition(relic_id: Variant) -> Dictionary:
	return _get_definition(_relic_definitions, relic_id)


func get_combat_object_definition(object_id: Variant) -> Dictionary:
	return _get_definition(_combat_object_definitions, object_id)


func get_character_definition(character_id: Variant) -> Dictionary:
	return _get_definition(_character_definitions, character_id)


func get_map_definition(map_id: Variant) -> Dictionary:
	return _get_definition(_map_definitions, map_id)


func get_map_definitions() -> Array[Dictionary]:
	return _get_definition_values(_map_definitions)


func get_skill_definitions() -> Array[Dictionary]:
	return _get_definition_values(_skill_definitions)


func get_relic_definitions() -> Array[Dictionary]:
	return _get_definition_values(_relic_definitions)


func get_enemy_definitions() -> Array[Dictionary]:
	return _get_definition_values(_enemy_definitions)


func get_enemy_skill_definitions() -> Array[Dictionary]:
	return _get_definition_values(_enemy_skill_definitions)


func get_upgrade_definitions() -> Array[Dictionary]:
	return _get_definition_values(_upgrade_definitions)


func get_level_up_upgrade_definitions() -> Array[Dictionary]:
	return _get_definition_values(_level_up_upgrade_definitions)


func get_character_definitions() -> Array[Dictionary]:
	return _get_definition_values(_character_definitions)


func get_synergy_definitions() -> Array[Dictionary]:
	return _synergy_definitions.duplicate(true)


func get_wave_config() -> Dictionary:
	return _wave_config.duplicate(true)


func _load_json_document(path: String) -> Dictionary:
	return JsonDataLoaderScript.load_dictionary(path, "DataManager")


func _index_definitions(document: Dictionary, key: String, id_key: String, target: Dictionary, path: String) -> void:
	DataDefinitionIndexScript.index_definitions(document, key, id_key, target, path)


func _index_upgrade_definitions(document: Dictionary, key: String, path: String) -> void:
	DataDefinitionIndexScript.index_upgrade_definitions(document, key, path, _upgrade_definitions, _level_up_upgrade_definitions)


func _get_dictionary_array(document: Dictionary, key: String, path: String) -> Array[Dictionary]:
	return DataDefinitionIndexScript.get_dictionary_array(document, key, path)


func _get_definition(source: Dictionary, definition_id: Variant) -> Dictionary:
	return DataDefinitionIndexScript.get_definition(source, definition_id)


func _get_definition_values(source: Dictionary) -> Array[Dictionary]:
	return DataDefinitionIndexScript.get_definition_values(source)
