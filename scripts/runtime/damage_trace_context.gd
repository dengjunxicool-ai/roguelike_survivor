## 文件用途：在事件字典、DamagePacket、状态参数和节点元数据之间传递调试攻击 trace，并保存最近受击来源。
## 使用方式：预加载 DamageTraceContext 后调用静态方法；创建继发伤害或状态时传入原上下文，只有显式允许才回退到当前根 trace。
extends RefCounted
class_name DamageTraceContext


const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")

const TRACE_ID_KEY: String = "debug_attack_trace_id"
const LAST_TRACE_CONTEXT_META: String = "last_damage_trace_context"


## 作用：读取根节点 debug_attack_trace_id，根节点为空返回零。
## 使用：通过预加载脚本的 current_trace_id(...) 静态入口调用。 入参：root: Node。 返回 int；具体值及空输入行为见作用说明。
static func current_trace_id(root: Node) -> int:
	return int(root.get_meta(TRACE_ID_KEY, 0)) if root != null else 0


## 作用：深拷贝事件上下文并补入解析出的正数 trace ID，保留输入字典不变。
## 使用：通过预加载脚本的 normalize_event_context(...) 静态入口调用。 入参：event_context: Dictionary, root: Node = null, allow_current_trace: bool = false。 返回 Dictionary；具体值及空输入行为见作用说明。
static func normalize_event_context(event_context: Dictionary, root: Node = null, allow_current_trace: bool = false) -> Dictionary:
	var context: Dictionary = event_context.duplicate(true)
	for field: String in ["origin_skill_id", "listener_skill_id", "event_id", "parent_event_id", "proc_depth", "is_copy", "can_generate_secondary_proc", "combat_seconds", "cast_damage_multiplier"]:
		if not context.has(field):
			var value: Variant = _value_from_context(event_context, field, null)
			if value != null: context[field] = value
	var trace_id: int = get_trace_id(context, root, allow_current_trace)
	if trace_id > 0:
		context[TRACE_ID_KEY] = trace_id
	return context


## 作用：深拷贝 packet 字典并从 context 传递正数 trace ID，返回新的事件/记录视图。
## 使用：packet 是显式字典视图，context 是原事件/包/节点；返回带 trace 的深拷贝，不修改输入。仅 allow_current_trace=true 时采用 root 当前 trace。
static func apply_to_packet(packet: Dictionary, context: Variant, root: Node = null, allow_current_trace: bool = false) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	for field: String in ["origin_skill_id", "listener_skill_id", "event_id", "parent_event_id", "proc_depth", "is_copy", "can_generate_secondary_proc", "combat_seconds", "cast_damage_multiplier"]:
		var value: Variant = _value_from_context(context, field, null)
		if value != null:
			result[field] = value
	var trace_id: int = get_trace_id(context, root, allow_current_trace)
	if trace_id > 0:
		result[TRACE_ID_KEY] = trace_id
	return result


## 作用：深拷贝状态参数，补齐 trace 和缺失的来源、攻击者标识，已有非空来源保持不变。
## 使用：传入待施加状态参数与来源 context，返回补齐 trace/来源的参数深拷贝；已有非空来源优先，root 当前 trace 仅显式允许时使用。
static func apply_to_status_params(status_params: Dictionary, context: Variant, root: Node = null, allow_current_trace: bool = false) -> Dictionary:
	var result: Dictionary = status_params.duplicate(true)
	var trace_id: int = get_trace_id(context, root, allow_current_trace)
	if trace_id > 0:
		result[TRACE_ID_KEY] = trace_id
	for key: String in ["source_origin_id", "source_skill_id", "source_instance_id", "attacker_id", "origin_skill_id", "listener_skill_id", "event_id", "parent_event_id", "proc_depth", "is_copy", "can_generate_secondary_proc", "combat_seconds"]:
		if result.has(key) and result[key] != null and str(result[key]) != "":
			continue
		var source_value: Variant = _value_from_context(context, key, null)
		if source_value != null and str(source_value) != "":
			result[key] = source_value
	return result


## 作用：解析 context 的 trace 并写入 node 元数据，返回 ID；空节点返回零。
## 使用：通过预加载脚本的 apply_to_node_meta(...) 静态入口调用。 入参：node: Node, context: Variant, root: Node = null, allow_current_trace: bool = false。 返回 int；具体值及空输入行为见作用说明。
static func apply_to_node_meta(node: Node, context: Variant, root: Node = null, allow_current_trace: bool = false) -> int:
	if node == null:
		return 0
	var trace_id: int = get_trace_id(context, root, allow_current_trace)
	if trace_id > 0:
		node.set_meta(TRACE_ID_KEY, trace_id)
	return trace_id


