extends RefCounted
class_name DamageApplicationService


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const DamageApplicationResultScript: Script = preload("res://scripts/combat/damage_application_result.gd")
const DamageApplicationContextScript: Script = preload("res://scripts/combat/damage_application_context.gd")
const DamageApplicationPipelineScript: Script = preload("res://scripts/combat/damage_application_pipeline.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")


static func apply_damage(target: Node, amount_or_packet: Variant, damage_type: Variant = &"") -> RefCounted:
	return DamageApplicationPipelineScript.apply(DamageApplicationContextScript.create(target, amount_or_packet, damage_type))


static func apply_player_damage(player: Node, amount_or_packet: Variant, damage_type: Variant = &"") -> RefCounted:
	return DamageApplicationPipelineScript.apply_player(DamageApplicationContextScript.create(player, amount_or_packet, damage_type))


static func apply_enemy_damage(enemy: Node, amount_or_packet: Variant, damage_type: Variant = &"") -> RefCounted:
	return DamageApplicationPipelineScript.apply_enemy(DamageApplicationContextScript.create(enemy, amount_or_packet, damage_type))


static func _packet_amount(amount_or_packet: Variant) -> int:
	return DamageApplicationPipelineScript.packet_amount(amount_or_packet)


static func _packet_with_amount(amount_or_packet: Variant, amount: int) -> Variant:
	return DamageApplicationPipelineScript.packet_with_amount(amount_or_packet, amount)
