## 文件用途：维护主动与被动技能、主攻击方法、学习历史、槽位、替换继承和属性来源。
## 使用方式：挂在玩家下；初始攻击使用 set_primary_attack_method，普通学习使用 add_skill，升级成功后刷新属性并发信号。
extends Node
class_name SkillManager


const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const SkillSlotPolicyScript: Script = preload("res://scripts/skills/skill_slot_policy.gd")
const RuntimeDefinitionResolverScript: Script = preload("res://scripts/skills/skill_runtime_definition_resolver.gd")
const SkillLearningPolicyScript: Script = preload("res://scripts/skills/skill_learning_policy.gd")
const MAX_LEARNED_GOD_SCHOOLS: int = 2

signal skill_added(skill_id: StringName)
signal skill_upgraded(skill_id: StringName, new_level: int)
signal skill_changed

@export_range(1, 20, 1, "or_greater") var max_active_skills: int = 5
@export_range(1, 20, 1, "or_greater") var max_passive_skills: int = 3

var active_skills: Dictionary = {}
var passive_skills: Dictionary = {}
var learned_skill_ids: Dictionary = {}
var _learned_god_school_ids: Array[StringName] = []
var run_generation: int = 0
var passive_modifiers: Array = []
var _skill_effect_modifier_source_ids: Array[String] = []
var _primary_attack_method: RefCounted = null


## 作用：检查学习、槽位和神系限制，完成攻击继承与替换，再登记技能、属性及信号。
## 使用：skill_id 为标准技能 ID；rarity 为目标稀有度；会发出对应变更信号；返回布尔判断或执行是否成功。
func add_skill(skill_id: Variant, rarity: String = "") -> bool:
	var id: StringName = _to_skill_id(skill_id)
	if id == &"" or has_skill(id):
		return false

	var definition_data: Dictionary = _get_skill_definition_data(id)
	if definition_data.is_empty():
		return false
	if not preload("res://scripts/skills/skill_requirement_policy.gd").new().evaluate(get_parent(), definition_data).available:
		return false
	if _is_starting_attack_method_definition(definition_data):
		return false
	var category: String = _category_from_skill_type(definition_data)
	if category != "active" and category != "passive":
		return false
	if not _can_current_character_learn(definition_data):
		return false
	if not _can_learn_god_school_definition(definition_data):
		return false
	var capacity: StringName = SkillSlotPolicyScript.capacity_group(definition_data)
	if capacity in [&"core", &"fusion"]:
		for owned: RefCounted in get_all_skills():
			if StringName(String(owned.skill_type)) == capacity: return false
	var replaced_active_skill_id: StringName = &""
	if category == "active":
		replaced_active_skill_id = _find_replaced_active_skill_id(id, definition_data)
		if _is_attack_replacement_definition(definition_data):
			definition_data = _with_inherited_attack_runtime(definition_data, replaced_active_skill_id)
		if replaced_active_skill_id == &"" and _is_capacity_counted_active_definition(definition_data) and is_active_skill_full():
			return false
	elif category == "passive" and is_passive_skill_full():
		return false

	var definition: RefCounted = SkillDefinitionScript.new(definition_data)
	var skill_instance: RefCounted = SkillInstanceScript.new(definition)
	if rarity != "":
		skill_instance.set("current_rarity", rarity)
	if replaced_active_skill_id != &"":
		_remove_active_skill(replaced_active_skill_id)
		if _get_primary_attack_id() == replaced_active_skill_id:
			_clear_primary_attack_method()

	if category == "passive":
		passive_skills[id] = skill_instance
	else:
		active_skills[id] = skill_instance
	_refresh_skill_modifier_payload(skill_instance)
	learned_skill_ids[id] = true
	var school_id: StringName = _get_skill_instance_primary_god_school(skill_instance)
	if school_id != &"" and not _learned_god_school_ids.has(school_id): _learned_god_school_ids.append(school_id)
	skill_added.emit(id)
	skill_changed.emit()
	return true


