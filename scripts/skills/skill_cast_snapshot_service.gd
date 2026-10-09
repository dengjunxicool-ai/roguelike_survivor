## 成功输出的纯数据记录；最终动作已应用成长，复制不得再次适配。
extends RefCounted
class_name SkillCastSnapshotService
const ALLOWED := ["deal_damage", "apply_status", "spawn_projectile", "spawn_projectiles_at_targets", "spawn_projectile_burst", "spawn_area", "instant_area_hit", "chain_to_targets", "pull", "knockback"]
var _records: Array[Dictionary] = []
func record(context: Dictionary, actions: Array) -> bool:
	var skill: RefCounted = context.get("skill_instance") as RefCounted
	if skill == null or String(skill.skill_type) not in ["attack", "cast"] or bool(context.get("is_copy", false)) or int(context.get("proc_depth",0)) > 0:
		return false
	var safe: Array = filter_actions(actions)
	_embed_owned_projectile_hits(safe, skill)
	if safe.is_empty(): return false
	var item: Dictionary = {"version":1,"origin_skill_id":String(skill.skill_id),"school":String(skill.school),"skill_type":String(skill.skill_type),"actions":safe,"base_growth_applied":true,"power":float(context.get("power",100.0))}
	clear_origin(skill.skill_id)
	_records.append(JSON.parse_string(JSON.stringify(item)))
	return true
func get_last(filter: Dictionary = {}) -> Dictionary:
	for i: int in range(_records.size()-1,-1,-1):
		var item: Dictionary = _records[i]
		if filter.has("skill_type") and item.skill_type != filter.skill_type: continue
		if filter.has("exclude_school") and item.school == filter.exclude_school: continue
		return item.duplicate(true)
	return {}
func clear_origin(skill_id: StringName) -> void:
	_records = _records.filter(func(x: Dictionary) -> bool: return x.origin_skill_id != String(skill_id))
func clear() -> void:
	_records.clear()
static func filter_actions(actions: Array) -> Array:
	var result: Array = []
	for raw: Variant in actions:
		if not raw is Dictionary or String(raw.get("type","")) not in ALLOWED: continue
		var action: Dictionary = pure_data(raw)
		var params: Dictionary = action.get("params",{})
		for key: String in params.keys():
			if key.begins_with("effects_") or key == "on_hit": params.erase(key)
			elif key.begins_with("actions") and params[key] is Array: params[key] = filter_actions(params[key])
		result.append(action)
	return result
static func pure_data(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if value[key] is Object or value[key] is Callable or value[key] is Vector2: continue
			result[String(key)] = pure_data(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			if not item is Object and not item is Callable: result.append(pure_data(item))
		return result
	return String(value) if value is StringName else value

# Legacy attacks deliver their own damage via a hit event. Copy its pure payload,
# rather than allowing unrelated listeners to fire on a derived projectile.
static func _embed_owned_projectile_hits(actions: Array, skill: RefCounted) -> void:
	var events: Array = skill.definition.events.duplicate(true)
	events.append_array(skill.runtime_events)
	for action: Dictionary in actions:
		if String(action.type) not in ["spawn_projectile","spawn_projectile_burst","spawn_projectiles_at_targets"]: continue
		var params: Dictionary = action.params
		var hits: Array = params.get("actions_on_hit",[])
		for event: Dictionary in events:
			if String(event.get("trigger","")) != "on_projectile_hit": continue
			if event.has("source_id") and String(event.source_id) != String(params.get("projectile_id","")): continue
			var payload: Array = filter_actions(event.get("actions",[]))
			for hit: Dictionary in payload:
				if event.has("conditions"): hit["conditions"] = pure_data(event.conditions)
			hits.append_array(payload)
		params["actions_on_hit"] = hits
