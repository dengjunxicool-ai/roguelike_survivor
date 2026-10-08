extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")
const StatusEffectManagerScript := preload("res://scripts/combat/status_effect_manager.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return

	var source: Array[Dictionary] = _source_statuses()
	_expect(not source.is_empty(), "source status pool is non-empty")
	if source.is_empty():
		_finish()
		return

	_verify_owner_and_facade(manager, source)
	_verify_manager_source_and_cache(manager)
	_verify_empty_owner_authoritative(manager, source)
	_finish()


func _source_statuses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in JsonDataLoaderScript.load_array(
		DataPathsScript.STATUS_EFFECTS_PATH,
		"statuses",
		"verify_data_access_status_lookup"
	):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _verify_owner_and_facade(manager: Node, source: Array[Dictionary]) -> void:
	for definition: Dictionary in source:
		var status_id: StringName = StringName(String(definition.get("id", "")))
		_expect(manager.call("get_status_definition", status_id) == definition, "owner lookup matches %s" % status_id)
		_expect(GameDataScript.get_status(status_id) == definition, "facade lookup matches %s" % status_id)
	_expect(GameDataScript.get_status(&"").is_empty(), "empty status ID stays empty")
	_expect(GameDataScript.get_status(&"__missing_phase6_status_lookup__").is_empty(), "missing status ID stays empty")

	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var owner_probe: Dictionary = manager.call("get_status_definition", first_id)
	var facade_probe: Dictionary = GameDataScript.get_status(first_id)
	_mutate_definition(owner_probe, "__phase6_status_owner__")
	_mutate_definition(facade_probe, "__phase6_status_facade__")
	_expect(manager.call("get_status_definition", first_id) == source[0], "owner status lookup is isolated")
	_expect(GameDataScript.get_status(first_id) == source[0], "facade status lookup is isolated")


func _verify_manager_source_and_cache(manager: Node) -> void:
	var original: Dictionary = (manager.get("_status_definitions") as Dictionary).duplicate(true)
	var sentinel_id: StringName = &"__phase6_status_cache__"
	var sentinel: Dictionary = {
		"id": String(sentinel_id),
		"duration": 4.0,
		"max_stacks": 3,
		"effect": {"move_slow_per_stack": 0.17}
	}
	manager.set("_status_definitions", {sentinel_id: sentinel.duplicate(true)})
	_expect(GameDataScript.get_status(sentinel_id) == sentinel, "facade prefers manager status sentinel")

	var status_manager: Node = StatusEffectManagerScript.new()
	root.add_child(status_manager)
	var first_lookup: Dictionary = status_manager.call("_get_status_definition", sentinel_id)
	_expect(first_lookup == sentinel, "StatusEffectManager cache miss uses manager-backed facade")
	_mutate_definition(first_lookup, "__phase6_status_cache_probe__")

	var changed: Dictionary = sentinel.duplicate(true)
	changed["duration"] = 99.0
	manager.set("_status_definitions", {sentinel_id: changed})
	var cached_lookup: Dictionary = status_manager.call("_get_status_definition", sentinel_id)
	_expect(cached_lookup == sentinel, "StatusEffectManager cache hit avoids owner re-query")
	_expect(not cached_lookup.has("__phase6_status_cache_probe__"), "StatusEffectManager cached result is deeply isolated")
	var cached_effect: Dictionary = cached_lookup.get("effect", {}) as Dictionary
	_expect(not cached_effect.has("__phase6_status_cache_probe__"), "StatusEffectManager cached nested result is isolated")
	status_manager.free()

	manager.set("_status_definitions", original)


func _verify_empty_owner_authoritative(manager: Node, source: Array[Dictionary]) -> void:
	var original: Dictionary = (manager.get("_status_definitions") as Dictionary).duplicate(true)
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	manager.set("_status_definitions", {})
	_expect(GameDataScript.get_status(first_id).is_empty(), "empty owner remains authoritative")
	_expect(GameDataScript.get_status(first_id).is_empty(), "repeat lookup does not reload JSON")
	manager.set("_status_definitions", original)


func _mutate_definition(definition: Dictionary, marker: String) -> void:
	var effect: Dictionary = definition.get("effect", {}) as Dictionary
	effect[marker] = true
	definition[marker] = true


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_status_lookup] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_status_lookup] PASS")
	quit(1 if _failed else 0)
