extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")
const EnemySkillRepositoryScript := preload("res://scripts/enemies/skills/enemy_skill_repository.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return

	var source: Array[Dictionary] = _source_enemy_skills()
	_expect(not source.is_empty(), "source enemy skill pool is non-empty")
	if source.is_empty():
		_finish()
		return

	_verify_owner_and_facade(manager, source)
	_verify_manager_source(manager)
	_verify_empty_owner_authoritative(manager, source)
	_verify_repository_contract(manager, source)
	_finish()


func _source_enemy_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in JsonDataLoaderScript.load_array(
		DataPathsScript.ENEMY_SKILLS_PATH,
		"enemy_skills",
		"verify_data_access_enemy_skills"
	):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _verify_owner_and_facade(manager: Node, source: Array[Dictionary]) -> void:
	var owner_pool: Array[Dictionary] = _to_dictionary_array(manager.call("get_enemy_skill_definitions"))
	var facade_pool: Array[Dictionary] = GameDataScript.get_enemy_skill_pool()
	_expect(_ids(owner_pool) == _ids(source), "owner enemy skill IDs and order match source")
	_expect(owner_pool == source, "owner enemy skill pool matches source")
	_expect(facade_pool == source, "facade enemy skill pool matches source")
	_mutate_definition(owner_pool[0], "__phase6_enemy_skill_owner__")
	_mutate_definition(facade_pool[0], "__phase6_enemy_skill_facade__")
	_expect(_to_dictionary_array(manager.call("get_enemy_skill_definitions")) == source, "owner enemy skill pool is isolated")
	_expect(GameDataScript.get_enemy_skill_pool() == source, "facade enemy skill pool is isolated")


func _verify_manager_source(manager: Node) -> void:
	var original: Dictionary = manager.get("_enemy_skill_definitions").duplicate(true)
	var sentinel_id: StringName = &"__phase6_enemy_skill_manager__"
	var sentinel: Dictionary = {
		"id": String(sentinel_id),
		"display_name": "Phase 6 Enemy Skill",
		"runtime": "active",
		"cooldown": 2.5,
		"actions": [{"type": "damage", "amount": 17.0}]
	}
	manager.set("_enemy_skill_definitions", {sentinel_id: sentinel.duplicate(true)})
	_expect(GameDataScript.get_enemy_skill_pool() == [sentinel], "facade prefers manager enemy skill sentinel")

	var repository: RefCounted = EnemySkillRepositoryScript.new()
	var definition: RefCounted = repository.call("get_skill", sentinel_id) as RefCounted
	_expect(definition != null, "repository loads manager enemy skill sentinel")
	if definition != null:
		_expect(definition.call("to_dictionary") == sentinel, "repository preserves manager sentinel definition")
		_expect(is_equal_approx(float(definition.get("cooldown")), 2.5), "repository preserves manager sentinel cooldown")

	manager.set("_enemy_skill_definitions", original)


func _verify_empty_owner_authoritative(manager: Node, source: Array[Dictionary]) -> void:
	var original: Dictionary = (manager.get("_enemy_skill_definitions") as Dictionary).duplicate(true)
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	manager.set("_enemy_skill_definitions", {})
	_expect(GameDataScript.get_enemy_skill_pool().is_empty(), "empty owner remains authoritative")
	_expect(GameDataScript.get_enemy_skill_pool().is_empty(), "repeat lookup does not reload JSON")
	manager.set("_enemy_skill_definitions", original)


func _verify_repository_contract(manager: Node, source: Array[Dictionary]) -> void:
	var repository: RefCounted = EnemySkillRepositoryScript.new()
	var all_skills: Array[RefCounted] = repository.call("get_all_skills")
	_expect(all_skills.size() == source.size(), "repository loads every enemy skill")
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var first_definition: RefCounted = repository.call("get_skill", first_id) as RefCounted
	_expect(first_definition != null, "repository resolves known enemy skill")
	if first_definition != null:
		_expect(first_definition.call("to_dictionary") == source[0], "repository known skill matches source")
		_expect(repository.call("get_skill", first_id) == first_definition, "repository reuses cached definition instance")
	_expect(repository.call("get_skill", &"__missing_phase6_enemy_skill__") == null, "repository keeps unknown skill null")
	_expect(manager.name == &"DataManager", "DataManager name is restored after enemy skill probes")


func _mutate_definition(definition: Dictionary, marker: String) -> void:
	var actions: Array = definition.get("actions", []) as Array
	if not actions.is_empty() and actions[0] is Dictionary:
		var action: Dictionary = actions[0]
		action[marker] = true
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
	push_error("[verify_data_access_enemy_skills] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_enemy_skills] PASS")
	quit(1 if _failed else 0)
