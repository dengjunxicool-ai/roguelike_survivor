extends SceneTree

const DiagnosticScript: Script = preload("res://scripts/game/run_diagnostic_service.gd")
var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var stats: Dictionary = {"damage_done_total": 120, "damage_taken_total": 30, "last_damage_source": "contact", "damage_done_by_origin": {"primary_attack": 120}, "damage_taken_by_source": {"contact": 30}}
	var state: Dictionary = {"selected_character_id": &"knight", "selected_map_id": &"abandoned_dungeon", "run_seconds": 9.8, "player_dead": true, "run_stats": stats}
	var original: Dictionary = state.duplicate(true)
	var early: Dictionary = DiagnosticScript.build_diagnostic(state)
	_expect(String(early.get("diagnosis_text", "")).contains("过早") and not String(early.get("diagnosis_text", "")).contains("没有明显短板"), "early defeat is recognized even with damage done above damage taken", early)
	_expect(String(early.get("diagnosis_text", "")).contains("接触伤害"), "early defeat explains recorded final damage source", early)
	_expect(String(early.get("next_run_suggestion", "")).contains("包围"), "early contact defeat recommends avoiding surrounds", early)
	_expect(early.get("recommended_character_id") == &"knight" and early.get("recommended_map_id") == &"abandoned_dungeon", "recommendation IDs stay selected IDs")
	_expect(early.get("damage_share") == {"primary_attack": 1.0} and early.get("damage_taken_share") == {"contact": 1.0}, "early diagnosis preserves recorded source statistics")
	_expect(state == original, "diagnostic does not mutate real run snapshot")
	for source: String in ["ranged", "map_toxic_fog"]:
		var source_state: Dictionary = state.duplicate(true)
		source_state["run_stats"]["last_damage_source"] = source
		var source_result: Dictionary = DiagnosticScript.build_diagnostic(source_state)
		var wanted: String = "远程伤害" if source == "ranged" else "毒雾"
		_expect(String(source_result.get("diagnosis_text", "")).contains(wanted), "early defeat uses recorded %s source" % source, source_result)
		var suggestion_keyword: String = "远程" if source == "ranged" else "危险区域"
		_expect(String(source_result.get("next_run_suggestion", "")).contains(suggestion_keyword), "early %s advice targets recorded source" % source, source_result)
	var no_record: Dictionary = DiagnosticScript.build_diagnostic({"run_seconds": 10.0, "player_dead": true})
	_expect(String(no_record.get("diagnosis_text", "")).contains("不足") and String(no_record.get("death_cause", "")) == "未记录", "absent damage sample remains explicitly insufficient without inventing a fatal source", no_record)
	var unknown_source_state: Dictionary = state.duplicate(true)
	unknown_source_state["run_stats"].erase("last_damage_source")
	var unknown_source: Dictionary = DiagnosticScript.build_diagnostic(unknown_source_state)
	_expect(String(unknown_source.get("diagnosis_text", "")).contains("未记录") and not String(unknown_source.get("diagnosis_text", "")).contains("接触伤害"), "missing final damage source is not inferred from source totals", unknown_source)
	var long_run: Dictionary = DiagnosticScript.build_diagnostic({"run_seconds": 240.0, "kill_count": 40, "player_dead": true, "run_stats": stats})
	_expect(String(long_run.get("diagnosis_text", "")).contains("清场效率"), "long-run low-kill diagnosis remains available", long_run)
	var victory_state: Dictionary = state.duplicate(true)
	victory_state["result_state"] = "RESULT_VICTORY"
	victory_state["player_dead"] = false
	var victory: Dictionary = DiagnosticScript.build_diagnostic(victory_state)
	_expect(String(victory.get("diagnosis_text", "")).contains("胜利") and not String(victory.get("diagnosis_text", "")).contains("过早"), "short victory receives victory feedback instead of early defeat", victory)
	_expect(String(victory.get("death_cause", "")) == "未死亡", "victory does not turn its last recorded hit into death")
	var abandoned: Dictionary = state.duplicate(true)
	abandoned["player_dead"] = false
	var abandoned_result: Dictionary = DiagnosticScript.build_diagnostic(abandoned)
	_expect(not String(abandoned_result.get("diagnosis_text", "")).contains("过早"), "living abandonment is not treated as early death", abandoned_result)
	print("[ShortRunDiagnostics] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _expect(condition: bool, label: String, actual: Variant = null) -> void:
	if condition:
		print("[ShortRunDiagnostics] PASS " + label)
	else:
		_failed = true
		push_error("[ShortRunDiagnostics] FAIL %s actual=%s" % [label, str(actual)])
