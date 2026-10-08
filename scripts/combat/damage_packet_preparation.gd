extends RefCounted
class_name DamagePacketPreparation

static func prepare(packet: DamagePacket, target: Node = null) -> DamagePacket:
	var errors: Array[String] = packet.validate()
	if not errors.is_empty():
		push_error("Invalid DamagePacket: " + "; ".join(errors))
		return null
	var prepared: DamagePacket = packet.clone()
	if target != null:
		prepared.target_id = str(target.get_instance_id())
	prepared.reaction_depth = maxi(prepared.reaction_depth, 0)
	DamagePacketValidator.validate_packet(prepared, target)
	return prepared
