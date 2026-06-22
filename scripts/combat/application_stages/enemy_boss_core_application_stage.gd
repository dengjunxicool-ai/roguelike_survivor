extends RefCounted
class_name EnemyBossCoreApplicationStage


var stage_name: StringName = &"enemy_boss_core"


func apply_with_host(host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	var final_amount: int = int(context.get("final_amount"))
	var reward_controller: Node = enemy.get("_reward_controller") as Node
	if reward_controller != null:
		final_amount = int(reward_controller.call("apply_boss_core_damage_reduction", final_amount))
	context.set("final_amount", final_amount)
	if final_amount <= 0:
		context.call("set_result", host.call("make_result", false, 0, context.get("damage_result"), &"mitigated"))
