## 文件用途：维护伤害元素、来源和敌人等级对应的属性快照键。
## 使用方式：伤害计算按 element_bonus_key、origin_bonus_keys 与 enemy_type_bonus_key 取对应加成；未匹配返回空值。
extends RefCounted
class_name ModifierKeyRegistry


## 作用：为非空元素生成对应的伤害倍率加成键。
## 使用：伤害计算按 element_bonus_key、origin_bonus_keys 与 enemy_type_bonus_key 取对应加成；未匹配返回空值。
static func element_bonus_key(element: Variant) -> String:
	var text: String = String(element)
	return "%s_damage_multiplier_add" % text if text != "" else ""


## 作用：按伤害来源返回所需倍率与初始技能加成键，未知来源无加成键。
## 使用：origin 为世界位置或伤害来源；无匹配项时返回空数组。
static func origin_bonus_keys(origin: Variant) -> Array[String]:
	match String(origin):
		"primary_attack":
			return ["primary_attack_damage_multiplier_add", "direct_damage_multiplier_add", "starting_skill_damage_add"]
		"status_dot":
			return ["dot_damage_multiplier_add"]
		"reaction":
			return ["reaction_damage_multiplier_add"]
		"field":
			return ["field_damage_multiplier_add", "area_damage_multiplier_add"]
		"trap":
			return ["trap_damage_multiplier_add"]
	return []


## 作用：返回 Boss 或精英伤害倍率键，普通目标返回空字符串。
## 使用：伤害计算按 element_bonus_key、origin_bonus_keys 与 enemy_type_bonus_key 取对应加成；未匹配返回空值。
static func enemy_type_bonus_key(target_class: Variant) -> String:
	if String(target_class) == "boss":
		return "boss_damage_multiplier_add"
	if String(target_class) == "elite":
		return "elite_damage_multiplier_add"
	return ""
