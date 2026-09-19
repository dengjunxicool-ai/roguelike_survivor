extends SceneTree


const BuilderScript: Script = preload("res://scripts/upgrades/skill_learn_option_builder.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_complete_result_and_ownership()
	_verify_display_name_fallbacks()
	_verify_description_fallbacks()
	_verify_texture_and_level_fallbacks()
	_verify_invalid_and_malformed_inputs()
	if not _failed:
		print("[verify_skill_learn_option_builder] PASS")
	quit(1 if _failed else 0)


func _verify_complete_result_and_ownership() -> void:
	var skill: Dictionary = {
		"id": "fire_attack_searing",
		"display_name": "Searing",
		"max_level": 5,
		"background_texture": "res://skill-primary.png",
		"card_background_texture": "res://skill-card.png",
	}
	var upgrade: Dictionary = {
		"id": "learn_skill_fire_attack_searing",
		"display_name": "Learn Searing",
		"description": "fallback description",
		"level_descriptions": ["first description", "second description"],
		"tags": ["fire", {"nested": [1]}],
	}
	var skill_before: Dictionary = skill.duplicate(true)
	var upgrade_before: Dictionary = upgrade.duplicate(true)
	var result: Dictionary = BuilderScript.build_option_data(skill, upgrade, "epic")
	var expected_keys: Array[String] = [
		"affected_origin", "background_texture", "description", "display_name", "does_not_affect",
		"id", "level_text", "payload", "rarity", "recommended_reason", "tags", "type",
	]
	var actual_keys: Array[String] = []
	for key: Variant in result.keys():
		actual_keys.append(str(key))
	actual_keys.sort()
	_expect(actual_keys == expected_keys, "complete result has the exact key set", actual_keys)
	_expect(str(result.get("id", "")) == "level_up_upgrade:learn_skill_fire_attack_searing:epic", "option id is unchanged", result)
	_expect(str(result.get("type", "")) == "level_up_upgrade", "option type is unchanged", result)
	_expect(str(result.get("display_name", "")) == "Learn Searing", "upgrade display name wins", result)
	_expect(str(result.get("description", "")) == "first description", "first level description wins", result)
	_expect(str(result.get("rarity", "")) == "epic", "rarity passes through exactly", result)
	_expect(str(result.get("background_texture", "")) == "res://skill-primary.png", "primary skill texture wins", result)
	_expect(str(result.get("affected_origin", "")) == "神系技能", "affected origin is unchanged", result)
	_expect(str(result.get("does_not_affect", "")) == "不替换角色初始技能。", "does-not-affect text is unchanged", result)
	_expect(str(result.get("recommended_reason", "")) == "从神系技能池学习一个新技能。", "recommendation text is unchanged", result)
	_expect(str(result.get("level_text", "")) == "Lv1 / 5", "level text is unchanged", result)
	var payload: Dictionary = result.get("payload", {}) as Dictionary
	_expect(payload.get("upgrade_id") is StringName and payload.get("upgrade_id") == &"learn_skill_fire_attack_searing", "payload upgrade id is StringName", payload)
	_expect(payload.get("learn_skill_id") is StringName and payload.get("learn_skill_id") == &"fire_attack_searing", "payload skill id is StringName", payload)
	_expect(int(payload.get("level", 0)) == 1 and str(payload.get("target_rarity", "")) == "epic", "payload level and rarity are unchanged", payload)
	var returned_tags: Array = result.get("tags", []) as Array
	var returned_nested_tag: Dictionary = returned_tags[1] as Dictionary
	returned_nested_tag["nested"] = [9]
	payload["level"] = 99
	_expect(skill == skill_before and upgrade == upgrade_before, "building and mutating output do not mutate inputs", [skill, upgrade])
	var rebuilt: Dictionary = BuilderScript.build_option_data(skill, upgrade, "epic")
	_expect(int((rebuilt.get("payload", {}) as Dictionary).get("level", 0)) == 1, "payload is newly owned on every call", rebuilt)
	_expect(((rebuilt.get("tags", []) as Array)[1] as Dictionary).get("nested", []) == [1], "nested tags are newly owned on every call", rebuilt)


func _verify_display_name_fallbacks() -> void:
	var skill: Dictionary = {"id": "skill_a", "display_name": "Skill A"}
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a"}, "rare").get("display_name", "")) == "Skill A", "absent upgrade display uses skill display")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "display_name": null}, "rare").get("display_name", "")) == "skill_a", "null upgrade display falls directly to skill id")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "display_name": ""}, "rare").get("display_name", "missing")) == "", "empty upgrade display remains empty")
	_expect(str(BuilderScript.build_option_data({"id": "skill_a"}, {"id": "upgrade_a"}, "rare").get("display_name", "")) == "skill_a", "missing display fields use skill id")


func _verify_description_fallbacks() -> void:
	var skill: Dictionary = {"id": "skill_a"}
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "level_descriptions": ["L1"], "description": "fallback"}, "common").get("description", "")) == "L1", "first level description wins")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "level_descriptions": [], "description": "fallback"}, "common").get("description", "")) == "fallback", "empty level descriptions use description")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "level_descriptions": [""], "description": "fallback"}, "common").get("description", "missing")) == "", "empty first level description remains empty")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "level_descriptions": "invalid"}, "common").get("description", "missing")) == "", "malformed descriptions use empty fallback")


func _verify_texture_and_level_fallbacks() -> void:
	var upgrade: Dictionary = {"id": "upgrade_a", "max_level": 4, "background_texture": "res://upgrade.png"}
	var card_fallback: Dictionary = BuilderScript.build_option_data({"id": "skill_a", "card_background_texture": "res://card.png"}, upgrade, "legendary")
	_expect(str(card_fallback.get("background_texture", "")) == "res://card.png", "skill card texture is the secondary texture")
	_expect(str(card_fallback.get("level_text", "")) == "Lv1 / 4", "missing skill max level uses upgrade max level")
	_expect(str(card_fallback.get("rarity", "")) == "legendary", "rarity is not recalculated")
	var no_skill_texture: Dictionary = BuilderScript.build_option_data({"id": "skill_a", "max_level": 0}, upgrade, "")
	_expect(str(no_skill_texture.get("background_texture", "missing")) == "", "upgrade texture is not a fallback")
	_expect(str(no_skill_texture.get("level_text", "")) == "Lv1 / 1", "non-positive skill max level clamps to one")
	_expect(str(no_skill_texture.get("rarity", "missing")) == "", "empty rarity passes through without repair")


func _verify_invalid_and_malformed_inputs() -> void:
	_expect(BuilderScript.build_option_data({}, {"id": "upgrade_a"}, "common").is_empty(), "missing skill id is rejected")
	_expect(BuilderScript.build_option_data({"id": null}, {"id": "upgrade_a"}, "common").is_empty(), "null skill id is rejected")
	_expect(BuilderScript.build_option_data({"id": "skill_a"}, {}, "common").is_empty(), "missing upgrade id is rejected")
	_expect(BuilderScript.build_option_data({"id": "skill_a"}, {"id": ""}, "common").is_empty(), "empty upgrade id is rejected")
	var malformed: Dictionary = BuilderScript.build_option_data({"id": "skill_a"}, {"id": "upgrade_a", "tags": "invalid"}, "common")
	_expect((malformed.get("tags", []) as Array).is_empty(), "malformed tags become an empty array", malformed)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_learn_option_builder] FAIL %s actual=%s" % [label, str(actual)])
