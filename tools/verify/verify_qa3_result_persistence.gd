extends "res://tools/verify/qa_app_fixture.gd"
const MapRuntime = preload("res://scripts/maps/map_runtime.gd")
var evidence: Dictionary = {}
var out_dir: String = ""
var inject: bool = true
var before_bytes: String = ""

func snapshot() -> Dictionary:
	var controller: RefCounted = ui.get("_result_controller")
	var unlock_service: RefCounted = controller.get("_result_unlock_service")
	var labels: Dictionary = controller.get("_labels_by_state").get("RESULT_VICTORY", {})
	var unlock_label: Label = labels.get("unlock") as Label
	return {
		"state": ui.current_state,
		"progression_recorded": ui.get("_result_progression_recorded"),
		"progression_summary": ui.get("_last_progression_summary").duplicate(true),
		"unlock_cache": unlock_service.get("_unlocks_by_result_key").duplicate(true),
		"unlock_label": unlock_label.text if unlock_label != null else "missing",
		"total_runs": SaveManager.get_counter(&"total_runs"),
		"total_kills": SaveManager.get_counter(&"total_kills"),
		"victories": SaveManager.get_counter(&"victories"),
		"mage_runs": SaveManager.get_character_specialization_progress(&"mage", &"runs"),
		"mage_kills": SaveManager.get_character_specialization_progress(&"mage", &"kills"),
		"mage_seconds": SaveManager.get_character_specialization_progress(&"mage", &"survival_seconds"),
		"ranger_unlocked": SaveManager.is_unlocked("character", &"ranger"),
		"survival_achievement": SaveManager.is_unlocked("achievement", &"survive_5_minutes"),
		"map_cleared": SaveManager.is_map_cleared(&"abandoned_dungeon"),
		"next_map_unlocked": MapRuntime.is_map_unlocked(GameData.get_map(&"toxic_fog_graveyard")),
		"last_summary": SaveManager.get_last_run_summary(),
		"save_unchanged": FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == before_bytes,
	}