## 作用：从伤害输入和结算视图提取 trace、来源及元素，保存到目标 last_damage_trace_context 元数据。
## 使用：target 为受击目标，amount_or_packet 为伤害来源输入，damage_result 为结算字典视图；写目标元数据，供死亡继发伤害继续传递来源。
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
	for field: String in ["origin_skill_id", "listener_skill_id", "event_id", "parent_event_id", "proc_depth", "is_copy", "can_generate_secondary_proc", "combat_seconds"]:
		var value: Variant = _value_from_source(amount_or_packet, field, damage_result.get(field))
		if value != null: trace_context[field] = value
	target.set_meta(LAST_TRACE_CONTEXT_META, trace_context)


## 作用：返回节点最近伤害来源上下文的深拷贝，空节点或无记录返回空字典。
## 使用：通过预加载脚本的 get_last_damage_trace_context(...) 静态入口调用。 入参：node: Node。 返回 Dictionary；具体值及空输入行为见作用说明。
static func get_last_damage_trace_context(node: Node) -> Dictionary:
	if node == null:
		return {}
	var value: Variant = node.get_meta(LAST_TRACE_CONTEXT_META, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：从最近受击上下文取得 trace ID，无记录返回零。
## 使用：通过预加载脚本的 get_last_damage_trace_id(...) 静态入口调用。 入参：node: Node。 返回 int；具体值及空输入行为见作用说明。
static func get_last_damage_trace_id(node: Node) -> int:
	return int(get_last_damage_trace_context(node).get(TRACE_ID_KEY, 0))


## 作用：优先解析 value 内携带的正数 trace；仅 allow_current_trace=true 时回退读取 root 的当前 trace。
## 使用：value 可为上下文字典、节点或 DamagePacket；返回正数 trace 或零，root 回退由 allow_current_trace 控制。
static func get_trace_id(value: Variant = {}, root: Node = null, allow_current_trace: bool = false) -> int:
	var direct_id: int = _trace_id_from_value(value)
	if direct_id > 0:
		return direct_id
	if allow_current_trace:
		return current_trace_id(root)
	return 0


## 作用：递归从上下文字典、嵌套伤害/状态包、节点元数据或 DamagePacket 找 trace；拒绝失效对象。
## 使用：通过预加载脚本的 _trace_id_from_value(...) 静态入口调用。 入参：value: Variant。 返回 int；具体值及空输入行为见作用说明。
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
	if typeof(value) == TYPE_OBJECT and not is_instance_valid(value):
		return 0
	if value is Node:
		var node: Node = value
		var meta_id: int = int(node.get_meta(TRACE_ID_KEY, 0))
		if meta_id > 0:
			return meta_id
		return get_last_damage_trace_id(node)
	if value is DamagePacketScript:
		return int(value.call("get_value", TRACE_ID_KEY, 0))
	return 0


## 作用：按 key 从 Dictionary 或有效 DamagePacket 读值，其他类型及失效对象返回 fallback。
## 使用：通过预加载脚本的 _value_from_source(...) 静态入口调用。 入参：source: Variant, key: Variant, fallback: Variant = null。 返回 Variant；具体值及空输入行为见作用说明。
static func _value_from_source(source: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if source is Dictionary:
		return (source as Dictionary).get(key, fallback)
	if typeof(source) == TYPE_OBJECT and not is_instance_valid(source):
		return fallback
	if source is DamagePacketScript:
		return source.call("get_value", key, fallback)
	return fallback


## 作用：优先读取上下文直接字段，再从登记的嵌套包读取非空值，未匹配使用 fallback。
## 使用：通过预加载脚本的 _value_from_context(...) 静态入口调用。 入参：context: Variant, key: Variant, fallback: Variant = null。 返回 Variant；具体值及空输入行为见作用说明。
static func _value_from_context(context: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if not (context is Dictionary):
		return _value_from_source(context, key, fallback)
	var dictionary: Dictionary = context
	if dictionary.has(key):
		return dictionary.get(key)
	for packet_key: String in ["damage_packet", "packet", "source_packet", "amount_or_packet", "status"]:
		var value: Variant = _value_from_source(dictionary.get(packet_key), key, null)
		if value != null and str(value) != "":
			return value
	return fallback
