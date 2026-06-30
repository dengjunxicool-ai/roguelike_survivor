extends RefCounted
class_name GameData
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataAccessScript: Script = preload("res://scripts/core/game_data_access.gd")


const SKILLS_PATH: String = DataPathsScript.SKILLS_PATH
const ENEMIES_PATH: String = DataPathsScript.ENEMIES_PATH
const ENEMY_SKILLS_PATH: String = DataPathsScript.ENEMY_SKILLS_PATH
const STATUS_EFFECTS_PATH: String = DataPathsScript.STATUS_EFFECTS_PATH
const UPGRADES_PATH: String = DataPathsScript.UPGRADES_PATH
const WAVES_PATH: String = DataPathsScript.WAVES_PATH
const CHARACTERS_PATH: String = DataPathsScript.CHARACTERS_PATH
const MAPS_PATH: String = DataPathsScript.MAPS_PATH
const RELICS_PATH: String = DataPathsScript.RELICS_PATH
const PROGRESSION_GOALS_PATH: String = DataPathsScript.PROGRESSION_GOALS_PATH
const CHALLENGES_PATH: String = DataPathsScript.CHALLENGES_PATH
const SKILL_LEARN_UPGRADE_PREFIX: String = "learn_skill_"
const LEGACY_FIRE_SKILL_LEARN_UPGRADE_PREFIX: String = "learn_fire_skill_"

static var _document_cache: Dictionary = {}


