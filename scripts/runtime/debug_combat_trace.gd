## 文件用途：为调试单次攻击记录爆炸位置和伤害结算视图，维护根节点 trace 记录及可清理范围圈。
## 使用方式：由调试面板 begin_attack_trace 开始批次；战斗入口调用 record_damage/record_explosion；界面用 get_records 读取深拷贝并可 clear。
extends RefCounted
class_name DebugCombatTrace


const DebugExplosionSiteOverlayScript: Script = preload("res://scripts/runtime/debug_explosion_site_overlay.gd")
const DamageTraceContextScript: Script = preload("res://scripts/runtime/damage_trace_context.gd")

const TRACE_ID_META: String = "debug_attack_trace_id"
const TRACE_RECORDS_META: String = "debug_combat_trace_records"


## 作用：递增根节点攻击 trace，清空旧记录并返回新 ID；空根节点返回零。
## 使用：传入 SceneTree 根节点，返回递增 trace ID；会清空已有记录，空 root 返回零。
static func begin_attack_trace(root: Node) -> int:
	if root == null:
		return 0

	var trace_id: int = int(root.get_meta(TRACE_ID_META, 0)) + 1
	root.set_meta(TRACE_ID_META, trace_id)
	root.set_meta(TRACE_RECORDS_META, [])
	return trace_id


## 作用：委托 DamageTraceContext 查询根节点当前攻击 trace。
## 使用：通过预加载脚本的 current_attack_trace_id(...) 静态入口调用。 入参：root: Node。 返回 int；具体值及空输入行为见作用说明。
static func current_attack_trace_id(root: Node) -> int:
	return DamageTraceContextScript.current_trace_id(root)


## 作用：调试模式下创建爆炸位置覆盖层，再记录半径、技能与伤害包字段；无正数 trace 不保存记录。
## 使用：传入场景根/挂载父节点、世界位置、半径和技能来源；可选 trace_id 与伤害包字典补齐追踪字段，调试关闭时跳过。
static func record_explosion(root: Node, parent: Node, position: Vector2, radius: float, skill_id: String, source_instance_id: String, trace_id: int = 0, damage_packet: Dictionary = {}) -> void:
	if root == null or not _is_debug_enabled(root):
		return

	var overlay_parent: Node = _resolve_parent(parent)
	if overlay_parent != null:
		var overlay: Node2D = DebugExplosionSiteOverlayScript.new() as Node2D
		overlay.name = "DebugExplosionSiteOverlay_%d" % Time.get_ticks_msec()
		overlay.global_position = position
		overlay.call("setup", radius, "%s explosion %.0f" % [skill_id, radius])
		overlay_parent.add_child(overlay)

	if trace_id <= 0:
		trace_id = current_attack_trace_id(root)
	if trace_id <= 0:
		return

	var record: Dictionary = {
		"type": "explosion",
		"trace_id": trace_id,
		"skill_id": skill_id,
		"source_instance_id": source_instance_id,
		"position": position,
		"radius": radius
	}
	if not damage_packet.is_empty():
		record["damage_packet"] = damage_packet.duplicate(true)
		_copy_packet_field(record, damage_packet, "raw_amount")
		_copy_packet_field(record, damage_packet, "amount")
		_copy_packet_field(record, damage_packet, "damage_origin")
		_copy_packet_field(record, damage_packet, "damage_type")
		_copy_packet_field(record, damage_packet, "element")
		_copy_packet_field(record, damage_packet, "source_type")
		_copy_packet_field(record, damage_packet, "source_id")
		_copy_packet_field(record, damage_packet, "source_origin_id")
		_copy_packet_field(record, damage_packet, "source_skill_id")
		_copy_packet_field(record, damage_packet, "can_crit")
		_copy_packet_field(record, damage_packet, "uses_character_damage_multiplier")
		_copy_packet_field(record, damage_packet, "uses_skill_level_coefficient")
		_copy_packet_field(record, damage_packet, "skill_level_coefficient")
	_append_record(root, record)


