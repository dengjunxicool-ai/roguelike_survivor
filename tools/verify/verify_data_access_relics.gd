extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")
const RelicManagerScript := preload("res://scripts/relics/relic_manager.gd")

var _failed: bool = false
var _signal_events: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return

	var source: Array[Dictionary] = _source_relics()
	_expect(not source.is_empty(), "source relic pool is non-empty")
	_verify_owner_and_facade(manager, source)
	_verify_manager_source_and_empty_owner(manager, source)
	_verify_relic_manager_contract(manager, source)
	_finish()


func _source_relics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in JsonDataLoaderScript.load_array(DataPathsScript.RELICS_PATH, "relics", "verify_data_access_relics"):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _verify_owner_and_facade(manager: Node, source: Array[Dictionary]) -> void:
	var owner_pool: Array[Dictionary] = _to_dictionary_array(manager.call("get_relic_definitions"))
	var facade_pool: Array[Dictionary] = GameDataScript.get_relic_pool()
	_expect(_ids(owner_pool) == _ids(source), "owner IDs and order match source")
	_expect(owner_pool == source, "owner pool matches source")
	_expect(facade_pool == source, "facade pool matches source")
	for definition: Dictionary in source:
		var relic_id: StringName = StringName(String(definition.get("id", "")))
		_expect(manager.call("get_relic_definition", relic_id) == definition, "owner lookup matches %s" % relic_id)
		_expect(GameDataScript.get_relic(relic_id) == definition, "facade lookup matches %s" % relic_id)
	_expect(GameDataScript.get_relic(&"").is_empty(), "empty relic ID stays empty")
	_expect(GameDataScript.get_relic(&"__missing_phase6_relic__").is_empty(), "missing relic ID stays empty")

	var owner_probe: Array[Dictionary] = _to_dictionary_array(manager.call("get_relic_definitions"))
	var facade_probe: Array[Dictionary] = GameDataScript.get_relic_pool()
	_expect(_mutate_nested_relic(owner_probe, "__phase6_relic_owner__"), "owner pool exposes nested mutation probe")
	_expect(_mutate_nested_relic(facade_probe, "__phase6_relic_facade__"), "facade pool exposes nested mutation probe")
	_expect(_to_dictionary_array(manager.call("get_relic_definitions")) == source, "owner pool is isolated")
	_expect(GameDataScript.get_relic_pool() == source, "facade pool is isolated")
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var lookup_probe: Dictionary = GameDataScript.get_relic(first_id)
	_mutate_definition(lookup_probe, "__phase6_relic_lookup__")
	_expect(GameDataScript.get_relic(first_id) == source[0], "single facade lookup is isolated")


func _verify_manager_source_and_empty_owner(manager: Node, source: Array[Dictionary]) -> void:
	var original: Dictionary = manager.get("_relic_definitions").duplicate(true)
	var sentinel_id: StringName = &"__phase6_relic_manager__"
	var sentinel: Dictionary = {
		"id": String(sentinel_id),
		"trigger_condition": {"event": "phase6_relic"},
		"modifiers": [{"scope": {"domain": "phase6_relic"}}],
		"unlock": {"type": "phase6_relic"}
	}
	var sentinel_index: Dictionary = {}
	sentinel_index[sentinel_id] = sentinel.duplicate(true)
	manager.set("_relic_definitions", sentinel_index)
	_expect(GameDataScript.get_relic_pool() == [sentinel], "pool facade prefers manager sentinel")
	_expect(GameDataScript.get_relic(sentinel_id) == sentinel, "lookup facade prefers manager sentinel")

	manager.set("_relic_definitions", {})
	_expect(GameDataScript.get_relic_pool().is_empty(), "empty relic owner pool stays authoritative")
	_expect(GameDataScript.get_relic(StringName(String(source[0].get("id", "")))).is_empty(), "empty relic lookup does not reload JSON")

	manager.set("_relic_definitions", original)


func _verify_relic_manager_contract(manager: Node, source: Array[Dictionary]) -> void:
	_expect(source.size() >= 2, "RelicManager contract has at least two source relics")
	if source.size() < 2:
		return

	var original: Dictionary = manager.get("_relic_definitions").duplicate(true)
	var host: Node = Node.new()
	root.add_child(host)
	var relic_manager: Node = RelicManagerScript.new()
	host.add_child(relic_manager)
	relic_manager.call("_load_relic_definitions")
	_expect(relic_manager.get("_relic_definitions").size() == source.size(), "RelicManager indexes the complete facade pool")

	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var definition_probe: Dictionary = relic_manager.call("get_relic_definition", first_id)
	_mutate_definition(definition_probe, "__phase6_relic_local__")
	_expect(relic_manager.call("get_relic_definition", first_id) == source[0], "RelicManager definition query is isolated")

	_signal_events.clear()
	relic_manager.relic_added.connect(_record_relic_added)
	relic_manager.relics_changed.connect(_record_relics_changed)
	_expect(bool(relic_manager.call("add_relic", first_id)), "valid relic can be added")
	_expect(_signal_events == ["relic_added", "relics_changed"], "successful acquisition preserves signal order")
	_expect(not bool(relic_manager.call("add_relic", first_id)), "duplicate relic stays rejected")
	_expect(not bool(relic_manager.call("add_relic", &"__missing_phase6_relic__")), "missing relic stays rejected")
	_expect(_signal_events == ["relic_added", "relics_changed"], "failed acquisitions emit no signals")

	var late_id: StringName = &"__phase6_relic_late__"
	var late_definition: Dictionary = {"id": String(late_id), "modifiers": [], "negative_modifier": []}
	var late_index: Dictionary = original.duplicate(true)
	late_index[late_id] = late_definition.duplicate(true)
	manager.set("_relic_definitions", late_index)
	_expect(relic_manager.call("get_relic_definition", late_id) == late_definition, "local miss resolves through facade lookup")
	var late_probe: Dictionary = relic_manager.call("get_relic_definition", late_id)
	late_probe["id"] = "mutated"
	_expect(relic_manager.call("get_relic_definition", late_id) == late_definition, "late cached definition is isolated")

	var capacity_manager: Node = RelicManagerScript.new()
	capacity_manager.set("max_relics", 1)
	host.add_child(capacity_manager)
	capacity_manager.call("_load_relic_definitions")
	_expect(bool(capacity_manager.call("add_relic", first_id)), "capacity probe accepts first relic")
	var second_id: StringName = StringName(String(source[1].get("id", "")))
	_expect(not bool(capacity_manager.call("add_relic", second_id)), "capacity probe rejects second relic")

	manager.set("_relic_definitions", original)
	host.free()
	_signal_events.clear()


func _record_relic_added(_relic_id: StringName) -> void:
	_signal_events.append("relic_added")


func _record_relics_changed() -> void:
	_signal_events.append("relics_changed")


func _mutate_nested_relic(pool: Array[Dictionary], marker: String) -> bool:
	if pool.is_empty():
		return false
	_mutate_definition(pool[0], marker)
	return true


func _mutate_definition(definition: Dictionary, marker: String) -> void:
	var modifiers: Array = definition.get("modifiers", []) as Array
	if not modifiers.is_empty() and modifiers[0] is Dictionary:
		var modifier: Dictionary = modifiers[0]
		var scope: Dictionary = modifier.get("scope", {}) as Dictionary
		scope[marker] = true
	var trigger: Dictionary = definition.get("trigger_condition", {}) as Dictionary
	trigger[marker] = true
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
	push_error("[verify_data_access_relics] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_relics] PASS")
	quit(1 if _failed else 0)
