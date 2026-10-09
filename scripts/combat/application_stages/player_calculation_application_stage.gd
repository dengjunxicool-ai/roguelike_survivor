## 文件用途：伤害应用管线的玩家伤害计算阶段。
## 使用方式：由DamageApplicationPipeline按固定顺序实例化调用；写context结果可短路后续阶段。
extends RefCounted
class_name PlayerCalculationApplicationStage


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")

var stage_name: StringName = &"player_calculation"


## 作用：以吸收后的包调用DamageSystem并保存公式结果和最终伤害量。
## 使用：host提供统一结果构造，context保存目标/原包与阶段值；调用会更新受击状态。
func apply_with_host(_host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var damage_result: Dictionary = DamageSystemScript.calculate(context.get("damage_payload"), player).to_dictionary()
	context.set("damage_result", damage_result)
	context.set("final_amount", int(damage_result.get("amount", 0)))