## 作用：查询当前主动或被动集合是否持有技能，不含独立主攻击对象。
## 使用：skill_id 为标准技能 ID。
func has_skill(skill_id: Variant) -> bool:
	var id: StringName = _to_skill_id(skill_id)
	return active_skills.has(id) or passive_skills.has(id)


## 作用：查询本局学习历史，已被替换技能仍可保留学习记录。
## 使用：skill_id 为标准技能 ID。
func has_learned_skill(skill_id: Variant) -> bool:
	return learned_skill_ids.has(_to_skill_id(skill_id))


## 作用：把非空技能 ID 记入本局学习历史。
## 使用：skill_id 为标准技能 ID。
func mark_skill_learned(skill_id: Variant) -> void:
	var id: StringName = _to_skill_id(skill_id)
	if id != &"":
		learned_skill_ids[id] = true


## 作用：按 ID 返回已持有主动或被动实例，未找到返回 null。
## 使用：skill_id 为标准技能 ID；无法解析或创建时返回 null。
func get_skill(skill_id: Variant) -> RefCounted:
	var id: StringName = _to_skill_id(skill_id)
	if active_skills.has(id):
		return active_skills[id] as RefCounted
	if passive_skills.has(id):
		return passive_skills[id] as RefCounted

	return null


## 作用：从合法攻击定义创建独立主攻击实例，设置可选稀有度并发变更信号。
## 使用：skill_id 为标准技能 ID；rarity 为目标稀有度；会发出对应变更信号；返回布尔判断或执行是否成功。
func set_primary_attack_method(skill_id: Variant, rarity: String = "") -> bool:
	var id: StringName = _to_skill_id(skill_id)
	if id == &"":
		return false
	var definition_data: Dictionary = _get_skill_definition_data(id)
	if definition_data.is_empty() or not _is_attack_method_definition(definition_data):
		return false
	var definition: RefCounted = SkillDefinitionScript.new(definition_data)
	var skill_instance: RefCounted = SkillInstanceScript.new(definition)
	if rarity != "":
		skill_instance.set("current_rarity", rarity)
	_primary_attack_method = skill_instance
	skill_changed.emit()
	return true


## 作用：返回独立主攻击实例引用。
## 使用：挂在玩家下；初始攻击使用 set_primary_attack_method，普通学习使用 add_skill，升级成功后刷新属性并发信号。
func get_primary_attack_method() -> RefCounted:
	return _primary_attack_method


## 作用：返回当前独立主攻击技能 ID。
## 使用：挂在玩家下；初始攻击使用 set_primary_attack_method，普通学习使用 add_skill，升级成功后刷新属性并发信号。
func get_primary_attack_id() -> StringName:
	return _get_primary_attack_id()


## 作用：遍历已拥有技能去重收集主要神系，不将融合定义计为新神系。
## 使用：由本文件 get_learned_god_school_count/_can_learn_god_school_definition 调用。
func get_learned_god_schools() -> Array[StringName]:
	var schools: Array[StringName] = _learned_god_school_ids.duplicate()
	for skill_instance: RefCounted in get_all_skills():
		var school: StringName = _get_skill_instance_primary_god_school(skill_instance)
		if school != &"" and not schools.has(school):
			schools.append(school)
	return schools


## 作用：返回当前持有技能涉及的主要神系数量。
## 使用：挂在玩家下；初始攻击使用 set_primary_attack_method，普通学习使用 add_skill，升级成功后刷新属性并发信号。
func get_learned_god_school_count() -> int:
	return get_learned_god_schools().size()


## 作用：优先显式 replaces_skill，其次主攻击或同攻击冲刺槽技能，确定替换目标。
## 使用：由本文件 add_skill 调用。
func _find_replaced_active_skill_id(new_skill_id: StringName, definition_data: Dictionary) -> StringName:
	if not _is_active_slot_replacement_definition(definition_data):
		return &""
	var explicit_id: StringName = _to_skill_id(definition_data.get("replaces_skill", ""))
	if explicit_id != &"" and explicit_id != new_skill_id and active_skills.has(explicit_id):
		return explicit_id
	if _is_attack_replacement_definition(definition_data) and _get_primary_attack_id() != &"":
		return _get_primary_attack_id()
	for active_id_variant: Variant in active_skills.keys():
		var active_id: StringName = _to_skill_id(active_id_variant)
		if active_id == new_skill_id:
			continue
		if _is_attack_replacement_definition(definition_data) and _is_active_attack_slot_skill(active_id):
			return active_id
		if _is_dash_replacement_definition(definition_data) and _is_active_dash_slot_skill(active_id):
			return active_id
	return &""