func reveal_unlock() -> void:
	var controller: RefCounted = ui.get("_result_controller")
	var labels: Dictionary = controller.get("_labels_by_state").get("RESULT_VICTORY", {})
	var unlock_label: Label = labels.get("unlock") as Label
	var ancestor: Node = unlock_label.get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		ancestor.ensure_control_visible(unlock_label)
		await settle()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): out_dir = argument.trim_prefix("--evidence-dir=")
		if argument == "--inject-failure": inject = true
		if argument == "--control": inject = false
	if out_dir == "": out_dir = ProjectSettings.globalize_path("user://").replace("\\", "/")
	var save_path: String = ProjectSettings.globalize_path(SaveManager.SAVE_PATH).replace("\\", "/")
	check(save_path.begins_with("E:/codex/"), "userdata isolated on E drive")
	check(out_dir.begins_with("E:/codex/"), "evidence isolated on E drive")
	check(SaveManager.reset_progress(), "seed valid old save")
	check(SaveManager.save_value("run_counters", "total_runs", 7), "seed runs 7")
	check(SaveManager.save_value("run_counters", "total_kills", 111), "seed kills 111")
	check(SaveManager.save_value("run_counters", "victories", 2), "seed victories 2")
	check(SaveManager.save_value("character_specialization", "mage:runs", 3), "seed mage runs 3")
	check(SaveManager.save_value("character_specialization", "mage:kills", 10), "seed mage kills 10")
	check(SaveManager.save_value("character_specialization", "mage:survival_seconds", 30), "seed mage seconds 30")
	check(SaveManager.save_last_run_summary({"qa_old_summary": true}), "seed old summary")
	var legacy := ConfigFile.new()
	check(legacy.load(SaveManager.SAVE_PATH) == OK, "read seeded valid save")
	legacy.erase_section(SaveManager.SECTION_PENDING_RECEIPTS)
	check(legacy.save(SaveManager.SAVE_PATH) == OK and SaveManager.get_progress_epoch() == "legacy", "old schema without receipt metadata remains supported")
	await setup_run()
	ui.set("_run_seconds", 301.0)
	ui.set("_kill_count", 42)
	before_bytes = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	evidence["before"] = snapshot()
	evidence["save_path"] = save_path
	evidence["inject_failure"] = inject
	var config := ConfigFile.new()
	check(config.load(SaveManager.SAVE_PATH) == OK, "old save parses normally")
	var temporary_path: String = save_path + ".tmp"
	var old_print_errors: bool = Engine.print_error_messages
	if inject:
		check(DirAccess.make_dir_absolute(temporary_path) == OK, "create temporary-file path as a directory")
		check(DirAccess.dir_exists_absolute(temporary_path), "fault injection is directory collision")
		Engine.print_error_messages = false
		var return_value: int = SaveManager.increment_counter(&"qa_probe", 1)
		evidence["fault_probe_return"] = return_value
		check(return_value == -1, "storage failure returns -1")
		check(FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == before_bytes, "probe preserves valid old save")
	ui._on_boss_defeated(301.0)
	await settle()
	Engine.print_error_messages = old_print_errors
	evidence["first_result"] = snapshot()
	if inject:
		check(not ui.get("_result_progression_recorded"), "failed result is not marked recorded")
		check(not String(evidence["first_result"].get("unlock_label","" )).contains("游侠"), "failed result does not claim ranger unlock")
		check(evidence["first_result"]["unlock_cache"].is_empty(), "failed result does not enter success cache")
		check(evidence["first_result"]["save_unchanged"] and SaveManager.get_last_run_summary().has("qa_old_summary"), "failed atomic result retains complete previous save and summary")
		check(SaveManager.get_counter(&"total_runs") == 7 and SaveManager.get_counter(&"total_kills") == 111 and SaveManager.get_character_specialization_progress(&"mage", &"kills") == 10, "failed atomic result does not partially increment progression")
	print("FIRST_RESULT ", JSON.stringify(evidence["first_result"]))
	check(ui.current_state == "RESULT_VICTORY", "actual UI enters victory result")
	await reveal_unlock()
	await capture("first-result")
	if inject:
		check(DirAccess.remove_absolute(temporary_path) == OK, "remove write fault")
		check(SaveManager.save_value("qa", "recovered_probe", true), "storage recovery can write")
		ui._refresh_result_screen("RESULT_VICTORY")
		await settle()
		evidence["after_recovery_refresh"] = snapshot()
		print("AFTER_RECOVERY ", JSON.stringify(evidence["after_recovery_refresh"]))
		check(SaveManager.get_counter(&"total_runs") == 8, "recovery retries run counter exactly once")
		check(SaveManager.is_unlocked("character", &"ranger"), "recovery persists ranger unlock")
		check(ui.get("_result_progression_recorded"), "recovered result marked recorded")
		evidence["verified_fixes"] = ["failed_result_not_cached", "recovery_retries_atomic_result"]
		await reveal_unlock()
		await capture("after-recovery")
	ui._refresh_result_screen("RESULT_VICTORY")
	await settle()
	evidence["second_refresh"] = snapshot()
	check(SaveManager.get_counter(&"total_runs") == 8, "control exactly one run recorded")
	check(SaveManager.get_counter(&"total_kills") == 153, "control exactly 42 kills recorded")
	check(SaveManager.get_counter(&"victories") == 3, "control exactly one victory recorded")
	check(SaveManager.get_character_specialization_progress(&"mage", &"runs") == 4, "control mage run recorded")
	check(SaveManager.get_character_specialization_progress(&"mage", &"kills") == 52, "control mage kills recorded")
	check(SaveManager.get_character_specialization_progress(&"mage", &"survival_seconds") == 331, "control mage seconds recorded")
	check(SaveManager.is_unlocked("character", &"ranger") and SaveManager.is_map_cleared(&"abandoned_dungeon"), "control unlocks persisted")
	var file := FileAccess.open(out_dir.path_join("evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	await finish()