## 作用：仅记录调试模式中与当前 trace 匹配的伤害，保存来源、公式阶段和最终伤害，并绘制状态 DOT 命中点。
## 使用：在伤害结算后传入 root、目标、来源包、DamageResult 字典视图和 final_amount；仅保存当前 trace 的调试记录，不在此结算伤害。
static func record_damage(root: Node, target: Node, amount_or_packet: Variant, damage_result: Dictionary, final_amount: int) -> void:
	if root == null or not _is_debug_enabled(root):
		return

	var trace_id: int = DamageTraceContextScript.get_trace_id(amount_or_packet)
	if trace_id <= 0 or trace_id != current_attack_trace_id(root):
		return

	var target_name: String = "unknown"
	if target != null:
		target_name = String(target.get("enemy_id")) if target.get("enemy_id") != null else target.name

	var record: Dictionary = {
		"type": "damage",
		"trace_id": trace_id,
		"target": target_name,
		"target_id": str(target.get_instance_id()) if target != null else "",
		"source_skill_id": String(_packet_value(amount_or_packet, "source_skill_id", damage_result.get("source_skill_id", ""))),
		"source_origin_id": String(_packet_value(amount_or_packet, "source_origin_id", damage_result.get("source_origin_id", ""))),
		"source_type": String(_packet_value(amount_or_packet, "source_type", "")),
		"source_instance_id": String(_packet_value(amount_or_packet, "source_instance_id", "")),
		"raw_amount": float(damage_result.get("raw_amount", _packet_value(amount_or_packet, "raw_amount", 0.0))),
		"final_amount": final_amount,
		"multiplier": float(damage_result.get("multiplier", 1.0)),
		"is_critical": bool(damage_result.get("is_critical", false)),
		"damage_origin": String(damage_result.get("damage_origin", _packet_value(amount_or_packet, "damage_origin", ""))),
		"damage_type": String(damage_result.get("damage_type", _packet_value(amount_or_packet, "damage_type", ""))),
		"element": String(damage_result.get("element", _packet_value(amount_or_packet, "element", ""))),
		"stages": _get_dictionary(damage_result.get("trace", damage_result.get("stages", {})))
	}
	_append_record(root, record)
	_record_element_damage_site(root, target, record, final_amount)


## 作用：释放 debug_explosion_site_overlays 组覆盖层并清空记录与 trace ID，返回待释放覆盖层数。
## 使用：通过预加载脚本的 clear(...) 静态入口调用。 入参：root: Node。 返回 int；具体值及空输入行为见作用说明。
static func clear(root: Node) -> int:
	if root == null:
		return 0

	var cleared: int = 0
	var tree: SceneTree = root.get_tree()
	if tree != null:
		for node: Node in tree.get_nodes_in_group(&"debug_explosion_site_overlays"):
			if node != null and is_instance_valid(node):
				node.queue_free()
				cleared += 1

	root.set_meta(TRACE_RECORDS_META, [])
	root.set_meta(TRACE_ID_META, 0)
	return cleared


## 作用：深拷贝根节点追踪记录数组，供面板读取时避免污染存储。
## 使用：传入记录所在 root，返回记录数组深拷贝；调用方可排序、展示而不修改根记录。
static func get_records(root: Node) -> Array:
	if root == null:
		return []

	var records_variant: Variant = root.get_meta(TRACE_RECORDS_META, [])
	if records_variant is Array:
		return (records_variant as Array).duplicate(true)
	return []


## 作用：为状态 DOT 伤害目标创建元素色位置圈和伤害标签，非 Node2D 或无父容器时跳过。
## 使用：通过预加载脚本的 _record_element_damage_site(...) 静态入口调用。 入参：root: Node, target: Node, record: Dictionary, final_amount: int。
static func _record_element_damage_site(root: Node, target: Node, record: Dictionary, final_amount: int) -> void:
	if not _should_record_element_damage_site(record):
		return
	var target_2d: Node2D = target as Node2D
	if target_2d == null:
		return

	var overlay_parent: Node = _resolve_parent(target_2d.get_parent())
	if overlay_parent == null:
		return

	var element: String = String(record.get("element", ""))
	var source_skill_id: String = String(record.get("source_skill_id", ""))
	var overlay: Node2D = DebugExplosionSiteOverlayScript.new() as Node2D
	overlay.name = "DebugElementDamageSiteOverlay_%d" % Time.get_ticks_msec()
	overlay.global_position = target_2d.global_position
	overlay.set("ring_color", _element_site_color(element))
	overlay.call("setup", 30.0, "%s tick %d" % [source_skill_id if source_skill_id != "" else element, final_amount])
	overlay_parent.add_child(overlay)


