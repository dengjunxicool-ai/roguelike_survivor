## 文件用途：保存伤害中间阶段和顺序的独立追踪字典。
## 使用方式：由计算上下文或 DamageResult 创建；导出时深复制，供诊断和结果展示。
extends RefCounted
class_name DamageTrace


var stages: Dictionary = {}


## 作用：创建追踪并从给定阶段字典深复制内容。
## 使用：无输入时创建空追踪。
static func create(stage_values: Dictionary = {}) -> RefCounted:
	var trace: RefCounted = new()
	trace.call("sync_from_dictionary", stage_values)
	return trace


## 作用：深复制阶段字典并返回自身。
## 使用：替换当前全部追踪项，不与输入共享嵌套数据。
func sync_from_dictionary(stage_values: Dictionary) -> RefCounted:
	stages = stage_values.duplicate(true)
	return self


## 作用：写入单个阶段追踪值。
## 使用：key 为追踪名称，value 为结果值。
func set_stage(key: Variant, value: Variant) -> void:
	stages[key] = value


## 作用：读取阶段值，缺失时返回默认值。
## 使用：用于诊断读取，fallback 可任意类型。
func get_stage(key: Variant, fallback: Variant = null) -> Variant:
	return stages.get(key, fallback)


## 作用：复制保存执行顺序数组。
## 使用：只描述顺序，不改变已保存的其他项。
func set_stage_order(order: Array) -> void:
	stages["stage_order"] = order.duplicate()


## 作用：导出追踪字典的深复制。
## 使用：返回内容可供外部编辑而不污染原追踪。
func to_dictionary() -> Dictionary:
	return stages.duplicate(true)
