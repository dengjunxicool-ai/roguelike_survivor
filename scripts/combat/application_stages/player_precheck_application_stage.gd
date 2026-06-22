extends RefCounted
class_name PlayerPrecheckApplicationStage


var stage_name: StringName = &"player_precheck"


func apply_with_host(host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var amount_or_packet: Variant = context.get("amount_or_packet")
	if int(player.get("current_health")) <= 0:
		context.call("set_result", host.call("make_result", false, 0, {}, &"dead"))
		return
	var incoming_amount: int = int(host.call("packet_amount", amount_or_packet))
	context.set("incoming_amount", incoming_amount)
	if incoming_amount <= 0:
		context.call("set_result", host.call("make_result", false, 0, {}, &"empty"))
		return
	if bool(player.call("_is_damage_blocked_by_hit_protection", amount_or_packet)):
		context.call("set_result", host.call("make_result", false, 0, {}, &"hit_protection"))
