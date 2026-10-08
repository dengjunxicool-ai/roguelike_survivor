extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")

class MissingAccessorManager:
	extends Node

class WrongTypeManager:
	extends Node

	func get_combat_object_definition(_object_id: Variant) -> Variant:
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

	var source: Array[Dictionary] = _source_combat_objects()
	_expect(not source.is_empty(), "source combat object pool is non-empty")
	if source.is_empty():
		_finish()
		return

	_verify_owner_and_facade(manager, source)
	_verify_manager_source(manager)
	_verify_empty_owner_fallback(manager, source)
	_verify_replacement_manager_fallback(manager, source, MissingAccessorManager.new(), "missing accessor")
	_verify_replacement_manager_fallback(manager, source, WrongTypeManager.new(), "wrong-type accessor")
	_verify_full_fallback(manager, source)
	_finish()


func _source_combat_objects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in JsonDataLoaderScript.load_array(
		DataPathsScript.COMBAT_OBJECTS_PATH,
		"combat_objects",
		"verify_data_access_combat_objects"
	):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _verify_owner_and_facade(manager: Node, source: Array[Dictionary]) -> void:
	for definition: Dictionary in source:
		var object_id: StringName = StringName(String(definition.get("id", "")))
		_expect(manager.call("get_combat_object_definition", object_id) == definition, "owner lookup matches %s" % object_id)
		_expect(GameDataScript.get_combat_object(object_id) == definition, "facade lookup matches %s" % object_id)
	_expect(GameDataScript.get_combat_object(&"").is_empty(), "empty combat object ID stays empty")
	_expect(GameDataScript.get_combat_object(&"__missing_phase6_combat_object__").is_empty(), "missing combat object ID stays empty")

	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var owner_probe: Dictionary = manager.call("get_combat_object_definition", first_id)
	var facade_probe: Dictionary = GameDataScript.get_combat_object(first_id)
	_mutate_definition(owner_probe, "__phase6_combat_object_owner__")
	_mutate_definition(facade_probe, "__phase6_combat_object_facade__")
	_expect(manager.call("get_combat_object_definition", first_id) == source[0], "owner combat object lookup is isolated")
	_expect(GameDataScript.get_combat_object(first_id) == source[0], "facade combat object lookup is isolated")


func _verify_manager_source(manager: Node) -> void:
	var original: Dictionary = manager.get("_combat_object_definitions").duplicate(true)
	var sentinel_id: StringName = &"__phase6_combat_object_manager__"
	var sentinel: Dictionary = {
		"id": String(sentinel_id),
		"type": "projectile",
		"scene": "res://scenes/combat/fireball_projectile.tscn",
		"collision_radius": 17,
		"visual": {"scale": [0.5, 0.5], "animations": {"fly": {"animation": "fly"}}}
	}
	manager.set("_combat_object_definitions", {sentinel_id: sentinel.duplicate(true)})
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_combat_object(sentinel_id) == sentinel, "facade prefers manager combat object sentinel")
	_expect(not GameDataScript._document_cache.has(DataPathsScript.COMBAT_OBJECTS_PATH), "manager path avoids combat object JSON cache")
	manager.set("_combat_object_definitions", original)
	GameDataScript._document_cache.clear()


func _verify_empty_owner_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original: Dictionary = manager.get("_combat_object_definitions").duplicate(true)
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	manager.set("_combat_object_definitions", {})
	GameDataScript._document_cache.clear()
	var fallback: Dictionary = GameDataScript.get_combat_object(first_id)
	_expect(fallback == source[0], "empty owner combat object lookup falls back")
	_expect(GameDataScript._document_cache.has(DataPathsScript.COMBAT_OBJECTS_PATH), "empty owner fallback uses combat object document cache")
	_mutate_definition(fallback, "__phase6_combat_object_empty_owner__")
	_expect(GameDataScript.get_combat_object(first_id) == source[0], "empty owner combat object fallback is isolated")
	manager.set("_combat_object_definitions", original)
	GameDataScript._document_cache.clear()


func _verify_replacement_manager_fallback(
	manager: Node,
	source: Array[Dictionary],
	replacement: Node,
	label: String
) -> void:
	var original_name: StringName = manager.name
	manager.name = &"Phase6CombatObjectOwnerUnavailable"
	replacement.name = &"DataManager"
	root.add_child(replacement)
	GameDataScript._document_cache.clear()
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	_expect(GameDataScript.get_combat_object(first_id) == source[0], "%s falls back to combat object JSON" % label)
	replacement.free()
	manager.name = original_name
	GameDataScript._document_cache.clear()


func _verify_full_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original_name: StringName = manager.name
	manager.name = &"Phase6CombatObjectUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var fallback: Dictionary = GameDataScript.get_combat_object(first_id)
	_expect(fallback == source[0], "full combat object fallback matches source")
	_expect(GameDataScript._document_cache.has(DataPathsScript.COMBAT_OBJECTS_PATH), "full fallback loads combat object document")
	_mutate_definition(fallback, "__phase6_combat_object_full_fallback__")
	_expect(GameDataScript.get_combat_object(first_id) == source[0], "full combat object fallback is isolated")
	_expect(GameDataScript.get_combat_object(&"__missing_phase6_combat_object__").is_empty(), "full fallback keeps missing combat object empty")
	manager.name = original_name
	GameDataScript._document_cache.clear()


func _mutate_definition(definition: Dictionary, marker: String) -> void:
	var visual: Dictionary = definition.get("visual", {}) as Dictionary
	visual[marker] = true
	var animations: Dictionary = visual.get("animations", {}) as Dictionary
	animations[marker] = {"animation": marker}
	definition[marker] = true


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_combat_objects] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_combat_objects] PASS")
	quit(1 if _failed else 0)
