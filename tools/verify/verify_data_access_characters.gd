extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")
const CharacterRuntimeScript := preload("res://scripts/characters/character_runtime.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return

	var source: Array[Dictionary] = _source_characters()
	_expect(not source.is_empty(), "source character pool is non-empty")
	if source.is_empty():
		_finish()
		return

	_verify_owner_and_facade(manager, source)
	_verify_manager_source(manager)
	_verify_empty_owner_fallback(manager, source)
	_verify_missing_accessor_fallback(manager, source)
	_verify_full_fallback(manager, source)
	_verify_character_runtime_contract(manager, source)
	_finish()


func _source_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in JsonDataLoaderScript.load_array(
		DataPathsScript.CHARACTERS_PATH,
		"characters",
		"verify_data_access_characters"
	):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _verify_owner_and_facade(manager: Node, source: Array[Dictionary]) -> void:
	var owner_pool: Array[Dictionary] = _to_dictionary_array(manager.call("get_character_definitions"))
	_expect(_ids(owner_pool) == _ids(source), "owner character IDs and order match source")
	_expect(owner_pool == source, "owner character pool matches source")
	for definition: Dictionary in source:
		var character_id: StringName = StringName(String(definition.get("id", "")))
		_expect(manager.call("get_character_definition", character_id) == definition, "owner lookup matches %s" % character_id)
		_expect(GameDataScript.get_character(character_id) == definition, "facade lookup matches %s" % character_id)
	_expect(GameDataScript.get_character(&"").is_empty(), "empty character ID stays empty")
	_expect(GameDataScript.get_character(&"__missing_phase6_character__").is_empty(), "missing character ID stays empty")

	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var owner_probe: Dictionary = manager.call("get_character_definition", first_id)
	var facade_probe: Dictionary = GameDataScript.get_character(first_id)
	_mutate_definition(owner_probe, "__phase6_character_owner__")
	_mutate_definition(facade_probe, "__phase6_character_facade__")
	_expect(manager.call("get_character_definition", first_id) == source[0], "owner lookup is deeply isolated")
	_expect(GameDataScript.get_character(first_id) == source[0], "facade lookup is deeply isolated")


func _verify_manager_source(manager: Node) -> void:
	var original: Dictionary = manager.get("_character_definitions").duplicate(true)
	var sentinel_id: StringName = &"__phase6_character_manager__"
	var sentinel: Dictionary = {
		"id": String(sentinel_id),
		"display_name": "Phase 6 Character",
		"starting_skill_id": "__phase6_character_skill__",
		"base_stats": {"max_health": 777.0},
		"trait": {"id": "__phase6_character_trait__"}
	}
	manager.set("_character_definitions", {sentinel_id: sentinel.duplicate(true)})
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_character(sentinel_id) == sentinel, "facade prefers manager character sentinel")
	_expect(not GameDataScript._document_cache.has(DataPathsScript.CHARACTERS_PATH), "manager path avoids character JSON cache")

	var runtime: Node = CharacterRuntimeScript.new()
	root.add_child(runtime)
	_expect(bool(runtime.call("initialize", String(sentinel_id))), "CharacterRuntime accepts manager sentinel")
	_expect(runtime.call("get_character_id") == String(sentinel_id), "CharacterRuntime preserves manager sentinel ID")
	_expect(runtime.call("get_starting_skill_id") == "__phase6_character_skill__", "CharacterRuntime preserves manager sentinel starting skill")
	_expect(is_equal_approx(float(runtime.call("get_stat", "max_health", 0.0)), 777.0), "CharacterRuntime preserves manager sentinel stats")
	runtime.free()

	manager.set("_character_definitions", original)
	GameDataScript._document_cache.clear()


func _verify_empty_owner_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original: Dictionary = manager.get("_character_definitions").duplicate(true)
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	manager.set("_character_definitions", {})
	GameDataScript._document_cache.clear()
	var fallback: Dictionary = GameDataScript.get_character(first_id)
	_expect(fallback == source[0], "empty owner character lookup falls back")
	_expect(GameDataScript._document_cache.has(DataPathsScript.CHARACTERS_PATH), "empty owner fallback uses character document cache")
	_mutate_definition(fallback, "__phase6_character_empty_owner__")
	_expect(GameDataScript.get_character(first_id) == source[0], "empty owner fallback is isolated")
	manager.set("_character_definitions", original)
	GameDataScript._document_cache.clear()


func _verify_missing_accessor_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original_name: StringName = manager.name
	manager.name = &"Phase6CharacterOwnerWithoutAccessor"
	var unavailable_manager: Node = Node.new()
	unavailable_manager.name = &"DataManager"
	root.add_child(unavailable_manager)
	GameDataScript._document_cache.clear()

	var first_id: StringName = StringName(String(source[0].get("id", "")))
	_expect(GameDataScript.get_character(first_id) == source[0], "missing accessor falls back to character JSON")
	var runtime: Node = CharacterRuntimeScript.new()
	root.add_child(runtime)
	_expect(bool(runtime.call("initialize", String(first_id))), "CharacterRuntime initializes through missing-accessor fallback")
	_expect(runtime.call("get_character_id") == String(first_id), "missing-accessor fallback preserves character ID")
	runtime.free()

	unavailable_manager.free()
	manager.name = original_name
	GameDataScript._document_cache.clear()


func _verify_full_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original_name: StringName = manager.name
	manager.name = &"Phase6CharacterUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var fallback: Dictionary = GameDataScript.get_character(first_id)
	_expect(fallback == source[0], "full character fallback matches source")
	_expect(GameDataScript._document_cache.has(DataPathsScript.CHARACTERS_PATH), "full fallback loads character document")
	_mutate_definition(fallback, "__phase6_character_full_fallback__")
	_expect(GameDataScript.get_character(first_id) == source[0], "full character fallback is isolated")
	manager.name = original_name
	GameDataScript._document_cache.clear()


func _verify_character_runtime_contract(manager: Node, source: Array[Dictionary]) -> void:
	var first: Dictionary = source[0]
	var first_id: String = String(first.get("id", ""))
	var runtime: Node = CharacterRuntimeScript.new()
	root.add_child(runtime)
	_expect(bool(runtime.call("initialize", first_id)), "CharacterRuntime initializes known source character")
	_expect(runtime.call("get_character_id") == first_id, "CharacterRuntime preserves source character ID")
	_expect(
		runtime.call("get_starting_skill_id") == String(first.get("starting_skill_id", "")),
		"CharacterRuntime preserves source starting skill"
	)
	var base_stats: Dictionary = first.get("base_stats", {}) as Dictionary
	if base_stats.has("max_health"):
		_expect(
			is_equal_approx(float(runtime.call("get_stat", "max_health", 0.0)), float(base_stats.get("max_health", 0.0))),
			"CharacterRuntime preserves source max health"
		)
	runtime.free()
	_expect(manager.name == &"DataManager", "DataManager name is restored after fallback probes")


func _mutate_definition(definition: Dictionary, marker: String) -> void:
	var base_stats: Dictionary = definition.get("base_stats", {}) as Dictionary
	base_stats[marker] = true
	var trait_data: Dictionary = definition.get("trait", {}) as Dictionary
	trait_data[marker] = true
	var unlock: Dictionary = definition.get("unlock", {}) as Dictionary
	unlock[marker] = true


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
	push_error("[verify_data_access_characters] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_characters] PASS")
	quit(1 if _failed else 0)
