## 可消费的首次/末次/返回参数；数据覆盖与普通成长均已在适配前完成。
extends RefCounted
static func status_stacks(context: Dictionary, status: String) -> int:
	if context.has("target_statuses"):
		for item: Variant in context.target_statuses:
			if item is Dictionary and String(item.get("id",item.get("status_id",""))) == status: return int(item.get("stacks",0))
		return 0
	var target: Node = context.get("target") as Node
	return int(target.get_status_stack(status)) if target != null and target.has_method("get_status_stack") else 0
static func prepare(params: Dictionary, context: Dictionary, type: String) -> Dictionary:
	var result: Dictionary = params.duplicate(true)
	var first: bool = int(context.get("milestone_hit_index",0)) == 0
	if type == "apply_status":
		if first and params.has("first_hit_stacks"): result.stack = int(params.first_hit_stacks)
		if context.get("milestone_first_tick",false): result.stack = int(result.get("stack",1))+int(params.get("first_tick_extra_stacks",0))
		if params.has("first_uncursed_stacks") and status_stacks(context,"cursed") == 0 and first: result.stack = int(params.first_uncursed_stacks)
	if type == "deal_damage":
		var scale: float = float(params.get("last_tick_multiplier",1.0)) if context.get("milestone_last_tick",false) else 1.0
		if params.has("bonus_status") and status_stacks(context,String(params.bonus_status)) > 0: scale *= float(params.get("bonus_multiplier",1.0))
		preload("res://scripts/skills/skill_replay_service.gd").scale_damage(result,scale)
	return result
static func restore_cooldown(params: Dictionary, context: Dictionary) -> bool:
	var skill: RefCounted = context.get("skill_instance") as RefCounted
	if skill == null: return false
	var key: String = "milestone_refund:"+String(context.get("source_instance_id",context.get("cast_instance_id",context.get("event_id",0))))
	var used: Dictionary = skill.get_meta("milestone_refunds",{})
	if used.has(key): return false
	used[key] = true
	if used.size() > 256: used.erase(used.keys()[0])
	skill.set_meta("milestone_refunds",used)
	skill.cooldown_remaining = maxf(float(skill.cooldown_remaining)-float(params.get("seconds",0.5)),0.0)
	return true
