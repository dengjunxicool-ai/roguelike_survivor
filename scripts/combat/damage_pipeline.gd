## 文件用途：顺序组合可复用的伤害公式阶段，并传递上一阶段输出。
## 使用方式：create 接收阶段对象；execute_with_host 使用 DamageSystem 等宿主执行，stage_names 可检查顺序。
extends RefCounted
class_name DamagePipeline


var stages: Array[RefCounted] = []


## 作用：过滤非 RefCounted 项并保留阶段顺序建立管线。
## 使用：stage_list 为阶段实例列表；返回管线对象。
static func create(stage_list: Array = []) -> RefCounted:
	var pipeline: RefCounted = new()
	pipeline.set("stages", [])
	for stage: Variant in stage_list:
		if stage is RefCounted:
			pipeline.get("stages").append(stage)
	return pipeline


## 作用：顺序调用每个阶段，将前一输出作为后一输入。
## 使用：host 提供处理方法，calculation_context 为共享计算状态，返回最终值。
func execute_with_host(host: Object, calculation_context: RefCounted, initial_value: Variant) -> Variant:
	var value: Variant = initial_value
	for stage: RefCounted in stages:
		value = stage.call("apply_with_host", host, calculation_context, value)
	return value


## 作用：按当前执行顺序读取阶段名称。
## 使用：返回新数组供追踪和契约验证使用。
func stage_names() -> Array:
	var names: Array = []
	for stage: RefCounted in stages:
		names.append(stage.get("stage_name"))
	return names
