extends SceneTree


const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_attack_growth()
	_verify_fusion_growth()
	_verify_core_growth_is_fixed()
	_verify_rarity_pools()
	if not _failed:
		print("[verify_skill_growth_scaling] PASS")
	quit(1 if _failed else 0)


func _verify_attack_growth() -> void:
	var skill: RefCounted = _make_skill("fire_attack_searing", "attack", 5)
	skill.set("current_level", 2)
	skill.set("current_rarity", "rare")
	_expect_close(
		float(SkillGrowthScalingScript.stat_multiplier(skill, "damage")),
		1.08 * 1.25,
		"attack Lv2 rare damage multiplier"
	)
	_expect_close(
		float(SkillGrowthScalingScript.stat_multiplier(skill, "radius")),
		1.03 * 1.25,
		"attack Lv2 rare radius multiplier"
	)
	_expect_close(
		float(SkillGrowthScalingScript.stat_multiplier(skill, "duration")),
		1.05 * 1.25,
		"attack Lv2 rare duration multiplier"
	)
	_expect_close(
		float(SkillGrowthScalingScript.stat_multiplier(skill, "tick_damage")),
		1.0,
		"attack tick damage remains unscaled"
	)


func _verify_fusion_growth() -> void:
	var skill: RefCounted = _make_skill("fusion_fire_frost_steam_mist", "fusion", 2)
	skill.set("current_level", 2)
	skill.set("current_rarity", "legendary")
	_expect_close(
		float(SkillGrowthScalingScript.stat_multiplier(skill, "damage")),
		1.15 * 1.95,
		"fusion Lv2 legendary damage multiplier"
	)
	_expect_close(
		float(SkillGrowthScalingScript.stat_multiplier(skill, "cooldown")),
		0.97 / 1.95,
		"fusion Lv2 legendary cooldown multiplier"
	)


func _verify_core_growth_is_fixed() -> void:
	var skill: RefCounted = _make_skill("fire_core_inferno_cycle", "core", 1)
	skill.set("current_level", 1)
	skill.set("current_rarity", "legendary")
	_expect_close(float(SkillGrowthScalingScript.stat_multiplier(skill, "damage")), 1.0, "core damage is fixed")
	_expect_close(float(SkillGrowthScalingScript.stat_multiplier(skill, "duration")), 1.0, "core duration is fixed")


func _verify_rarity_pools() -> void:
	_expect(
		SkillGrowthScalingScript.rarity_weight_map_for_max_level(5) == {"normal": 1.0, "rare": 2.0, "epic": 1.0, "legendary": 1.0},
		"max level 5 rarity weights",
		SkillGrowthScalingScript.rarity_weight_map_for_max_level(5)
	)
	_expect(
		SkillGrowthScalingScript.rarity_weight_map_for_max_level(2) == {"epic": 1.0, "legendary": 1.0},
		"max level 2 rarity weights",
		SkillGrowthScalingScript.rarity_weight_map_for_max_level(2)
	)
	_expect(
		SkillGrowthScalingScript.rarity_weight_map_for_max_level(1) == {"legendary": 1.0},
		"max level 1 rarity weights",
		SkillGrowthScalingScript.rarity_weight_map_for_max_level(1)
	)


func _make_skill(skill_id: String, skill_type: String, max_level: int) -> RefCounted:
	var definition: RefCounted = SkillDefinitionScript.new({
		"id": skill_id,
		"name": skill_id,
		"type": skill_type,
		"rarity": "normal",
		"max_level": max_level
	})
	return SkillInstanceScript.new(definition)


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
	push_error("[verify_skill_growth_scaling] FAIL %s actual=%s" % [label, str(actual)])
