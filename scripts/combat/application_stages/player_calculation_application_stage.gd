extends RefCounted
class_name PlayerCalculationApplicationStage


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")

var stage_name: StringName = &"player_calculation"


func apply_with_host(_host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var damage_result: Dictionary = DamageSystemScript.calculate(context.get("damage_payload"), player, context.get("legacy_damage_type"))
	context.set("damage_result", damage_result)
	context.set("final_amount", int(damage_result.get("amount", 0)))
