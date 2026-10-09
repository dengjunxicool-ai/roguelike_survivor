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
	var target: Node = result.get("target") as Node
	if not result.has("target_statuses") and target != null and event_name in [&"attack_hit", &"on_projectile_hit", &"area_tick", &"post_damage_hit"]:
		var statuses: Node = target.get_node_or_null("StatusEffectManager")
		if statuses != null: result["target_statuses"] = statuses.get_status_snapshot()
	var object_id: int = int(packet.get("source_object_id",0))
	if object_id>0 and is_instance_id_valid(object_id):
		var object: Node = instance_from_id(object_id) as Node
		if object!=null and not object.is_queued_for_deletion() and int(object.get("spawn_generation"))==int(packet.get("source_generation",-1)):
			var kind: String = String(packet.get("source_object_kind",""))
			if kind in ["projectile","area"] and not result.has(kind): result[kind]=object;result["source"]=object;result["source_id"]=object.source_id
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
