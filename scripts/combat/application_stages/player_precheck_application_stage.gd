## 文件用途：伤害应用管线的玩家受击预检查阶段。
## 使用方式：由DamageApplicationPipeline按固定顺序实例化调用；写context结果可短路后续阶段。
extends RefCounted
class_name PlayerPrecheckApplicationStage


var stage_name: StringName = &"player_precheck"


## 作用：检查存活、入伤伤害量和命中保护，拒绝时设置对应终止结果。
## 使用：host提供统一结果构造，context保存目标/原包与阶段值；调用会更新受击状态。
func apply_with_host(host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var packet: DamagePacket = context.get("packet")
	if int(player.get("current_health")) <= 0:
		context.call("set_result", host.call("make_result", false, 0, {}, &"dead"))
		return
	var incoming_amount: int = int(host.call("packet_amount", packet))
	context.set("incoming_amount", incoming_amount)
	if incoming_amount <= 0:
		context.call("set_result", host.call("make_result", false, 0, {}, &"empty"))
		return
	if bool(player.call("_is_damage_blocked_by_hit_protection", packet)):
		context.call("set_result", host.call("make_result", false, 0, {}, &"hit_protection"))
