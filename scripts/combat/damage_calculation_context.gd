extends RefCounted
class_name DamageCalculationContext


const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const DamageTraceScript: Script = preload("res://scripts/combat/damage_trace.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")

var packet: DamagePacket
var packet_dictionary: Dictionary = {}
var target: Node = null
var target_profile: RefCounted
var attacker: Node = null
var damage_modifiers: Dictionary = {}
var stages: Dictionary = {}
var trace: RefCounted
var raw_amount: float = 0.0
var value: float = 0.0
var critical: bool = false
var final_amount: int = 0
var result: Dictionary = {}
var result_object: DamageResult


static func create(packet_object: DamagePacket, target_node: Node, attacker_node: Node = null) -> RefCounted:
	var context: RefCounted = new()
	context.packet = packet_object
	context.target = target_node
	context.attacker = attacker_node
	context.target_profile = TargetDamageProfileResolverScript.resolve(target_node)
	context.trace = DamageTraceScript.create()
	context.sync_packet_dictionary()
	context.raw_amount = maxf(float(context.packet_dictionary.get("raw_amount", 0.0)), 0.0)
	context.value = context.raw_amount
	return context


func sync_packet_dictionary() -> Dictionary:
	packet_dictionary = packet.to_dictionary()
	return packet_dictionary

func packet_dict() -> Dictionary:
	return packet_dictionary


func packet_value(key: Variant, fallback: Variant = null) -> Variant:
	return packet.get_value(key, fallback)

func packet_has(key: Variant) -> bool:
	return packet.has_value(key)

func set_stage(key: Variant, stage_value: Variant) -> void:
	stages[key] = stage_value
	if trace != null:
		trace.call("set_stage", key, stage_value)


func set_stage_order(order: Array) -> void:
	stages["stage_order"] = order.duplicate()
	if trace != null:
		trace.call("set_stage_order", order)


func finish(final_damage: int, is_critical: bool, final_value: float, output: Dictionary) -> Dictionary:
	final_amount = final_damage
	critical = is_critical
	value = final_value
	result = output
	return result


func finish_with_result(output_object: DamageResult) -> Dictionary:
	result_object = output_object
	var output: Dictionary = output_object.to_dictionary() if output_object != null else {}
	return finish(int(output.get("amount", 0)), bool(output.get("is_critical", false)), float(output.get("amount", 0)), output)
