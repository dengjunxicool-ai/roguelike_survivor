## 文件用途：依据槽位、神系、互斥组、学习历史和 offer_rule 判定技能能否出现。
## 使用方式：升级池调用 is_skill_available，传玩家和技能定义；该服务只筛选，不学习技能或消费随机数。
extends RefCounted
class_name SkillOfferService


const KNOWN_EXCLUSIVE_GROUPS: Array[String] = [
	"attack_school",
	"dash_school",
	"core_school"
]
const MAX_LEARNED_GOD_SCHOOLS: int = 2
const GOD_SCHOOLS: Array[StringName] = [&"fire", &"frost", &"thunder", &"curse", &"holy", &"chaos"]


## 作用：依次校验 ID、学习历史、容量、互斥组、融合和神系限制，再检查 offer_rule。
## 使用：player 为玩家节点；skill 为技能实例或定义；返回布尔判断或执行是否成功。
func is_skill_available(player: Node, skill: Dictionary, allow_replacement: bool = true) -> bool:
	var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
	if skill_id == &"":
		return false
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager == null:
		return false
	if _has_learned(skill_manager, skill_id):
		return false
	if _is_blocked_by_capacity(skill_manager, skill):
		if not allow_replacement or not preload("res://scripts/skills/skill_slot_policy.gd").counts_active_capacity(skill) or bool(player.get_meta("ordinary_replacement_used", false)): return false
		var limit: int = int(skill_manager.get("max_active_skills"))
		skill_manager.set("max_active_skills", limit + 1)
		var eligible: bool = is_skill_available(player, skill, false)
		skill_manager.set("max_active_skills", limit)
		return eligible
	if _is_blocked_by_exclusive_group(skill_manager, skill):
		return false
	if _get_skill_type(skill) == "fusion":
		if _learned_god_school_count(skill_manager) < MAX_LEARNED_GOD_SCHOOLS:
			return false
		if _has_any_fusion(skill_manager):
			return false
	elif _would_exceed_god_school_limit(skill_manager, skill):
		return false
	return _offer_rule_met(skill_manager, skill, _get_dictionary(skill.get("offer_rule", {})))


## 作用：根据 slot_category 查询被动容量或计数主动容量是否已满。
## 使用：skill_manager 为技能管理器；skill 为技能实例或定义；返回布尔判断或执行是否成功。
func _is_blocked_by_capacity(skill_manager: Node, skill: Dictionary) -> bool:
	var category: String = _get_skill_category(skill)
	if category == "passive":
		return skill_manager.has_method("is_passive_skill_full") and bool(skill_manager.call("is_passive_skill_full"))
	if category == "active" and preload("res://scripts/skills/skill_slot_policy.gd").counts_active_capacity(skill):
		return skill_manager.has_method("is_active_skill_full") and bool(skill_manager.call("is_active_skill_full"))
	return false


## 作用：排除初始技能、攻击冲刺互斥组和 attack/dash 类型后判定主动容量占用。
## 使用：skill 为技能实例或定义。
func _is_capacity_counted_active_skill(skill: Dictionary) -> bool:
	var skill_type: String = _get_skill_type(skill)
	return (
		not bool(skill.get("is_starting_skill", false))
		and _string_or(skill.get("exclusive_group", ""), "") != "attack_school"
		and _string_or(skill.get("exclusive_group", ""), "") != "dash_school"
		and skill_type != "attack"
		and skill_type != "dash"
	)


## 作用：检查必需神系、技能和神系技能数量，非融合可尝试开启首个所需神系。
## 使用：skill_manager 为技能管理器；skill 为技能实例或定义；返回布尔判断或执行是否成功。
func _offer_rule_met(skill_manager: Node, skill: Dictionary, offer_rule: Dictionary) -> bool:
	var required_schools: Array = _get_array(offer_rule.get("required_schools", []))
	for school_variant: Variant in required_schools:
		var required_school: StringName = StringName(_string_or(school_variant, ""))
		if _count_school(skill_manager, required_school) <= 0 and not _can_open_required_school(skill_manager, skill, required_school, required_schools):
			return false
	for skill_variant: Variant in _get_array(offer_rule.get("required_skills", [])):
		if not _has_learned(skill_manager, StringName(_string_or(skill_variant, ""))):
			return false
	if _get_skill_type(skill) != "fusion":
		var min_counts: Dictionary = _get_dictionary(offer_rule.get("required_min_skill_count", {}))
		for school_variant: Variant in min_counts.keys():
			if _count_school(skill_manager, StringName(_string_or(school_variant, ""))) < int(min_counts[school_variant]):
				return false
	return true


