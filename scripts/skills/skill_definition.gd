## 文件用途：保存标准技能配置的隔离副本，包括基础数值、动作、触发、Modifier 和特殊规则。
## 使用方式：SkillManager 使用 GameData 字典构造，再由 SkillInstance 保存运行状态；配置字段转换时深拷贝复合数据。
extends RefCounted
class_name SkillDefinition


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")

var id: StringName = &""
var display_name: String = ""
var school: StringName = &""
var fusion_school: Variant = null
var skill_type: String = ""
var rarity: String = "normal"
var exclusive_group: String = ""
var mechanic_family: String = ""
var offer_enabled: bool = true
var capabilities: Array = []
var offer_rule: Dictionary = {}
var trigger_rules: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var slot_category: String = ""
var tags: Array[String] = []
var max_level: int = 1
var base: Dictionary = {}
var damage_scaling: Dictionary = {}
var modifiers: Dictionary = {}
var skill_modifiers: Array[Dictionary] = []
var base_special_rules: Dictionary = {}
var runtime_rules: Dictionary = {}
var components: Array[Dictionary] = []
var events: Array[Dictionary] = []


## 作用：把技能标准配置字段转成定义对象，并隔离复合数据与展开配置 Modifier。
## 使用：SkillManager 使用 GameData 字典构造，再由 SkillInstance 保存运行状态；配置字段转换时深拷贝复合数据。
func _init(data: Dictionary = {}) -> void:
	id = StringName(_string_or(data.get("id", ""), ""))
	display_name = _string_or(data.get("display_name", ""), "")
	school = StringName(_string_or(data.get("school", ""), ""))
	var fusion_value: Variant = data.get("fusion_school", null)
	fusion_school = null if fusion_value == null else StringName(_string_or(fusion_value, ""))
	skill_type = _string_or(data.get("skill_type", ""), "")
	rarity = _string_or(data.get("rarity", "normal"), "normal")
	exclusive_group = _string_or(data.get("exclusive_group", ""), "")
	mechanic_family = _string_or(data.get("mechanic_family", ""), "")
	offer_enabled = bool(data.get("offer_enabled", true))
	capabilities = data.get("capabilities", []).duplicate()
	offer_rule = _parse_dictionary(data.get("offer_rule", {}))
	trigger_rules = _parse_dictionary_array(data.get("trigger_rules", []))
	effects = _parse_dictionary_array(data.get("effects", []))
	slot_category = _string_or(data.get("slot_category", ""), "")
	tags = _parse_string_array(data.get("tags", []))
	max_level = maxi(int(data.get("max_level", 1)), 1)
	base = _parse_dictionary(data.get("base", {}))
	damage_scaling = _parse_dictionary(data.get("damage_scaling", {}))
	modifiers = ModifierSourceScript.flatten_effects(data.get("modifiers", []), ModifierSourceScript.SOURCE_SKILL)
	skill_modifiers = _parse_dictionary_array(data.get("skill_modifiers", []))
	base_special_rules = _parse_dictionary(data.get("base_special_rules", {}))
	runtime_rules = _parse_dictionary(data.get("runtime_rules", {}))
	components = _parse_dictionary_array(data.get("components", []))
	events = _parse_dictionary_array(data.get("events", []))


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else String(value)


## 作用：判断定义标签数组是否含指定标签。
## 使用：SkillManager 使用 GameData 字典构造，再由 SkillInstance 保存运行状态；配置字段转换时深拷贝复合数据。
func has_tag(tag: String) -> bool:
	return tags.has(tag)


## 作用：读取定义中的单项基础数值，并在未配置时返回调用方默认值。
## 使用：stat_name 为待查询属性键；default_value 为缺值备用结果。
func get_base_stat(stat_name: String, default_value: Variant = 0) -> Variant:
	return base.get(stat_name, default_value)


## 作用：把配置数组元素转换为字符串标签数组。
## 使用：由本文件 _init 调用。
func _parse_string_array(value: Variant) -> Array[String]:
	var parsed: Array[String] = []
	if not (value is Array):
		return parsed

	var source: Array = value
	for item: Variant in source:
		parsed.append(String(item))

	return parsed


## 作用：只接受字典并返回深拷贝，其他类型返回空字典。
## 使用：由本文件 _init 调用；无适用数据时返回空字典。
func _parse_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


## 作用：筛出配置数组中的字典项并逐个深拷贝。
## 使用：由本文件 _init 调用。
func _parse_dictionary_array(value: Variant) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	if not (value is Array):
		return parsed

	var source: Array = value
	for item_variant: Variant in source:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			parsed.append(item.duplicate(true))

	return parsed
