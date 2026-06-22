extends RefCounted
class_name TargetDamageProfile


var target_type: StringName = &"normal"
var armor: float = 0.0
var defense: float = 0.0
var resistances: Dictionary = {}
var vulnerability_cap: float = 0.30
var vulnerability_floor: float = -0.60
var true_percent_cap: float = 1.0
var incoming_damage_reduction: float = 0.0
var can_receive_reaction: bool = true
var origin_taken_modifiers: Dictionary = {}


func is_player() -> bool:
	return target_type == &"player"


func is_boss() -> bool:
	return target_type == &"boss"


func is_elite() -> bool:
	return target_type == &"elite"