## 作用：根据伤害起源、类型或来源是否表示状态 DOT，决定是否绘制元素伤害位置圈。
## 使用：通过预加载脚本的 _should_record_element_damage_site(...) 静态入口调用。 入参：record: Dictionary。 返回 bool；具体值及空输入行为见作用说明。
static func _should_record_element_damage_site(record: Dictionary) -> bool:
	var damage_origin: String = String(record.get("damage_origin", ""))
	var damage_type: String = String(record.get("damage_type", ""))
	var source_type: String = String(record.get("source_type", ""))
	return damage_origin == "status_dot" or damage_type == "status_dot" or source_type == "status"


## 作用：按元素映射调试位置圈颜色，未知元素使用淡蓝色。
## 使用：通过预加载脚本的 _element_site_color(...) 静态入口调用。 入参：element: String。 返回 Color；具体值及空输入行为见作用说明。
static func _element_site_color(element: String) -> Color:
	match element:
		"fire", "burning":
			return Color(1.0, 0.32, 0.08, 0.86)
		"poison":
			return Color(0.42, 1.0, 0.18, 0.82)
		"bleed":
			return Color(0.95, 0.05, 0.08, 0.82)
		"ice":
			return Color(0.48, 0.82, 1.0, 0.82)
		"lightning":
			return Color(1.0, 0.9, 0.2, 0.84)
		"holy":
			return Color(1.0, 0.92, 0.54, 0.84)
		_:
			return Color(0.68, 0.88, 1.0, 0.78)


## 作用：深拷贝追加一条追踪记录并写回根节点元数据。
## 使用：通过预加载脚本的 _append_record(...) 静态入口调用。 入参：root: Node, record: Dictionary。
static func _append_record(root: Node, record: Dictionary) -> void:
	var records: Array = get_records(root)
	records.append(record.duplicate(true))
	root.set_meta(TRACE_RECORDS_META, records)


## 作用：仅在 packet 含 key 时把该字段复制到 record，补齐爆炸记录的来源及公式开关。
## 使用：通过预加载脚本的 _copy_packet_field(...) 静态入口调用。 入参：record: Dictionary, packet: Dictionary, key: String。
static func _copy_packet_field(record: Dictionary, packet: Dictionary, key: String) -> void:
	if packet.has(key):
		record[key] = packet[key]


## 作用：查询根节点开发模式或调试手控标志，确定是否允许记录诊断内容。
## 使用：通过预加载脚本的 _is_debug_enabled(...) 静态入口调用。 入参：root: Node。 返回 bool；具体值及空输入行为见作用说明。
static func _is_debug_enabled(root: Node) -> bool:
	return bool(root.get_meta("developer_mode_enabled", false)) or bool(root.get_meta("debug_control_mode", false))


## 作用：优先返回传入 parent，否则从主循环 SceneTree 取 current_scene。
## 使用：通过预加载脚本的 _resolve_parent(...) 静态入口调用。 入参：parent: Node。 返回 Node；具体值及空输入行为见作用说明。
static func _resolve_parent(parent: Node) -> Node:
	if parent != null:
		return parent

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null


## 作用：按接口从字典或 RefCounted 包读取字段，优先 get_value 再 packet_value，缺少接口用 fallback。
## 使用：通过预加载脚本的 _packet_value(...) 静态入口调用。 入参：packet_source: Variant, key: Variant, fallback: Variant = null。 返回 Variant；具体值及空输入行为见作用说明。
static func _packet_value(packet_source: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).get(key, fallback)
	if packet_source is RefCounted:
		if packet_source.has_method("get_value"):
			return packet_source.call("get_value", key, fallback)
		if packet_source.has_method("packet_value"):
			return packet_source.call("packet_value", key, fallback)
	return fallback


## 作用：对字典返回深拷贝，其他值返回空字典，供隔离记录中的公式阶段视图。
## 使用：通过预加载脚本的 _get_dictionary(...) 静态入口调用。 入参：value: Variant。 返回 Dictionary；具体值及空输入行为见作用说明。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
