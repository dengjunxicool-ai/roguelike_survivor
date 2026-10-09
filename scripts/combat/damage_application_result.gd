## 文件用途：记录一次伤害是否应用、实际伤害量、计算视图和拒绝/完成原因。
## 使用方式：受击服务返回此对象；对外展示或检查时导出字典。
extends RefCounted
class_name DamageApplicationResult


var applied: bool = false
var amount: int = 0
var damage_result: Dictionary = {}
var reason: StringName = &""


## 作用：创建应用结果并深复制计算字典。
## 使用：applied_value、amount_value、reason_value 描述应用结果，避免共享可变计算视图。
static func make(applied_value: bool, amount_value: int, result: Dictionary = {}, reason_value: StringName = &"") -> RefCounted:
	var application_result: RefCounted = new()
	application_result.applied = applied_value
	application_result.amount = amount_value
	application_result.damage_result = result.duplicate(true)
	application_result.reason = reason_value
	return application_result


## 作用：导出应用状态、伤害量、原因及独立计算字典。
## 使用：供调用方检查或事件展示，不改变保存的结果。
func to_dictionary() -> Dictionary:
	return {
		"applied": applied,
		"amount": amount,
		"damage_result": damage_result.duplicate(true),
		"reason": reason
	}
