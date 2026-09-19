extends SceneTree


const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var data_manager: Node = root.get_node_or_null("DataManager")
	_expect(data_manager != null, "DataManager autoload exists")
	if data_manager == null:
		_finish()
		return

	_expect(data_manager.has_method("get_progression_goals"), "DataManager exposes get_progression_goals")
	if not data_manager.has_method("get_progression_goals"):
		_finish()
		return

	var source: Dictionary = JsonDataLoaderScript.load_dictionary(
		DataPathsScript.PROGRESSION_GOALS_PATH,
		"verify_data_access_progression_goals"
	)
	var manager_result: Dictionary = _call_dictionary(data_manager, "get_progression_goals")
	GameDataScript._document_cache.clear()
	var facade_result: Dictionary = GameDataScript.get_progression_goals()

	_expect(not source.is_empty(), "source progression-goals document is non-empty")
	_expect(manager_result == source, "DataManager values match the source document")
	_expect(facade_result == manager_result, "GameData normal path matches DataManager")
	_expect(
		not GameDataScript._document_cache.has(DataPathsScript.PROGRESSION_GOALS_PATH),
		"GameData normal path does not enter the JSON document cache"
	)
	_expect(
		_character_sequences(manager_result) == _character_sequences(source),
		"character and goal order matches the source",
		_character_sequences(manager_result)
	)
	_expect(
		_map_sequences(manager_result) == _map_sequences(source),
		"map and objective order matches the source",
		_map_sequences(manager_result)
	)

	_verify_manager_result_isolation(data_manager, source)
	_verify_facade_result_isolation(data_manager, source)

	var original_manager_name: StringName = data_manager.name
	data_manager.name = &"Stage5BUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var fallback_result: Dictionary = GameDataScript.get_progression_goals()
	var fallback_loaded_document: bool = GameDataScript._document_cache.has(DataPathsScript.PROGRESSION_GOALS_PATH)
	data_manager.name = original_manager_name
	GameDataScript._document_cache.clear()

	_expect(fallback_result == source, "fallback values match the source document")
	_expect(fallback_loaded_document, "fallback enters the JSON document cache")
	_expect(
		_character_sequences(fallback_result) == _character_sequences(source),
		"fallback preserves character and goal order"
	)
	_expect(
		_map_sequences(fallback_result) == _map_sequences(source),
		"fallback preserves map and objective order"
	)
	_expect(GameDataScript.get_progression_goals() == manager_result, "restored facade returns manager-backed values")

	_finish()


func _verify_manager_result_isolation(data_manager: Node, source: Dictionary) -> void:
	var first: Dictionary = _call_dictionary(data_manager, "get_progression_goals")
	var characters: Array = first.get("character_specializations", []) as Array
	_expect(not characters.is_empty(), "manager character goals exist for mutation isolation")
	if not characters.is_empty():
		var first_character: Dictionary = characters[0] as Dictionary
		var goals: Array = first_character.get("goals", []) as Array
		goals.append("__stage5b_probe_goal__")
		first_character["__stage5b_probe"] = true
	_expect(_call_dictionary(data_manager, "get_progression_goals") == source, "DataManager returns deeply isolated progression goals")


func _verify_facade_result_isolation(data_manager: Node, source: Dictionary) -> void:
	var first: Dictionary = GameDataScript.get_progression_goals()
	var maps: Array = first.get("map_challenges", []) as Array
	_expect(not maps.is_empty(), "facade map objectives exist for mutation isolation")
	if not maps.is_empty():
		var first_map: Dictionary = maps[0] as Dictionary
		var objectives: Array = first_map.get("objectives", []) as Array
		objectives.append("__stage5b_probe_objective__")
		first_map["__stage5b_probe"] = true
	_expect(GameDataScript.get_progression_goals() == source, "GameData returns deeply isolated progression goals")
	_expect(_call_dictionary(data_manager, "get_progression_goals") == source, "facade mutation does not affect DataManager")


func _call_dictionary(data_manager: Node, method_name: String) -> Dictionary:
	var value: Variant = data_manager.call(method_name)
	return value as Dictionary if value is Dictionary else {}


func _character_sequences(document: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_variant: Variant in document.get("character_specializations", []):
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			result.append({
				"character_id": String(entry.get("character_id", "")),
				"goals": (entry.get("goals", []) as Array).duplicate(true),
			})
	return result


func _map_sequences(document: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_variant: Variant in document.get("map_challenges", []):
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			result.append({
				"map_id": String(entry.get("map_id", "")),
				"objectives": (entry.get("objectives", []) as Array).duplicate(true),
			})
	return result


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_progression_goals] FAIL %s actual=%s" % [label, str(actual)])


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_progression_goals] PASS")
	quit(1 if _failed else 0)
