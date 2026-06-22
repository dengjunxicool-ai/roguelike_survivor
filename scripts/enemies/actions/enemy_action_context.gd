extends RefCounted
class_name EnemyActionContext


static func create(owner: Node, skill: Dictionary, action: Dictionary, runtime_params: Dictionary = {}) -> Dictionary:
	return {
		"owner": owner,
		"skill": skill.duplicate(true),
		"action": action.duplicate(true),
		"runtime_params": runtime_params.duplicate(true)
	}
