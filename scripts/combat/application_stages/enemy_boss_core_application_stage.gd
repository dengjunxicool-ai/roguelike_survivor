## 文件用途：伤害应用管线的敌人Boss核心保护阶段。
## 使用方式：由DamageApplicationPipeline按固定顺序实例化调用；写context结果可短路后续阶段。
extends RefCounted
class_name EnemyBossCoreApplicationStage


var stage_name: StringName = &"enemy_boss_core"


## 作用：对最终伤害量应用奖励控制器的核心减伤；非正值写mitigated结果终止。
## 使用：host提供统一结果构造，context保存目标/原包与阶段值；调用会更新受击状态。
func apply_with_host(host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	var final_amount: int = int(context.get("final_amount"))
	var reward_controller: Node = enemy.get("_reward_controller") as Node
	if reward_controller != null:
		final_amount = int(reward_controller.call("apply_boss_core_damage_reduction", final_amount))
	context.set("final_amount", final_amount)
	if final_amount <= 0:
		context.call("set_result", host.call("make_result", false, 0, context.get("damage_result"), &"mitigated"))
