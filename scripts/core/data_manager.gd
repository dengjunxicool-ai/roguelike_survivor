extends Node


const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const ContentValidator := preload("res://scripts/core/content_config_validator.gd")
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
const PROGRESSION_GOALS_PATH: String = DataPathsScript.PROGRESSION_GOALS_PATH
const CHALLENGES_PATH: String = DataPathsScript.CHALLENGES_PATH

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
const DAILY_CHALLENGES_KEY: String = "daily_challenges"
const WEEKLY_CHALLENGES_KEY: String = "weekly_challenges"
const CURSE_CHOICES_KEY: String = "curse_choices"
const LEVEL_UP_UPGRADES_KEY: String = "level_up_upgrades"
const PERMANENT_UPGRADES_KEY: String = "permanent_upgrades"
const RARITY_WEIGHTS_KEY: String = "rarity_weights"
const UPGRADE_KEYS: Array[String] = [
	CURSE_CHOICES_KEY,
	LEVEL_UP_UPGRADES_KEY,
	PERMANENT_UPGRADES_KEY
]

var is_loaded: bool = false

var _summon_definitions: Dictionary = {}
var _god_definitions: Array[Dictionary] = []

var _skill_definitions: Dictionary = {}
var _starting_skill_definitions: Array[Dictionary] = []
var _enemy_definitions: Dictionary = {}
var _enemy_skill_definitions: Dictionary = {}
var _upgrade_definitions: Dictionary = {}
var _level_up_upgrade_definitions: Dictionary = {}
var _curse_choice_pool: Array[Dictionary] = []
var _level_up_upgrade_pool: Array[Dictionary] = []
var _permanent_upgrade_pool: Array[Dictionary] = []
var _rarity_weights: Dictionary = {}
var _status_definitions: Dictionary = {}
var _relic_definitions: Dictionary = {}
var _combat_object_definitions: Dictionary = {}
var _character_definitions: Dictionary = {}
var _map_definitions: Dictionary = {}
var _synergy_definitions: Array[Dictionary] = []
var _wave_config: Dictionary = {}
var _skill_system_config: Dictionary = {}
var _progression_goals: Dictionary = {}
var _daily_challenge_definitions: Array[Dictionary] = []
var _weekly_challenge_definitions: Array[Dictionary] = []


func _ready() -> void:
	if not load_all():
		get_tree().quit(1)


func load_all() -> bool:
	var loaded: Dictionary = ContentValidator.load_sources()
	var errors: Array[String] = loaded.errors
	errors.append_array(ContentValidator.validate_documents(loaded.documents, loaded.schema))
	if not errors.is_empty():
		for error: String in errors:
			push_error("[DataManager] " + error)
		return false
	_publish_documents(loaded.documents)
	return true


