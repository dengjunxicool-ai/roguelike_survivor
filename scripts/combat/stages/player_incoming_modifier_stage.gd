## 文件用途：伤害计算管线的玩家入伤倍率阶段适配器。
## 使用方式：由DamageSystem构建有序管线并实例化；apply_with_host接收共享计算上下文。
extends RefCounted
class_name PlayerIncomingModifierStage


var stage_name: StringName = &"incoming_modifiers"


## 作用：忽略上一输入，从上下文原始值计算波次/阶段/临时防护倍率。
## 使用：host为计算宿主，calculation_context保存包/目标/追踪；返回值传给下一阶段。
func apply_with_host(host: Object, calculation_context: RefCounted, _input_value: Variant) -> Variant:
	return host.call("_apply_player_incoming_modifier_stage", calculation_context)
