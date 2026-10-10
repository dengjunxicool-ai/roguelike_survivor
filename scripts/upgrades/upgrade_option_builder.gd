## 文件用途：纯数据构建技能升级、普通属性升级和调试卡片的展示与应用载荷。
## 使用方式：由 UpgradePool 传入等级、稀有度、权重及推荐理由；本构建器不抽随机数也不应用升级效果。
extends RefCounted
class_name UpgradeOptionBuilder

## 作用：构建已拥有技能升至指定下一等级的卡片，不直接改技能等级。
## 使用：skill_id 为标准技能 ID；rarity 为目标稀有度。
static func build_skill_level_up_data(skill_id: StringName, next_level: int, skill_name: String, rarity: String, current_rarity: String, max_level: int) -> Dictionary:
	rarity = preload("res://scripts/skills/skill_growth_scaling.gd").keep_highest_rarity(current_rarity,rarity)
	return {
			"id": "skill_level_up:%s:%d:%s" % [_string_or(skill_id, ""), next_level, rarity],
			"type": "skill_level_up",
			"display_name": "%s Lv%d" % [skill_name, next_level],
			"description": _build_skill_level_up_description(skill_name, next_level),
			"rarity": rarity,
			"tags": ["skill", "level_up"],
			"affected_origin": "当前技能",
			"does_not_affect": "不学习新的技能。",
			"recommended_reason": "提高已拥有技能的等级，保持当前品质。",
			"level_text": "Lv%d / %d" % [next_level, maxi(max_level, next_level)],
			"payload": {
				"skill_id": skill_id,
				"level": next_level,
				"current_rarity": current_rarity,
				"target_rarity": rarity
			}
		}


## 作用：构建普通升级卡，携带升级 ID、学习技能引用、抽取权重和当前等级展示。
## 使用：由 UpgradePool 传入等级、稀有度、权重及推荐理由；本构建器不抽随机数也不应用升级效果。
static func build_upgrade_data(upgrade: Dictionary, upgrade_level: int, weight: float, recommended_reason: String) -> Dictionary:
	var payload: Dictionary = {"upgrade_id": StringName(_string_or(upgrade.get("id", ""), "")), "weight": weight}
	if upgrade.has("learn_skill_id"):
		payload["learn_skill_id"] = StringName(_string_or(upgrade.get("learn_skill_id", ""), ""))
	return {
			"id": "level_up_upgrade:%s" % _string_or(upgrade.get("id", ""), ""),
			"type": "level_up_upgrade",
			"display_name": _string_or(upgrade.get("display_name", upgrade.get("id", "")), _string_or(upgrade.get("id", ""), "")),
			"description": _get_level_up_upgrade_description(upgrade),
			"rarity": _string_or(upgrade.get("rarity", "common"), "common"),
			"background_texture": _get_option_background_texture(upgrade),
			"tags": _get_array(upgrade.get("tags", [])),
			"affected_origin": _infer_affected_origin(upgrade),
			"does_not_affect": _infer_does_not_affect(upgrade),
			"recommended_reason": recommended_reason,
			"level_text": "Lv%d / %d" % [upgrade_level + 1, maxi(int(upgrade.get("max_level", 1)), 1)],
			"payload": payload
		}


## 作用：构建神系调试卡，并把当前已选次数用于等级说明。
## 使用：god_id 为筛选神系 ID。
static func build_debug_data(upgrade: Dictionary, current_level: int, god_id: StringName) -> Dictionary:
	var upgrade_id: StringName = StringName(_string_or(upgrade.get("id", ""), ""))
	return {
		"id": "level_up_upgrade:%s" % _string_or(upgrade_id, ""),
		"type": "level_up_upgrade",
		"display_name": _string_or(upgrade.get("display_name", upgrade_id), _string_or(upgrade_id, "")),
		"description": _get_debug_upgrade_description(upgrade, current_level),
		"rarity": _string_or(upgrade.get("rarity", "common"), "common"),
		"background_texture": _get_option_background_texture(upgrade),
		"tags": _get_array(upgrade.get("tags", [])),
		"affected_origin": "Dev / God skill pool",
		"does_not_affect": "Dev list ignores normal offer count.",
		"recommended_reason": "Dev card for inspecting god skill runtime behavior.",
		"level_text": "Lv%d / %d" % [current_level + 1, maxi(int(upgrade.get("max_level", 1)), 1)],
		"payload": {
			"upgrade_id": upgrade_id,
			"learn_skill_id": StringName(_string_or(upgrade.get("learn_skill_id", ""), "")),
			"debug_god_id": god_id
		}
	}


