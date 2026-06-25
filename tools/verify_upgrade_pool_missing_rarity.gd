extends SceneTree


const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")
const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")


class FakeSkillManager:
	extends Node

	var skills: Array = []

	func get_all_skills() -> Array:
		return skills


func _init() -> void:
	var player: Node = Node.new()
	var skill_manager: FakeSkillManager = FakeSkillManager.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	root.add_child(player)

	var definition: RefCounted = SkillDefinitionScript.new({
		"id": "test_fireball_no_rarity",
		"display_name": "Test Fireball",
		"category": "active",
		"max_level": 2,
		"level_descriptions": ["Lv1", "Lv2"]
	})
	var skill_instance: RefCounted = SkillInstanceScript.new(definition)
	skill_manager.skills = [skill_instance]

	var upgrade_pool: RefCounted = UpgradePoolScript.new()
	var options: Array = upgrade_pool.call("_build_skill_level_up_options", player)
	_assert(not options.is_empty(), "upgrade pool offers a level-up option for a skill without rarity")
	var option: RefCounted = options[0] as RefCounted
	_assert(option != null, "upgrade option is created")
	_assert(String(option.get("rarity")) == "common", "missing rarity defaults to common")

	print("[verify_upgrade_pool_missing_rarity] PASS")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	push_error("FAIL %s" % message)
	quit(1)
