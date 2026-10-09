## 文件用途：伤害计算管线的元素抗性阶段适配器。
## 使用方式：由DamageSystem构建有序管线并实例化；apply_with_host接收共享计算上下文。
extends RefCounted
class_name ResistanceDamageStage


var stage_name: StringName = &"resistance"


## 作用：把防御后输入交给宿主抗性处理。
## 使用：host为计算宿主，calculation_context保存包/目标/追踪；返回值传给下一阶段。
func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_resistance_stage", calculation_context, float(input_value))
