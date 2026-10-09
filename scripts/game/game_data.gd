## 文件用途：为业务提供统一玩法数据查询门面。
## 使用方式：静态调用 get_*；仅访问已加载 DataManager，不另行读盘或维护配置缓存。

extends RefCounted
class_name GameData


## 作用：所属服务。
## 使用：本文件由 get_skill、get_skill_system_config、get_enemy 调用；返回 Node 对象/值。
static func _owner() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var owner: Node = tree.root.get_node_or_null("DataManager") if tree != null else null
	assert(owner != null, "[GameData] DataManager must be initialized.")
	assert(owner.is_loaded, "[GameData] Content must pass validation before use.")
	return owner


## 作用：获取技能；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_skill 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_skill(definition_id: StringName) -> Dictionary:
	return _owner().get_skill_definition(definition_id)


## 作用：获取技能系统配置；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_skill_system_config 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回结果字典。
static func get_skill_system_config() -> Dictionary:
	return _owner().get_skill_system_config()


## 作用：获取敌人；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_enemy 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_enemy(definition_id: StringName) -> Dictionary:
	return _owner().get_enemy_definition(definition_id)


## 作用：获取敌方技能；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_enemy_skill 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_enemy_skill(definition_id: StringName) -> Dictionary:
	return _owner().get_enemy_skill_definition(definition_id)


## 作用：获取角色；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_character 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_character(definition_id: StringName) -> Dictionary:
	return _owner().get_character_definition(definition_id)


## 作用：获取地图；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_map 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_map(definition_id: StringName) -> Dictionary:
	return _owner().get_map_definition(definition_id)


## 作用：获取遗物；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_relic 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_relic(definition_id: StringName) -> Dictionary:
	return _owner().get_relic_definition(definition_id)


## 作用：获取状态效果；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_status 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_status(definition_id: StringName) -> Dictionary:
	return _owner().get_status_definition(definition_id)


## 作用：获取战斗对象；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_combat_object 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_combat_object(definition_id: StringName) -> Dictionary:
	return _owner().get_combat_object_definition(definition_id)


## 作用：获取升级；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_upgrade 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_upgrade(definition_id: StringName) -> Dictionary:
	return _owner().get_upgrade_definition(definition_id)


## 作用：获取召唤；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_summon 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 definition_id（定义ID）；返回结果字典。
static func get_summon(definition_id: StringName) -> Dictionary:
	return _owner().get_summon_definition(definition_id)


## 作用：获取全部技能池；转发给统一 DataManager 数据 owner。
## 使用：本文件由 get_skill_pool 调用；返回 Array[Dictionary] 列表。
static func get_all_skill_pool() -> Array[Dictionary]:
	return _owner().get_skill_definitions()


## 作用：获取起始技能池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_starting_skill_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_starting_skill_pool() -> Array[Dictionary]:
	return _owner().get_starting_skill_definitions()


## 作用：获取敌人池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_enemy_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_enemy_pool() -> Array[Dictionary]:
	return _owner().get_enemy_definitions()


## 作用：获取敌方技能池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_enemy_skill_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_enemy_skill_pool() -> Array[Dictionary]:
	return _owner().get_enemy_skill_definitions()


## 作用：获取角色池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_character_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_character_pool() -> Array[Dictionary]:
	return _owner().get_character_definitions()


## 作用：获取地图池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_map_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_map_pool() -> Array[Dictionary]:
	return _owner().get_map_definitions()


## 作用：获取遗物池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_relic_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_relic_pool() -> Array[Dictionary]:
	return _owner().get_relic_definitions()


## 作用：获取状态效果池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_status_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_status_pool() -> Array[Dictionary]:
	return _owner().get_status_definitions()


## 作用：获取协同池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_synergy_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_synergy_pool() -> Array[Dictionary]:
	return _owner().get_synergy_definitions()


## 作用：获取神系池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_god_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_god_pool() -> Array[Dictionary]:
	return _owner().get_god_definitions()


## 作用：获取召唤池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_summon_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_summon_pool() -> Array[Dictionary]:
	return _owner().get_summon_definitions()


## 作用：获取诅咒选择池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_curse_choice_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_curse_choice_pool() -> Array[Dictionary]:
	return _owner().get_curse_choice_definitions()


## 作用：获取升级升级池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_level_up_upgrade_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_level_up_upgrade_pool() -> Array[Dictionary]:
	return _owner().get_level_up_upgrade_definitions()


## 作用：获取永久升级池；转发给统一 DataManager 数据 owner。
## 使用：本文件由 get_permanent_upgrade 调用；返回 Array[Dictionary] 列表。
static func get_permanent_upgrade_pool() -> Array[Dictionary]:
	return _owner().get_permanent_upgrade_definitions()


## 作用：获取每日挑战池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_daily_challenge_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_daily_challenge_pool() -> Array[Dictionary]:
	return _owner().get_daily_challenge_definitions()


## 作用：获取每周挑战池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_weekly_challenge_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_weekly_challenge_pool() -> Array[Dictionary]:
	return _owner().get_weekly_challenge_definitions()


## 作用：获取稀有度权重；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_rarity_weights 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回结果字典。
static func get_rarity_weights() -> Dictionary:
	return _owner().get_rarity_weights()


## 作用：获取波次配置；转发给统一 DataManager 数据 owner。
## 使用：本文件由 get_run_config 调用；返回结果字典。
static func get_wave_config() -> Dictionary:
	return _owner().get_wave_config()


## 作用：获取成长目标列表；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_progression_goals 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回结果字典。
static func get_progression_goals() -> Dictionary:
	return _owner().get_progression_goals()


## 作用：获取技能池；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_skill_pool 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回 Array[Dictionary] 列表。
static func get_skill_pool() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill: Dictionary in get_all_skill_pool():
		if not bool(skill.get("is_starting_skill", false)):
			result.append(skill)
	return result


## 作用：获取永久升级；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_permanent_upgrade 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；输入 upgrade_id（升级ID）；返回结果字典。
static func get_permanent_upgrade(upgrade_id: StringName) -> Dictionary:
	for upgrade: Dictionary in get_permanent_upgrade_pool():
		if StringName(upgrade["id"]) == upgrade_id:
			return upgrade
	return {}


## 作用：获取单局配置；转发给统一 DataManager 数据 owner。
## 使用：通过 GameData.get_run_config 静态调用；须先完成 DataManager 加载，不读取第二份配置或缓存；返回结果字典。
static func get_run_config() -> Dictionary:
	return get_wave_config().get("run", {}).duplicate(true)
