## 文件用途：伤害应用管线的敌人伤害计算阶段。
## 使用方式：由DamageApplicationPipeline按固定顺序实例化调用；写context结果可短路后续阶段。
extends RefCounted
class_name EnemyCalculationApplicationStage


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")

var stage_name: StringName = &"enemy_calculation"


## 作用：调用DamageSystem计算敌人伤害并保存伤害量、结果及显示元素。
## 使用：host提供统一结果构造，context保存目标/原包与阶段值；调用会更新受击状态。
func apply_with_host(_host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	var damage_result: Dictionary = DamageSystemScript.calculate(context.get("packet"), enemy).to_dictionary()
	context.set("damage_result", damage_result)
	context.set("final_amount", int(damage_result.get("amount", 0)))
	context.set("display_damage_type", StringName(String(damage_result.get("element", damage_result.get("damage_type", context.get("packet").get_value("element"))))))
