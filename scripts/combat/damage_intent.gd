extends RefCounted
class_name DamageIntent


const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")

var target: Node = null
var packet: DamagePacket
var application_policy: StringName = &"default"


static func create(target_node: Node, damage_packet: DamagePacket, policy: StringName = &"default") -> RefCounted:
	var intent: RefCounted = new()
	intent.target = target_node
	intent.packet = damage_packet.clone()
	intent.application_policy = policy
	return intent


func apply() -> RefCounted:
	return DamageApplicationServiceScript.apply_damage(target, packet)
