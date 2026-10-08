extends SceneTree

const GameDataScript := preload("res://scripts/game/game_data.gd")
const UpgradePoolScript := preload("res://scripts/upgrades/upgrade_pool.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return

	var original_definitions: Dictionary = (manager.get("_skill_definitions") as Dictionary).duplicate(true)
	var sentinel_id: StringName = &"__phase6_upgrade_pool_skill__"
	var sentinel: Dictionary = {
		"id": String(sentinel_id),
		"display_name": "Phase 6 Upgrade Pool Skill",
		"description": "Facade-owned debug skill fixture.",
		"rarity": "common",
		"tags": ["fire", "skill"],
		"god_id": "fire",
		"offer_in_upgrade_pool": true,
		"max_level": 1,
		"base": {"damage": 17}
	}
	manager.set("_skill_definitions", {sentinel_id: sentinel.duplicate(true)})
	GameDataScript._document_cache.clear()

	var pool: RefCounted = UpgradePoolScript.new()
	var debug_definitions: Array[Dictionary] = _to_dictionary_array(
		pool.call("_get_debug_god_skill_definitions", &"fire")
	)
	_expect(debug_definitions == [sentinel], "debug pool prefers the GameData manager-backed skill pool")
	_expect(bool(pool.call("_is_debug_god_skill", sentinel_id, &"fire")), "debug single lookup uses the GameData manager-backed skill")

	if not debug_definitions.is_empty():
		(debug_definitions[0].get("base", {}) as Dictionary)["damage"] = 999
		(debug_definitions[0].get("tags", []) as Array).append("mutated")
	var second_read: Array[Dictionary] = _to_dictionary_array(
		pool.call("_get_debug_god_skill_definitions", &"fire")
	)
	_expect(second_read == [sentinel], "debug pool results remain deeply isolated")
	_expect((manager.get("_skill_definitions") as Dictionary).get(sentinel_id, {}) == sentinel, "debug callers cannot mutate DataManager skill definitions")

	var player: Node = Node.new()
	var skill_manager: Node = Node.new()
	skill_manager.name = &"SkillManager"
	player.add_child(skill_manager)
	_expect(bool(pool.call("_is_learn_skill_upgrade_available", player, sentinel_id)), "normal learn eligibility accepts a facade-owned skill")
	_expect(not bool(pool.call("_is_learn_skill_upgrade_available", player, &"__phase6_missing_upgrade_pool_skill__")), "normal learn eligibility rejects an unknown skill")
	player.free()

	manager.set("_skill_definitions", original_definitions)
	GameDataScript._document_cache.clear()
	_finish()


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
	push_error("[verify_data_access_upgrade_pool_skills] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_upgrade_pool_skills] PASS")
	quit(1 if _failed else 0)
