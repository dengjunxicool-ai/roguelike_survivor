extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")
const SkillManagerScript := preload("res://scripts/skills/skill_manager.gd")
const CharacterRunInitializerScript := preload("res://scripts/characters/character_run_initializer.gd")

class MissingAccessorManager:
	extends Node

class WrongTypeManager:
	extends Node

	func get_starting_skill_definitions() -> Variant:
		return "not-an-array"

	func get_skill_definition(_skill_id: Variant) -> Variant:
		return "not-a-dictionary"

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return

	var starting_source: Array[Dictionary] = _source_skills("starting_skills")
	var normal_source: Array[Dictionary] = _source_skills("skills")
	_expect(not starting_source.is_empty(), "source starting-skill pool is non-empty")
	_expect(not normal_source.is_empty(), "source normal-skill pool is non-empty")
	if starting_source.is_empty() or normal_source.is_empty():
		_finish()
		return

	_verify_owner_facade_and_lookup(manager, starting_source, normal_source)
	_verify_manager_source(manager)
	_verify_empty_owner_fallback(manager, starting_source, normal_source)
	_verify_replacement_manager_fallback(manager, starting_source, normal_source, MissingAccessorManager.new(), "missing accessor")
	_verify_replacement_manager_fallback(manager, starting_source, normal_source, WrongTypeManager.new(), "wrong-type accessor")
	_verify_full_fallback(manager, starting_source, normal_source)
	_finish()


func _source_skills(section: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in JsonDataLoaderScript.load_array(
		DataPathsScript.SKILLS_PATH,
		section,
		"verify_data_access_skills"
	):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _verify_owner_facade_and_lookup(
	manager: Node,
	starting_source: Array[Dictionary],
	normal_source: Array[Dictionary]
) -> void:
	var owner_pool: Array[Dictionary] = _to_dictionary_array(manager.call("get_starting_skill_definitions"))
	var facade_pool: Array[Dictionary] = GameDataScript.get_starting_skill_pool()
	_expect(_ids(owner_pool) == _ids(starting_source), "owner starting-skill IDs and order match source")
	_expect(owner_pool == starting_source, "owner starting-skill pool matches source")
	_expect(_ids(facade_pool) == _ids(starting_source), "facade starting-skill IDs and order match source")
	_expect(facade_pool == starting_source, "facade starting-skill pool matches source")

	var first_starting_id: StringName = _first_valid_id(starting_source)
	var first_normal_id: StringName = _first_valid_id(normal_source)
	_expect(first_starting_id != &"", "starting source has a valid first ID")
	_expect(GameDataScript.get_skill(first_starting_id) == starting_source[0], "facade finds starting skill")
	_expect(GameDataScript.get_skill(first_normal_id) == normal_source[0], "facade finds normal skill")
	_expect(GameDataScript.get_skill(&"__missing_phase6_skill__").is_empty(), "missing skill stays empty")

	var initializer: RefCounted = CharacterRunInitializerScript.new()
	_expect(
		StringName(initializer.call("_first_configured_starting_skill_id")) == first_starting_id,
		"character initializer preserves the first configured starting skill ID"
	)

	_mutate_definition(owner_pool[0], "__phase6_skill_owner__")
	_mutate_definition(facade_pool[0], "__phase6_skill_facade__")
	var lookup_probe: Dictionary = GameDataScript.get_skill(first_normal_id)
	_mutate_definition(lookup_probe, "__phase6_skill_lookup__")
	_expect(_to_dictionary_array(manager.call("get_starting_skill_definitions")) == starting_source, "owner starting-skill pool is isolated")
	_expect(GameDataScript.get_starting_skill_pool() == starting_source, "facade starting-skill pool is isolated")
	_expect(GameDataScript.get_skill(first_normal_id) == normal_source[0], "manager-backed skill lookup is isolated")


func _verify_manager_source(manager: Node) -> void:
	var original_pool: Array[Dictionary] = _to_dictionary_array(manager.get("_starting_skill_definitions")).duplicate(true)
	var original_definitions: Dictionary = (manager.get("_skill_definitions") as Dictionary).duplicate(true)
	var sentinel_id: StringName = &"__phase6_starting_skill_manager__"
	var sentinel: Dictionary = {
		"id": String(sentinel_id),
		"display_name": "Phase 6 Starting Skill",
		"base": {"damage": 17},
		"components": [{"type": "cooldown", "params": {"seconds": 1.0}}],
		"is_starting_skill": true
	}
	var sentinel_pool: Array[Dictionary] = [sentinel.duplicate(true)]
	manager.set("_starting_skill_definitions", sentinel_pool)
	manager.set("_skill_definitions", {sentinel_id: sentinel.duplicate(true)})
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_starting_skill_pool() == [sentinel], "facade prefers manager starting-skill sentinel")
	_expect(GameDataScript.get_skill(sentinel_id) == sentinel, "facade lookup prefers manager skill sentinel")
	_expect(not GameDataScript._document_cache.has(DataPathsScript.SKILLS_PATH), "manager paths avoid skill JSON cache")

	var skill_manager: Node = SkillManagerScript.new()
	root.add_child(skill_manager)
	_expect(skill_manager.call("_get_primary_starting_skill_data") == sentinel, "SkillManager primary source uses facade sentinel")
	_expect(skill_manager.call("_get_skill_definition_data", sentinel_id) == sentinel, "SkillManager lookup uses facade sentinel")
	skill_manager.free()

	var initializer: RefCounted = CharacterRunInitializerScript.new()
	_expect(
		StringName(initializer.call("_first_configured_starting_skill_id")) == sentinel_id,
		"character initializer uses facade sentinel order"
	)

	manager.set("_starting_skill_definitions", original_pool)
	manager.set("_skill_definitions", original_definitions)
	GameDataScript._document_cache.clear()


