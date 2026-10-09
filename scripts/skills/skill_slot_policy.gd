## 文件用途：集中判定技能槽位分类、初始攻击、攻击替换、冲刺替换及主动容量占用。
## 使用方式：SkillManager 和学习策略传入标准技能字典；攻击和冲刺不计普通主动槽容量。
extends RefCounted
class_name SkillSlotPolicy


## 作用：读取技能定义 slot_category，缺字段返回空字符串。
## 使用：definition 为技能定义。
static func category(definition: Dictionary) -> String:
	return String(definition.get("slot_category", ""))


## 作用：依据配置 is_starting_skill 判断角色初始攻击。
## 使用：definition 为技能定义。
static func is_starting_attack(definition: Dictionary) -> bool:
	return bool(definition.get("is_starting_skill", false))


## 作用：判断初始攻击或 skill_type 为 attack 的攻击槽定义。
## 使用：definition 为技能定义。
static func is_attack(definition: Dictionary) -> bool:
	return is_starting_attack(definition) or String(definition.get("skill_type", "")) == "attack"


## 作用：判断 skill_type 是否为 dash。
## 使用：definition 为技能定义。
static func is_dash(definition: Dictionary) -> bool:
	return String(definition.get("skill_type", "")) == "dash"


## 作用：排除攻击和冲刺槽，判断是否占普通主动技能容量。
## 使用：definition 为技能定义。
static func counts_active_capacity(definition: Dictionary) -> bool:
	return not is_attack(definition) and not is_dash(definition)
