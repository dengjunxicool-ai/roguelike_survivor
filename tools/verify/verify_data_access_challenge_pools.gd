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

	for method_name: String in ["get_daily_challenge_definitions", "get_weekly_challenge_definitions"]:
		_expect(data_manager.has_method(method_name), "DataManager exposes %s" % method_name)
	if not data_manager.has_method("get_daily_challenge_definitions") or not data_manager.has_method("get_weekly_challenge_definitions"):
		_finish()
		return

	var source_document: Dictionary = JsonDataLoaderScript.load_dictionary(
		DataPathsScript.CHALLENGES_PATH,
		"verify_data_access_challenge_pools"
	)
	var source_daily: Array[Dictionary] = _to_dictionary_array(source_document.get("daily_challenges", []))
	var source_weekly: Array[Dictionary] = _to_dictionary_array(source_document.get("weekly_challenges", []))
	var manager_daily: Array[Dictionary] = _call_pool(data_manager, "get_daily_challenge_definitions")
	var manager_weekly: Array[Dictionary] = _call_pool(data_manager, "get_weekly_challenge_definitions")

	var facade_daily: Array[Dictionary] = GameDataScript.get_daily_challenge_pool()
	var facade_weekly: Array[Dictionary] = GameDataScript.get_weekly_challenge_pool()

	_expect(not source_daily.is_empty(), "source daily pool is non-empty")
	_expect(not source_weekly.is_empty(), "source weekly pool is non-empty")
	_expect(manager_daily == source_daily, "DataManager daily values match source")
	_expect(manager_weekly == source_weekly, "DataManager weekly values match source")
	_expect(_signatures(manager_daily) == _signatures(source_daily), "daily order and modifiers match source", _signatures(manager_daily))
	_expect(_signatures(manager_weekly) == _signatures(source_weekly), "weekly order and modifiers match source", _signatures(manager_weekly))
	_expect(facade_daily == manager_daily, "daily facade matches DataManager")
	_expect(facade_weekly == manager_weekly, "weekly facade matches DataManager")

	_verify_manager_isolation(data_manager, source_daily, source_weekly)
	_verify_facade_isolation(data_manager, source_daily, source_weekly)
	_verify_independent_empty_owner(data_manager, manager_daily, manager_weekly, source_daily, source_weekly)

	_finish()


func _verify_manager_isolation(data_manager: Node, source_daily: Array[Dictionary], source_weekly: Array[Dictionary]) -> void:
	var daily_probe: Array[Dictionary] = _call_pool(data_manager, "get_daily_challenge_definitions")
	var weekly_probe: Array[Dictionary] = _call_pool(data_manager, "get_weekly_challenge_definitions")
	_expect(_mutate_first_scope(daily_probe, "__stage5c_daily_manager__"), "daily manager pool has nested scope")
	_expect(_mutate_first_scope(weekly_probe, "__stage5c_weekly_manager__"), "weekly manager pool has nested scope")
	_expect(_call_pool(data_manager, "get_daily_challenge_definitions") == source_daily, "daily manager output is deeply isolated")
	_expect(_call_pool(data_manager, "get_weekly_challenge_definitions") == source_weekly, "weekly manager output is deeply isolated")


func _verify_facade_isolation(data_manager: Node, source_daily: Array[Dictionary], source_weekly: Array[Dictionary]) -> void:
	var daily_probe: Array[Dictionary] = GameDataScript.get_daily_challenge_pool()
	var weekly_probe: Array[Dictionary] = GameDataScript.get_weekly_challenge_pool()
	_expect(_mutate_first_scope(daily_probe, "__stage5c_daily_facade__"), "daily facade pool has nested scope")
	_expect(_mutate_first_scope(weekly_probe, "__stage5c_weekly_facade__"), "weekly facade pool has nested scope")
	_expect(GameDataScript.get_daily_challenge_pool() == source_daily, "daily facade output is deeply isolated")
	_expect(GameDataScript.get_weekly_challenge_pool() == source_weekly, "weekly facade output is deeply isolated")
	_expect(_call_pool(data_manager, "get_daily_challenge_definitions") == source_daily, "daily facade mutation does not affect DataManager")
	_expect(_call_pool(data_manager, "get_weekly_challenge_definitions") == source_weekly, "weekly facade mutation does not affect DataManager")


func _verify_independent_empty_owner(data_manager: Node, manager_daily: Array[Dictionary], manager_weekly: Array[Dictionary], source_daily: Array[Dictionary], source_weekly: Array[Dictionary]) -> void:
	var empty: Array[Dictionary] = []
	data_manager.set("_daily_challenge_definitions", empty)
	_expect(GameDataScript.get_daily_challenge_pool().is_empty(), "empty daily owner stays authoritative")
	_expect(GameDataScript.get_weekly_challenge_pool() == source_weekly, "weekly owner remains independent")
	data_manager.set("_daily_challenge_definitions", manager_daily)
	data_manager.set("_weekly_challenge_definitions", empty)
	_expect(GameDataScript.get_weekly_challenge_pool().is_empty(), "empty weekly owner stays authoritative")
	_expect(GameDataScript.get_daily_challenge_pool() == source_daily, "daily owner remains independent")
	data_manager.set("_weekly_challenge_definitions", manager_weekly)


func _mutate_first_scope(pool: Array[Dictionary], marker: String) -> bool:
	if pool.is_empty():
		return false
	var modifiers: Array = pool[0].get("modifiers", []) as Array
	if modifiers.is_empty() or not (modifiers[0] is Dictionary):
		return false
	var modifier: Dictionary = modifiers[0]
	var scope: Dictionary = modifier.get("scope", {}) as Dictionary
	scope[marker] = true
	return true


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


func _signatures(pool: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for challenge: Dictionary in pool:
		result.append({
			"challenge_id": String(challenge.get("challenge_id", "")),
			"modifiers": (challenge.get("modifiers", []) as Array).duplicate(true),
		})
	return result


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_challenge_pools] FAIL %s actual=%s" % [label, str(actual)])


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_challenge_pools] PASS")
	quit(1 if _failed else 0)
