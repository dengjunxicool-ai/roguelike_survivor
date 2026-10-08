extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")

const POOL_CASES: Array[Dictionary] = [
	{"key": "curse_choices", "field": "_curse_choice_pool", "owner": "get_curse_choice_definitions", "facade": "get_curse_choice_pool"},
	{"key": "level_up_upgrades", "field": "_level_up_upgrade_pool", "owner": "get_level_up_upgrade_definitions", "facade": "get_level_up_upgrade_pool"},
	{"key": "permanent_upgrades", "field": "_permanent_upgrade_pool", "owner": "get_permanent_upgrade_definitions", "facade": "get_permanent_upgrade_pool"},
]

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return
	for case: Dictionary in POOL_CASES:
		_expect(manager.has_method(String(case["owner"])), "owner exposes %s" % case["owner"])
	_expect(manager.has_method("get_rarity_weights"), "owner exposes get_rarity_weights")
	if _failed:
		_finish()
		return

	var document: Dictionary = JsonDataLoaderScript.load_dictionary(DataPathsScript.UPGRADES_PATH, "verify_data_access_upgrade_catalog")
	var sources: Dictionary = {}
	for case: Dictionary in POOL_CASES:
		sources[case["key"]] = _to_dictionary_array(document.get(case["key"], []))
	var source_weights: Dictionary = _dictionary(document.get("rarity_weights", {})).duplicate(true)

	for case: Dictionary in POOL_CASES:
		var source: Array[Dictionary] = _to_dictionary_array(sources[case["key"]])
		var owner_pool: Array[Dictionary] = _owner_pool(manager, String(case["owner"]))
		var facade_pool: Array[Dictionary] = _facade_pool(String(case["facade"]))
		_expect(not source.is_empty(), "%s source is non-empty" % case["key"])
		_expect(owner_pool == source, "%s owner matches source" % case["key"])
		_expect(_ids(owner_pool) == _ids(source), "%s order matches source" % case["key"], _ids(owner_pool))
		_expect(facade_pool == source, "%s facade matches source" % case["key"])
	_expect(_owner_weights(manager) == source_weights, "owner rarity weights match source")
	_expect(GameDataScript.get_rarity_weights() == source_weights, "rarity facade matches source")

	var permanent_source: Array[Dictionary] = _to_dictionary_array(sources["permanent_upgrades"])
	for item: Dictionary in permanent_source:
		_expect(GameDataScript.get_permanent_upgrade(StringName(String(item.get("id", "")))) == item, "permanent lookup matches source")
	var curse_source: Array[Dictionary] = _to_dictionary_array(sources["curse_choices"])
	var level_up_source: Array[Dictionary] = _to_dictionary_array(sources["level_up_upgrades"])
	_expect(GameDataScript.get_permanent_upgrade(StringName(String(curse_source[0].get("id", "")))).is_empty(), "manager permanent lookup rejects curse IDs")
	_expect(GameDataScript.get_permanent_upgrade(StringName(String(level_up_source[0].get("id", "")))).is_empty(), "manager permanent lookup rejects level-up IDs")
	var permanent_probe: Dictionary = GameDataScript.get_permanent_upgrade(StringName(String(permanent_source[0].get("id", ""))))
	var permanent_probe_pool: Array[Dictionary] = [permanent_probe]
	_expect(_mutate_first_nested_scope(permanent_probe_pool, "modifiers", "__stage5d_permanent_manager__"), "permanent manager lookup has nested modifier scope")
	_expect(GameDataScript.get_permanent_upgrade(StringName(String(permanent_source[0].get("id", "")))) == permanent_source[0], "permanent manager lookup is isolated")
	_expect(GameDataScript.get_permanent_upgrade(&"__missing_stage5d__").is_empty(), "missing permanent lookup stays empty")

	_verify_manager_and_facade_isolation(manager, sources, source_weights)
	_verify_independent_owner_pools(manager, sources, source_weights)
	_finish()