static func get_skill(skill_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_skill_definition", skill_id)
	if not data.is_empty():
		return data
	var god_starting_skill: Dictionary = _find_by_id(_get_array(SKILLS_PATH, "starting_skills"), skill_id)
	if not god_starting_skill.is_empty():
		return god_starting_skill
	var god_skill: Dictionary = _find_by_id(_get_array(SKILLS_PATH, "skills"), skill_id)
	if not god_skill.is_empty():
		return god_skill
	return {}


static func get_primary_attack(attack_id: StringName) -> Dictionary:
	return get_skill(attack_id)


static func get_enemy(enemy_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_enemy_definition", enemy_id)
	if not data.is_empty():
		return data
	return _find_by_id(_get_array(ENEMIES_PATH, "monsters"), enemy_id)


static func get_enemy_skill(skill_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_enemy_skill_definition", skill_id)
	if not data.is_empty():
		return data
	return _find_by_id(_get_array(ENEMY_SKILLS_PATH, "enemy_skills"), skill_id)


static func get_character(character_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_character_definition", character_id)
	if not data.is_empty():
		return data
	return _find_by_id(_get_array(CHARACTERS_PATH, "characters"), character_id)


static func get_map(map_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_map_definition", map_id)
	if not data.is_empty():
		return data
	return _find_by_id(_get_array(MAPS_PATH, "maps"), map_id)


static func get_character_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_character_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(CHARACTERS_PATH, "characters")


static func get_map_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_map_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(MAPS_PATH, "maps")


static func get_relic_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_relic_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(RELICS_PATH, "relics")


static func get_progression_goals() -> Dictionary:
	return _load_document(PROGRESSION_GOALS_PATH).duplicate(true)


static func get_daily_challenge_pool() -> Array[Dictionary]:
	return _get_dictionary_array(CHALLENGES_PATH, "daily_challenges")


static func get_weekly_challenge_pool() -> Array[Dictionary]:
	return _get_dictionary_array(CHALLENGES_PATH, "weekly_challenges")


static func get_skill_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_skill_definitions")
	if not data.is_empty():
		return _filter_out_starting_skill_definitions(data)
	return _filter_out_starting_skill_definitions(_get_dictionary_array(SKILLS_PATH, "skills"))


static func get_primary_attack_pool() -> Array[Dictionary]:
	var skills: Array[Dictionary] = _get_dictionary_array(SKILLS_PATH, "starting_skills")
	skills.append_array(get_skill_pool())
	return skills


static func _filter_out_starting_skill_definitions(skills: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill: Dictionary in skills:
		if bool(skill.get("is_starting_skill", false)):
			continue
		if StringName(_string_or(skill.get("id", ""), "")) == &"fireball":
			continue
		result.append(skill)
	return result


static func get_enemy_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_enemy_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(ENEMIES_PATH, "monsters")


static func get_enemy_skill_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_enemy_skill_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(ENEMY_SKILLS_PATH, "enemy_skills")


static func get_status_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_status_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(STATUS_EFFECTS_PATH, "statuses")


static func get_curse_choice_pool() -> Array[Dictionary]:
	return _get_dictionary_array(UPGRADES_PATH, "curse_choices")


static func get_level_up_upgrade_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_level_up_upgrade_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(UPGRADES_PATH, "level_up_upgrades")


static func get_upgrade(upgrade_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_upgrade_definition", upgrade_id)
	if not data.is_empty():
		return data

	var upgrade_id_text: String = String(upgrade_id)
	if upgrade_id_text.begins_with(SKILL_LEARN_UPGRADE_PREFIX):
		var skill_id: StringName = StringName(upgrade_id_text.substr(SKILL_LEARN_UPGRADE_PREFIX.length()))
		return _make_skill_learn_upgrade(upgrade_id_text, skill_id)
	if upgrade_id_text.begins_with(LEGACY_FIRE_SKILL_LEARN_UPGRADE_PREFIX):
		var skill_id: StringName = StringName(upgrade_id_text.substr(LEGACY_FIRE_SKILL_LEARN_UPGRADE_PREFIX.length()))
		return _make_fire_skill_learn_upgrade(upgrade_id_text, skill_id)

	var categories: Array[String] = [
		"curse_choices",
		"level_up_upgrades",
		"permanent_upgrades"
	]

	for category: String in categories:
		var upgrade: Dictionary = _find_by_id(_get_array(UPGRADES_PATH, category), upgrade_id)
		if not upgrade.is_empty():
			return upgrade

	return {}


static func _make_skill_learn_upgrade(upgrade_id: String, skill_id: StringName) -> Dictionary:
	if skill_id == &"":
		return {}
	var skill: Dictionary = get_skill(skill_id)
	if skill.is_empty():
		return {}
	if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary_from_value(skill.get("offer_rule", {})).is_empty():
		return {}

	var tags: Array = []
	for tag_variant: Variant in _get_array(SKILLS_PATH, "skills"):
		if not (tag_variant is Dictionary):
			continue
		var candidate: Dictionary = tag_variant
		if StringName(String(candidate.get("id", ""))) == skill_id:
			tags = _build_skill_learn_tags(candidate)
			break
	if tags.is_empty():
		tags = _build_skill_learn_tags(skill)

	var description: String = _string_or(skill.get("description", "Learn %s." % _string_or(skill_id, "")), "")
	return {
		"id": upgrade_id,
		"display_name": _string_or(skill.get("display_name", skill_id), _string_or(skill_id, "")),
		"description": description,
		"rarity": _string_or(skill.get("rarity", "common"), "common"),
		"tags": tags,
		"enabled": true,
		"max_level": 1,
		"learn_skill_id": _string_or(skill_id, ""),
		"god_id": _string_or(_get_skill_god_id(skill), ""),
		"level_descriptions": [description]
	}


static func _make_fire_skill_learn_upgrade(upgrade_id: String, skill_id: StringName) -> Dictionary:
	var upgrade: Dictionary = _make_skill_learn_upgrade(upgrade_id, skill_id)
	if upgrade.is_empty() or not _is_fire_related_skill(get_skill(skill_id)):
		return {}
	return upgrade


static func _is_fire_related_skill(skill: Dictionary) -> bool:
	if StringName(_string_or(skill.get("god_id", ""), "")) == &"fire":
		return true
	if StringName(_string_or(skill.get("school", ""), "")) == &"fire":
		return true
	if StringName(_string_or(skill.get("fusion_school", ""), "")) == &"fire":
		return true
	for tag_variant: Variant in _get_array_from_value(skill.get("tags", [])):
		if _string_or(tag_variant, "") == "fire":
			return true
	return false


static func _string_or(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return str(value)


static func _get_dictionary_from_value(value: Variant) -> Dictionary:
	return GameDataAccessScript.get_dictionary_from_value(value)


static func _build_skill_learn_tags(skill: Dictionary) -> Array:
	var tags: Array = []
	for tag_variant: Variant in _get_array_from_value(skill.get("tags", [])):
		var tag: String = String(tag_variant)
		if tag != "" and not tags.has(tag):
			tags.append(tag)
	var god_id: String = _string_or(_get_skill_god_id(skill), "")
	if god_id != "" and not tags.has(god_id):
		tags.push_front(god_id)
	if not tags.has("skill"):
		tags.push_front("skill")
	return tags


static func _get_skill_god_id(skill: Dictionary) -> StringName:
	for key: String in ["god_id", "school", "fusion_school"]:
		var value: String = _string_or(skill.get(key, ""), "")
		if value != "":
			return StringName(value)
	for tag_variant: Variant in _get_array_from_value(skill.get("tags", [])):
		var tag: String = _string_or(tag_variant, "")
		if tag in ["fire", "frost", "thunder", "curse", "holy", "chaos"]:
			return StringName(tag)
	return &""


static func get_permanent_upgrade(upgrade_id: StringName) -> Dictionary:
	return _find_by_id(_get_array(UPGRADES_PATH, "permanent_upgrades"), upgrade_id)


static func get_permanent_upgrade_pool() -> Array[Dictionary]:
	return _get_dictionary_array(UPGRADES_PATH, "permanent_upgrades")


static func get_rarity_weights() -> Dictionary:
	var document: Dictionary = _load_document(UPGRADES_PATH)
	var weights: Variant = document.get("rarity_weights", {})
	if weights is Dictionary:
		var weight_data: Dictionary = weights
		return weight_data

	return {}


static func get_run_config() -> Dictionary:
	var document: Dictionary = get_wave_config()
	var run_config: Variant = document.get("run", {})
	if run_config is Dictionary:
		var run_data: Dictionary = run_config
		return run_data

	return {}


static func get_wave_config() -> Dictionary:
	var data_manager: Node = _get_data_manager()
	if data_manager != null and data_manager.has_method("get_wave_config"):
		var data: Variant = data_manager.call("get_wave_config")
		if data is Dictionary:
			var wave_data: Dictionary = data
			if not wave_data.is_empty():
				return wave_data

	return _load_document(WAVES_PATH)


static func _get_array(path: String, key: String) -> Array:
	return GameDataAccessScript.get_array(_document_cache, path, key)


static func _get_array_from_value(value: Variant) -> Array:
	return GameDataAccessScript.get_array_from_value(value)


static func _get_dictionary_array(path: String, key: String) -> Array[Dictionary]:
	return GameDataAccessScript.get_dictionary_array(_document_cache, path, key)


static func _find_by_id(items: Array, target_id: StringName) -> Dictionary:
	return GameDataAccessScript.find_by_id(items, target_id)


static func _load_document(path: String) -> Dictionary:
	return GameDataAccessScript.load_document(_document_cache, path)


static func _get_data_manager() -> Node:
	return GameDataAccessScript.get_data_manager()


static func _get_definition_from_data_manager(method_name: String, definition_id: Variant) -> Dictionary:
	return GameDataAccessScript.get_definition_from_data_manager(method_name, definition_id)


static func _get_pool_from_data_manager(method_name: String) -> Array[Dictionary]:
	return GameDataAccessScript.get_pool_from_data_manager(method_name)
