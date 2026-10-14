## Catches misleading positive diagnosis after genuine deaths at and beyond the old 60-second boundary.
extends SceneTree

const Diagnostic = preload("res://scripts/game/run_diagnostic_service.gd")
var failed: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await process_frame
	var stats: Dictionary = {"damage_done_total": 1949, "damage_taken_total": 96, "last_damage_source": "contact", "damage_done_by_origin": {"primary_attack": 1949}, "damage_taken_by_source": {"contact": 96}}
	for seconds: float in [59.9, 60.0, 108.5833, 219.9, 220.0, 300.0]:
		var state: Dictionary = {"result_state": "RESULT_DEFEAT", "player_dead": true, "run_seconds": seconds, "kill_count": 180, "run_stats": stats}
		var original: Dictionary = state.duplicate(true)
		var result: Dictionary = Diagnostic.build_diagnostic(state)
		var text: String = String(result.get("diagnosis_text", ""))
		expect(text.contains("死亡") and not text.contains("没有明显短板"), "genuine death at %.4fs is never praised as shortcoming-free" % seconds)
		expect(text.contains("接触伤害"), "death at %.4fs retains its actual final source" % seconds)
		expect(state == original, "diagnosis is read-only at %.4fs" % seconds)
	var late: Dictionary = Diagnostic.build_diagnostic({"player_dead": true, "run_seconds": 240.0, "kill_count": 40, "run_stats": stats})
	expect(String(late.get("diagnosis_text", "")).contains("死亡") and String(late.get("diagnosis_text", "")).contains("清场效率"), "late death preserves both outcome and supported low-clear observation")
	var boss: Dictionary = Diagnostic.build_diagnostic({"player_dead": true, "run_seconds": 310.0, "boss_seen": true, "run_stats": {"damage_done_total": 8000, "damage_taken_total": 75, "last_damage_source": "boss"}})
	expect(String(boss.get("diagnosis_text", "")).contains("Boss") and String(boss.get("next_run_suggestion", "")).contains("预警"), "Boss death receives attack-warning survival advice despite large damage output")
	var abandoned: Dictionary = Diagnostic.build_diagnostic({"player_dead": false, "result_state": "RESULT_DEFEAT", "run_seconds": 108.0, "run_stats": stats})
	expect(String(abandoned.get("diagnosis_text", "")).contains("主动结束") and not String(abandoned.get("diagnosis_text", "")).contains("死亡"), "living abandonment is explicit rather than inferred as a death")
	var unknown: Dictionary = Diagnostic.build_diagnostic({"player_dead": true, "run_seconds": 108.0, "run_stats": {"damage_done_total": 5000, "damage_taken_total": 100}})
	expect(String(unknown.get("diagnosis_text", "")).contains("未记录") and not String(unknown.get("diagnosis_text", "")).contains("接触伤害"), "unknown final source is not invented for longer deaths")
	var victory: Dictionary = Diagnostic.build_diagnostic({"result_state": "RESULT_VICTORY", "player_dead": false, "run_seconds": 108.0, "run_stats": stats})
	expect(String(victory.get("diagnosis_text", "")).contains("胜利") and String(victory.get("death_cause", "")) == "未死亡", "victory keeps its actual outcome and does not reuse the last hit as fatal")
	quit(1 if failed > 0 else 0)

func expect(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failed += 1