func _verify_empty_owner_fallback(
	manager: Node,
	starting_source: Array[Dictionary],
	normal_source: Array[Dictionary]
) -> void:
	var original_pool: Array[Dictionary] = _to_dictionary_array(manager.get("_starting_skill_definitions")).duplicate(true)
	var original_definitions: Dictionary = (manager.get("_skill_definitions") as Dictionary).duplicate(true)
	var empty_pool: Array[Dictionary] = []
	manager.set("_starting_skill_definitions", empty_pool)
	manager.set("_skill_definitions", {})
	GameDataScript._document_cache.clear()
	var fallback: Array[Dictionary] = GameDataScript.get_starting_skill_pool()
	_expect(fallback == starting_source, "empty owner starting-skill pool falls back")
	_expect(GameDataScript.get_skill(_first_valid_id(starting_source)) == starting_source[0], "empty owner starting lookup falls back")
	_expect(GameDataScript.get_skill(_first_valid_id(normal_source)) == normal_source[0], "empty owner normal lookup falls back")
	_expect(GameDataScript._document_cache.has(DataPathsScript.SKILLS_PATH), "empty owner fallback uses skill document cache")
	_mutate_definition(fallback[0], "__phase6_skill_empty_owner_pool__")
	var lookup_probe: Dictionary = GameDataScript.get_skill(_first_valid_id(normal_source))
	_mutate_definition(lookup_probe, "__phase6_skill_empty_owner_lookup__")
	_expect(GameDataScript.get_starting_skill_pool() == starting_source, "empty owner starting-skill fallback is isolated")
	_expect(GameDataScript.get_skill(_first_valid_id(normal_source)) == normal_source[0], "empty owner skill fallback is isolated")
	manager.set("_starting_skill_definitions", original_pool)
	manager.set("_skill_definitions", original_definitions)
	GameDataScript._document_cache.clear()


func _verify_replacement_manager_fallback(
	manager: Node,
	starting_source: Array[Dictionary],
	normal_source: Array[Dictionary],
	replacement: Node,
	label: String
) -> void:
	var original_name: StringName = manager.name
	manager.name = &"Phase6SkillOwnerUnavailable"
	replacement.name = &"DataManager"
	root.add_child(replacement)
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_starting_skill_pool() == starting_source, "%s falls back to starting-skill JSON" % label)
	_expect(GameDataScript.get_skill(_first_valid_id(starting_source)) == starting_source[0], "%s finds starting skill" % label)
	_expect(GameDataScript.get_skill(_first_valid_id(normal_source)) == normal_source[0], "%s finds normal skill" % label)
	replacement.free()
	manager.name = original_name
	GameDataScript._document_cache.clear()


func _verify_full_fallback(
	manager: Node,
	starting_source: Array[Dictionary],
	normal_source: Array[Dictionary]
) -> void:
	var original_name: StringName = manager.name
	manager.name = &"Phase6SkillUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var pool_fallback: Array[Dictionary] = GameDataScript.get_starting_skill_pool()
	var starting_lookup: Dictionary = GameDataScript.get_skill(_first_valid_id(starting_source))
	var normal_lookup: Dictionary = GameDataScript.get_skill(_first_valid_id(normal_source))
	_expect(_ids(pool_fallback) == _ids(starting_source), "full starting-skill fallback preserves IDs and order")
	_expect(pool_fallback == starting_source, "full starting-skill fallback matches source")
	_expect(starting_lookup == starting_source[0], "full fallback finds starting skill")
	_expect(normal_lookup == normal_source[0], "full fallback finds normal skill")
	_mutate_definition(pool_fallback[0], "__phase6_skill_full_pool__")
	_mutate_definition(starting_lookup, "__phase6_skill_full_starting_lookup__")
	_mutate_definition(normal_lookup, "__phase6_skill_full_normal_lookup__")
	_expect(GameDataScript.get_starting_skill_pool() == starting_source, "full starting-skill fallback is isolated")
	_expect(GameDataScript.get_skill(_first_valid_id(starting_source)) == starting_source[0], "full starting lookup fallback is isolated")
	_expect(GameDataScript.get_skill(_first_valid_id(normal_source)) == normal_source[0], "full normal lookup fallback is isolated")
	manager.name = original_name
	GameDataScript._document_cache.clear()


func _first_valid_id(pool: Array[Dictionary]) -> StringName:
	for item: Dictionary in pool:
		var item_id: StringName = StringName(String(item.get("id", "")))
		if item_id != &"":
			return item_id
	return &""


func _mutate_definition(definition: Dictionary, marker: String) -> void:
	var base: Dictionary = definition.get("base", {}) as Dictionary
	base[marker] = true
	var components: Array = definition.get("components", []) as Array
	if not components.is_empty() and components[0] is Dictionary:
		var component: Dictionary = components[0]
		component[marker] = true
	definition[marker] = true


func _ids(pool: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in pool:
		result.append(String(item.get("id", "")))
	return result


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_skills] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_skills] PASS")
	quit(1 if _failed else 0)
