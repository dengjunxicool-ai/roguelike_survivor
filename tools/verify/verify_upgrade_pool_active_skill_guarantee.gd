extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")


class TestPlayer:
	extends Node2D

	var selected_character_id: StringName = &"mage"
	var max_health: int = 100
	var current_health: int = 100
	var level: int = 3

	func _init() -> void:
		add_to_group(&"player")

	func set_run_modifier_source(_source_id: Variant, _modifiers: Variant) -> void:
		pass

	func clear_run_modifier_source(_source_id: Variant) -> void:
		pass


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := _make_player_with_early_fire_loadout()
	for seed: int in range(1, 41):
		var pool: RefCounted = UpgradePoolScript.new()
		var rng: RandomNumberGenerator = pool.get("_rng") as RandomNumberGenerator
		rng.seed = seed
		var options: Array = pool.call("generate_options", player, 3)
		_expect(_has_direct_active_learn_option(options), "seed %d offers a direct active learn option" % seed, _summarize(options))
	player.queue_free()
	var player_with_one_active := _make_player_with_early_fire_loadout()
	var manager: Node = player_with_one_active.get_node("SkillManager")
	manager.call("add_skill", &"fire_cast_meteor_rain")
	for seed: int in range(1, 41):
		var pool: RefCounted = UpgradePoolScript.new()
		var rng: RandomNumberGenerator = pool.get("_rng") as RandomNumberGenerator
		rng.seed = seed
		var options: Array = pool.call("generate_options", player_with_one_active, 3)
		_expect(_has_direct_active_learn_option(options), "seed %d offers a second direct active learn option" % seed, _summarize(options))
	player_with_one_active.queue_free()
	if not _failed:
		print("[verify_upgrade_pool_active_skill_guarantee] PASS")
	quit(1 if _failed else 0)


func _make_player_with_early_fire_loadout() -> TestPlayer:
	var player := TestPlayer.new()
	player.name = "Player"
	var skill_manager: Node = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	root.add_child(player)
	skill_manager.call("add_skill", &"fireball")
	skill_manager.call("upgrade_skill", &"fireball")
	skill_manager.call("add_skill", &"fire_dash_blazing_run")
	return player


func _has_direct_active_learn_option(options: Array) -> bool:
	for option_variant: Variant in options:
		var option: Dictionary = _option_dictionary(option_variant)
		var payload: Dictionary = _dictionary(option.get("payload", {}))
		var skill_id: StringName = StringName(String(payload.get("learn_skill_id", "")))
		if skill_id == &"":
			continue
		var skill: Dictionary = GameData.get_skill(skill_id)
		var skill_type: String = String(skill.get("skill_type", skill.get("type", skill.get("category", ""))))
		if skill_type == "cast" or skill_type == "summon":
			return true
	return false


func _summarize(options: Array) -> String:
	var parts: Array[String] = []
	for option_variant: Variant in options:
		var option: Dictionary = _option_dictionary(option_variant)
		var payload: Dictionary = _dictionary(option.get("payload", {}))
		parts.append("%s/%s" % [String(option.get("id", "")), String(payload.get("learn_skill_id", payload.get("skill_id", payload.get("upgrade_id", ""))))])
	return ", ".join(parts)


func _option_dictionary(option_variant: Variant) -> Dictionary:
	var option: RefCounted = option_variant as RefCounted
	if option != null and option.has_method("to_dictionary"):
		var value: Variant = option.call("to_dictionary")
		return value if value is Dictionary else {}
	return option_variant if option_variant is Dictionary else {}


func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_upgrade_pool_active_skill_guarantee] FAIL %s actual=%s" % [label, str(actual)])
