## 文件用途：伤害计算管线的输出倍率阶段适配器。
## 使用方式：由DamageSystem构建有序管线并实例化；apply_with_host接收共享计算上下文。
extends RefCounted
class_name OutgoingDamageStage


var stage_name: StringName = &"outgoing"


## 作用：忽略上一输入，从上下文原始值计算角色/技能/来源输出倍率。
## 使用：host为计算宿主，calculation_context保存包/目标/追踪；返回值传给下一阶段。
func apply_with_host(host: Object, calculation_context: RefCounted, _input_value: Variant) -> Variant:
	return host.call("_apply_outgoing_stage", calculation_context)
