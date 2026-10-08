extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")
const SynergyManagerScript := preload("res://scripts/skills/synergy_manager.gd")

class MissingAccessorManager:
	extends Node

class WrongTypeManager:
	extends Node

	func get_synergy_definitions() -> Variant:
		return "not-an-array"

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return

	var source: Array[Dictionary] = _source_synergies()
	_expect(not source.is_empty(), "source synergy pool is non-empty")
	if source.is_empty():
		_finish()
		return

	_verify_owner_and_facade(manager, source)
	_verify_manager_source(manager)
	_verify_empty_owner_fallback(manager, source)
	_verify_replacement_manager_fallback(manager, source, MissingAccessorManager.new(), "missing accessor")
	_verify_replacement_manager_fallback(manager, source, WrongTypeManager.new(), "wrong-type accessor")
	_verify_full_fallback(manager, source)
	_verify_synergy_manager_contract(source)
	_finish()


func _source_synergies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in JsonDataLoaderScript.load_array(
		DataPathsScript.SYNERGIES_PATH,
		"synergies",
		"verify_data_access_synergies"
	):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _verify_owner_and_facade(manager: Node, source: Array[Dictionary]) -> void:
	var owner_pool: Array[Dictionary] = _to_dictionary_array(manager.call("get_synergy_definitions"))
	var facade_pool: Array[Dictionary] = GameDataScript.get_synergy_pool()
	_expect(_ids(owner_pool) == _ids(source), "owner synergy IDs and order match source")
	_expect(owner_pool == source, "owner synergy pool matches source")
	_expect(_ids(facade_pool) == _ids(source), "facade synergy IDs and order match source")
	_expect(facade_pool == source, "facade synergy pool matches source")
	_mutate_definition(owner_pool[0], "__phase6_synergy_owner__")
	_mutate_definition(facade_pool[0], "__phase6_synergy_facade__")
	_expect(_to_dictionary_array(manager.call("get_synergy_definitions")) == source, "owner synergy pool is isolated")
	_expect(GameDataScript.get_synergy_pool() == source, "facade synergy pool is isolated")


func _verify_manager_source(manager: Node) -> void:
	var original: Array[Dictionary] = _to_dictionary_array(manager.get("_synergy_definitions")).duplicate(true)
	var sentinel: Dictionary = {
		"id": "__phase6_synergy_manager__",
		"display_name": "Phase 6 Synergy",
		"required_skill_tags": ["phase6_a", "phase6_b"],
		"effect": {"type": "phase6", "amount": 17.0}
	}
	var sentinel_pool: Array[Dictionary] = [sentinel.duplicate(true)]
	manager.set("_synergy_definitions", sentinel_pool)
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_synergy_pool() == [sentinel], "facade prefers manager synergy sentinel")
	_expect(not GameDataScript._document_cache.has(DataPathsScript.SYNERGIES_PATH), "manager path avoids synergy JSON cache")

	var synergy_manager: Node = SynergyManagerScript.new()
	synergy_manager.name = "Phase6SynergyManagerSentinel"
	root.add_child(synergy_manager)
	synergy_manager.call("refresh_active_synergies", null)
	_expect(
		_to_string_names(synergy_manager.get("recognized_synergies")) == [&"__phase6_synergy_manager__"],
		"SynergyManager recognizes manager sentinel through facade"
	)
	synergy_manager.free()

	manager.set("_synergy_definitions", original)
	GameDataScript._document_cache.clear()


func _verify_empty_owner_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original: Array[Dictionary] = _to_dictionary_array(manager.get("_synergy_definitions")).duplicate(true)
	var empty_pool: Array[Dictionary] = []
	manager.set("_synergy_definitions", empty_pool)
	GameDataScript._document_cache.clear()
	var fallback: Array[Dictionary] = GameDataScript.get_synergy_pool()
	_expect(fallback == source, "empty owner synergy pool falls back")
	_expect(GameDataScript._document_cache.has(DataPathsScript.SYNERGIES_PATH), "empty owner fallback uses synergy document cache")
	_mutate_definition(fallback[0], "__phase6_synergy_empty_owner__")
	_expect(GameDataScript.get_synergy_pool() == source, "empty owner synergy fallback is isolated")
	manager.set("_synergy_definitions", original)
	GameDataScript._document_cache.clear()


func _verify_replacement_manager_fallback(
	manager: Node,
	source: Array[Dictionary],
	replacement: Node,
	label: String
) -> void:
	var original_name: StringName = manager.name
	manager.name = &"Phase6SynergyOwnerUnavailable"
	replacement.name = &"DataManager"
	root.add_child(replacement)
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_synergy_pool() == source, "%s falls back to synergy JSON" % label)
	replacement.free()
	manager.name = original_name
	GameDataScript._document_cache.clear()


func _verify_full_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original_name: StringName = manager.name
	manager.name = &"Phase6SynergyUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var fallback: Array[Dictionary] = GameDataScript.get_synergy_pool()
	_expect(_ids(fallback) == _ids(source), "full synergy fallback preserves IDs and order")
	_expect(fallback == source, "full synergy fallback matches source")
	_expect(GameDataScript._document_cache.has(DataPathsScript.SYNERGIES_PATH), "full fallback loads synergy document")
	_mutate_definition(fallback[0], "__phase6_synergy_full_fallback__")
	_expect(GameDataScript.get_synergy_pool() == source, "full synergy fallback is isolated")
	manager.name = original_name
	GameDataScript._document_cache.clear()


func _verify_synergy_manager_contract(source: Array[Dictionary]) -> void:
	var synergy_manager: Node = SynergyManagerScript.new()
	synergy_manager.name = "Phase6SynergyManagerContract"
	root.add_child(synergy_manager)
	synergy_manager.call("refresh_active_synergies", null)
	_expect(
		_to_string_names(synergy_manager.get("recognized_synergies")) == _string_name_ids(source),
		"SynergyManager preserves configured synergy IDs and order"
	)
	_expect((synergy_manager.get("active_synergies") as Array).is_empty(), "null player keeps active synergies empty")
	synergy_manager.free()


func _mutate_definition(definition: Dictionary, marker: String) -> void:
	var effect: Dictionary = definition.get("effect", {}) as Dictionary
	effect[marker] = true
	definition[marker] = true


func _ids(pool: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in pool:
		result.append(String(item.get("id", "")))
	return result


func _string_name_ids(pool: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for item: Dictionary in pool:
		result.append(StringName(String(item.get("id", ""))))
	return result


func _to_string_names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			result.append(StringName(String(item)))
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
	push_error("[verify_data_access_synergies] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_synergies] PASS")
	quit(1 if _failed else 0)
