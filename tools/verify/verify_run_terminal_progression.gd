extends SceneTree


const RunProgressionServiceScript: Script = preload("res://scripts/game/run_progression_service.gd")
const SaveManagerScript: Script = preload("res://scripts/game/save_manager.gd")
const APP_SCENE: PackedScene = preload("res://scenes/app/app_bootstrap.tscn")

const STATE_RUNNING: String = "RUNNING"
const STATE_RESULT_DEFEAT: String = "RESULT_DEFEAT"
const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"

var _failed: bool = false
var _save_path: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _guard_isolated_save_path():
		quit(1)
		return
	_verify_defeat_progression()
	_verify_victory_progression_and_summary_isolation()
	await _verify_defeat_is_terminal_and_recorded_once()
	await _verify_victory_is_terminal_and_recorded_once()
	await _verify_debug_run_death_is_ignored()
	_clean_isolated_save()
	print("[verify_run_terminal_progression] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


func _guard_isolated_save_path() -> bool:
	_save_path = ProjectSettings.globalize_path("user://save.cfg").replace("\\", "/")
	var normalized_path: String = _save_path.to_lower()
	var isolated: bool = normalized_path.begins_with("e:/codex/")
	_expect(isolated, "save path is isolated under E:/codex", _save_path)
	return isolated


func _verify_defeat_progression() -> void:
	_clean_isolated_save()
	var summary: Dictionary = RunProgressionServiceScript.record_run_result(STATE_RESULT_DEFEAT, _run_state())
	_expect(String(summary.get("result_state", "")) == STATE_RESULT_DEFEAT, "defeat summary keeps result state", summary)
	_expect(not bool(summary.get("victory", true)), "defeat summary is not a victory", summary)
	_expect(SaveManagerScript.get_counter(&"total_runs") == 1, "defeat increments total runs once")
	_expect(SaveManagerScript.get_counter(&"defeats") == 1, "defeat increments defeat count once")
	_expect(SaveManagerScript.get_counter(&"victories") == 0, "defeat does not increment victory count")
	_expect(SaveManagerScript.get_counter(&"total_kills") == 7, "defeat records kill count", SaveManagerScript.get_counter(&"total_kills"))
	_expect(SaveManagerScript.get_counter(&"character:mage:runs") == 1, "defeat records character run")
	_expect(SaveManagerScript.get_counter(&"map:abandoned_dungeon:runs") == 1, "defeat records map run")


func _verify_victory_progression_and_summary_isolation() -> void:
	_clean_isolated_save()
	var summary: Dictionary = RunProgressionServiceScript.record_run_result(STATE_RESULT_VICTORY, _run_state())
	_expect(bool(summary.get("victory", false)), "victory summary is marked as victory", summary)
	_expect(SaveManagerScript.get_counter(&"total_runs") == 1, "victory increments total runs once")
	_expect(SaveManagerScript.get_counter(&"victories") == 1, "victory increments victory count once")
	_expect(SaveManagerScript.get_counter(&"boss_kills") == 1, "victory increments boss kill count once")
	_expect(SaveManagerScript.get_counter(&"defeats") == 0, "victory does not increment defeat count")
	_expect(SaveManagerScript.get_counter(&"map:abandoned_dungeon:clears") == 1, "victory records map clear")
	var first_read: Dictionary = SaveManagerScript.get_last_run_summary()
	first_read["kill_count"] = 999
	var first_stats: Dictionary = _dictionary(first_read.get("run_stats", {}))
	first_stats["damage_done_total"] = 999
	var second_read: Dictionary = SaveManagerScript.get_last_run_summary()
	var second_stats: Dictionary = _dictionary(second_read.get("run_stats", {}))
	_expect(int(second_read.get("kill_count", 0)) == 7, "summary top-level data is isolated from caller changes", second_read)
	_expect(int(second_stats.get("damage_done_total", 0)) == 11, "summary nested data is isolated from caller changes", second_stats)


func _verify_defeat_is_terminal_and_recorded_once() -> void:
	_clean_isolated_save()
	var app: Node = await _new_app()
	var ui: Node = app.get_node("UIManager")
	_prepare_running_ui(ui)
	ui.call("_on_player_died")
	_expect(String(ui.get("current_state")) == STATE_RESULT_DEFEAT, "player death enters defeat result", ui.get("current_state"))
	ui.call("_on_boss_defeated", 240.0)
	_expect(String(ui.get("current_state")) == STATE_RESULT_DEFEAT, "defeat result cannot be overwritten by a later boss signal", ui.get("current_state"))
	ui.call("_refresh_result_screen", String(ui.get("current_state")))
	ui.call("_refresh_result_screen", String(ui.get("current_state")))
	_expect(SaveManagerScript.get_counter(&"total_runs") == 1, "repeated defeat refresh records progression once", SaveManagerScript.get_counter(&"total_runs"))
	await _free_app(app)


func _verify_victory_is_terminal_and_recorded_once() -> void:
	_clean_isolated_save()
	var app: Node = await _new_app()
	var ui: Node = app.get_node("UIManager")
	_prepare_running_ui(ui)
	ui.call("_on_boss_defeated", 240.0)
	_expect(String(ui.get("current_state")) == STATE_RESULT_VICTORY, "boss defeat enters victory result", ui.get("current_state"))
	ui.call("_on_player_died")
	_expect(String(ui.get("current_state")) == STATE_RESULT_VICTORY, "victory result cannot be overwritten by a later player signal", ui.get("current_state"))
	ui.call("_refresh_result_screen", String(ui.get("current_state")))
	ui.call("_refresh_result_screen", String(ui.get("current_state")))
	_expect(SaveManagerScript.get_counter(&"total_runs") == 1, "repeated victory refresh records progression once", SaveManagerScript.get_counter(&"total_runs"))
	await _free_app(app)


func _verify_debug_run_death_is_ignored() -> void:
	_clean_isolated_save()
	var app: Node = await _new_app()
	var ui: Node = app.get_node("UIManager")
	_prepare_running_ui(ui)
	var debug_run_scene := Node.new()
	debug_run_scene.set_meta("debug", true)
	root.add_child(debug_run_scene)
	var coordinator: RefCounted = ui.get("_run_scene_coordinator") as RefCounted
	coordinator.set("_active_run_scene", debug_run_scene)
	ui.call("_on_player_died")
	_expect(String(ui.get("current_state")) == STATE_RUNNING, "debug run death remains in running state", ui.get("current_state"))
	_expect(SaveManagerScript.get_counter(&"total_runs") == 0, "debug run death does not record progression", SaveManagerScript.get_counter(&"total_runs"))
	coordinator.set("_active_run_scene", null)
	debug_run_scene.free()
	await _free_app(app)


func _new_app() -> Node:
	paused = false
	var app: Node = APP_SCENE.instantiate()
	root.add_child(app)
	for _index: int in range(4):
		await process_frame
	return app


func _prepare_running_ui(ui: Node) -> void:
	var state_machine: RefCounted = ui.get("_state_machine") as RefCounted
	state_machine.call("force_transition_to", STATE_RUNNING)
	ui.set("current_state", STATE_RUNNING)
	ui.set("_selected_character_id", CHARACTER_ID)
	ui.set("_selected_map_id", MAP_ID)
	ui.set("_selected_map_name", "Dungeon")
	ui.set("_run_seconds", 120.0)
	ui.set("_kill_count", 7)
	ui.set("_run_start_souls", 0)
	ui.set("_run_souls_earned", 3)
	ui.set("_result_progression_recorded", false)
	var previous_summary: Dictionary = ui.get("_last_progression_summary")
	previous_summary.clear()


func _free_app(app: Node) -> void:
	paused = false
	app.free()
	await process_frame


func _run_state() -> Dictionary:
	return {
		"selected_character_id": CHARACTER_ID,
		"selected_map_id": MAP_ID,
		"selected_map_name": "Dungeon",
		"run_seconds": 120.0,
		"kill_count": 7,
		"run_souls_earned": 3,
		"main_attack_level": 2,
		"run_stats": {"damage_done_total": 11}
	}


func _clean_isolated_save() -> void:
	if _save_path == "" or not FileAccess.file_exists(_save_path):
		return
	var error: Error = DirAccess.remove_absolute(_save_path)
	_expect(error == OK or error == ERR_DOES_NOT_EXIST, "isolated save can be reset", error)


func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, label: String, actual: Variant = null) -> void:
	if condition:
		print("[verify_run_terminal_progression] PASS %s" % label)
		return
	_failed = true
	push_error("[verify_run_terminal_progression] FAIL %s actual=%s" % [label, str(actual)])
