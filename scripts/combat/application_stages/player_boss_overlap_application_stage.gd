## 文件用途：伤害应用管线的玩家Boss重叠保护阶段。
## 使用方式：由DamageApplicationPipeline按固定顺序实例化调用；写context结果可短路后续阶段。
extends RefCounted
class_name PlayerBossOverlapApplicationStage


var stage_name: StringName = &"player_boss_overlap"


## 作用：调用玩家重叠保护调整终值，非正值写mitigated结果终止。
## 使用：host提供统一结果构造，context保存目标/原包与阶段值；调用会更新受击状态。
func apply_with_host(host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var final_damage: int = int(context.get("final_amount"))
	final_damage = int(player.call("_apply_boss_overlap_protection", final_damage, context.get("packet")))
	context.set("final_amount", final_damage)
	if final_damage <= 0:
		context.call("set_result", host.call("make_result", false, 0, context.get("damage_result"), &"mitigated"))