func _verify_manager_and_facade_isolation(manager: Node, sources: Dictionary, source_weights: Dictionary) -> void:
	for case: Dictionary in POOL_CASES:
		var owner_modifier_probe: Array[Dictionary] = _owner_pool(manager, String(case["owner"]))
		var owner_level_probe: Array[Dictionary] = _owner_pool(manager, String(case["owner"]))
		var facade_modifier_probe: Array[Dictionary] = _facade_pool(String(case["facade"]))
		var facade_level_probe: Array[Dictionary] = _facade_pool(String(case["facade"]))
		_expect(_mutate_first_nested_scope(owner_modifier_probe, "modifiers", "__stage5d_owner_modifier__"), "%s owner has nested modifier scope" % case["key"])
		_expect(_mutate_first_nested_scope(owner_level_probe, "level_modifiers", "__stage5d_owner_level__"), "%s owner has nested level modifier scope" % case["key"])
		_expect(_mutate_first_nested_scope(facade_modifier_probe, "modifiers", "__stage5d_facade_modifier__"), "%s facade has nested modifier scope" % case["key"])
		_expect(_mutate_first_nested_scope(facade_level_probe, "level_modifiers", "__stage5d_facade_level__"), "%s facade has nested level modifier scope" % case["key"])
		_expect(_owner_pool(manager, String(case["owner"])) == sources[case["key"]], "%s owner is isolated" % case["key"])
		_expect(_facade_pool(String(case["facade"])) == sources[case["key"]], "%s facade is isolated" % case["key"])
	var owner_weights: Dictionary = _owner_weights(manager)
	var facade_weights: Dictionary = GameDataScript.get_rarity_weights()
	_mutate_first_weight(owner_weights)
	_mutate_first_weight(facade_weights)
	_expect(_owner_weights(manager) == source_weights, "owner weights are isolated")
	_expect(GameDataScript.get_rarity_weights() == source_weights, "facade weights are isolated")


func _verify_independent_owner_pools(manager: Node, sources: Dictionary, source_weights: Dictionary) -> void:
	var originals: Dictionary = {}
	for case: Dictionary in POOL_CASES:
		originals[case["field"]] = _owner_pool(manager, String(case["owner"]))
	var original_weights: Dictionary = _owner_weights(manager)

	for target: Dictionary in POOL_CASES:
		var sentinel: Array[Dictionary] = [{"id": "__stage5d_%s__" % target["key"], "modifiers": [{"scope": {"domain": "stage5d"}}]}]
		manager.set(String(target["field"]), sentinel.duplicate(true))
		_expect(_facade_pool(String(target["facade"])) == sentinel, "%s facade returns manager sentinel" % target["key"])
		if target["key"] == "permanent_upgrades":
			var sentinel_id: StringName = StringName(String(sentinel[0].get("id", "")))
			_expect(GameDataScript.get_permanent_upgrade(sentinel_id) == sentinel[0], "permanent lookup returns manager sentinel")
		manager.set(String(target["field"]), (originals[target["field"]] as Array).duplicate(true))

	for target: Dictionary in POOL_CASES:
		var empty_pool: Array[Dictionary] = []
		manager.set(String(target["field"]), empty_pool)
		_expect(_facade_pool(String(target["facade"])).is_empty(), "%s empty owner remains authoritative" % target["key"])
		for other: Dictionary in POOL_CASES:
			if other["key"] == target["key"]:
				continue
			_expect(_facade_pool(String(other["facade"])) == sources[other["key"]], "%s remains manager-backed" % other["key"])
		manager.set(String(target["field"]), (originals[target["field"]] as Array).duplicate(true))

	manager.set("_rarity_weights", {"__stage5d_weight__": 7})
	_expect(GameDataScript.get_rarity_weights() == {"__stage5d_weight__": 7}, "rarity facade returns manager sentinel")
	manager.set("_rarity_weights", {})
	_expect(GameDataScript.get_rarity_weights().is_empty(), "empty owner weights stay authoritative")
	for case: Dictionary in POOL_CASES:
		_expect(_facade_pool(String(case["facade"])) == sources[case["key"]], "%s remains manager-backed while rarity is empty" % case["key"])
	manager.set("_rarity_weights", original_weights.duplicate(true))


func _facade_pool(method_name: String) -> Array[Dictionary]:
	match method_name:
		"get_curse_choice_pool": return GameDataScript.get_curse_choice_pool()
		"get_level_up_upgrade_pool": return GameDataScript.get_level_up_upgrade_pool()
		"get_permanent_upgrade_pool": return GameDataScript.get_permanent_upgrade_pool()
	return []


func _owner_pool(manager: Node, method_name: String) -> Array[Dictionary]:
	return _to_dictionary_array(manager.call(method_name))


func _owner_weights(manager: Node) -> Dictionary:
	return _dictionary(manager.call("get_rarity_weights")).duplicate(true)


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _ids(pool: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in pool:
		result.append(String(item.get("id", "")))
	return result


func _mutate_first_nested_scope(pool: Array[Dictionary], list_key: String, marker: String) -> bool:
	for item: Dictionary in pool:
		var outer: Array = item.get(list_key, []) as Array
		if outer.is_empty():
			continue
		var candidates: Array = outer[0] as Array if outer[0] is Array else outer
		if not candidates.is_empty() and candidates[0] is Dictionary:
			var modifier: Dictionary = candidates[0]
			var scope: Dictionary = modifier.get("scope", {}) as Dictionary
			scope[marker] = true
			return true
	return false


func _mutate_first_weight(weights: Dictionary) -> bool:
	if weights.is_empty():
		return false
	weights[weights.keys()[0]] = -999
	return true


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_upgrade_catalog] FAIL %s actual=%s" % [label, str(actual)])


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_upgrade_catalog] PASS")
	quit(1 if _failed else 0)
