## 文件用途：伤害应用管线的玩家护盾吸收阶段。
## 使用方式：由DamageApplicationPipeline按固定顺序实例化调用；写context结果可短路后续阶段。
extends RefCounted
class_name PlayerAbsorbApplicationStage


var stage_name: StringName = &"player_absorb"


## 作用：依次消费角色特性、火系被动、十字遗物和腐蚀膜护盾；全部吸收即终止。
## 使用：host提供统一结果构造，context保存目标/原包与阶段值；调用会更新受击状态。
func apply_with_host(host: Object, context: RefCounted) -> void:
	var player: Node = context.get("target") as Node
	var packet: DamagePacket = context.get("packet")
	var damage_type: Variant = context.get("packet").get_value("element")
	var trait_system: Node = player.get_node_or_null("CharacterTraitSystem")
	context.set("trait_system", trait_system)
	var incoming_amount: int = int(context.get("incoming_amount"))
	var absorbed_amount: int = incoming_amount
	var shield_total: int = 0
	if trait_system != null and trait_system.has_method("request_damage_absorb"):
		var absorb_result: RefCounted = trait_system.call("request_damage_absorb", incoming_amount, {
			"raw_amount": incoming_amount,
			"source": packet,
			"damage_type": damage_type
		}) as RefCounted
		if absorb_result != null:
			absorbed_amount = int(absorb_result.get("amount"))
	if absorbed_amount > 0:
		var bus: Node = player.get_node_or_null("SkillEventBus")
		var now: float = float(bus.combat_seconds()) if bus != null else 0.0
		if now >= float(player.get_meta("holy_guard_ready_at",0.0)):
			var live: Array = []
			var guarded: bool = false
			for reference: WeakRef in player.get_meta("holy_guardians",[]):
				var guard: Node = reference.get_ref()
				if guard == null or not is_instance_valid(guard) or not guard.can_guard(player): continue
				live.append(reference)
				guarded = true
			player.set_meta("holy_guardians",live)
			if guarded:
				absorbed_amount -= mini(absorbed_amount, maxi(roundi(0.1*float(player.get("max_health"))),0))
				player.set_meta("holy_guard_ready_at",now+2.0)
	if absorbed_amount > 0:
		var fire_shield: int = _get_live_fire_passive_shield(player)
		if fire_shield > 0:
			var fire_absorbed: int = mini(fire_shield, absorbed_amount)
			shield_total += fire_absorbed
			player.set_meta("fire_passive_shield", maxi(fire_shield - fire_absorbed, 0))
			absorbed_amount = maxi(absorbed_amount - fire_absorbed, 0)
			if fire_absorbed >= fire_shield:
				var bus: Node = player.get_node_or_null("SkillEventBus")
				if bus != null:
					bus.emit_skill_event(&"shield_broken", {"caster":player,"owner":player,"skill_manager":player.get_node_or_null("SkillManager"),"parent":player.get_parent()})
	if absorbed_amount > 0:
		var relic_shield: int = int(player.get_meta("cross_relic_shield_points", 0))
		if relic_shield > 0:
			var relic_absorbed: int = mini(relic_shield, absorbed_amount)
			shield_total += relic_absorbed
			player.set_meta("cross_relic_shield_points", maxi(relic_shield - relic_absorbed, 0))
			absorbed_amount = maxi(absorbed_amount - relic_absorbed, 0)
	if absorbed_amount > 0:
		var corrosive_film_shield: int = int(player.get_meta("corrosive_film_shield_points", 0))
		if corrosive_film_shield > 0:
			var corrosive_absorbed: int = mini(corrosive_film_shield, absorbed_amount)
			shield_total += corrosive_absorbed
			player.set_meta("corrosive_film_shield_points", maxi(corrosive_film_shield - corrosive_absorbed, 0))
			absorbed_amount = maxi(absorbed_amount - corrosive_absorbed, 0)
	preload("res://scripts/runtime/skill_balance_metrics.gd").observe(player,{"kind":"shield_absorbed","amount":shield_total})
	context.set("absorbed_amount", absorbed_amount)
	if absorbed_amount <= 0:
		context.call("set_result", host.call("make_result", false, 0, {}, &"absorbed"))
		return
	context.set("damage_payload", host.call("packet_with_amount", packet, absorbed_amount))


## 作用：读取火系被动护盾，到期时同时清护盾量和期限。
## 使用：player为受击玩家；返回当前可消费整数盾量。
func _get_live_fire_passive_shield(player: Node) -> int:
	var expires_at: float = float(player.get_meta("fire_passive_shield_expires_at", 0.0))
	var bus: Node = player.get_node_or_null("SkillEventBus")
	var now: float = float(bus.combat_seconds()) if bus != null else Time.get_ticks_msec()/1000.0
	if expires_at > 0.0 and now >= expires_at:
		player.set_meta("fire_passive_shield", 0)
		player.set_meta("fire_passive_shield_expires_at", 0.0)
		return 0
	return int(player.get_meta("fire_passive_shield", 0))
