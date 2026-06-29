extends SceneTree

const CharacterRunInitializerScript: Script = preload("res://scripts/characters/character_run_initializer.gd")
const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const SkillOfferServiceScript: Script = preload("res://scripts/skills/skill_offer_service.gd")


class RuntimeStub:
	extends Node

	func initialize(_character_id: String) -> bool:
		return true


class TestPlayer:
	extends Node2D

	var selected_character_id: StringName = &"mage"

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
	_verify_starting_loadout_grants_primary_and_dash()
	_verify_primary_and_dash_do_not_consume_active_capacity()
	_verify_passive_capacity_is_three()
	_verify_offer_service_hides_full_capacity_skills()
	if not _failed:
		print("[verify_skill_slot_capacity_rules] PASS")
	quit(1 if _failed else 0)


func _make_player_with_skill_manager() -> TestPlayer:
	var player := TestPlayer.new()
	player.name = "Player"
	var runtime := RuntimeStub.new()
	runtime.name = "CharacterRuntime"
	player.add_child(runtime)
	var skill_manager: Node = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	root.add_child(player)
	return player


func _verify_starting_loadout_grants_primary_and_dash() -> void:
	var player := _make_player_with_skill_manager()
	var initializer: RefCounted = CharacterRunInitializerScript.new()
	initializer.call("configure_starting_skills", player)
	var skill_manager := player.get_node("SkillManager")
	_expect(bool(skill_manager.call("has_skill", &"fireball")), "starting loadout grants primary attack", skill_manager.call("get_all_skills"))
	_expect(bool(skill_manager.call("has_skill", &"fire_dash_blazing_run")), "starting loadout grants dash skill", skill_manager.call("get_all_skills"))
	_expect(skill_manager.call("get_active_skills").size() == 2, "starting primary and dash are both active skills internally", skill_manager.call("get_active_skills").size())
	player.queue_free()


func _verify_primary_and_dash_do_not_consume_active_capacity() -> void:
	var player := _make_player_with_skill_manager()
	var skill_manager := player.get_node("SkillManager")
	_expect(bool(skill_manager.call("add_skill", &"fireball")), "adds primary skill", "")
	_expect(bool(skill_manager.call("add_skill", &"fire_dash_blazing_run")), "adds dash skill", "")
	for skill_id: StringName in [
		&"fire_cast_meteor_rain",
		&"fire_cast_lava_rift",
		&"fire_cast_scorching_vortex",
		&"fire_summon_crimson_dragon",
		&"fire_summon_ember_fox_pack"
	]:
		_expect(bool(skill_manager.call("add_skill", skill_id)), "adds ordinary active %s" % String(skill_id), skill_manager.call("get_active_skills").size())
	_expect(not bool(skill_manager.call("add_skill", &"fire_power_combustion_chain")), "rejects sixth ordinary active skill", skill_manager.call("get_active_skills").size())
	_expect(skill_manager.call("get_active_skills").size() == 7, "active dictionary contains primary dash and five ordinary actives", skill_manager.call("get_active_skills").size())
	player.queue_free()


func _verify_passive_capacity_is_three() -> void:
	var player := _make_player_with_skill_manager()
	var skill_manager := player.get_node("SkillManager")
	for skill_id: StringName in [
		&"fire_passive_burning_focus",
		&"fire_passive_overheated_casting",
		&"fire_passive_scorched_ground_affinity"
	]:
		_expect(bool(skill_manager.call("add_skill", skill_id)), "adds passive %s" % String(skill_id), skill_manager.call("get_passive_skills").size())
	_expect(not bool(skill_manager.call("add_skill", &"frost_passive_frozen_vulnerability")), "rejects fourth passive skill", skill_manager.call("get_passive_skills").size())
	_expect(skill_manager.call("get_passive_skills").size() == 3, "keeps three passive skills", skill_manager.call("get_passive_skills").size())
	player.queue_free()


func _verify_offer_service_hides_full_capacity_skills() -> void:
	var player := _make_player_with_skill_manager()
	var skill_manager := player.get_node("SkillManager")
	skill_manager.call("add_skill", &"fireball")
	skill_manager.call("add_skill", &"fire_dash_blazing_run")
	for skill_id: StringName in [
		&"fire_cast_meteor_rain",
		&"fire_cast_lava_rift",
		&"fire_cast_scorching_vortex",
		&"fire_summon_crimson_dragon",
		&"fire_summon_ember_fox_pack",
		&"fire_passive_burning_focus",
		&"fire_passive_overheated_casting",
		&"fire_passive_scorched_ground_affinity"
	]:
		skill_manager.call("add_skill", skill_id)

	var offer_service: RefCounted = SkillOfferServiceScript.new()
	_expect(
		not bool(offer_service.call("is_skill_available", player, GameData.get_skill(&"fire_power_combustion_chain"))),
		"offer service hides sixth ordinary active skill",
		"available"
	)
	_expect(
		not bool(offer_service.call("is_skill_available", player, GameData.get_skill(&"frost_passive_frozen_vulnerability"))),
		"offer service hides fourth passive skill",
		"available"
	)
	player.queue_free()


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_slot_capacity_rules] FAIL %s actual=%s" % [label, str(actual)])