## 作用：判断新定义是否替换攻击槽或冲刺槽。
## 使用：由本文件 _find_replaced_active_skill_id 调用。
func _is_active_slot_replacement_definition(definition_data: Dictionary) -> bool:
	return _is_attack_replacement_definition(definition_data) or _is_dash_replacement_definition(definition_data)


## 作用：委托槽位策略判断攻击替换定义。
## 使用：由本文件 add_skill/_find_replaced_active_skill_id 调用。
func _is_attack_replacement_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.is_attack(definition_data)


## 作用：委托槽位策略判断可用作主攻击的定义。
## 使用：由本文件 set_primary_attack_method 调用。
func _is_attack_method_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.is_attack(definition_data)


## 作用：依据 is_starting_skill 判定初始攻击定义。
## 使用：由本文件 add_skill 调用。
func _is_starting_attack_method_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.is_starting_attack(definition_data)


## 作用：按 skill_type 判定冲刺替换定义。
## 使用：由本文件 _find_replaced_active_skill_id/_is_active_slot_replacement_definition 调用。
func _is_dash_replacement_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.is_dash(definition_data)


## 作用：结合实例互斥组、类型和配置标记判定已有技能是否占攻击槽。
## 使用：skill_id 为标准技能 ID。
func _is_active_attack_slot_skill(skill_id: StringName) -> bool:
	var skill_instance: RefCounted = active_skills.get(skill_id, null) as RefCounted
	if skill_instance != null:
		if _string_or(skill_instance.get("exclusive_group"), "") == "attack_school":
			return true
		if _string_or(skill_instance.get("skill_type"), "") == "attack":
			return true
	var definition_data: Dictionary = _get_skill_definition_data(skill_id)
	return bool(definition_data.get("is_starting_skill", false)) or _is_attack_replacement_definition(definition_data)


## 作用：结合实例互斥组、类型与定义判定已有技能是否占冲刺槽。
## 使用：skill_id 为标准技能 ID。
func _is_active_dash_slot_skill(skill_id: StringName) -> bool:
	var skill_instance: RefCounted = active_skills.get(skill_id, null) as RefCounted
	if skill_instance != null:
		if _string_or(skill_instance.get("exclusive_group"), "") == "dash_school":
			return true
		if _string_or(skill_instance.get("skill_type"), "") == "dash":
			return true
	var definition_data: Dictionary = _get_skill_definition_data(skill_id)
	return _is_dash_replacement_definition(definition_data)


## 作用：委托槽位策略判断技能是否计普通主动槽容量。
## 使用：由本文件 add_skill/_count_capacity_active_skills 调用。
func _is_capacity_counted_active_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.counts_active_capacity(definition_data)


## 作用：选择被替换攻击或初始攻击定义，为新攻击补齐缺失运行字段。
## 使用：由本文件 add_skill 调用。
func _with_inherited_attack_runtime(definition_data: Dictionary, replaced_active_skill_id: StringName) -> Dictionary:
	var source: Dictionary = _get_skill_definition_data(replaced_active_skill_id) if replaced_active_skill_id != &"" else {}
	if source.is_empty():
		source = _get_primary_starting_skill_data()
	return RuntimeDefinitionResolverScript.inherit_attack(definition_data, source)


## 作用：返回配置初始技能池首项供攻击继承使用。
## 使用：由本文件 _with_inherited_attack_runtime 调用；无适用数据时返回空字典。
func _get_primary_starting_skill_data() -> Dictionary:
	for skill: Dictionary in GameData.get_starting_skill_pool():
		return skill
	return {}


