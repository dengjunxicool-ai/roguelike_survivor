## 用最终动作生成真实输出；不记录复制、不重抽品质、不施加第二份成长。
extends RefCounted
class_name SkillReplayService
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Targeting = preload("res://scripts/skills/targeting_service.gd")
var _executor: RefCounted = Executor.new()
const Snapshots = preload("res://scripts/skills/skill_cast_snapshot_service.gd")
func replay(snapshot: Dictionary, context: Dictionary, damage_scale: float) -> bool:
	if snapshot.is_empty() or int(snapshot.get("version",0)) != 1 or not snapshot.get("base_growth_applied",false): return false
	var actions: Array = Snapshots.filter_actions(snapshot.get("actions",[]))
	if actions.is_empty(): return false
	var child: Dictionary = context.duplicate(true)
	child.erase("_cast_result")
	child.erase("is_cast_source")
	child["is_copy"] = true
	child["proc_depth"] = mini(int(context.get("proc_depth",0))+1,2)
	child["can_generate_secondary_proc"] = false
	child["parent_event_id"] = int(context.get("event_id",0))
	child["origin_skill_id"] = StringName(snapshot.origin_skill_id)
	child["skill_id"] = StringName(snapshot.origin_skill_id)
	child["power"] = float(snapshot.get("power",100.0))
	child["status_power_snapshot"] = true
	child["cast_damage_multiplier"] = 1.0
	var manager: Node = context.get("skill_manager") as Node
	child["skill_instance"] = manager.get_skill(snapshot.origin_skill_id) if manager != null else null
	if child.skill_instance == null and manager != null:
		var primary: RefCounted = manager.get_primary_attack_method()
		if primary != null and String(primary.skill_id)==String(snapshot.origin_skill_id): child.skill_instance = primary
	if child.skill_instance == null: return false
	var target: Node = child.get("target") as Node
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion() or (target.has_method("is_dead") and target.is_dead()):
		child["target"] = Targeting.find_target(context.get("caster"),"nearest_enemy",{"range":INF})
	if child.get("target") == null: return false
	scale_damage(actions, maxf(damage_scale,0.0))
	var executor: RefCounted = _executor
	var succeeded: bool = false
	for action: Dictionary in actions:
		var result: Variant = executor.execute_action(action,child)
		succeeded = succeeded or (result is bool and result) or ((result is int or result is float) and result > 0)
	return succeeded
static func scale_damage(value: Variant, multiplier: float) -> void:
	if value is Array:
		for child: Variant in value: scale_damage(child,multiplier)
	elif value is Dictionary:
		for key: Variant in value.keys():
			if key in ["amount","damage","power_scale","power_scale_per_stack","amount_per_stack","last_target_bonus_power","extra_main_power"]:
				if value[key] is int or value[key] is float: value[key] = float(value[key])*multiplier
				elif value[key] is Dictionary and value[key].get("stat","") == "power": value[key]["scale"] = float(value[key].get("scale",1.0))*multiplier
			else: scale_damage(value[key],multiplier)
