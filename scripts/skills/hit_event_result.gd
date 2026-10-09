## 文件用途：表示命中事件是否消费基础伤害、附加伤害列表和纯副作用标志。
## 使用方式：SkillEventBus 用 from_value 归一监听器返回值，再用 to_dictionary 输出明确事件视图。
extends RefCounted
class_name HitEventResult


var consume_base_damage: bool = false
var appended_damage: Array = []
var side_effect_only: bool = true


## 作用：将字典或布尔命中结果转换为消费基础伤害、附加伤害与纯副作用标志；已有可导出对象直接复用。
## 使用：SkillEventBus 用 from_value 归一监听器返回值，再用 to_dictionary 输出明确事件视图。
static func from_value(value: Variant) -> RefCounted:
	if value is RefCounted and value.has_method("to_dictionary"):
		return value
	var result: RefCounted = new()
	if value is Dictionary:
		var dictionary: Dictionary = value
		result.consume_base_damage = bool(dictionary.get("consume_base_damage", false))
		result.appended_damage = _get_array(dictionary.get("appended_damage", []))
		result.side_effect_only = bool(dictionary.get("side_effect_only", not result.consume_base_damage and result.appended_damage.is_empty()))
	elif value is bool:
		result.consume_base_damage = bool(value)
		result.side_effect_only = not result.consume_base_damage
	return result


## 作用：输出消费基础伤害、附加伤害列表副本和纯副作用标志的明确事件视图。
## 使用：SkillEventBus 用 from_value 归一监听器返回值，再用 to_dictionary 输出明确事件视图。
func to_dictionary() -> Dictionary:
	return {
		"consume_base_damage": consume_base_damage,
		"appended_damage": appended_damage.duplicate(true),
		"side_effect_only": side_effect_only
	}


## 作用：仅接受 Array；深拷贝输出以隔离调用方修改，其余类型返回空数组。
## 使用：由本文件 from_value 调用；无匹配项时返回空数组。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