## 作用：移除主动技能并清理其效果来源与被动属性贡献。
## 使用：skill_id 为标准技能 ID。
func _remove_active_skill(skill_id: StringName) -> void:
	if skill_id == &"":
		return
	_clear_temporary_skill_sources(skill_id)
	active_skills.erase(skill_id)
	_remove_skill_effect_modifier_source(skill_id)
	_remove_passive_modifiers_for_skill(skill_id)


## 作用：逆序删除带指定 source_skill_id 的被动效果条目。
## 使用：skill_id 为标准技能 ID。
func _remove_passive_modifiers_for_skill(skill_id: StringName) -> void:
	var id_text: String = _string_or(skill_id, "")
	for index: int in range(passive_modifiers.size() - 1, -1, -1):
		var modifier: Variant = passive_modifiers[index]
		if modifier is Dictionary and _string_or((modifier as Dictionary).get("source_skill_id", ""), "") == id_text:
			passive_modifiers.remove_at(index)


## 作用：移除玩家上该技能效果来源并清理来源 ID 记录。
## 使用：skill_id 为标准技能 ID。
func _remove_skill_effect_modifier_source(skill_id: StringName) -> void:
	var source_id: String = "skill:%s:effects" % _string_or(skill_id, "")
	var owner: Node = get_parent()
	if owner != null and owner.has_method("clear_run_modifier_source"):
		owner.call("clear_run_modifier_source", source_id)
	_skill_effect_modifier_source_ids.erase(source_id)

func _clear_temporary_skill_sources(skill_id: StringName) -> void:
	var owner: Node = get_parent()
	var store: Node = owner.get_node_or_null("ModifierStore") if owner != null else null
	if store != null:
		store.call("clear_skill_sources", skill_id)


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else String(value)


## 作用：升级持有实例，更新可选稀有度、刷新属性并发升级及变更信号。
## 使用：skill_id 为标准技能 ID；rarity 为目标稀有度；会发出对应变更信号；返回布尔判断或执行是否成功。
func upgrade_skill(skill_id: Variant, rarity: String = "") -> bool:
	var skill_instance: RefCounted = get_skill(skill_id)
	if skill_instance == null or not skill_instance.level_up():
		return false

	var id: StringName = StringName(skill_instance.get("skill_id"))
	var new_level: int = int(skill_instance.get("current_level"))
	skill_instance.set("current_rarity", SkillGrowthScalingScript.keep_highest_rarity(String(skill_instance.get("current_rarity")), rarity))
	_refresh_skill_modifier_payload(skill_instance)
	skill_upgraded.emit(id, new_level)
	skill_changed.emit()
	return true


## 作用：按主动再被动顺序返回持有实例，不包含独立主攻击。
## 使用：由本文件 get_learned_god_schools 调用。
func get_all_skills() -> Array:
	var skills: Array = []
	skills.append_array(active_skills.values())
	skills.append_array(passive_skills.values())
	return skills


## 作用：返回主攻击在前、普通主动在后的执行列表。
## 使用：挂在玩家下；初始攻击使用 set_primary_attack_method，普通学习使用 add_skill，升级成功后刷新属性并发信号。
func get_active_skills() -> Array:
	var skills: Array = []
	if _primary_attack_method != null:
		skills.append(_primary_attack_method)
	skills.append_array(active_skills.values())
	return skills


## 作用：返回当前被动技能实例列表。
## 使用：挂在玩家下；初始攻击使用 set_primary_attack_method，普通学习使用 add_skill，升级成功后刷新属性并发信号。
func get_passive_skills() -> Array:
	return passive_skills.values()


## 作用：清空主动、被动、学习历史、主攻击和技能效果来源，并发变更信号。
## 使用：会发出对应变更信号。
func clear_skills() -> void:
	var owner: Node = get_parent()
	var store: Node = owner.get_node_or_null("ModifierStore") if owner != null else null
	if store != null:
		store.call("clear_timed_sources")
	var bus: Node = owner.get_node_or_null("SkillEventBus") if owner != null else null
	if bus != null and bus.has_method("reset_run_state"):
		bus.call("reset_run_state")
	if owner != null:
		owner.set_meta("ordinary_replacement_used", false)
		owner.set_meta("core_offer_misses", 0)
		owner.remove_meta("core_offer_level")
		owner.remove_meta("core_offer_due")
	active_skills.clear()
	passive_skills.clear()
	learned_skill_ids.clear()
	_learned_god_school_ids.clear()
	run_generation += 1
	passive_modifiers.clear()
	_primary_attack_method = null
	_clear_skill_effect_modifier_sources()
	skill_changed.emit()


