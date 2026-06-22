extends RefCounted
class_name DamageAbsorbResult


var amount: int = 0
var absorbed: int = 0
var metadata: Dictionary = {}


func _init(result_amount: int = 0, result_absorbed: int = 0, result_metadata: Dictionary = {}) -> void:
	amount = maxi(result_amount, 0)
	absorbed = maxi(result_absorbed, 0)
	metadata = result_metadata.duplicate(true)


static func unchanged(original_amount: int) -> DamageAbsorbResult:
	return DamageAbsorbResult.new(original_amount, 0, {})
