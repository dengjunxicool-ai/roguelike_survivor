extends RefCounted
class_name EnemySynergyApplicationStage


var stage_name: StringName = &"enemy_synergy"


func apply_with_host(_host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	var final_amount: int = int(context.get("final_amount"))
	final_amount = int(enemy.call("_apply_damage_synergies", final_amount, context.get("display_damage_type")))
	context.set("final_amount", final_amount)
