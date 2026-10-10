## 次级输出允许基础状态反应，不允许再次生成复制、回响等输出链。
extends RefCounted
class_name SkillProcPolicy
static func can_generate(context: Dictionary, proc_id: StringName) -> bool:
	var depth: int = int(context.get("proc_depth", 0))
	if depth >= 2:
		return false
	if proc_id == &"status_reaction":
		return true
	return not bool(context.get("is_copy", false)) and bool(context.get("can_generate_secondary_proc", depth == 0))
static func child_context(context: Dictionary, proc_id: StringName) -> Dictionary:
	var child: Dictionary = context.duplicate(true)
	child["parent_event_id"] = int(context.get("event_id", 0))
	child["proc_depth"] = int(context.get("proc_depth", 0)) + 1
	child["can_generate_secondary_proc"] = false
	child["cast_damage_multiplier"] = 1.0
	child["is_copy"] = bool(context.get("is_copy", false)) or proc_id == &"copy"
	child["origin_skill_id"] = context.get("listener_skill_id", context.get("origin_skill_id", ""))
	return child