## 作用：比较计容量主动技能数量与导出上限。
## 使用：由本文件 add_skill 调用。
func is_active_skill_full() -> bool:
	return _count_capacity_active_skills() >= max_active_skills


## 作用：比较被动技能数量与导出上限。
## 使用：由本文件 add_skill 调用。
func is_passive_skill_full() -> bool:
	return passive_skills.size() >= max_passive_skills


## 作用：按槽位策略统计会占普通主动容量的已拥有技能。
## 使用：由本文件 is_active_skill_full 调用。
func _count_capacity_active_skills() -> int:
	var count: int = 0
	for active_id_variant: Variant in active_skills.keys():
		var active_id: StringName = _to_skill_id(active_id_variant)
		var definition_data: Dictionary = _get_skill_definition_data(active_id)
		if _is_capacity_counted_active_definition(definition_data):
			count += 1
	return count


## 作用：深拷贝追加效果列表或单个效果字典，并通知技能变更。
## 使用：会发出对应变更信号。
func add_passive_modifier(modifiers: Variant) -> void:
	if modifiers is Array:
		passive_modifiers.append_array((modifiers as Array).duplicate(true))
	elif modifiers is Dictionary:
		passive_modifiers.append((modifiers as Dictionary).duplicate(true))
	skill_changed.emit()


## 作用：先移除旧技能贡献，再重建技能 effects 与被动 skill_modifiers。
## 使用：skill_instance 为技能运行实例。
func _refresh_skill_modifier_payload(skill_instance: RefCounted) -> void:
	if skill_instance == null:
		return
	var skill_id: StringName = StringName(skill_instance.get("skill_id"))
	_remove_skill_effect_modifier_source(skill_id)
	_remove_passive_modifiers_for_skill(skill_id)
	_apply_skill_effect_payload(skill_instance)
	if _string_or(skill_instance.get("skill_type"), "") == "passive":
		_apply_passive_skill_payload(skill_instance)


## 作用：复制被动技能属性效果，标记来源技能并按成长缩放后注册。
## 使用：skill_instance 为技能运行实例。
func _apply_passive_skill_payload(skill_instance: RefCounted) -> void:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted if skill_instance != null else null
	if definition == null:
		return
	var modifiers_variant: Variant = definition.get("skill_modifiers")
	if modifiers_variant is Array and not (modifiers_variant as Array).is_empty():
		var modifiers: Array = (modifiers_variant as Array).duplicate(true)
		for modifier_variant: Variant in modifiers:
			if modifier_variant is Dictionary:
				var modifier: Dictionary = modifier_variant
				modifier["source_skill_id"] = String(skill_instance.get("skill_id"))
				_scale_modifier_source_values(modifier, skill_instance)
		add_passive_modifier(modifiers)


## 作用：筛选技能 effects 中 add_modifier 项，转换和缩放后注册被动效果与玩家来源。
## 使用：skill_instance 为技能运行实例。
func _apply_skill_effect_payload(skill_instance: RefCounted) -> void:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted if skill_instance != null else null
	if definition == null:
		return
	var skill_id: StringName = StringName(skill_instance.get("skill_id"))
	var effects_variant: Variant = definition.get("effects")
	if not (effects_variant is Array):
		return
	var modifiers: Array[Dictionary] = []
	for effect_variant: Variant in effects_variant:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if String(effect.get("type", "")) != "add_modifier":
			continue
		var modifier: Dictionary = _modifier_effect_to_source(effect, skill_instance)
		if not modifier.is_empty():
			modifier["source_skill_id"] = String(skill_id)
			modifiers.append(modifier)
	if not modifiers.is_empty():
		add_passive_modifier(modifiers)
		_set_skill_effect_modifier_source(skill_id, modifiers)