## 作用：生成指定技能提升到下一等级的卡片说明。
## 使用：由本文件 build_skill_level_up_data 调用。
static func _build_skill_level_up_description(skill_name: String, next_level: int) -> String:
	return "提升 %s 至 Lv%d。" % [skill_name, next_level]


## 作用：优先取升级首条等级说明，否则使用通用 description。
## 使用：由本文件 build_upgrade_data 调用。
static func _get_level_up_upgrade_description(upgrade: Dictionary) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if not descriptions.is_empty():
		return _string_or(descriptions[0], "")
	return _string_or(upgrade.get("description", ""), "")


## 作用：按升级标签优先顺序生成影响伤害来源或生存移动的展示文字。
## 使用：由本文件 build_upgrade_data 调用。
static func _infer_affected_origin(upgrade: Dictionary) -> String:
	var tags: Array = _get_array(upgrade.get("tags", []))
	if tags.has("dot"):
		return "DOT"
	if tags.has("reaction"):
		return "反应"
	if tags.has("trap"):
		return "陷阱"
	if tags.has("field") or tags.has("area"):
		return "领域 / 范围"
	if tags.has("boss"):
		return "精英 / Boss"
	if tags.has("survival"):
		return "生存"
	if tags.has("mobility"):
		return "移动"
	return "通用属性"


## 作用：按升级标签生成未覆盖的伤害来源说明，供卡片解释效果边界。
## 使用：由本文件 build_upgrade_data 调用。
static func _infer_does_not_affect(upgrade: Dictionary) -> String:
	var tags: Array = _get_array(upgrade.get("tags", []))
	if tags.has("dot"):
		return "不直接提高命中伤害、陷阱伤害或反应触发次数。"
	if tags.has("reaction"):
		return "不直接提高 DOT tick、普通命中伤害或状态施加频率。"
	if tags.has("boss"):
		return "不影响普通怪清场效率，除非描述中另有说明。"
	if tags.has("survival"):
		return "不直接提高伤害输出或资源收益。"
	if tags.has("trap"):
		return "不直接提高非陷阱类技能、DOT 或反应伤害。"
	return "不影响未在标签和效果中列出的伤害来源。"


## 作用：优先取当前升级等级对应说明，越界时回退首条或通用说明。
## 使用：由本文件 build_debug_data 调用。
static func _get_debug_upgrade_description(upgrade: Dictionary, current_level: int) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if current_level >= 0 and current_level < descriptions.size():
		return _string_or(descriptions[current_level], "")
	if not descriptions.is_empty():
		return _string_or(descriptions[0], "")
	return _string_or(upgrade.get("description", ""), "")


## 作用：先查主配置两种卡面字段，再查备用配置，均缺失返回空路径。
## 使用：fallback 为缺值备用结果。
static func _get_option_background_texture(primary: Dictionary, fallback: Dictionary = {}) -> String:
	for key: String in ["background_texture", "card_background_texture"]:
		var value: String = _string_or(primary.get(key, ""), "")
		if value != "":
			return value

	for key: String in ["background_texture", "card_background_texture"]:
		var value: String = _string_or(fallback.get(key, ""), "")
		if value != "":
			return value

	return ""


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 build_upgrade_data/build_debug_data 调用；无匹配项时返回空数组。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
