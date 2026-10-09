## 文件用途：伤害计算管线的最大生命百分比阶段适配器。
## 使用方式：由DamageSystem构建有序管线并实例化；apply_with_host接收共享计算上下文。
extends RefCounted
class_name TruePercentDamageStage


const DamageTruePercentResolverScript: Script = preload("res://scripts/combat/damage_true_percent_resolver.gd")

var stage_name: StringName = &"true_percent"


## 作用：读取目标最大生命和百分比，返回百分比基础伤害。
## 使用：host为计算宿主，calculation_context保存包/目标/追踪；返回值传给下一阶段。
func apply_with_host(_host: Object, calculation_context: RefCounted, _input_value: Variant) -> Variant:
	var target: Node = calculation_context.get("target") as Node
	var max_health: float = 0.0
	if target != null:
		max_health = maxf(float(target.get("max_health")), 0.0)
	var percent: float = DamageTruePercentResolverScript.resolve_true_percent(calculation_context)
	return DamageTruePercentResolverScript.apply_true_percent_stage(calculation_context, max_health, percent)
