extends RefCounted
class_name EnemyCalculationApplicationStage


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")

var stage_name: StringName = &"enemy_calculation"


func apply_with_host(_host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	var damage_result: Dictionary = DamageSystemScript.calculate(context.get("amount_or_packet"), enemy, context.get("legacy_damage_type"))
	context.set("damage_result", damage_result)
	context.set("final_amount", int(damage_result.get("amount", 0)))
	context.set("display_damage_type", StringName(String(damage_result.get("element", damage_result.get("damage_type", context.get("legacy_damage_type"))))))
