extends RefCounted
class_name DamageResult


const DamageTraceScript: Script = preload("res://scripts/combat/damage_trace.gd")

var amount: int = 0
var raw_amount: float = 0.0
var multiplier: float = 1.0
var is_critical: bool = false
var damage_origin: StringName = &""
var damage_type: StringName = &""
var element: StringName = &""
var trace: RefCounted = DamageTraceScript.create()


static func make(packet_source: Variant, final_amount: int, critical: bool, raw_damage: float, damage_multiplier: float, stage_values: Dictionary) -> RefCounted:
	var result: RefCounted = new()
	result.amount = final_amount
	result.raw_amount = raw_damage
	result.multiplier = damage_multiplier
	result.is_critical = critical
	result.damage_origin = StringName(String(_packet_value(packet_source, "damage_origin", "")))
	result.damage_type = StringName(String(_packet_value(packet_source, "damage_type", "")))
	result.element = StringName(String(_packet_value(packet_source, "element", "")))
	result.trace = DamageTraceScript.create(stage_values)
	return result


static func make_for_context(calculation_context: RefCounted, final_amount: int, critical: bool, raw_damage: float, damage_multiplier: float, stage_values: Dictionary) -> RefCounted:
	return make(calculation_context, final_amount, critical, raw_damage, damage_multiplier, stage_values)


static func from_dictionary(value: Dictionary) -> RefCounted:
	var result: RefCounted = new()
	result.amount = int(value.get("amount", 0))
	result.raw_amount = float(value.get("raw_amount", 0.0))
	result.multiplier = float(value.get("multiplier", 1.0))
	result.is_critical = bool(value.get("is_critical", false))
	result.damage_origin = StringName(String(value.get("damage_origin", "")))
	result.damage_type = StringName(String(value.get("damage_type", "")))
	result.element = StringName(String(value.get("element", "")))
	result.trace = DamageTraceScript.create(value.get("trace", value.get("stages", {})))
	return result


func to_dictionary() -> Dictionary:
	var trace_dictionary: Dictionary = trace.call("to_dictionary") if trace != null else {}
	return {
		"amount": amount,
		"raw_amount": raw_amount,
		"multiplier": multiplier,
		"is_critical": is_critical,
		"damage_origin": damage_origin,
		"damage_type": damage_type,
		"element": element,
		"stages": trace_dictionary.duplicate(true),
		"trace": trace_dictionary
	}


static func _packet_value(packet_source: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).get(key, fallback)
	if packet_source is RefCounted:
		if packet_source.has_method("packet_value"):
			return packet_source.call("packet_value", key, fallback)
		if packet_source.has_method("get_value"):
			return packet_source.call("get_value", key, fallback)
	return fallback
