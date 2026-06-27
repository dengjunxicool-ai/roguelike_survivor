extends Node


const DataPathsScript := preload("res://scripts/core/data_paths.gd")
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
	if not FileAccess.file_exists(path):
		push_error("[DataManager] Data file does not exist: %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataManager] Could not open data file: %s (error: %s)" % [path, error_string(FileAccess.get_open_error())])
		return {}

	var json := JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	if parse_error != OK:
		push_error(
			"[DataManager] Failed to parse JSON file: %s (line %d: %s)" % [
				path,
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return {}

	var data: Variant = json.data
	if not (data is Dictionary):
		push_error("[DataManager] JSON root must be an object: %s" % path)
		return {}

	return data


func _index_definitions(document: Dictionary, key: String, id_key: String, target: Dictionary, path: String) -> void:
	for item: Dictionary in _get_dictionary_array(document, key, path):
		var item_id: StringName = StringName(String(item.get(id_key, "")))
		if item_id == &"":
			push_error("[DataManager] Definition in %s.%s is missing a non-empty %s." % [path, key, id_key])
			continue

		target[item_id] = item.duplicate(true)


func _index_upgrade_definitions(document: Dictionary, key: String, path: String) -> void:
	for item: Dictionary in _get_dictionary_array(document, key, path):
		var item_id: StringName = StringName(String(item.get("id", "")))
		if item_id == &"":
			push_error("[DataManager] Definition in %s.%s is missing a non-empty id." % [path, key])
			continue

		var item_copy: Dictionary = item.duplicate(true)
		_upgrade_definitions[item_id] = item_copy
		if key == "level_up_upgrades":
			_level_up_upgrade_definitions[item_id] = item_copy.duplicate(true)


func _get_dictionary_array(document: Dictionary, key: String, path: String) -> Array[Dictionary]:
	if document.is_empty():
		return []

	var value: Variant = document.get(key, [])
	if not (value is Array):
		push_error("[DataManager] Expected %s.%s to be an array." % [path, key])
		return []

	var items: Array[Dictionary] = []
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			items.append(item)
		else:
			push_error("[DataManager] Expected every item in %s.%s to be an object." % [path, key])

	return items


func _get_definition(source: Dictionary, definition_id: Variant) -> Dictionary:
	var key: StringName = StringName(String(definition_id))
	if not source.has(key):
		return {}

	var definition: Dictionary = source[key]
	return definition.duplicate(true)


func _get_definition_values(source: Dictionary) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for value_variant: Variant in source.values():
		if value_variant is Dictionary:
			var value: Dictionary = value_variant
			values.append(value.duplicate(true))
	return values
