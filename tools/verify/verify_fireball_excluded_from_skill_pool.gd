extends SceneTree


const SkillLearnDefinitionRepositoryScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(not GameData.get_skill(&"fireball").is_empty(), "fireball remains queryable as a starting attack")
	_expect(not _pool_has_skill(GameData.get_skill_pool(), &"fireball"), "fireball is excluded from ordinary skill pool", _summarize_pool(GameData.get_skill_pool()))
	_expect(_pool_has_skill(GameData.get_primary_attack_pool(), &"fireball"), "fireball remains available in primary attack pool", _summarize_pool(GameData.get_primary_attack_pool()))

	var misconfigured_pool: Array[Dictionary] = [
		{
			"id": "fireball",
			"is_starting_skill": true,
			"offer_in_upgrade_pool": true,
			"offer_rule": {"required_schools": ["fire"]}
		},
		{
			"id": "fire_cast_meteor_rain",
			"offer_in_upgrade_pool": true,
			"offer_rule": {"required_schools": ["fire"]}
		}
	]
	var learn_definitions: Array[Dictionary] = SkillLearnDefinitionRepositoryScript.get_skill_learn_definitions(misconfigured_pool, "offer_rule")
	_expect(not _pool_has_skill(learn_definitions, &"fireball"), "starting fireball cannot enter skill learn definitions even if misconfigured", _summarize_pool(learn_definitions))
	_expect(_pool_has_skill(learn_definitions, &"fire_cast_meteor_rain"), "ordinary learnable fire skill remains available", _summarize_pool(learn_definitions))

	if not _failed:
		print("[verify_fireball_excluded_from_skill_pool] PASS")
	quit(1 if _failed else 0)


func _pool_has_skill(pool: Array, skill_id: StringName) -> bool:
	for item: Variant in pool:
		if item is Dictionary and StringName(String((item as Dictionary).get("id", ""))) == skill_id:
			return true
	return false


func _summarize_pool(pool: Array) -> String:
	var ids: Array[String] = []
	for item: Variant in pool:
		if item is Dictionary:
			ids.append(String((item as Dictionary).get("id", "")))
	return ", ".join(ids)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_fireball_excluded_from_skill_pool] FAIL %s actual=%s" % [label, str(actual)])
