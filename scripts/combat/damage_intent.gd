extends RefCounted
class_name DamageIntent


const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")

var target: Node = null
var packet: Variant = {}
var damage_type: Variant = &""
var application_policy: StringName = &"default"


static func create(target_node: Node, damage_packet: Variant, legacy_damage_type: Variant = &"", policy: StringName = &"default") -> RefCounted:
	var intent: RefCounted = new()
	intent.target = target_node
	intent.packet = damage_packet.duplicate(true) if damage_packet is Dictionary else damage_packet
	intent.damage_type = legacy_damage_type
	intent.application_policy = policy
	return intent


func apply() -> RefCounted:
	return DamageApplicationServiceScript.apply_damage(target, packet, damage_type)