## 作用：删除效果 type，校验 stat/value 并计算成长后的结构化属性效果。
## 使用：skill_instance 为技能运行实例；无适用数据时返回空字典。
func _modifier_effect_to_source(effect: Dictionary, skill_instance: RefCounted) -> Dictionary:
	var source: Dictionary = effect.duplicate(true)
	source.erase("type")
	var stat: String = String(source.get("stat", ""))
	if stat == "" or not source.has("value"):
		return {}
	source["value"] = _scale_modifier_value(stat, source["value"], skill_instance)
	return source


## 作用：对结构化属性效果的 value 应用对应 stat 成长。
## 使用：skill_instance 为技能运行实例；会原地更新 modifier.value。
func _scale_modifier_source_values(modifier: Dictionary, skill_instance: RefCounted) -> void:
	if modifier.has("stat") and modifier.has("value"):
		modifier["value"] = _scale_modifier_value(String(modifier["stat"]), modifier["value"], skill_instance)


## 作用：根据属性类别计算数值成长，并保持原整数或浮点类型。
## 使用：skill_instance 为技能运行实例。
func _scale_modifier_value(key: String, value: Variant, skill_instance: RefCounted) -> Variant:
	if not _is_number(value):
		return value
	# Penalties and explicit cooldown/threshold/healing/shield rules do not grow with rarity.
	if float(value) < 0.0 or key.contains("cooldown") or key.contains("threshold") or key.contains("heal") or key.contains("shield"):
		return value
	var stat_kind: String = _modifier_stat_kind(key, skill_instance)
	var affects_geometry_or_time: bool = not key.contains("damage") and (key.contains("duration") or key.contains("radius") or key.contains("area") or key.contains("range") or key.contains("interval"))
	var scaled: float = float(value) * SkillGrowthScalingScript.stat_multiplier(skill_instance, stat_kind, not affects_geometry_or_time)
	return roundi(scaled) if typeof(value) == TYPE_INT else scaled


## 作用：按属性键中的冷却、范围、时长或伤害语义确定成长类别。
## 使用：skill_instance 为技能运行实例。
func _modifier_stat_kind(key: String, skill_instance: RefCounted) -> String:
	if skill_instance != null and _string_or(skill_instance.get("skill_type"), "") == "passive":
		return "modifier"
	if key.contains("cooldown") or key.contains("interval"):
		return "cooldown"
	if key.contains("radius") or key.contains("area") or key.contains("range"):
		return "radius"
	if key.contains("duration"):
		return "duration"
	if key.contains("damage") or key.contains("attack"):
		return "damage"
	return "damage"


## 作用：向玩家登记技能效果的稳定来源，并记录后续清理所需 ID。
## 使用：skill_id 为标准技能 ID。
func _set_skill_effect_modifier_source(skill_id: StringName, modifiers: Array[Dictionary]) -> void:
	if skill_id == &"" or modifiers.is_empty():
		return
	var owner: Node = get_parent()
	if owner == null or not owner.has_method("set_run_modifier_source"):
		return
	var source_id: String = "skill:%s:effects" % String(skill_id)
	owner.call("set_run_modifier_source", source_id, modifiers)
	if not _skill_effect_modifier_source_ids.has(source_id):
		_skill_effect_modifier_source_ids.append(source_id)


## 作用：逐个移除玩家上的技能效果来源并清空登记表。
## 使用：由本文件 clear_skills 调用。
func _clear_skill_effect_modifier_sources() -> void:
	var owner: Node = get_parent()
	if owner != null and owner.has_method("clear_run_modifier_source"):
		for source_id: String in _skill_effect_modifier_source_ids:
			owner.call("clear_run_modifier_source", source_id)
	_skill_effect_modifier_source_ids.clear()


## 作用：通过 GameData 查询指定技能定义。
## 使用：skill_id 为标准技能 ID。
func _get_skill_definition_data(skill_id: StringName) -> Dictionary:
	return GameData.get_skill(skill_id)


