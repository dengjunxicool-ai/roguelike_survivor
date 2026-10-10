## 可选战斗计量；仅隔离验证设置 root metadata 后采样，不改变任何战斗结果。
extends RefCounted
class_name SkillBalanceMetrics
const META: StringName = &"skill_balance_metrics"
var _totals: Dictionary = {}
var _frames: Array[float] = []
func _init() -> void: reset()
func record(event: Dictionary) -> void:
	var kind: String = str(event.get("kind",""))
	match kind:
		"damage":
			var amount: float = maxf(float(event.get("amount",0)),0)
			var effective: float = minf(amount,maxf(float(event.get("health_before",amount)),0))
			_totals.actual_damage += effective
			_totals.overkill += amount-effective
			if str(event.get("damage_origin","")) in ["dot","status_dot"]: _totals.status_damage += effective
			var source: String = str(event.get("source_skill_id","unknown"))
			_totals.damage_by_skill[source] = float(_totals.damage_by_skill.get(source,0))+effective
		"shield_generated","shield_absorbed": _totals[kind] += maxf(float(event.get("amount",0)),0)
		"trigger":
			_totals.trigger_count += 1
			var source: String = str(event.get("origin_skill_id","unknown"))
			_totals.triggers_by_skill[source] = int(_totals.triggers_by_skill.get(source,0))+1
		"denied":
			var reason: String = str(event.get("reason","unknown"))
			_totals.denied_reason[reason] = int(_totals.denied_reason.get(reason,0))+1
		"buff": _totals.buff_uptime += maxf(float(event.get("duration",0)),0)
		"frame":
			_frames.append(maxf(float(event.get("milliseconds",0)),0))
			_totals.object_peak = maxi(_totals.object_peak,int(event.get("objects",0)))
		"control": _totals.control_seconds += maxf(float(event.get("seconds",0)),0)
		"resource": _totals.resource_cycles += int(event.get("crossings",0))
		"boss_trigger": _totals.boss_trigger_count += 1
func snapshot() -> Dictionary:
	var result: Dictionary = _totals.duplicate(true)
	var sorted: Array[float] = _frames.duplicate()
	sorted.sort()
	result.frame_p95 = sorted[maxi(ceili(sorted.size()*.95)-1,0)] if not sorted.is_empty() else 0.0
	result.frame_samples = sorted.size()
	return result
func reset() -> void:
	_totals = {"actual_damage":0.0,"overkill":0.0,"status_damage":0.0,"trigger_count":0,"denied_reason":{},"buff_uptime":0.0,"shield_generated":0.0,"shield_absorbed":0.0,"object_peak":0,"damage_by_skill":{},"triggers_by_skill":{},"control_seconds":0.0,"resource_cycles":0,"boss_trigger_count":0}
	_frames.clear()
static func observe(node: Node, event: Dictionary) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	if not node.get_tree().root.has_meta(META): return
	var metrics: RefCounted = node.get_tree().root.get_meta(META)
	if metrics != null: metrics.record(event)
