## 文件用途：负责玩法配置的统一加载、校验、索引及原子发布。
## 使用方式：project.godot 中作为 DataManager autoload；业务通过 GameData 门面查询，替换数据前先验证。

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


## 作用：在 autoload 入树时加载全部玩法配置，失败则退出游戏。
## 使用：由 Godot 自动调用；加载失败使用非零退出码，不允许带非法数据启动。
func _ready() -> void:
	if not load_all():
		get_tree().quit(1)


## 作用：读取 schema 中登记的全部数据，统一验证通过后发布索引。
## 使用：启动或显式重载时调用；返回成功标志，校验失败保留原已发布数据。
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


## 作用：验证候选数据集，全部合法才替换当前配置。
## 使用：传入以 res:// 路径为键的完整文档字典；返回错误数组，空数组表示发布成功。
func replace_documents(documents: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema: Dictionary = ContentValidator.read_document(ContentValidator.SCHEMA_PATH, errors)
	errors.append_array(ContentValidator.validate_documents(documents, schema))
	if errors.is_empty():
		_publish_documents(documents)
	return errors


## 作用：清空并重建各数据域索引、列表与配置快照。
## 使用：只接收已通过统一校验的完整数据集；最后设置 is_loaded。
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

## 作用：获取技能定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 skill_id（技能ID）。
func get_skill_definition(skill_id: Variant) -> Dictionary:
	return _get_definition(_skill_definitions, skill_id)


## 作用：获取敌人定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 enemy_id（敌人ID）。
func get_enemy_definition(enemy_id: Variant) -> Dictionary:
	return _get_definition(_enemy_definitions, enemy_id)


## 作用：获取敌方技能定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 skill_id（技能ID）。
func get_enemy_skill_definition(skill_id: Variant) -> Dictionary:
	return _get_definition(_enemy_skill_definitions, skill_id)


## 作用：获取升级定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 upgrade_id（升级ID）。
func get_upgrade_definition(upgrade_id: Variant) -> Dictionary:
	return _get_definition(_upgrade_definitions, upgrade_id)


## 作用：获取状态效果定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 status_id（状态效果ID）。
func get_status_definition(status_id: Variant) -> Dictionary:
	return _get_definition(_status_definitions, status_id)


## 作用：获取遗物定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 relic_id（遗物ID）。
func get_relic_definition(relic_id: Variant) -> Dictionary:
	return _get_definition(_relic_definitions, relic_id)


## 作用：获取战斗对象定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 object_id（对象ID）。
func get_combat_object_definition(object_id: Variant) -> Dictionary:
	return _get_definition(_combat_object_definitions, object_id)


## 作用：获取角色定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 character_id（角色ID）。
func get_character_definition(character_id: Variant) -> Dictionary:
	return _get_definition(_character_definitions, character_id)


## 作用：获取地图定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 map_id（地图ID）。
func get_map_definition(map_id: Variant) -> Dictionary:
	return _get_definition(_map_definitions, map_id)


## 作用：获取地图定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_map_definitions() -> Array[Dictionary]:
	return _get_definition_values(_map_definitions)


## 作用：获取技能定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_skill_definitions() -> Array[Dictionary]:
	return _get_definition_values(_skill_definitions)


## 作用：获取起始技能定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_starting_skill_definitions() -> Array[Dictionary]:
	return _starting_skill_definitions.duplicate(true)


## 作用：获取遗物定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_relic_definitions() -> Array[Dictionary]:
	return _get_definition_values(_relic_definitions)


## 作用：获取敌人定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_enemy_definitions() -> Array[Dictionary]:
	return _get_definition_values(_enemy_definitions)


## 作用：获取敌方技能定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_enemy_skill_definitions() -> Array[Dictionary]:
	return _get_definition_values(_enemy_skill_definitions)


## 作用：获取状态效果定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_status_definitions() -> Array[Dictionary]:
	return _get_definition_values(_status_definitions)


## 作用：获取升级定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_upgrade_definitions() -> Array[Dictionary]:
	return _get_definition_values(_upgrade_definitions)


## 作用：获取诅咒选择定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_curse_choice_definitions() -> Array[Dictionary]:
	return _curse_choice_pool.duplicate(true)


## 作用：获取升级升级定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_level_up_upgrade_definitions() -> Array[Dictionary]:
	return _level_up_upgrade_pool.duplicate(true)


## 作用：获取永久升级定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_permanent_upgrade_definitions() -> Array[Dictionary]:
	return _permanent_upgrade_pool.duplicate(true)


## 作用：获取稀有度权重；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_rarity_weights() -> Dictionary:
	return _rarity_weights.duplicate(true)


## 作用：获取角色定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_character_definitions() -> Array[Dictionary]:
	return _get_definition_values(_character_definitions)


## 作用：获取协同定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_synergy_definitions() -> Array[Dictionary]:
	return _synergy_definitions.duplicate(true)


## 作用：获取波次配置；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_wave_config() -> Dictionary:
	return _wave_config.duplicate(true)


## 作用：获取技能系统配置；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_skill_system_config() -> Dictionary:
	return _skill_system_config.duplicate(true)


## 作用：获取成长目标列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_progression_goals() -> Dictionary:
	return _progression_goals.duplicate(true)


## 作用：获取每日挑战定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_daily_challenge_definitions() -> Array[Dictionary]:
	return _daily_challenge_definitions.duplicate(true)


## 作用：获取每周挑战定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_weekly_challenge_definitions() -> Array[Dictionary]:
	return _weekly_challenge_definitions.duplicate(true)


## 作用：索引定义列表。
## 使用：本文件由 _publish_documents 调用；输入 document（文档数据）、key（键）、id_key（ID键）、target（目标）、path（路径）。
func _index_definitions(document: Dictionary, key: String, id_key: String, target: Dictionary, path: String) -> void:
	DataDefinitionIndexScript.index_definitions(document, key, id_key, target, path)


## 作用：索引升级定义列表。
## 使用：本文件由 _publish_documents 调用；输入 document（文档数据）、key（键）、path（路径）。
func _index_upgrade_definitions(document: Dictionary, key: String, path: String) -> void:
	DataDefinitionIndexScript.index_upgrade_definitions(document, key, path, _upgrade_definitions, _level_up_upgrade_definitions)


## 作用：获取字典数组，供当前模块后续逻辑使用。
## 使用：本文件由 _publish_documents 调用；输入 document（文档数据）、key（键）、path（路径）；返回 Array[Dictionary] 列表。
func _get_dictionary_array(document: Dictionary, key: String, path: String) -> Array[Dictionary]:
	return DataDefinitionIndexScript.get_dictionary_array(document, key, path)


## 作用：获取定义，供当前模块后续逻辑使用。
## 使用：本文件由 get_skill_definition、get_enemy_definition、get_enemy_skill_definition 调用；输入 source（来源）、definition_id（定义ID）；返回结果字典。
func _get_definition(source: Dictionary, definition_id: Variant) -> Dictionary:
	return DataDefinitionIndexScript.get_definition(source, definition_id)


## 作用：获取定义值列表，供当前模块后续逻辑使用。
## 使用：本文件由 get_map_definitions、get_skill_definitions、get_relic_definitions 调用；输入 source（来源）；返回 Array[Dictionary] 列表。
func _get_definition_values(source: Dictionary) -> Array[Dictionary]:
	return DataDefinitionIndexScript.get_definition_values(source)


## 作用：获取召唤定义；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表；输入 summon_id（召唤ID）。
func get_summon_definition(summon_id: Variant) -> Dictionary:
	return _get_definition(_summon_definitions, summon_id)


## 作用：获取召唤定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_summon_definitions() -> Array[Dictionary]:
	return _get_definition_values(_summon_definitions)


## 作用：获取神系定义列表；查询已发布配置并隔离调用者修改。
## 使用：成功加载后使用；返回独立配置容器或定义列表。
func get_god_definitions() -> Array[Dictionary]:
	return _god_definitions.duplicate(true)
