extends RefCounted
class_name PlayerHealthApplicationStage


var stage_name: StringName = &"player_health_apply"


func apply_with_host(host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var amount_or_packet: Variant = context.get("amount_or_packet")
	var damage_type: Variant = context.get("legacy_damage_type")
	var damage_result: Dictionary = context.get("damage_result")
	var final_damage: int = int(context.get("final_amount"))
	var current_health: int = maxi(int(player.get("current_health")) - final_damage, 0)
	player.set("current_health", current_health)
	player.call("_record_damage_taken", final_damage, damage_result, amount_or_packet)
	var final_health: int = maxi(int(player.get("current_health")), 0)
	player.set("current_health", final_health)
	damage_result["target_current_health"] = final_health
	damage_result["lethal_prevented"] = current_health == 0 and final_health > 0
	player.emit_signal("health_changed", final_health, int(player.get("max_health")))
	player.call("_show_damage_number", final_damage, damage_result)
	var visual_controller: Node = player.get("_visual_controller") as Node
	if visual_controller != null:
		visual_controller.call("show_hurt")
	var trait_system: Node = context.get("trait_system") as Node
	if trait_system != null and trait_system.has_method("handle_player_damaged"):
		trait_system.call("handle_player_damaged", {
			"amount": final_damage,
			"raw_amount": int(context.get("incoming_amount")),
			"damage_type": damage_result.get("element", damage_type)
		})
	if final_health == 0:
		if visual_controller != null:
			visual_controller.call("play_state", "death", true)
		player.emit_signal("died")
	context.call("set_result", host.call("make_result", true, final_damage, damage_result, &"applied"))
