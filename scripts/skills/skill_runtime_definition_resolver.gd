## 文件用途：为攻击替换定义补齐来源攻击中缺失的运行字段。
## 使用方式：inherit_attack 接收新定义及被替换定义，返回深拷贝结果，仅补空的基础值、组件、事件、缩放、运行族和粒子字段。
extends RefCounted
class_name SkillRuntimeDefinitionResolver


const INHERITED_RUNTIME_FIELDS: Array[String] = ["base", "components", "events", "damage_scaling", "runtime_family", "particle"]


## 作用：深拷贝新攻击定义，仅从来源填充空缺运行字段，保留新定义显式值。
## 使用：definition 为技能定义；source 为来源数据或对象。
static func inherit_attack(definition: Dictionary, source: Dictionary) -> Dictionary:
	var result: Dictionary = definition.duplicate(true)
	for key: String in INHERITED_RUNTIME_FIELDS:
		if source.has(key) and _is_empty(result.get(key, null)):
			var value: Variant = source[key]
			result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


## 作用：判断 null 或空容器、字符串是否属于可继承的空值。
## 使用：由本文件 inherit_attack 调用；返回布尔判断或执行是否成功。
static func _is_empty(value: Variant) -> bool:
	if value == null:
		return true
	if value is Dictionary or value is Array or value is String:
		return value.is_empty()
	if value is StringName:
		return value == &""
	return false
