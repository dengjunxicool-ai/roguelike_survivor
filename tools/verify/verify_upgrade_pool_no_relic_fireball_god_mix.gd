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
	var player := _make_player()
	var skill_manager: Node = player.get_node("SkillManager")
	skill_manager.call("set_primary_attack_method", &"fireball")
	skill_manager.call("add_skill", &"frost_cast_frost_field")

	var pool: RefCounted = UpgradePoolScript.new()
	var skill_level_options: Array = pool.call("_build_skill_level_up_options", player)
	_expect(not _has_option_prefix(skill_level_options, "skill_level_up:fireball:"), "fireball does not generate owned skill level-up cards", _summarize(skill_level_options))

	var relic_upgrade: Dictionary = {
		"id": "test_relic_card",
		"display_name": "Test Relic Card",
		"description": "Should never enter level-up skill card pool.",
		"rarity": "epic",
		"enabled": true,
		"max_level": 1,
		"relic_id": "test_relic",
		"tags": ["relic"]
	}
	_expect(pool.call("_is_relic_related_upgrade", relic_upgrade) == true, "relic-like level-up upgrade is detected as relic-related", relic_upgrade)

	var frost_upgrade: Dictionary = GameData.get_upgrade(&"learn_skill_frost_attack_frostbite")
	_expect(not frost_upgrade.is_empty(), "generic skill learn upgrade resolves frost skills", frost_upgrade)
	_expect(String(frost_upgrade.get("learn_skill_id", "")) == "frost_attack_frostbite", "generic frost learn upgrade points at frost skill", frost_upgrade)
	_expect(GameData.get_upgrade(&"learn_fire_skill_frost_attack_frostbite").is_empty(), "legacy fire learn prefix does not resolve frost skills")

	var god_options: Array = pool.call("_build_god_skill_learn_options", player)
	_expect(_has_school(god_options, &"frost"), "normal god skill learn options include non-fire schools when offer rules allow them", _summarize(god_options))

	if not _failed:
		print("[verify_upgrade_pool_no_relic_fireball_god_mix] PASS")
	quit(1 if _failed else 0)


func _make_player() -> TestPlayer:
	var player := TestPlayer.new()
	player.name = "Player"
	var skill_manager: Node = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	root.add_child(player)
	return player


func _has_option_prefix(options: Array, prefix: String) -> bool:
	for option_variant: Variant in options:
		var option: Dictionary = _option_dictionary(option_variant)
		if String(option.get("id", "")).begins_with(prefix):
			return true
	return false


func _has_school(options: Array, school_id: StringName) -> bool:
	for option_variant: Variant in options:
		var option: Dictionary = _option_dictionary(option_variant)
		var payload: Dictionary = _dictionary(option.get("payload", {}))
		var skill_id: StringName = StringName(String(payload.get("learn_skill_id", "")))
		if skill_id == &"":
			continue
		var skill: Dictionary = GameData.get_skill(skill_id)
		if StringName(String(skill.get("school", skill.get("fusion_school", "")))) == school_id:
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
	push_error("[verify_upgrade_pool_no_relic_fireball_god_mix] FAIL %s actual=%s" % [label, str(actual)])
