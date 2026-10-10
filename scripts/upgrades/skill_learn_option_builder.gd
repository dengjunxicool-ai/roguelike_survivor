## 文件用途：把神系技能和动态学习升级转换为统一学习卡片字典。
## 使用方式：build_option_data 传技能、升级和稀有度；缺 ID 返回空字典，payload 保存 learn_skill_id 与目标稀有度。
extends RefCounted
class_name SkillLearnOptionBuilder


## 作用：把学习技能、升级定义和抽到的稀有度装配为卡片及应用载荷。
## 使用：skill 为技能实例或定义；rarity 为目标稀有度；无适用数据时返回空字典。
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
		"recommended_reason": "首次学习确定品质，后续升级保持品质。",
		"level_text": "Lv1 / %d" % max_level,
		"payload": {
			"upgrade_id": upgrade_id,
			"learn_skill_id": skill_id,
			"level": 1,
			"target_rarity": rarity,
		},
	}


## 作用：优先取学习升级第一条等级说明，否则读取通用说明。
## 使用：由本文件 build_option_data 调用。
static func _get_description(upgrade: Dictionary) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if not descriptions.is_empty():
		return _string_or(descriptions[0], "")
	return _string_or(upgrade.get("description", ""), "")


## 作用：按既定字段优先级读取学习技能卡面路径。
## 使用：skill 为技能实例或定义。
static func _get_background_texture(skill: Dictionary) -> String:
	for key: String in ["background_texture", "card_background_texture"]:
		var value: String = _string_or(skill.get(key, ""), "")
		if value != "":
			return value
	return ""


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 build_option_data/_get_description 调用；无匹配项时返回空数组。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
