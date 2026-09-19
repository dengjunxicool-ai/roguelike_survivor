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

	_expect(data_manager.has_method("get_status_definitions"), "DataManager exposes get_status_definitions")
	if not data_manager.has_method("get_status_definitions"):
		_finish()
		return

	var source_document: Dictionary = JsonDataLoaderScript.load_dictionary(
		DataPathsScript.STATUS_EFFECTS_PATH,
		"verify_data_access_status_pool"
	)
	var source_pool: Array[Dictionary] = _to_dictionary_array(source_document.get("statuses", []))
	var manager_pool: Array[Dictionary] = _call_pool(data_manager, "get_status_definitions")
	var facade_pool: Array[Dictionary] = GameDataScript.get_status_pool()

	_expect(not source_pool.is_empty(), "source status pool is non-empty")
	_expect(_ids(manager_pool) == _ids(source_pool), "DataManager preserves source status order", _ids(manager_pool))
	_expect(manager_pool == source_pool, "DataManager status values match the source document")
	_expect(facade_pool == manager_pool, "GameData normal path matches DataManager")
	_expect(
		(data_manager.call("get_status_definition", &"__stage5_missing_status__") as Dictionary).is_empty(),
		"unknown status id remains empty"
	)

	_verify_manager_result_isolation(data_manager)
	_verify_facade_result_isolation()

	var original_manager_name: StringName = data_manager.name
	data_manager.name = &"Stage5UnavailableDataManager"
	GameDataScript._document_cache.clear()
	var fallback_pool: Array[Dictionary] = GameDataScript.get_status_pool()
	data_manager.name = original_manager_name
	GameDataScript._document_cache.clear()

	_expect(_ids(fallback_pool) == _ids(source_pool), "fallback preserves source status order", _ids(fallback_pool))
	_expect(fallback_pool == source_pool, "fallback values match the source document")
	var restored_pool: Array[Dictionary] = GameDataScript.get_status_pool()
	_expect(restored_pool == manager_pool, "restored facade returns manager-backed values")

	_finish()


func _verify_manager_result_isolation(data_manager: Node) -> void:
	var first_pool: Array[Dictionary] = _call_pool(data_manager, "get_status_definitions")
	var heat: Dictionary = _find_by_id(first_pool, &"heat")
	_expect(not heat.is_empty(), "heat status exists for mutation isolation")
	if heat.is_empty():
		return
	var effect: Dictionary = heat.get("effect", {}) as Dictionary
	effect["__stage5_probe"] = true
	var fresh_heat: Dictionary = _find_by_id(_call_pool(data_manager, "get_status_definitions"), &"heat")
	var fresh_effect: Dictionary = fresh_heat.get("effect", {}) as Dictionary
	_expect(not fresh_effect.has("__stage5_probe"), "DataManager returns deeply isolated status definitions")


func _verify_facade_result_isolation() -> void:
	var first_pool: Array[Dictionary] = GameDataScript.get_status_pool()
	var heat: Dictionary = _find_by_id(first_pool, &"heat")
	_expect(not heat.is_empty(), "facade exposes heat for mutation isolation")
	if heat.is_empty():
		return
	var effect: Dictionary = heat.get("effect", {}) as Dictionary
	effect["__stage5_probe"] = true
	var fresh_heat: Dictionary = _find_by_id(GameDataScript.get_status_pool(), &"heat")
	var fresh_effect: Dictionary = fresh_heat.get("effect", {}) as Dictionary
	_expect(not fresh_effect.has("__stage5_probe"), "GameData manager path returns deeply isolated definitions")


func _call_pool(data_manager: Node, method_name: String) -> Array[Dictionary]:
	return _to_dictionary_array(data_manager.call(method_name))


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			result.append(item_variant as Dictionary)
	return result


func _ids(items: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for item: Dictionary in items:
		result.append(StringName(String(item.get("id", ""))))
	return result


func _find_by_id(items: Array[Dictionary], target_id: StringName) -> Dictionary:
	for item: Dictionary in items:
		if StringName(String(item.get("id", ""))) == target_id:
			return item
	return {}


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_status_pool] FAIL %s actual=%s" % [label, str(actual)])


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_status_pool] PASS")
	quit(1 if _failed else 0)
