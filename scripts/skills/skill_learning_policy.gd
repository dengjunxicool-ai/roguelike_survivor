## 文件用途：集中判定角色学习限制、神系数量限制与融合定义归属。
## 使用方式：SkillManager 与供给策略传角色数据、已学神系列表和上限，返回准入判断，不直接修改技能池。
extends RefCounted
class_name SkillLearningPolicy

const GOD_SCHOOLS: Array[StringName] = [&"fire", &"frost", &"thunder", &"curse", &"holy", &"chaos"]

## 作用：池内可学习技能、初始技能或未指定角色直接准入，其余要求匹配角色初始技能。
## 使用：character_id 为角色 ID。
static func can_current_character_learn(skill_data: Dictionary, character_id: StringName, character: Dictionary) -> bool:
	if is_pool_learnable_skill(skill_data) or bool(skill_data.get("is_starting_skill", false)) or character_id == &"":
		return true
	return StringName(String(character.get("starting_skill_id", ""))) == StringName(String(skill_data.get("id", "")))


## 作用：融合技能要求已学神系达到上限；普通技能允许已有神系或尚有新神系容量。
## 使用：SkillManager 与供给策略传角色数据、已学神系列表和上限，返回准入判断，不直接修改技能池。
static func can_learn_god_school(skill_data: Dictionary, learned_schools: Array[StringName], maximum_schools: int) -> bool:
	if is_fusion_definition(skill_data):
		return learned_schools.size() >= maximum_schools
	var school: StringName = definition_primary_god_school(skill_data)
	return school == &"" or learned_schools.has(school) or learned_schools.size() < maximum_schools


## 作用：检查 learnable_from_pool、offer_in_upgrade_pool 或非空 offer_rule 是否声明学习供给。
## 使用：由本文件 can_current_character_learn 调用。
static func is_pool_learnable_skill(skill_data: Dictionary) -> bool:
	return (
		bool(skill_data.get("learnable_from_pool", false))
		or bool(skill_data.get("offer_in_upgrade_pool", false))
		or not _get_dictionary(skill_data.get("offer_rule", {})).is_empty()
	)


## 作用：依据标准 skill_type 判断 fusion 定义。
## 使用：由本文件 can_learn_god_school/definition_primary_god_school 调用。
static func is_fusion_definition(skill_data: Dictionary) -> bool:
	return _string_or(skill_data.get("skill_type", ""), "") == "fusion"


## 作用：排除融合后读取实例或定义的已知神系，未知神系返回空 ID。
## 使用：skill_instance 为技能运行实例。
static func instance_primary_god_school(skill_instance: RefCounted) -> StringName:
	if skill_instance == null:
		return &""
	if _string_or(skill_instance.get("skill_type"), "") == "fusion":
		return &""
	var school: StringName = StringName(_string_or(skill_instance.get("school"), ""))
	if GOD_SCHOOLS.has(school):
		return school
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return &""
	school = StringName(_string_or(definition.get("school"), ""))
	return school if GOD_SCHOOLS.has(school) else &""


## 作用：排除融合后读取配置的已知主要神系。
## 使用：由本文件 can_learn_god_school 调用。
static func definition_primary_god_school(skill_data: Dictionary) -> StringName:
	if is_fusion_definition(skill_data):
		return &""
	var school: StringName = StringName(_string_or(skill_data.get("school", ""), ""))
	if GOD_SCHOOLS.has(school):
		return school
	return &""


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 is_pool_learnable_skill 调用；无适用数据时返回空字典。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else String(value)
