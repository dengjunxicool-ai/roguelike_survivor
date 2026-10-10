extends SceneTree
func _init() -> void:
	var path: String = "res://scripts/runtime/skill_balance_metrics.gd"
	if not ResourceLoader.exists(path):
		push_error("M4 balance metrics missing")
		quit(1)
		return
	var metrics: RefCounted = load(path).new()
	metrics.record({"kind":"damage","amount":160.0,"health_before":100.0,"damage_origin":"dot"})
	metrics.record({"kind":"shield_generated","amount":25})
	metrics.record({"kind":"shield_absorbed","amount":10})
	metrics.record({"kind":"trigger","origin_skill_id":"test"})
	metrics.record({"kind":"denied","reason":"missing_target"})
	metrics.record({"kind":"buff","duration":2.0})
	for i: int in 20: metrics.record({"kind":"frame","milliseconds":i+1,"objects":i})
	var result: Dictionary = metrics.snapshot()
	assert(result.actual_damage == 100 and result.overkill == 60 and result.status_damage == 100)
	assert(result.shield_generated == 25 and result.shield_absorbed == 10)
	assert(result.trigger_count == 1 and result.denied_reason.missing_target == 1)
	assert(result.buff_uptime == 2 and result.object_peak == 19 and result.frame_p95 == 19)
	metrics.reset()
	assert(metrics.snapshot().actual_damage == 0 and metrics.snapshot().frame_p95 == 0)
	print("[verify_skill_balance_metrics] PASS exact HP clamp, status, shield, reset, p95")
	quit(0)
