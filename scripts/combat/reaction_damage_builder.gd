extends RefCounted
class_name ReactionDamageBuilder


const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")


static func build(base_packet: Dictionary, reaction_type: String, amount: float, element: Variant = &"neutral", reaction_tier: String = "normal") -> Dictionary:
	return DamagePacketBuilderScript.from_reaction({
		"base_packet": base_packet,
		"reaction_type": reaction_type,
		"amount": amount,
		"element": element,
		"reaction_tier": reaction_tier
	})


static func build_any(packet_source: Variant, reaction_type: String, amount: float, element: Variant = &"neutral", reaction_tier: String = "normal") -> Dictionary:
	return build(_packet_dictionary(packet_source), reaction_type, amount, element, reaction_tier)


static func _packet_dictionary(packet_source: Variant) -> Dictionary:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).duplicate(true)
	if packet_source is RefCounted:
		if packet_source.has_method("packet_dict"):
			return packet_source.call("packet_dict")
		if packet_source.has_method("to_dictionary"):
			return packet_source.call("to_dictionary")
	return {}
