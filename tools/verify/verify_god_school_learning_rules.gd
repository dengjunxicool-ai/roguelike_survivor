extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const SkillOfferServiceScript: Script = preload("res://scripts/skills/skill_offer_service.gd")


class TestPlayer:
	extends Node2D

	var selected_character_id: StringName = &"mage"

	func set_run_modifier_source(_source_id: Variant, _modifiers: Variant) -> void:
		pass

	func clear_run_modifier_source(_source_id: Variant) -> void:
		pass


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := TestPlayer.new()
	player.name = "Player"
	var skill_manager: Node = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	skill_manager.set("max_active_skills", 20)
	skill_manager.set("max_passive_skills", 20)
	player.add_child(skill_manager)
	root.add_child(player)

	_expect(skill_manager.has_method("set_primary_attack_method"), "SkillManager exposes primary attack method API")
	if skill_manager.has_method("set_primary_attack_method"):
		_expect(bool(skill_manager.call("set_primary_attack_method", &"fireball")), "sets fireball as primary attack method")
	_expect(not bool(skill_manager.call("add_skill", &"fireball")), "fireball cannot be learned through add_skill")
	_expect(not bool(skill_manager.call("has_skill", &"fireball")), "primary fireball is not counted as a learned skill")
	_expect(skill_manager.call("get_skill", &"fireball") == null, "primary fireball is not returned by get_skill")
	_expect(not _has_skill_id(skill_manager.call("get_all_skills"), &"fireball"), "primary fireball is excluded from get_all_skills")
	_expect(_has_skill_id(skill_manager.call("get_active_skills"), &"fireball"), "primary fireball remains executable through get_active_skills")
	_expect(_god_school_count(skill_manager) == 0, "primary fireball does not count as a learned god school")

	_expect(bool(skill_manager.call("add_skill", &"fire_attack_searing")), "can learn first god school skill")
	_expect(_god_school_count(skill_manager) == 1, "first learned god skill opens one school")
	_expect(not _has_skill_id(skill_manager.call("get_active_skills"), &"fireball"), "attack replacement removes primary fireball method from executable active list")
	_expect(bool(skill_manager.call("add_skill", &"frost_cast_frost_field")), "can learn second god school skill")
	_expect(_god_school_count(skill_manager) == 2, "second learned god skill opens two schools")
	_expect(not bool(skill_manager.call("add_skill", &"thunder_cast_chain_lightning")), "cannot learn a third god school skill")

	var offer_service: RefCounted = SkillOfferServiceScript.new()
	_expect(not bool(offer_service.call("is_skill_available", player, GameData.get_skill(&"thunder_cast_chain_lightning"))), "offer service blocks third god school")
	_expect(bool(offer_service.call("is_skill_available", player, GameData.get_skill(&"fusion_fire_frost_steam_mist"))), "fusion is available after two god schools")

	var player_with_one_school := TestPlayer.new()
	player_with_one_school.name = "PlayerWithOneSchool"
	var one_school_manager: Node = SkillManagerScript.new()
	one_school_manager.name = "SkillManager"
	one_school_manager.set("max_active_skills", 20)
	one_school_manager.set("max_passive_skills", 20)
	player_with_one_school.add_child(one_school_manager)
	root.add_child(player_with_one_school)
	one_school_manager.call("add_skill", &"fire_attack_searing")
	_expect(not bool(offer_service.call("is_skill_available", player_with_one_school, GameData.get_skill(&"fusion_fire_frost_steam_mist"))), "fusion is unavailable before two god schools")

	player.queue_free()
	player_with_one_school.queue_free()
	await process_frame
	if not _failed:
		print("[verify_god_school_learning_rules] PASS")
	quit(1 if _failed else 0)


func _has_skill_id(skills: Variant, skill_id: StringName) -> bool:
	if not (skills is Array):
		return false
	for skill_variant: Variant in skills:
		var skill: RefCounted = skill_variant as RefCounted
		if skill != null and StringName(String(skill.get("skill_id"))) == skill_id:
			return true
	return false


func _god_school_count(skill_manager: Node) -> int:
	if skill_manager != null and skill_manager.has_method("get_learned_god_school_count"):
		return int(skill_manager.call("get_learned_god_school_count"))
	return -1


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_god_school_learning_rules] FAIL %s actual=%s" % [label, str(actual)])
