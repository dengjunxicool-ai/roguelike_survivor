extends RefCounted
class_name ReactionService


const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const ReactionDamageBuilderScript: Script = preload("res://scripts/combat/reaction_damage_builder.gd")


static func prepare_damage_packet(packet: Dictionary) -> Dictionary:
	return ReactionLimiterScript.prepare_damage_packet(packet)


static func can_trigger(packet: Dictionary, reaction_type: String, target: Node = null) -> bool:
	return ReactionLimiterScript.can_trigger(packet, reaction_type, target)


static func can_trigger_any(packet_source: Variant, reaction_type: String, target: Node = null) -> bool:
	return ReactionLimiterScript.can_trigger_any(packet_source, reaction_type, target)


static func can_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node = null) -> bool:
	return ReactionLimiterScript.can_trigger_for_context(calculation_context, reaction_type, target)


static func can_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node = null) -> bool:
	return ReactionLimiterScript.can_trigger_for_packet_object(packet_object, reaction_type, target)


static func record_trigger(packet: Dictionary, reaction_type: String, target: Node = null) -> void:
	ReactionLimiterScript.record_trigger(packet, reaction_type, target)


static func record_trigger_any(packet_source: Variant, reaction_type: String, target: Node = null) -> void:
	ReactionLimiterScript.record_trigger_any(packet_source, reaction_type, target)


static func record_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node = null) -> void:
	ReactionLimiterScript.record_trigger_for_context(calculation_context, reaction_type, target)


static func record_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node = null) -> void:
	ReactionLimiterScript.record_trigger_for_packet_object(packet_object, reaction_type, target)


static func make_reaction_packet(base_packet: Dictionary, reaction_type: String, amount: float, element: Variant = &"neutral") -> Dictionary:
	return ReactionDamageBuilderScript.build(base_packet, reaction_type, amount, element, ReactionLimiterScript.reaction_tier(reaction_type))


static func make_reaction_packet_any(packet_source: Variant, reaction_type: String, amount: float, element: Variant = &"neutral") -> Dictionary:
	return ReactionDamageBuilderScript.build_any(packet_source, reaction_type, amount, element, ReactionLimiterScript.reaction_tier(reaction_type))


static func try_trigger(packet: Dictionary, reaction_type: String, target: Node, amount: float, element: Variant = &"neutral") -> Array[Dictionary]:
	if not can_trigger(packet, reaction_type, target):
		return []
	record_trigger(packet, reaction_type, target)
	return [make_reaction_packet(packet, reaction_type, amount, element)]


static func try_trigger_any(packet_source: Variant, reaction_type: String, target: Node, amount: float, element: Variant = &"neutral") -> Array[Dictionary]:
	if not can_trigger_any(packet_source, reaction_type, target):
		return []
	record_trigger_any(packet_source, reaction_type, target)
	return [make_reaction_packet_any(packet_source, reaction_type, amount, element)]


static func try_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node, amount: float, element: Variant = &"neutral") -> Array[Dictionary]:
	return try_trigger_any(calculation_context, reaction_type, target, amount, element)


static func try_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node, amount: float, element: Variant = &"neutral") -> Array[Dictionary]:
	return try_trigger_any(packet_object, reaction_type, target, amount, element)