## 作用：单一神系普通技能在神系容量允许且归属匹配时可开启新神系。
## 使用：skill_manager 为技能管理器；skill 为技能实例或定义；返回布尔判断或执行是否成功。
func _can_open_required_school(skill_manager: Node, skill: Dictionary, required_school: StringName, required_schools: Array) -> bool:
	if required_school == &"" or required_schools.size() != 1:
		return false
	if _get_skill_type(skill) == "fusion":
		return false
	if _get_skill_primary_god_school(skill) != required_school:
		return false
	var learned_schools: Array[StringName] = _learned_god_schools(skill_manager)
	return learned_schools.has(required_school) or learned_schools.size() < MAX_LEARNED_GOD_SCHOOLS


## 作用：合并规则 blocked_by_exclusive_group 与自身互斥组，并检查已有技能冲突。
## 使用：skill_manager 为技能管理器；skill 为技能实例或定义；返回布尔判断或执行是否成功。
func _is_blocked_by_exclusive_group(skill_manager: Node, skill: Dictionary) -> bool:
	var blocked_groups: Array = _get_array(_get_dictionary(skill.get("offer_rule", {})).get("blocked_by_exclusive_group", []))
	var own_group: String = _string_or(skill.get("exclusive_group", ""), "")
	if own_group != "" or KNOWN_EXCLUSIVE_GROUPS.has(own_group):
		blocked_groups.append(own_group)
	for group_variant: Variant in blocked_groups:
		if _has_exclusive_group(skill_manager, _string_or(group_variant, "")):
			return true
	return false


## 作用：遍历持有技能，判断是否已占指定互斥组。
## 使用：skill_manager 为技能管理器；返回布尔判断或执行是否成功。
func _has_exclusive_group(skill_manager: Node, group: String) -> bool:
	if group == "":
		return false
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance != null and _string_or(skill_instance.get("exclusive_group"), "") == group:
			return true
	return false


## 作用：判断持有技能中是否已有 fusion，阻止重复供给融合。
## 使用：skill_manager 为技能管理器；返回布尔判断或执行是否成功。
func _has_any_fusion(skill_manager: Node) -> bool:
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance != null and _string_or(skill_instance.get("skill_type"), "") == "fusion":
			return true
	return false


## 作用：统计实例、定义、标签或元素归属包含指定神系的技能数量。
## 使用：skill_manager 为技能管理器。
func _count_school(skill_manager: Node, school: StringName) -> int:
	if school == &"":
		return 0
	var count: int = 0
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance == null:
			continue
		if _skill_instance_has_school(skill_instance, school):
			count += 1
	return count


## 作用：判断新增主要神系是否突破最多两神系限制。
## 使用：skill_manager 为技能管理器；skill 为技能实例或定义；返回布尔判断或执行是否成功。
func _would_exceed_god_school_limit(skill_manager: Node, skill: Dictionary) -> bool:
	var school: StringName = _get_skill_primary_god_school(skill)
	if school == &"":
		return false
	var learned_schools: Array[StringName] = _learned_god_schools(skill_manager)
	return not learned_schools.has(school) and learned_schools.size() >= MAX_LEARNED_GOD_SCHOOLS


## 作用：返回去重后的主要神系数量。
## 使用：skill_manager 为技能管理器。
func _learned_god_school_count(skill_manager: Node) -> int:
	return _learned_god_schools(skill_manager).size()


