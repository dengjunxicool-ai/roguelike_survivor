## 文件用途：表示特性吸收后的实际伤害、已吸收数值和附加状态。
## 使用方式：吸收入口返回此对象；amount 与 absorbed 截断到非负值，unchanged 表示保留原伤害。
extends RefCounted
class_name DamageAbsorbResult


var amount: int = 0
var absorbed: int = 0
var metadata: Dictionary = {}


## 作用：将剩余伤害及吸收量截断非负，并深拷贝附加结果元数据。
## 使用：吸收入口返回此对象；amount 与 absorbed 截断到非负值，unchanged 表示保留原伤害。
func _init(result_amount: int = 0, result_absorbed: int = 0, result_metadata: Dictionary = {}) -> void:
	amount = maxi(result_amount, 0)
	absorbed = maxi(result_absorbed, 0)
	metadata = result_metadata.duplicate(true)


## 作用：创建不吸收原伤害的 DamageAbsorbResult。
## 使用：吸收入口返回此对象；amount 与 absorbed 截断到非负值，unchanged 表示保留原伤害。
static func unchanged(original_amount: int) -> DamageAbsorbResult:
	return DamageAbsorbResult.new(original_amount, 0, {})
