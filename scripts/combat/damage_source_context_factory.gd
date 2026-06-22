extends RefCounted
class_name DamageSourceContextFactory


const DamageSourceContextScript: Script = preload("res://scripts/combat/damage_source_context.gd")


static func from_packet(packet: Dictionary, attacker: Node = null) -> RefCounted:
	var source_context: RefCounted = DamageSourceContextScript.from_dictionary(packet)
	if attacker != null and source_context.get("attacker") == null:
		source_context.set("attacker", attacker)
	if attacker != null and String(source_context.get("attacker_id")) == "":
		source_context.set("attacker_id", str(attacker.get_instance_id()))
	return source_context
