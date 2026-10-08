extends RefCounted
class_name DamageApplicationService


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const DamageApplicationResultScript: Script = preload("res://scripts/combat/damage_application_result.gd")
const DamageApplicationContextScript: Script = preload("res://scripts/combat/damage_application_context.gd")
const DamageApplicationPipelineScript: Script = preload("res://scripts/combat/damage_application_pipeline.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")


static func apply_damage(target: Node, packet: DamagePacket) -> RefCounted:
	return DamageApplicationPipelineScript.apply(DamageApplicationContextScript.create(target, packet))


static func apply_player_damage(player: Node, packet: DamagePacket) -> RefCounted:
	return DamageApplicationPipelineScript.apply_player(DamageApplicationContextScript.create(player, packet))


static func apply_enemy_damage(enemy: Node, packet: DamagePacket) -> RefCounted:
	return DamageApplicationPipelineScript.apply_enemy(DamageApplicationContextScript.create(enemy, packet))


static func _packet_amount(packet: DamagePacket) -> int:
	return DamageApplicationPipelineScript.packet_amount(packet)


static func _packet_with_amount(packet: DamagePacket, amount: int) -> DamagePacket:
	return DamageApplicationPipelineScript.packet_with_amount(packet, amount)
