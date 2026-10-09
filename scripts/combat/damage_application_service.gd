## 文件用途：为战斗调用方提供统一、玩家专用和敌人专用的 typed 受击入口。
## 使用方式：传入目标节点及 DamagePacket；返回 DamageApplicationResult，不绕过应用管线扣血。
extends RefCounted
class_name DamageApplicationService


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const DamageApplicationResultScript: Script = preload("res://scripts/combat/damage_application_result.gd")
const DamageApplicationContextScript: Script = preload("res://scripts/combat/damage_application_context.gd")
const DamageApplicationPipelineScript: Script = preload("res://scripts/combat/damage_application_pipeline.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")


## 作用：创建一次受击上下文并让管线自动选择目标处理方式。
## 使用：target 为受击节点，packet 为严格伤害包；返回应用结果。
static func apply_damage(target: Node, packet: DamagePacket) -> RefCounted:
	return DamageApplicationPipelineScript.apply(DamageApplicationContextScript.create(target, packet))


## 作用：创建玩家上下文并执行玩家受击顺序。
## 使用：仅用于 Player.take_damage 的玩家入口。
static func apply_player_damage(player: Node, packet: DamagePacket) -> RefCounted:
	return DamageApplicationPipelineScript.apply_player(DamageApplicationContextScript.create(player, packet))


## 作用：创建敌人上下文并执行敌人受击顺序。
## 使用：仅用于敌人聚合根入口，保留协同与死亡处理。
static func apply_enemy_damage(enemy: Node, packet: DamagePacket) -> RefCounted:
	return DamageApplicationPipelineScript.apply_enemy(DamageApplicationContextScript.create(enemy, packet))


## 作用：委托管线读取包的整数伤害量。
## 使用：用于应用层读取，返回值未做伤害公式计算。
static func _packet_amount(packet: DamagePacket) -> int:
	return DamageApplicationPipelineScript.packet_amount(packet)


## 作用：委托管线生成吸收后伤害量的克隆包。
## 使用：原输入不变，保留来源与输入校验错误。
static func _packet_with_amount(packet: DamagePacket, amount: int) -> DamagePacket:
	return DamageApplicationPipelineScript.packet_with_amount(packet, amount)
