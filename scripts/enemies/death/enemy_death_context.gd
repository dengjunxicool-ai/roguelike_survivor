extends RefCounted
class_name EnemyDeathContext


static func create(cause: String = "damage", policy: Dictionary = {}, source_context: Dictionary = {}) -> Dictionary:
	return {
		"cause": cause,
		"policy": policy.duplicate(true),
		"source_context": source_context.duplicate(true)
	}
