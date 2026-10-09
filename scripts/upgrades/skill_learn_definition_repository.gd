## 文件用途：过滤可学习技能并按稳定前缀生成或解析动态学习升级定义。
## 使用方式：普通升级直接查询 GameData；learn_skill_ ID 会从技能定义重建一阶学习升级，用于选项应用与结算查询。
extends RefCounted
class_name SkillLearnDefinitionRepository


## 作用：从技能池排除初始技能及无学习供给入口的定义，保留配置顺序并深拷贝。
## 使用：普通升级直接查询 GameData；learn_skill_ ID 会从技能定义重建一阶学习升级，用于选项应用与结算查询。
static func get_skill_learn_definitions(skill_pool: Array, offer_rule_key: String = "offer_rule") -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	for skill: Dictionary in skill_pool:
		var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
		if skill_id == &"":
			continue
		if bool(skill.get("is_starting_skill", false)):
			continue
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get(offer_rule_key, {})).is_empty():
			continue
		skills.append(skill.duplicate(true))
	return skills


## 作用：生成带神系与 skill 标签的一阶学习升级，并按传入前缀构造稳定 ID。
## 使用：skill 为技能实例或定义；god_id 为筛选神系 ID；无适用数据时返回空字典。
static func make_god_skill_learn_upgrade(skill: Dictionary, god_id: StringName, upgrade_prefix: String) -> Dictionary:
	var skill_id: String = _string_or(skill.get("id", ""), "")
	if skill_id == "":
		return {}
	var tags: Array[String] = to_string_array(_get_array(skill.get("tags", [])))
	if not tags.has("skill"):
		tags.push_front("skill")
	var god_text: String = _string_or(god_id, "")
	if god_text != "" and not tags.has(god_text):
		tags.push_front(god_text)
	var description: String = _string_or(skill.get("description", "Learn %s." % skill_id), "Learn %s." % skill_id)
	return {
		"id": "%s%s" % [upgrade_prefix, skill_id],
		"display_name": _string_or(skill.get("display_name", skill_id), skill_id),
		"description": description,
		"rarity": _string_or(skill.get("rarity", "common"), "common"),
		"tags": tags,
		"enabled": true,
		"max_level": 1,
		"learn_skill_id": StringName(skill_id),
		"school": god_id,
		"level_descriptions": [description]
	}


## 作用：判断有效技能的 school 或 fusion_school 是否匹配调试神系。
## 使用：skill 为技能实例或定义；god_id 为筛选神系 ID；返回布尔判断或执行是否成功。
static func is_debug_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	if skill.is_empty():
		return false
	if StringName(_string_or(skill.get("id", ""), "")) == &"":
		return false
	if StringName(_string_or(skill.get("school", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("fusion_school", ""), "")) == god_id:
		return true
	return false


## 作用：按输入数组顺序转换元素为字符串，返回独立的强类型数组。
## 使用：由本文件 make_god_skill_learn_upgrade 调用。
static func to_string_array(value: Array) -> Array[String]:
	var strings: Array[String] = []
	for item: Variant in value:
		strings.append(_string_or(item, ""))
	return strings


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 make_god_skill_learn_upgrade 调用；无匹配项时返回空数组。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 get_skill_learn_definitions/resolve_upgrade 调用；无适用数据时返回空字典。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)


## 作用：解析普通升级或 learn_skill_ 动态学习升级，过滤初始技能和无供给规则技能。
## 使用：普通升级直接查询 GameData；learn_skill_ ID 会从技能定义重建一阶学习升级，用于选项应用与结算查询；无适用数据时返回空字典。
static func resolve_upgrade(upgrade_id: StringName) -> Dictionary:
	var text: String = String(upgrade_id)
	if not text.begins_with("learn_skill_"):
		return GameData.get_upgrade(upgrade_id)
	var skill: Dictionary = GameData.get_skill(StringName(text.substr("learn_skill_".length())))
	if skill.is_empty() or bool(skill.get("is_starting_skill", false)) or _get_dictionary(skill.get("offer_rule", {})).is_empty():
		return {}
	return make_god_skill_learn_upgrade(skill, StringName(skill.get("school", "")), "learn_skill_")
