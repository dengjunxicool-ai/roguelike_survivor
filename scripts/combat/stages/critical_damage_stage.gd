## 文件用途：伤害计算管线的暴击阶段适配器。
## 使用方式：由DamageSystem构建有序管线并实例化；apply_with_host接收共享计算上下文。
extends RefCounted
class_name CriticalDamageStage


var stage_name: StringName = &"critical"


## 作用：调用宿主暴击处理并同步critical标记，返回减伤前浮点伤害。
## 使用：host为计算宿主，calculation_context保存包/目标/追踪；返回值传给下一阶段。
func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	var critical_result: Dictionary = host.call("_apply_critical_stage", calculation_context, float(input_value))
	calculation_context.set("critical", bool(critical_result.get("is_critical", false)))
	return float(critical_result.get("pre_mitigation", input_value))
