extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")

class TestPlayer:
	extends Node

	func set_run_modifier_source(_source_id: Variant, _modifiers: Variant) -> void:
		pass

	func clear_run_modifier_source(_source_id: Variant) -> void:
		pass


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player: TestPlayer = TestPlayer.new()
	root.add_child(player)
	var skill_manager: Node = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	_expect(bool(skill_manager.call("add_skill", &"fire_attack_searing")), "learns fire_attack_searing")
	var upgrade_pool: RefCounted = UpgradePoolScript.new()
	var options: Array = upgrade_pool.call("_build_skill_level_up_options", player)
	var option: RefCounted = _find_option_for_skill(options, &"fire_attack_searing")
	_expect(option != null, "creates fire_attack_searing level-up option", _option_ids(options))
	if option != null:
		var option_id: String = String(option.get("id"))
		var rarity: String = String(option.get("rarity"))
		var allowed: Dictionary = SkillGrowthScalingScript.rarity_weight_map_for_max_level(5)
		_expect(option_id.begins_with("skill_level_up:fire_attack_searing:2:"), "level-up option id carries rarity", option_id)
		_expect(allowed.has(rarity), "level-up option rarity is allowed for max level 5", rarity)
		_expect(option_id.ends_with(":%s" % rarity), "option id rarity matches displayed rarity", {"id": option_id, "rarity": rarity})
	if not _failed:
		print("[verify_skill_growth_upgrade_pool] PASS")
	quit(1 if _failed else 0)


func _find_option_for_skill(options: Array, skill_id: StringName) -> RefCounted:
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option == null:
			continue
		if String(option.get("id")).begins_with("skill_level_up:%s:" % String(skill_id)):
			return option
	return null


func _option_ids(options: Array) -> Array[String]:
	var ids: Array[String] = []
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option != null:
			ids.append(String(option.get("id")))
	return ids


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_growth_upgrade_pool] FAIL %s actual=%s" % [label, str(actual)])
