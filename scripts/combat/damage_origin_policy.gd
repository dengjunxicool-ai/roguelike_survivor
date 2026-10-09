## 文件用途：保存某种来源的默认伤害类型、加成键及缩放策略。
## 使用方式：DamageRuleRegistry 根据登记表构造，输出阶段和构建器读取属性。
extends RefCounted
class_name DamageOriginPolicy


var origin: StringName = &""
var default_damage_type: StringName = &"direct_physical"
var bonus_keys: Array[String] = []
var uses_skill_level: bool = false
var uses_character_damage: bool = true


## 作用：按来源名和策略字典建立独立策略对象。
## 使用：values 缺失字段使用主攻击类型和角色倍率默认值。
static func from_dictionary(origin_value: String, values: Dictionary) -> RefCounted:
	var policy: RefCounted = new()
	policy.origin = StringName(origin_value)
	policy.default_damage_type = StringName(String(values.get("default_damage_type", "direct_physical")))
	policy.bonus_keys = _string_array(values.get("bonus_keys", []))
	policy.uses_skill_level = bool(values.get("uses_skill_level", false))
	policy.uses_character_damage = bool(values.get("uses_character_damage", true))
	return policy


## 作用：将数组成员转为字符串列表。
## 使用：非数组返回空列表；原有顺序保留。
static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
