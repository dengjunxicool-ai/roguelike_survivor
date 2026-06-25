extends RefCounted
class_name GameData


const SKILLS_PATH: String = "res://data/skills.json"
const ENEMIES_PATH: String = "res://data/enemies.json"
const ENEMY_SKILLS_PATH: String = "res://data/enemy_skills.json"
const STATUS_EFFECTS_PATH: String = "res://data/status_effects.json"
const UPGRADES_PATH: String = "res://data/upgrades.json"
const WAVES_PATH: String = "res://data/waves.json"
const CHARACTERS_PATH: String = "res://data/characters.json"
const MAPS_PATH: String = "res://data/maps.json"
const RELICS_PATH: String = "res://data/relics.json"
const PROGRESSION_GOALS_PATH: String = "res://data/progression_goals.json"
const CHALLENGES_PATH: String = "res://data/challenges.json"
const FIRE_SKILL_LEARN_UPGRADE_PREFIX: String = "learn_fire_skill_"

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
		return data
	var skills: Array[Dictionary] = _get_dictionary_array(SKILLS_PATH, "starting_skills")
	skills.append_array(_get_dictionary_array(SKILLS_PATH, "skills"))
	return skills


static func get_primary_attack_pool() -> Array[Dictionary]:
	return get_skill_pool()


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
	if upgrade_id_text.begins_with(FIRE_SKILL_LEARN_UPGRADE_PREFIX):
		var skill_id: StringName = StringName(upgrade_id_text.substr(FIRE_SKILL_LEARN_UPGRADE_PREFIX.length()))
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


static func _make_fire_skill_learn_upgrade(upgrade_id: String, skill_id: StringName) -> Dictionary:
	if skill_id == &"":
		return {}
	var skill: Dictionary = get_skill(skill_id)
	if skill.is_empty():
		return {}
	if not _is_fire_related_skill(skill):
		return {}
	if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary_from_value(skill.get("offer_rule", {})).is_empty():
		return {}

	var tags: Array = []
	for tag_variant: Variant in _get_array(SKILLS_PATH, "skills"):
		if not (tag_variant is Dictionary):
			continue
		var candidate: Dictionary = tag_variant
		if StringName(String(candidate.get("id", ""))) == skill_id:
			tags = _build_fire_skill_learn_tags(candidate)
			break
	if tags.is_empty():
		tags = _build_fire_skill_learn_tags(skill)

	var description: String = String(skill.get("description", "Learn %s." % String(skill_id)))
	return {
		"id": upgrade_id,
		"display_name": String(skill.get("display_name", skill_id)),
		"description": description,
		"rarity": String(skill.get("rarity", "common")),
		"tags": tags,
		"enabled": true,
		"max_level": 1,
		"learn_skill_id": String(skill_id),
		"god_id": "fire",
		"level_descriptions": [description]
	}


static func _is_fire_related_skill(skill: Dictionary) -> bool:
	if StringName(String(skill.get("god_id", ""))) == &"fire":
		return true
	if StringName(String(skill.get("school", ""))) == &"fire":
		return true
	if StringName(String(skill.get("fusion_school", ""))) == &"fire":
		return true
	for tag_variant: Variant in _get_array_from_value(skill.get("tags", [])):
		if String(tag_variant) == "fire":
			return true
	return false


static func _get_dictionary_from_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


static func _build_fire_skill_learn_tags(skill: Dictionary) -> Array:
	var tags: Array = []
	for tag_variant: Variant in _get_array_from_value(skill.get("tags", [])):
		var tag: String = String(tag_variant)
		if tag != "" and not tags.has(tag):
			tags.append(tag)
	if not tags.has("fire"):
		tags.push_front("fire")
	if not tags.has("skill"):
		tags.push_front("skill")
	return tags


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
	var document: Dictionary = _load_document(path)
	var value: Variant = document.get(key, [])
	return _get_array_from_value(value)


static func _get_array_from_value(value: Variant) -> Array:
	if value is Array:
		var array_value: Array = value
		return array_value

	return []


static func _get_dictionary_array(path: String, key: String) -> Array[Dictionary]:
	var source_items: Array = _get_array(path, key)
	var dictionary_items: Array[Dictionary] = []

	for item_variant: Variant in source_items:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			dictionary_items.append(item)

	return dictionary_items


static func _find_by_id(items: Array, target_id: StringName) -> Dictionary:
	for item_variant: Variant in items:
		if not (item_variant is Dictionary):
			continue

		var item: Dictionary = item_variant
		var item_id: StringName = StringName(String(item.get("id", "")))
		if item_id == target_id:
			return item

	return {}


static func _load_document(path: String) -> Dictionary:
	if _document_cache.has(path):
		var cached_document: Dictionary = _document_cache[path]
		return cached_document

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open data file: %s" % path)
		_document_cache[path] = {}
		return {}

	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Could not parse data file as Dictionary: %s" % path)
		_document_cache[path] = {}
		return {}

	var document: Dictionary = parsed
	_document_cache[path] = document
	return document


static func _get_data_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null

	return tree.root.get_node_or_null("DataManager")


static func _get_definition_from_data_manager(method_name: String, definition_id: Variant) -> Dictionary:
	var data_manager: Node = _get_data_manager()
	if data_manager == null or not data_manager.has_method(method_name):
		return {}

	var data: Variant = data_manager.call(method_name, definition_id)
	if data is Dictionary:
		var definition: Dictionary = data
		return definition
	return {}


static func _get_pool_from_data_manager(method_name: String) -> Array[Dictionary]:
	var data_manager: Node = _get_data_manager()
	if data_manager == null or not data_manager.has_method(method_name):
		return []

	var data: Variant = data_manager.call(method_name)
	if not (data is Array):
		return []

	var items: Array[Dictionary] = []
	for item_variant: Variant in data:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			items.append(item)
	return items