## 作用：解析玩家选中角色后委托角色学习策略检查限制。
## 使用：由本文件 add_skill 调用。
func _can_current_character_learn(skill_data: Dictionary) -> bool:
	var owning_node: Node = get_parent()
	var selected: Variant = owning_node.get("selected_character_id") if owning_node != null else null
	var character_id: StringName = &"" if selected == null else StringName(String(selected))
	var character: Dictionary = GameData.get_character(character_id) if character_id != &"" else {}
	return SkillLearningPolicyScript.can_current_character_learn(skill_data, character_id, character)

## 作用：结合已学神系列表与两神系上限检查新定义准入。
## 使用：由本文件 add_skill 调用。
func _can_learn_god_school_definition(skill_data: Dictionary) -> bool:
	return SkillLearningPolicyScript.can_learn_god_school(skill_data, get_learned_god_schools(), MAX_LEARNED_GOD_SCHOOLS)

## 作用：读取标准技能 slot_category 作为槽位分类。
## 使用：由本文件 add_skill 调用。
func _category_from_skill_type(skill_data: Dictionary) -> String:
	return SkillSlotPolicyScript.category(skill_data)


## 作用：读取独立主攻击实例的技能 ID，缺实例返回空 ID。
## 使用：由本文件 add_skill/get_primary_attack_id 调用。
func _get_primary_attack_id() -> StringName:
	if _primary_attack_method == null:
		return &""
	return StringName(String(_primary_attack_method.get("skill_id")))


## 作用：清除独立主攻击实例引用。
## 使用：由本文件 add_skill 调用。
func _clear_primary_attack_method() -> void:
	_primary_attack_method = null


## 作用：委托学习策略解析实例的主要神系。
## 使用：skill_instance 为技能运行实例。
func _get_skill_instance_primary_god_school(skill_instance: RefCounted) -> StringName:
	return SkillLearningPolicyScript.instance_primary_god_school(skill_instance)

## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：挂在玩家下；初始攻击使用 set_primary_attack_method，普通学习使用 add_skill，升级成功后刷新属性并发信号；无适用数据时返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：严格判断 Variant 是否为 int 或 float，不把布尔或字符串当数值。
## 使用：由本文件 _scale_modifier_value 调用。
func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


## 作用：将调用方技能标識统一为 StringName。
## 使用：skill_id 为标准技能 ID。
func _to_skill_id(skill_id: Variant) -> StringName:
	return StringName(String(skill_id))

# Only commit removal after add_skill has accepted the replacement. Signals are
# blocked until both collections and source cleanup represent the new build.
func replace_ordinary_skill(old_id: StringName, new_id: StringName, rarity: String) -> bool:
	var old: RefCounted = get_skill(old_id)
	if old == null or not SkillSlotPolicyScript.counts_active_capacity(_get_skill_definition_data(old_id)):
		return false
	var data: Dictionary = _get_skill_definition_data(new_id)
	if data.is_empty() or not SkillSlotPolicyScript.counts_active_capacity(data) or has_learned_skill(new_id): return false
	var was_blocked: bool = is_blocking_signals()
	set_block_signals(true)
	active_skills.erase(old_id)
	var accepted: bool = add_skill(new_id, rarity)
	if not accepted:
		active_skills[old_id] = old
		set_block_signals(was_blocked)
		return false
	_clear_temporary_skill_sources(old_id)
	_remove_skill_effect_modifier_source(old_id)
	_remove_passive_modifiers_for_skill(old_id)
	_clear_origin_runtime(get_tree().root, old_id)
	set_block_signals(was_blocked)
	skill_added.emit(new_id)
	skill_changed.emit()
	return true

func _clear_origin_runtime(node: Node, id: StringName) -> void:
	if node.has_method("clear_origin"): node.call("clear_origin", id)
	for property: Dictionary in node.get_property_list():
		if String(property.name) not in ["_context", "damage_packet"]: continue
		var value: Variant = node.get(property.name)
		if value is Dictionary and StringName(String(value.get("source_skill_id", value.get("origin_skill_id", value.get("skill_id", ""))))) == id:
			node.get_parent().remove_child(node)
			node.queue_free()
			return
	for child: Node in node.get_children(): _clear_origin_runtime(child, id)
