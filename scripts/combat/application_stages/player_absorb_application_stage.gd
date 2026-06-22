extends RefCounted
class_name PlayerAbsorbApplicationStage


var stage_name: StringName = &"player_absorb"


func apply_with_host(host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var amount_or_packet: Variant = context.get("amount_or_packet")
	var damage_type: Variant = context.get("legacy_damage_type")
	var trait_system: Node = player.get_node_or_null("CharacterTraitSystem")
	context.set("trait_system", trait_system)
	var incoming_amount: int = int(context.get("incoming_amount"))
	var absorbed_amount: int = incoming_amount
	if trait_system != null and trait_system.has_method("request_damage_absorb"):
		var absorb_result: RefCounted = trait_system.call("request_damage_absorb", incoming_amount, {
			"raw_amount": incoming_amount,
			"source": amount_or_packet,
			"legacy_damage_type": damage_type
		}) as RefCounted
		if absorb_result != null:
			absorbed_amount = int(absorb_result.get("amount"))
	if absorbed_amount > 0:
		var fire_shield: int = _get_live_fire_passive_shield(player)
		if fire_shield > 0:
			var fire_absorbed: int = mini(fire_shield, absorbed_amount)
			player.set_meta("fire_passive_shield", maxi(fire_shield - fire_absorbed, 0))
			absorbed_amount = maxi(absorbed_amount - fire_absorbed, 0)
	if absorbed_amount > 0:
		var relic_shield: int = int(player.get_meta("cross_relic_shield_points", 0))
		if relic_shield > 0:
			var relic_absorbed: int = mini(relic_shield, absorbed_amount)
			player.set_meta("cross_relic_shield_points", maxi(relic_shield - relic_absorbed, 0))
			absorbed_amount = maxi(absorbed_amount - relic_absorbed, 0)
	if absorbed_amount > 0:
		var corrosive_film_shield: int = int(player.get_meta("corrosive_film_shield_points", 0))
		if corrosive_film_shield > 0:
			var corrosive_absorbed: int = mini(corrosive_film_shield, absorbed_amount)
			player.set_meta("corrosive_film_shield_points", maxi(corrosive_film_shield - corrosive_absorbed, 0))
			absorbed_amount = maxi(absorbed_amount - corrosive_absorbed, 0)
	context.set("absorbed_amount", absorbed_amount)
	if absorbed_amount <= 0:
		context.call("set_result", host.call("make_result", false, 0, {}, &"absorbed"))
		return
	context.set("damage_payload", host.call("packet_with_amount", amount_or_packet, absorbed_amount))


func _get_live_fire_passive_shield(player: Node) -> int:
	var expires_at: float = float(player.get_meta("fire_passive_shield_expires_at", 0.0))
	if expires_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= expires_at:
		player.set_meta("fire_passive_shield", 0)
		player.set_meta("fire_passive_shield_expires_at", 0.0)
		return 0
	return int(player.get_meta("fire_passive_shield", 0))
