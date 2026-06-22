extends RefCounted
class_name DamageTraceContext


const TRACE_ID_KEY: String = "debug_attack_trace_id"
const LAST_TRACE_CONTEXT_META: String = "last_damage_trace_context"


static func current_trace_id(root: Node) -> int:
	return int(root.get_meta(TRACE_ID_KEY, 0)) if root != null else 0


static func normalize_event_context(event_context: Dictionary, root: Node = null, allow_current_trace: bool = false) -> Dictionary:
	var context: Dictionary = event_context.duplicate(true)
	var trace_id: int = get_trace_id(context, root, allow_current_trace)
	if trace_id > 0:
		context[TRACE_ID_KEY] = trace_id
	return context


static func apply_to_packet(packet: Dictionary, context: Variant, root: Node = null, allow_current_trace: bool = false) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	var trace_id: int = get_trace_id(context, root, allow_current_trace)
	if trace_id > 0:
		result[TRACE_ID_KEY] = trace_id
	return result


static func apply_to_status_params(status_params: Dictionary, context: Variant, root: Node = null, allow_current_trace: bool = false) -> Dictionary:
	var result: Dictionary = status_params.duplicate(true)
	var trace_id: int = get_trace_id(context, root, allow_current_trace)
	if trace_id > 0:
		result[TRACE_ID_KEY] = trace_id
	return result


static func apply_to_node_meta(node: Node, context: Variant, root: Node = null, allow_current_trace: bool = false) -> int:
	if node == null:
		return 0
	var trace_id: int = get_trace_id(context, root, allow_current_trace)
	if trace_id > 0:
		node.set_meta(TRACE_ID_KEY, trace_id)
	return trace_id


static func persist_last_damage_trace(target: Node, amount_or_packet: Variant, damage_result: Dictionary = {}) -> void:
	if target == null:
		return
	var trace_id: int = get_trace_id({
		TRACE_ID_KEY: _value_from_source(amount_or_packet, TRACE_ID_KEY, damage_result.get(TRACE_ID_KEY, 0)),
		"damage_packet": amount_or_packet
	})
	var trace_context: Dictionary = {
		TRACE_ID_KEY: trace_id,
		"source_id": String(_value_from_source(amount_or_packet, "source_id", damage_result.get("source_id", ""))),
		"source_skill_id": String(_value_from_source(amount_or_packet, "source_skill_id", damage_result.get("source_skill_id", ""))),
		"source_instance_id": String(_value_from_source(amount_or_packet, "source_instance_id", damage_result.get("source_instance_id", ""))),
		"damage_origin": String(damage_result.get("damage_origin", _value_from_source(amount_or_packet, "damage_origin", ""))),
		"damage_type": String(damage_result.get("damage_type", _value_from_source(amount_or_packet, "damage_type", ""))),
		"element": String(damage_result.get("element", _value_from_source(amount_or_packet, "element", "")))
	}
	target.set_meta(LAST_TRACE_CONTEXT_META, trace_context)


static func get_last_damage_trace_context(node: Node) -> Dictionary:
	if node == null:
		return {}
	var value: Variant = node.get_meta(LAST_TRACE_CONTEXT_META, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func get_last_damage_trace_id(node: Node) -> int:
	return int(get_last_damage_trace_context(node).get(TRACE_ID_KEY, 0))


static func get_trace_id(value: Variant = {}, root: Node = null, allow_current_trace: bool = false) -> int:
	var direct_id: int = _trace_id_from_value(value)
	if direct_id > 0:
		return direct_id
	if allow_current_trace:
		return current_trace_id(root)
	return 0


static func _trace_id_from_value(value: Variant) -> int:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var direct: int = int(dictionary.get(TRACE_ID_KEY, 0))
		if direct > 0:
			return direct
		for packet_key: String in ["damage_packet", "packet", "source_packet", "amount_or_packet", "status"]:
			var packet_id: int = _trace_id_from_value(dictionary.get(packet_key))
			if packet_id > 0:
				return packet_id
		for node_key: String in ["source", "projectile", "area", "orbit_object", "enemy", "target"]:
			var node_id: int = _trace_id_from_value(dictionary.get(node_key))
			if node_id > 0:
				return node_id
		return 0
	if value is Node:
		var node: Node = value
		var meta_id: int = int(node.get_meta(TRACE_ID_KEY, 0))
		if meta_id > 0:
			return meta_id
		return get_last_damage_trace_id(node)
	if value is RefCounted and value.has_method("get_value"):
		return int(value.call("get_value", TRACE_ID_KEY, 0))
	return 0


static func _value_from_source(source: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if source is Dictionary:
		return (source as Dictionary).get(key, fallback)
	if source is RefCounted and source.has_method("get_value"):
		return source.call("get_value", key, fallback)
	return fallback
