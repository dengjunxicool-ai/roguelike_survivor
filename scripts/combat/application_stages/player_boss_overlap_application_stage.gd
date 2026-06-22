extends RefCounted
class_name PlayerBossOverlapApplicationStage


var stage_name: StringName = &"player_boss_overlap"


func apply_with_host(host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var final_damage: int = int(context.get("final_amount"))
	final_damage = int(player.call("_apply_boss_overlap_protection", final_damage, context.get("amount_or_packet")))
	context.set("final_amount", final_damage)
	if final_damage <= 0:
		context.call("set_result", host.call("make_result", false, 0, context.get("damage_result"), &"mitigated"))
