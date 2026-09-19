extends RefCounted
class_name SkillLearnOptionBuilder


static func build_option_data(skill: Dictionary, upgrade: Dictionary, rarity: String) -> Dictionary:
	var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
	var upgrade_id: StringName = StringName(_string_or(upgrade.get("id", ""), ""))
	if skill_id == &"" or upgrade_id == &"":
		return {}
	var max_level: int = maxi(int(skill.get("max_level", upgrade.get("max_level", 1))), 1)
	return {
		"id": "level_up_upgrade:%s:%s" % [_string_or(upgrade_id, ""), rarity],
		"type": "level_up_upgrade",
		"display_name": _string_or(upgrade.get("display_name", skill.get("display_name", skill_id)), _string_or(skill_id, "")),
		"description": _get_description(upgrade),
		"rarity": rarity,
		"background_texture": _get_background_texture(skill),
		"tags": _get_array(upgrade.get("tags", [])).duplicate(true),
		"affected_origin": "神系技能",
		"does_not_affect": "不替换角色初始技能。",
		"recommended_reason": "从神系技能池学习一个新技能。",
		"level_text": "Lv1 / %d" % max_level,
		"payload": {
			"upgrade_id": upgrade_id,
			"learn_skill_id": skill_id,
			"level": 1,
			"target_rarity": rarity,
		},
	}


static func _get_description(upgrade: Dictionary) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if not descriptions.is_empty():
		return _string_or(descriptions[0], "")
	return _string_or(upgrade.get("description", ""), "")


static func _get_background_texture(skill: Dictionary) -> String:
	for key: String in ["background_texture", "card_background_texture"]:
		var value: String = _string_or(skill.get(key, ""), "")
		if value != "":
			return value
	return ""


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
