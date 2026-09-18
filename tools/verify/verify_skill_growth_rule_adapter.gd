extends SceneTree


const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")
const SkillTriggerRuleAdapterScript: Script = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition: RefCounted = SkillDefinitionScript.new({
		"id": "test_cast_growth",
		"name": "test_cast_growth",
		"type": "cast",
		"rarity": "normal",
		"max_level": 5,
		"trigger_rules": [
			{
				"trigger": "cast_skill",
				"cooldown": 10.0,
				"effects": [
					{
						"type": "spawn_area",
						"area_id": "test_area",
						"radius_r": 2.0,
						"duration": 5.0,
						"effects_on_apply": [
							{"type": "damage", "power_scale": 1.0}
						],
						"effects_on_tick": [
							{"type": "damage", "power_scale": 0.25}
						]
					}
				]
			}
		]
	})
	var skill: RefCounted = SkillInstanceScript.new(definition)
	skill.set("current_level", 2)
	skill.set("current_rarity", "rare")
	var events: Array = SkillTriggerRuleAdapterScript.to_events(skill, definition)
	_expect(events.size() == 1, "creates one event", events.size())
	if events.is_empty():
		quit(1)
		return
	var event: Dictionary = events[0]
	_expect_close(float(event.get("cooldown", 0.0)), 10.0 * 0.96 / 1.25, "cast Lv2 rare cooldown")
	var actions: Array = event.get("actions", [])
	_expect(actions.size() == 1, "creates one action", actions.size())
	if actions.is_empty():
		quit(1)
		return
	var params: Dictionary = actions[0].get("params", {})
	_expect_close(float(params.get("radius_r", 0.0)), 2.0 * 1.05 * 1.25, "area radius_r scaled")
	_expect_close(float(params.get("duration", 0.0)), 5.0 * 1.06 * 1.25, "area duration scaled")
	var apply_actions: Array = params.get("actions_on_apply", [])
	var tick_actions: Array = params.get("actions_on_tick", [])
	_expect_close(float(apply_actions[0].get("params", {}).get("power_scale", 0.0)), 1.0 * 1.12 * 1.25, "apply damage scaled")
	_expect_close(float(tick_actions[0].get("params", {}).get("power_scale", 0.0)), 0.25, "tick damage not scaled")
	_verify_random_chance_per_level()
	if not _failed:
		print("[verify_skill_growth_rule_adapter] PASS")
	quit(1 if _failed else 0)


func _verify_random_chance_per_level() -> void:
	var definition: RefCounted = SkillDefinitionScript.new({
		"id": "test_chance_growth",
		"name": "test_chance_growth",
		"type": "attack",
		"rarity": "normal",
		"max_level": 5,
		"trigger_rules": [
			{
				"trigger": "attack_hit",
				"conditions": [
					{
						"type": "random_chance",
						"chance_per_level": 0.2,
						"max_chance": 1.0
					}
				],
				"effects": [
					{"type": "spawn_area", "area_id": "test_area"}
				]
			}
		]
	})
	var skill: RefCounted = SkillInstanceScript.new(definition)
	skill.set("current_level", 1)
	var level_one_event: Dictionary = SkillTriggerRuleAdapterScript.to_events(skill, definition)[0]
	_expect_close(_first_condition_chance(level_one_event), 0.2, "random_chance Lv1 uses 20 percent")
	skill.set("current_level", 5)
	var level_five_event: Dictionary = SkillTriggerRuleAdapterScript.to_events(skill, definition)[0]
	_expect_close(_first_condition_chance(level_five_event), 1.0, "random_chance Lv5 caps at 100 percent")


func _first_condition_chance(event: Dictionary) -> float:
	var conditions: Array = event.get("conditions", [])
	if conditions.is_empty():
		_fail("event has random_chance condition", event)
		return 0.0
	var params: Dictionary = conditions[0].get("params", {})
	return float(params.get("chance", -1.0))


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
	push_error("[verify_skill_growth_rule_adapter] FAIL %s actual=%s" % [label, str(actual)])
