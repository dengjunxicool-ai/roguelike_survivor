## 文件用途：伤害计算管线的玩家比例减伤阶段适配器。
## 使用方式：由DamageSystem构建有序管线并实例化；apply_with_host接收共享计算上下文。
extends RefCounted
class_name PlayerReductionStage


var stage_name: StringName = &"player_reduction"


## 作用：把护甲后输入交给宿主玩家比例减伤处理。
## 使用：host为计算宿主，calculation_context保存包/目标/追踪；返回值传给下一阶段。
func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	return host.call("_apply_player_reduction_stage", calculation_context, float(input_value))
