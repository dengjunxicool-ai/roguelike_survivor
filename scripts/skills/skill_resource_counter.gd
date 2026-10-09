## Fractional per-skill resources, stable occurrence/corpse deduplication.
extends RefCounted
class_name SkillResourceCounter
static func add(skill: RefCounted, key: StringName, amount: float, threshold: float) -> int:
	if skill == null or amount <= 0.0 or threshold <= 0.0: return 0
	var keys: Array = skill.get_meta("resource_keys", [])
	if not keys.has(key): keys.append(key)
	skill.set_meta("resource_keys", keys)
	var total: float = float(skill.get_meta(key, 0.0)) + amount
	var crossings: int = floori((total + 0.000001) / threshold)
	skill.set_meta(key, maxf(total - crossings * threshold, 0.0))
	return crossings
static func once(skill: RefCounted, key: String, token: String) -> bool:
	var seen: Dictionary = skill.get_meta("resource_seen", {})
	var identity: String = key + ":" + token
	if seen.has(identity): return false
	seen[identity] = true
	skill.set_meta("resource_seen", seen)
	return true
static func event_amount(skill: RefCounted, key: String, kind: String, context: Dictionary) -> float:
	var target: Node = context.get("target") as Node
	var event: String = String(context.get("event_name", ""))
	if bool(context.get("is_copy", false)) or (String(context.get("origin_skill_id", "")) == "fire_core_inferno_cycle" and int(context.get("proc_depth", 0)) > 0): return 0.0
	if target == null: return 0.0
	if event == "on_enemy_killed":
		return 1.0 if once(skill, key, "corpse:%d" % target.get_instance_id()) else 0.0
	if float(target.get("current_health")) <= 0.0: return 0.0
	var rank: String = String(preload("res://scripts/combat/target_damage_profile_resolver.gd").resolve(target).target_type)
	if rank not in ["elite", "boss"]: return 0.0
	var token: String = String(context.get("resolution_id", str(context.get("event_id", -1))))
	if not once(skill, key, token): return 0.0
	if kind == "burning" and event == "status_tick" and String(context.get("status_id", "")) == "burning":
		var ticks: float = float(context.get("status", {}).get("coalesced_tick_count", 1))
		return float(add(skill, StringName(key+"_ticks"), ticks, 5.0))
	if kind == "cursed" and event == "cursed_resolved": return 0.5
	return 0.0
static func clear(skill: RefCounted) -> void:
	if skill == null: return
	for key: Variant in skill.get_meta("resource_keys", []):
		if skill.has_meta(key): skill.remove_meta(key)
	for key: String in ["resource_keys", "resource_seen"]:
		if skill.has_meta(key): skill.remove_meta(key)
