extends RefCounted
class_name EnemyPrecheckApplicationStage


var stage_name: StringName = &"enemy_precheck"


func apply_with_host(host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	if _is_dead(enemy):
		context.call("set_result", host.call("make_result", false, 0, {}, &"dead"))


func _is_dead(enemy: Node) -> bool:
	if enemy != null and enemy.has_method("get_runtime_state"):
		return String(enemy.call("get_runtime_state")) == "dead"
	return enemy != null and bool(enemy.get("_is_dead"))
