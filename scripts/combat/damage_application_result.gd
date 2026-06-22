extends RefCounted
class_name DamageApplicationResult


var applied: bool = false
var amount: int = 0
var damage_result: Dictionary = {}
var reason: StringName = &""


static func make(applied_value: bool, amount_value: int, result: Dictionary = {}, reason_value: StringName = &"") -> RefCounted:
	var application_result: RefCounted = new()
	application_result.applied = applied_value
	application_result.amount = amount_value
	application_result.damage_result = result.duplicate(true)
	application_result.reason = reason_value
	return application_result


func to_dictionary() -> Dictionary:
	return {
		"applied": applied,
		"amount": amount,
		"damage_result": damage_result.duplicate(true),
		"reason": reason
	}
