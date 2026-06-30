extends SceneTree


const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")
const SummonDefinitionScript: Script = preload("res://scripts/summons/summon_definition.gd")
const SummonControllerScript: Script = preload("res://scripts/summons/summon_controller.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner: Node2D = Node2D.new()
	root.add_child(owner)
	var skill_definition: RefCounted = SkillDefinitionScript.new({
		"id": "test_summon_growth",
		"type": "summon",
		"max_level": 5,
		"rarity": "normal"
	})
	var skill: RefCounted = SkillInstanceScript.new(skill_definition)
	skill.set("current_level", 2)
	skill.set("current_rarity", "rare")
	var summon_definition: RefCounted = SummonDefinitionScript.from_dictionary({
		"id": "test_scaled_summon",
		"duration": 10.0,
		"attack": {
			"attack_type": "melee",
			"attack_range": 48.0,
			"attack_cooldown": 2.0,
			"damage_scale": 1.0
		}
	})
	var summon: Node2D = SummonControllerScript.new()
	root.add_child(summon)
	summon.call("setup", {
		"definition": summon_definition,
		"owner": owner,
		"skill_instance": skill,
		"player_power": 10.0
	})
	_expect_close(float(summon.get("_remaining_duration")), 10.0 * 1.06 * 1.25, "summon duration scaled")
	var attack: RefCounted = summon.get("_attack") as RefCounted
	_expect(attack != null, "summon attack component exists")
	if attack != null:
		_expect_close(float(attack.get("damage_scale")), 1.0 * 1.10 * 1.25, "summon damage_scale scaled")
		_expect_close(float(attack.get("attack_cooldown")), 2.0 * 0.97 / 1.25, "summon attack cooldown scaled")
	if not _failed:
		print("[verify_skill_growth_summon_runtime] PASS")
	quit(1 if _failed else 0)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= 0.0001:
		return
	_fail(label, {"actual": actual, "expected": expected})


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_fail(label, actual)


func _fail(label: String, actual: Variant = "") -> void:
	_failed = true
	push_error("[verify_skill_growth_summon_runtime] FAIL %s actual=%s" % [label, str(actual)])