## 作用：优先读取管理器神系列表并去重，缺入口时从持有实例推导。
## 使用：skill_manager 为技能管理器。
func _learned_god_schools(skill_manager: Node) -> Array[StringName]:
	if skill_manager != null and skill_manager.has_method("get_learned_god_schools"):
		var value: Variant = skill_manager.call("get_learned_god_schools")
		if value is Array:
			var schools: Array[StringName] = []
			for school_variant: Variant in value:
				var school: StringName = StringName(_string_or(school_variant, ""))
				if school != &"" and not schools.has(school):
					schools.append(school)
			return schools
	var schools: Array[StringName] = []
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		var school: StringName = _skill_instance_primary_god_school(skill_instance)
		if school != &"" and not schools.has(school):
			schools.append(school)
	return schools


## 作用：检查实例及定义的主神系、融合神系、标签和基础元素归属。
## 使用：skill_instance 为技能运行实例；返回布尔判断或执行是否成功。
func _skill_instance_has_school(skill_instance: RefCounted, school: StringName) -> bool:
	if StringName(_string_or(skill_instance.get("school"), "")) == school:
		return true
	if StringName(_string_or(skill_instance.get("fusion_school"), "")) == school:
		return true

	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return false
	if StringName(_string_or(definition.get("school"), "")) == school:
		return true
	if StringName(_string_or(definition.get("fusion_school"), "")) == school:
		return true

	var tags: Array = _get_array(definition.get("tags"))
	if tags.has(_string_or(school, "")):
		return true

	var base: Dictionary = _get_dictionary(definition.get("base"))
	return StringName(_string_or(base.get("element", ""), "")) == school


## 作用：排除融合后优先使用实例主神系，再从定义查询。
## 使用：skill_instance 为技能运行实例。
func _skill_instance_primary_god_school(skill_instance: RefCounted) -> StringName:
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


## 作用：只保留已知神系列表内的配置 school。
## 使用：skill 为技能实例或定义。
func _get_skill_primary_god_school(skill: Dictionary) -> StringName:
	var school: StringName = StringName(_string_or(skill.get("school", ""), ""))
	return school if GOD_SCHOOLS.has(school) else &""


## 作用：检查技能当前持有状态或本局学习历史。
## 使用：skill_manager 为技能管理器；skill_id 为标准技能 ID；返回布尔判断或执行是否成功。
func _has_learned(skill_manager: Node, skill_id: StringName) -> bool:
	if skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", skill_id)):
		return true
	if skill_manager.has_method("has_learned_skill") and bool(skill_manager.call("has_learned_skill", skill_id)):
		return true
	return false


## 作用：通过管理器公开方法取得持有主动与被动技能列表。
## 使用：skill_manager 为技能管理器；无匹配项时返回空数组。
func _get_all_skills(skill_manager: Node) -> Array:
	if skill_manager != null and skill_manager.has_method("get_all_skills"):
		var value: Variant = skill_manager.call("get_all_skills")
		if value is Array:
			return value
	return []


## 作用：先查玩家 SkillManager 子节点，再尝试玩家公开 getter。
## 使用：player 为玩家节点；无法解析或创建时返回 null。
func _get_skill_manager(player: Node) -> Node:
	if player == null:
		return null
	var manager: Node = player.get_node_or_null("SkillManager")
	if manager != null:
		return manager
	if player.has_method("get_skill_manager"):
		var value: Variant = player.call("get_skill_manager")
		if value is Node:
			return value
	return null


## 作用：读取标准技能配置 skill_type 字符串。
## 使用：skill 为技能实例或定义。
func _get_skill_type(skill: Dictionary) -> String:
	return _string_or(skill.get("skill_type", ""), "")


## 作用：读取标准技能配置 slot_category 字符串。
## 使用：skill 为技能实例或定义。
func _get_skill_category(skill: Dictionary) -> String:
	return _string_or(skill.get("slot_category", ""), "")


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 _offer_rule_met/_is_blocked_by_exclusive_group 调用。
func _get_array(value: Variant) -> Array:
	return value if value is Array else []


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 is_skill_available/_offer_rule_met 调用。
func _get_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else String(value)
