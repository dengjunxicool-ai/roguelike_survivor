extends RefCounted
class_name DamageRoundingService


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")

static var _fractional_buffers: Dictionary = {}


static func resolve(float_damage: float, packet: Dictionary, target: Node) -> int:
	if float_damage <= 0.0:
		return 0

	if _uses_fractional_buffer(packet):
		return _resolve_fractional(float_damage, packet, target)

	var final_damage: int = roundi(float_damage)
	if bool(packet.get("ignore_min_damage", false)):
		return maxi(final_damage, 0)
	return maxi(final_damage, 1)


static func resolve_for_context(float_damage: float, calculation_context: RefCounted) -> int:
	if float_damage <= 0.0:
		return 0

	if _uses_fractional_buffer_for_context(calculation_context):
		return _resolve_fractional_for_context(float_damage, calculation_context)

	var final_damage: int = roundi(float_damage)
	if bool(calculation_context.call("packet_value", "ignore_min_damage", false)):
		return maxi(final_damage, 0)
	return maxi(final_damage, 1)


static func clear_target(target: Node) -> void:
	if target == null:
		return

	var prefix: String = "%s:" % str(target.get_instance_id())
	for key: Variant in _fractional_buffers.keys():
		if String(key).begins_with(prefix):
			_fractional_buffers.erase(key)


static func _resolve_fractional(float_damage: float, packet: Dictionary, target: Node) -> int:
	var key: String = _buffer_key(packet, target)
	var buffered: float = float(_fractional_buffers.get(key, 0.0)) + float_damage
	var final_damage: int = floori(buffered)
	_fractional_buffers[key] = buffered - float(final_damage)
	return final_damage


static func _resolve_fractional_for_context(float_damage: float, calculation_context: RefCounted) -> int:
	var key: String = _buffer_key_for_context(calculation_context)
	var buffered: float = float(_fractional_buffers.get(key, 0.0)) + float_damage
	var final_damage: int = floori(buffered)
	_fractional_buffers[key] = buffered - float(final_damage)
	return final_damage


static func _uses_fractional_buffer(packet: Dictionary) -> bool:
	return DamageRuleRegistryScript.uses_fractional_buffer(packet)


static func _uses_fractional_buffer_for_context(calculation_context: RefCounted) -> bool:
	if bool(calculation_context.call("packet_value", "ignore_fractional_buffer", false)):
		return false
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", ""))
	var field_damage_model: String = String(calculation_context.call("packet_value", "field_damage_model", ""))
	return damage_type == DamageRuleRegistryScript.TYPE_STATUS_DOT or field_damage_model == "dot_tick" or bool(calculation_context.call("packet_value", "uses_fractional_buffer", false))


static func _buffer_key(packet: Dictionary, target: Node) -> String:
	var target_key: String = str(target.get_instance_id()) if target != null else "no_target"
	var source_instance_id: String = String(packet.get("source_instance_id", packet.get("source_id", packet.get("source_skill_id", "unknown"))))
	var damage_origin: String = String(packet.get("damage_origin", "unknown"))
	var damage_type: String = String(packet.get("damage_type", "unknown"))
	var element: String = String(packet.get("element", "neutral"))
	return "%s:%s:%s:%s:%s" % [target_key, source_instance_id, damage_origin, damage_type, element]


static func _buffer_key_for_context(calculation_context: RefCounted) -> String:
	var target: Node = calculation_context.get("target") as Node
	var target_key: String = str(target.get_instance_id()) if target != null else "no_target"
	var source_fallback: Variant = calculation_context.call("packet_value", "source_id", calculation_context.call("packet_value", "source_skill_id", "unknown"))
	var source_instance_id: String = String(calculation_context.call("packet_value", "source_instance_id", source_fallback))
	var damage_origin: String = String(calculation_context.call("packet_value", "damage_origin", "unknown"))
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", "unknown"))
	var element: String = String(calculation_context.call("packet_value", "element", "neutral"))
	return "%s:%s:%s:%s:%s" % [target_key, source_instance_id, damage_origin, damage_type, element]
