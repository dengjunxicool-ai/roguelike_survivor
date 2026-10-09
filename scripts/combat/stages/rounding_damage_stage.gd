## 文件用途：伤害计算管线的最终取整阶段适配器。
## 使用方式：由DamageSystem构建有序管线并实例化；apply_with_host接收共享计算上下文。
extends RefCounted
class_name RoundingDamageStage


var stage_name: StringName = &"rounding"


## 作用：把特殊倍率后输入交给宿主统一整数与小数池处理。
## 使用：host为计算宿主，calculation_context保存包/目标/追踪；返回值传给下一阶段。
func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_rounding_stage", calculation_context, float(input_value))
