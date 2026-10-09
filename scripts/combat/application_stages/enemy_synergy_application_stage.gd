## 文件用途：伤害应用管线的敌人受击协同阶段。
## 使用方式：由DamageApplicationPipeline按固定顺序实例化调用；写context结果可短路后续阶段。
extends RefCounted
class_name EnemySynergyApplicationStage


var stage_name: StringName = &"enemy_synergy"


## 作用：把公式伤害量和显示类型交给敌人协同方法，写回调整后伤害量。
## 使用：host提供统一结果构造，context保存目标/原包与阶段值；调用会更新受击状态。
func apply_with_host(_host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	var final_amount: int = int(context.get("final_amount"))
	final_amount = int(enemy.call("_apply_damage_synergies", final_amount, context.get("display_damage_type")))
	context.set("final_amount", final_amount)
