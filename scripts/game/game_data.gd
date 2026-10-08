extends RefCounted
class_name GameData


static func _owner() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var owner: Node = tree.root.get_node_or_null("DataManager") if tree != null else null
	assert(owner != null, "[GameData] DataManager must be initialized.")
	assert(owner.is_loaded, "[GameData] Content must pass validation before use.")
	return owner


static func get_skill(definition_id: StringName) -> Dictionary:
	return _owner().get_skill_definition(definition_id)


static func get_skill_system_config() -> Dictionary:
	return _owner().get_skill_system_config()


static func get_enemy(definition_id: StringName) -> Dictionary:
	return _owner().get_enemy_definition(definition_id)


static func get_enemy_skill(definition_id: StringName) -> Dictionary:
	return _owner().get_enemy_skill_definition(definition_id)


static func get_character(definition_id: StringName) -> Dictionary:
	return _owner().get_character_definition(definition_id)


static func get_map(definition_id: StringName) -> Dictionary:
	return _owner().get_map_definition(definition_id)


static func get_relic(definition_id: StringName) -> Dictionary:
	return _owner().get_relic_definition(definition_id)


static func get_status(definition_id: StringName) -> Dictionary:
	return _owner().get_status_definition(definition_id)


static func get_combat_object(definition_id: StringName) -> Dictionary:
	return _owner().get_combat_object_definition(definition_id)


static func get_upgrade(definition_id: StringName) -> Dictionary:
	return _owner().get_upgrade_definition(definition_id)


static func get_summon(definition_id: StringName) -> Dictionary:
	return _owner().get_summon_definition(definition_id)


static func get_all_skill_pool() -> Array[Dictionary]:
	return _owner().get_skill_definitions()


static func get_starting_skill_pool() -> Array[Dictionary]:
	return _owner().get_starting_skill_definitions()


static func get_enemy_pool() -> Array[Dictionary]:
	return _owner().get_enemy_definitions()


static func get_enemy_skill_pool() -> Array[Dictionary]:
	return _owner().get_enemy_skill_definitions()


static func get_character_pool() -> Array[Dictionary]:
	return _owner().get_character_definitions()


static func get_map_pool() -> Array[Dictionary]:
	return _owner().get_map_definitions()


static func get_relic_pool() -> Array[Dictionary]:
	return _owner().get_relic_definitions()


static func get_status_pool() -> Array[Dictionary]:
	return _owner().get_status_definitions()


static func get_synergy_pool() -> Array[Dictionary]:
	return _owner().get_synergy_definitions()


static func get_god_pool() -> Array[Dictionary]:
	return _owner().get_god_definitions()


static func get_summon_pool() -> Array[Dictionary]:
	return _owner().get_summon_definitions()


static func get_curse_choice_pool() -> Array[Dictionary]:
	return _owner().get_curse_choice_definitions()


static func get_level_up_upgrade_pool() -> Array[Dictionary]:
	return _owner().get_level_up_upgrade_definitions()


static func get_permanent_upgrade_pool() -> Array[Dictionary]:
	return _owner().get_permanent_upgrade_definitions()


static func get_daily_challenge_pool() -> Array[Dictionary]:
	return _owner().get_daily_challenge_definitions()


static func get_weekly_challenge_pool() -> Array[Dictionary]:
	return _owner().get_weekly_challenge_definitions()


static func get_rarity_weights() -> Dictionary:
	return _owner().get_rarity_weights()


static func get_wave_config() -> Dictionary:
	return _owner().get_wave_config()


static func get_progression_goals() -> Dictionary:
	return _owner().get_progression_goals()


static func get_skill_pool() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill: Dictionary in get_all_skill_pool():
		if not bool(skill.get("is_starting_skill", false)):
			result.append(skill)
	return result


static func get_permanent_upgrade(upgrade_id: StringName) -> Dictionary:
	for upgrade: Dictionary in get_permanent_upgrade_pool():
		if StringName(upgrade["id"]) == upgrade_id:
			return upgrade
	return {}


static func get_run_config() -> Dictionary:
	return get_wave_config().get("run", {}).duplicate(true)
