## 文件用途：伤害应用管线的敌人死亡预检查阶段。
## 使用方式：由DamageApplicationPipeline按固定顺序实例化调用；写context结果可短路后续阶段。
extends RefCounted
class_name EnemyPrecheckApplicationStage


var stage_name: StringName = &"enemy_precheck"


## 作用：已死目标写dead结果，阻止后续公式和生命副作用。
## 使用：host提供统一结果构造，context保存目标/原包与阶段值；调用会更新受击状态。
func apply_with_host(host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	if _is_dead(enemy):
		context.call("set_result", host.call("make_result", false, 0, {}, &"dead"))


## 作用：优先读取runtime_state，否则读取敌人_is_dead标记。
## 使用：enemy为敌人节点，返回是否已经死亡，空节点返回false。
func _is_dead(enemy: Node) -> bool:
	if enemy != null and enemy.has_method("get_runtime_state"):
		return String(enemy.call("get_runtime_state")) == "dead"
	return enemy != null and bool(enemy.get("_is_dead"))
