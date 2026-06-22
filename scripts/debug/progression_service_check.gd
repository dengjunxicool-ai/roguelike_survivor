extends Node


const RunProgressionServiceScript: Script = preload("res://scripts/game/run_progression_service.gd")

var _failed: bool = false


func _ready() -> void:
	var summary: Dictionary = RunProgressionServiceScript.record_run_result("RESULT_VICTORY", {
		"selected_character_id": &"mage",
		"selected_weapon_id": &"fire_staff",
		"selected_map_id": &"abandoned_dungeon",
		"selected_map_name": "废弃地牢",
		"run_seconds": 300.0,
		"kill_count": 42,
		"run_souls_earned": 0
	})
	_expect(bool(summary.get("victory", false)), "records victory flag")
	_expect(SaveManager.get_counter(&"total_runs") >= 1, "increments total run counter")
	_expect(SaveManager.get_weapon_mastery_xp(&"fire_staff") > 0, "adds weapon mastery xp")
	_expect(not SaveManager.get_last_run_summary().is_empty(), "stores last run summary")
	print("[ProgressionServiceCheck] done failed=%s" % str(_failed))
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[ProgressionServiceCheck] PASS %s" % message)
		return
	_failed = true
	push_error("[ProgressionServiceCheck] FAIL %s" % message)
