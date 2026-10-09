## 保留原始施放/命中来源；监听技能通过 listener_skill_id 单独标识。
extends RefCounted
class_name SkillEventContext
const PROC_FIELDS: Array[String] = ["origin_skill_id", "listener_skill_id", "event_id", "parent_event_id", "proc_depth", "is_copy", "can_generate_secondary_proc", "combat_seconds"]
static func from_context(context: Dictionary, event_name: StringName) -> Dictionary:
	var result: Dictionary = context.duplicate(true)
	var packet: Dictionary = context.get("damage_packet", {}) if context.get("damage_packet", {}) is Dictionary else {}
	for field: String in PROC_FIELDS:
		if not result.has(field) and packet.has(field):
			result[field] = packet[field]
	result["origin_skill_id"] = StringName(String(result.get("origin_skill_id", result.get("source_skill_id", result.get("skill_id", "")))))
	result["listener_skill_id"] = StringName(String(result.get("listener_skill_id", "")))
	result["parent_event_id"] = int(result.get("parent_event_id", 0))
	result["proc_depth"] = maxi(int(result.get("proc_depth", 0)), 0)
	result["is_copy"] = bool(result.get("is_copy", false))
	result["can_generate_secondary_proc"] = bool(result.get("can_generate_secondary_proc", result.proc_depth == 0 and not result.is_copy))
	result["combat_seconds"] = float(result.get("combat_seconds", 0.0))
	result["event_name"] = event_name
	var manager: Node = context.get("skill_manager") as Node
	var caster: Node = context.get("caster") as Node
	if manager == null and caster != null:
		manager = caster.get_node_or_null("SkillManager")
	var origin: RefCounted = manager.call("get_skill", result.origin_skill_id) as RefCounted if manager != null else null
	if origin == null:
		var candidate: RefCounted = context.get("skill_instance") as RefCounted
		if candidate != null and StringName(String(candidate.get("skill_id"))) == result.origin_skill_id:
			origin = candidate
	result["origin_skill_instance"] = origin
	if not result.has("source_tags"):
		var tags: Array = []
		var definition: RefCounted = origin.get("definition") as RefCounted if origin != null else null
		if definition != null:
			tags.append_array(definition.get("tags"))
			if context.get("area") is Node:
				tags.append("%s_area" % definition.get("school"))
		result["source_tags"] = tags
	return result

## 排队期间目标或来源可以销毁；派发前清除失效引用，保留纯数值来源快照。
static func purge_invalid_references(context: Dictionary) -> void:
	for key: Variant in context.keys():
		var value: Variant = context[key]
		if typeof(value) == TYPE_OBJECT and not is_instance_valid(value):
			context[key] = null
		elif value is Dictionary:
			purge_invalid_references(value)
		elif value is Array:
			for index: int in value.size():
				if typeof(value[index]) == TYPE_OBJECT and not is_instance_valid(value[index]): value[index] = null
				elif value[index] is Dictionary: purge_invalid_references(value[index])