func replace_documents(documents: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema: Dictionary = ContentValidator.read_document(ContentValidator.SCHEMA_PATH, errors)
	errors.append_array(ContentValidator.validate_documents(documents, schema))
	if errors.is_empty():
		_publish_documents(documents)
	return errors


func _publish_documents(documents: Dictionary) -> void:
	_summon_definitions.clear()
	_god_definitions.clear()
	_skill_definitions.clear()
	_starting_skill_definitions.clear()
	_enemy_definitions.clear()
	_enemy_skill_definitions.clear()
	_upgrade_definitions.clear()
	_level_up_upgrade_definitions.clear()
	_curse_choice_pool.clear()
	_level_up_upgrade_pool.clear()
	_permanent_upgrade_pool.clear()
	_rarity_weights.clear()
	_status_definitions.clear()
	_relic_definitions.clear()
	_combat_object_definitions.clear()
	_character_definitions.clear()
	_map_definitions.clear()
	_synergy_definitions.clear()
	_wave_config.clear()
	_progression_goals.clear()
	_daily_challenge_definitions.clear()
	_weekly_challenge_definitions.clear()

	var summon_document: Dictionary = documents[DataPathsScript.SUMMONS_PATH]
	_index_definitions(summon_document, "summons", "id", _summon_definitions, DataPathsScript.SUMMONS_PATH)
	_god_definitions = _get_dictionary_array(documents[DataPathsScript.GODS_PATH], "gods", DataPathsScript.GODS_PATH)

	var enemies_document: Dictionary = documents[ENEMIES_PATH]
	_index_definitions(enemies_document, ENEMIES_KEY, "id", _enemy_definitions, ENEMIES_PATH)

	var enemy_skills_document: Dictionary = documents[ENEMY_SKILLS_PATH]
	_index_definitions(enemy_skills_document, ENEMY_SKILLS_KEY, "id", _enemy_skill_definitions, ENEMY_SKILLS_PATH)

	var upgrades_document: Dictionary = documents[UPGRADES_PATH]
	_curse_choice_pool = _get_dictionary_array(upgrades_document, CURSE_CHOICES_KEY, UPGRADES_PATH)
	_level_up_upgrade_pool = _get_dictionary_array(upgrades_document, LEVEL_UP_UPGRADES_KEY, UPGRADES_PATH)
	_permanent_upgrade_pool = _get_dictionary_array(upgrades_document, PERMANENT_UPGRADES_KEY, UPGRADES_PATH)
	var rarity_weights_value: Variant = upgrades_document.get(RARITY_WEIGHTS_KEY, {})
	if rarity_weights_value is Dictionary:
		var rarity_weights_data: Dictionary = rarity_weights_value
		_rarity_weights = rarity_weights_data.duplicate(true)
	else:
		push_error("[DataManager] Expected %s.%s to be an object." % [UPGRADES_PATH, RARITY_WEIGHTS_KEY])
	for upgrade_key: String in UPGRADE_KEYS:
		_index_upgrade_definitions(upgrades_document, upgrade_key, UPGRADES_PATH)

	var status_document: Dictionary = documents[STATUS_EFFECTS_PATH]
	_index_definitions(status_document, STATUS_EFFECTS_KEY, "id", _status_definitions, STATUS_EFFECTS_PATH)

	var relics_document: Dictionary = documents[RELICS_PATH]
	_index_definitions(relics_document, RELICS_KEY, "id", _relic_definitions, RELICS_PATH)

	var combat_objects_document: Dictionary = documents[COMBAT_OBJECTS_PATH]
	_index_definitions(combat_objects_document, COMBAT_OBJECTS_KEY, "id", _combat_object_definitions, COMBAT_OBJECTS_PATH)

	var skills_document: Dictionary = documents[SKILLS_PATH]
	_starting_skill_definitions = _get_dictionary_array(skills_document, STARTING_SKILLS_KEY, SKILLS_PATH)
	_index_definitions(skills_document, STARTING_SKILLS_KEY, "id", _skill_definitions, SKILLS_PATH)
	_index_definitions(skills_document, SKILLS_KEY, "id", _skill_definitions, SKILLS_PATH)

	var characters_document: Dictionary = documents[CHARACTERS_PATH]
	_index_definitions(characters_document, CHARACTERS_KEY, "id", _character_definitions, CHARACTERS_PATH)

	var maps_document: Dictionary = documents[MAPS_PATH]
	_index_definitions(maps_document, MAPS_KEY, "id", _map_definitions, MAPS_PATH)

	var synergies_document: Dictionary = documents[SYNERGIES_PATH]
	_synergy_definitions = _get_dictionary_array(synergies_document, SYNERGIES_KEY, SYNERGIES_PATH)

	_wave_config = documents[WAVES_PATH].duplicate(true)
	_skill_system_config = documents[DataPathsScript.SKILL_SYSTEM_CONFIG_PATH].duplicate(true)
	_progression_goals = documents[PROGRESSION_GOALS_PATH].duplicate(true)

	var challenges_document: Dictionary = documents[CHALLENGES_PATH]
	_daily_challenge_definitions = _get_dictionary_array(challenges_document, DAILY_CHALLENGES_KEY, CHALLENGES_PATH)
	_weekly_challenge_definitions = _get_dictionary_array(challenges_document, WEEKLY_CHALLENGES_KEY, CHALLENGES_PATH)

	is_loaded = true

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


func get_starting_skill_definitions() -> Array[Dictionary]:
	return _starting_skill_definitions.duplicate(true)


func get_relic_definitions() -> Array[Dictionary]:
	return _get_definition_values(_relic_definitions)


func get_enemy_definitions() -> Array[Dictionary]:
	return _get_definition_values(_enemy_definitions)


func get_enemy_skill_definitions() -> Array[Dictionary]:
	return _get_definition_values(_enemy_skill_definitions)


func get_status_definitions() -> Array[Dictionary]:
	return _get_definition_values(_status_definitions)


func get_upgrade_definitions() -> Array[Dictionary]:
	return _get_definition_values(_upgrade_definitions)


func get_curse_choice_definitions() -> Array[Dictionary]:
	return _curse_choice_pool.duplicate(true)


func get_level_up_upgrade_definitions() -> Array[Dictionary]:
	return _level_up_upgrade_pool.duplicate(true)


func get_permanent_upgrade_definitions() -> Array[Dictionary]:
	return _permanent_upgrade_pool.duplicate(true)


func get_rarity_weights() -> Dictionary:
	return _rarity_weights.duplicate(true)


func get_character_definitions() -> Array[Dictionary]:
	return _get_definition_values(_character_definitions)


func get_synergy_definitions() -> Array[Dictionary]:
	return _synergy_definitions.duplicate(true)


func get_wave_config() -> Dictionary:
	return _wave_config.duplicate(true)


func get_skill_system_config() -> Dictionary:
	return _skill_system_config.duplicate(true)


func get_progression_goals() -> Dictionary:
	return _progression_goals.duplicate(true)


func get_daily_challenge_definitions() -> Array[Dictionary]:
	return _daily_challenge_definitions.duplicate(true)


func get_weekly_challenge_definitions() -> Array[Dictionary]:
	return _weekly_challenge_definitions.duplicate(true)


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


func get_summon_definition(summon_id: Variant) -> Dictionary:
	return _get_definition(_summon_definitions, summon_id)


func get_summon_definitions() -> Array[Dictionary]:
	return _get_definition_values(_summon_definitions)


func get_god_definitions() -> Array[Dictionary]:
	return _god_definitions.duplicate(true)
