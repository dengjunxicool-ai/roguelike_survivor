## 文件用途：保存技能当前等级、稀有度、冷却和局内叠加属性、标签、事件及特殊规则。
## 使用方式：由 SkillManager 从 SkillDefinition 创建；通过 level_up 和 add_runtime_* 修改状态，配置定义与运行增量分开保存。
extends RefCounted
class_name SkillInstance


const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")

var definition: RefCounted
var skill_id: StringName = &""
var school: StringName = &""
var fusion_school: Variant = null
var skill_type: String = ""
var exclusive_group: String = ""
var current_level: int = 1
var current_rarity: String = "normal"
var runtime_modifiers: Dictionary = {}
var runtime_special_rules: Dictionary = {}
var runtime_tags: Array[StringName] = []
var runtime_events: Array[Dictionary] = []
var cooldown_remaining: float = 0.0


## 作用：保存定义引用并初始化技能身份、稀有度与运行属性，合并基础及火系运行规则。
## 使用：skill_definition 为已解析技能定义。
func _init(skill_definition: RefCounted) -> void:
	definition = skill_definition
	if definition != null:
		skill_id = definition.id
		school = StringName(String(definition.get("school")))
		fusion_school = definition.get("fusion_school")
		skill_type = String(definition.get("skill_type"))
		exclusive_group = String(definition.get("exclusive_group"))
		current_rarity = String(definition.get("rarity"))
		var definition_modifiers: Variant = definition.get("modifiers")
		if definition_modifiers is Dictionary:
			runtime_modifiers = (definition_modifiers as Dictionary).duplicate(true)
		var definition_special_rules: Variant = definition.get("base_special_rules")
		if definition_special_rules is Dictionary:
			add_runtime_special_rules(definition_special_rules as Dictionary)
		var definition_runtime_rules: Variant = definition.get("runtime_rules")
		if definition_runtime_rules is Dictionary:
			add_runtime_special_rules({
				"fire_runtime_rules": (definition_runtime_rules as Dictionary).duplicate(true)
			})


## 作用：在尚未达到最大等级时增加一级，并返回是否成功。
## 使用：由 SkillManager 从 SkillDefinition 创建；通过 level_up 和 add_runtime_* 修改状态，配置定义与运行增量分开保存；返回布尔判断或执行是否成功。
func level_up() -> bool:
	if not can_level_up():
		return false

	current_level += 1
	return true


## 作用：比较当前等级与定义上限，缺定义时不能升级。
## 使用：由本文件 level_up 调用；返回布尔判断或执行是否成功。
func can_level_up() -> bool:
	if definition == null:
		return false

	return current_level < definition.max_level


## 作用：累加同名数值运行属性，非数值或首次字段直接赋值。
## 使用：由 SkillManager 从 SkillDefinition 创建；通过 level_up 和 add_runtime_* 修改状态，配置定义与运行增量分开保存。
func add_runtime_modifier(key: Variant, value: Variant) -> void:
	var modifier_key: String = String(key)
	if modifier_key == "":
		return

	if runtime_modifiers.has(modifier_key) and _is_number(runtime_modifiers[modifier_key]) and _is_number(value):
		runtime_modifiers[modifier_key] = float(runtime_modifiers[modifier_key]) + float(value)
	else:
		runtime_modifiers[modifier_key] = value


## 作用：把非空、未重复的标签加入实例运行标签。
## 使用：由 SkillManager 从 SkillDefinition 创建；通过 level_up 和 add_runtime_* 修改状态，配置定义与运行增量分开保存。
func add_runtime_tag(tag: Variant) -> void:
	var tag_id: StringName = StringName(String(tag))
	if tag_id != &"" and not runtime_tags.has(tag_id):
		runtime_tags.append(tag_id)


## 作用：逐项深拷贝并追加字典型运行事件。
## 使用：由 SkillManager 从 SkillDefinition 创建；通过 level_up 和 add_runtime_* 修改状态，配置定义与运行增量分开保存。
func add_runtime_events(events: Array) -> void:
	for event_variant: Variant in events:
		if event_variant is Dictionary:
			var event: Dictionary = event_variant
			runtime_events.append(event.duplicate(true))


## 作用：递归合并运行特殊规则，数字累加、数组替换、字典递归。
## 使用：rules 为当前技能有效规则。
func add_runtime_special_rules(rules: Dictionary) -> void:
	_merge_special_rules(runtime_special_rules, rules)


## 作用：从定义基础值计算实例属性，合并运行属性；缺定义返回零。
## 使用：stat_name 为待查询属性键。
func get_effective_stat(stat_name: String) -> Variant:
	if definition == null:
		return 0

	var value: Variant = definition.get_base_stat(stat_name, 0)
	return SkillModifierCalculatorScript.calculate(value, stat_name, runtime_modifiers)


## 作用：严格判断 Variant 是否为 int 或 float，不把布尔或字符串当数值。
## 使用：由本文件 add_runtime_modifier/_merge_special_rules 调用。
func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


## 作用：递归合并规则字典，隔离复合数据并累加同名数值。
## 使用：target 为本次命中目标；source 为来源数据或对象。
func _merge_special_rules(target: Dictionary, source: Dictionary) -> void:
	for key_variant: Variant in source.keys():
		var key: String = String(key_variant)
		if key == "":
			continue
		var value: Variant = source[key_variant]
		if value is Dictionary:
			var existing: Dictionary = {}
			if target.get(key) is Dictionary:
				existing = (target[key] as Dictionary).duplicate(true)
			_merge_special_rules(existing, value)
			target[key] = existing
		elif value is Array:
			target[key] = (value as Array).duplicate(true)
		elif target.has(key) and _is_number(target[key]) and _is_number(value):
			target[key] = float(target[key]) + float(value)
		else:
			target[key] = value


## 作用：以原始数值类型决定返回浮点或四舍五入后的整数。
## 使用：由 SkillManager 从 SkillDefinition 创建；通过 level_up 和 add_runtime_* 修改状态，配置定义与运行增量分开保存。
func _match_number_type(value: float, original_value: Variant) -> Variant:
	if typeof(original_value) == TYPE_INT:
		return roundi(value)

	return value
