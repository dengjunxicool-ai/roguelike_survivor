extends "res://tools/verify/qa_app_fixture.gd"
const ENEMY_SCENE = preload("res://scenes/enemies/enemy.tscn")
const PacketBuilder = preload("res://scripts/combat/damage_packet_builder.gd")
var phase: String = "missing-local"
var out_dir: String = ""
var observations: Array = []
func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
		if argument.begins_with("--evidence-dir="): out_dir = argument.trim_prefix("--evidence-dir=")
	if out_dir == "": out_dir = ProjectSettings.globalize_path("user://")
	# This fixture deliberately starts with invalid ConfigFile syntax. Suppress
	# only that startup parse before the script can reach its local read probe.
	if phase == "journal-recover": Engine.print_error_messages = false
	call_deferred("run")
func service() -> Node: return root.get_node("PendingSaves")
func path_to(relative: String) -> String: return ProjectSettings.globalize_path(relative)
func block(relative: String) -> void: check(DirAccess.make_dir_absolute(path_to(relative)) == OK, "block " + relative)
func unblock(relative: String) -> void: check(DirAccess.remove_absolute(path_to(relative)) == OK, "unblock " + relative)
func snap(label: String) -> void:
	var journal := ConfigFile.new()
	var errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var err: int = journal.load("user://pending_rewards.cfg")
	Engine.print_error_messages = errors
	var epoch: String = SaveManager.get_progress_epoch()
	var row: Dictionary = {"label":label,"balance":SaveManager.get_soul_stones(),"runs":SaveManager.get_counter(&"total_runs"),"kills":SaveManager.get_counter(&"total_kills"),"summary":SaveManager.get_last_run_summary(),"epoch":epoch,"queue":service().get("_pending").duplicate(true),"journal_load_error":err,"journal":journal.get_value("pending","entries",{}) if err == OK else {},"journal_durable":service().get("_journal_durable"),"journal_readable":service().get("_journal_readable"),"status":service().call("status_text")}
	observations.append(row)
	print("OBS ",JSON.stringify(row))
func store_obs() -> void:
	var file := FileAccess.open(out_dir.path_join(phase+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t")); file.close()
func kill_captain() -> void:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.set("enemy_id",&"skeleton_captain"); enemy.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(enemy); enemy.set("target",player)
	check(enemy.get("soul_drop") == 35,"production captain drop 35")
	var packet: DamagePacket = PacketBuilder.from_skill_action_object({"amount":1000000,"damage_type":&"direct_physical","element":&"physical","params":{"can_crit":false,"can_trigger_reaction":false,"uses_character_damage_multiplier":false,"uses_skill_level_coefficient":false,"ignore_defense":true,"ignore_resistance":true},"context":{"caster":player,"target":enemy,"skill_id":&"fireball","source_instance_id":&"qa4:persistence"}})
	enemy.call("take_damage",packet)
	await settle(6)
	check(not is_instance_valid(enemy),"production enemy owner freed")
func seed_fixture() -> void:
	check(SaveManager.reset_progress() and SaveManager.add_soul_stones(100) == 100,"seed valid modern epoch save")
	check(SaveManager.save_value("run_counters","total_runs",7) and SaveManager.save_value("run_counters","total_kills",111),"seed counters")
	await setup_run()
func failed_result(seconds: float, kills: int) -> void:
	ui._run_seconds = seconds; ui._kill_count = kills
	ui._on_boss_defeated(seconds)
	await settle()
func restart_app() -> void:
	app = APP.instantiate(); root.add_child(app); await settle(); ui = app.get_node("UIManager")
func run() -> void:
	if phase == "journal-recover": await settle(2)
	Engine.print_error_messages = true
	check(path_to("user://").replace("\\","/").begins_with("E:/codex/"),"userdata isolated")
	if phase == "missing-local" or phase == "missing-prepare" or phase == "deleted-prepare":
		await seed_fixture(); block("user://save.cfg.tmp"); await kill_captain(); await failed_result(301,42)
		check(service().get("_pending").size()==2,"both real reward and result journaled"); snap("before_missing")
		if phase == "deleted-prepare":
			check(DirAccess.copy_absolute(path_to("user://save.cfg"),path_to("user://original-save.cfg"))==OK,"retain original before deletion")
			check(DirAccess.remove_absolute(path_to("user://save.cfg"))==OK,"delete main while journal valid")
		else:
			check(DirAccess.rename_absolute(path_to("user://save.cfg"),path_to("user://original-save.cfg"))==OK,"temporarily rename main away without altering bytes")
		if phase == "missing-local":
			service().call("retry_pending"); snap("missing_after_retry")
			check(service().get("_pending").size()==2 and String(service().call("status_text"))!="","missing main preserves durable receipts and warns")
			unblock("user://save.cfg.tmp")
			check(not SaveManager.save_value("settings", "master_volume", 40.0) and not FileAccess.file_exists(SaveManager.SAVE_PATH), "ordinary setting cannot replace missing main with empty base")
			check(SaveManager.add_soul_stones(4)==-1 and not FileAccess.file_exists(SaveManager.SAVE_PATH), "ordinary soul write cannot replace missing main with empty base")
			check(DirAccess.rename_absolute(path_to("user://original-save.cfg"),path_to("user://save.cfg"))==OK,"restore unchanged main")
			service().call("retry_pending"); snap("restored")
			check(SaveManager.get_soul_stones()==135 and SaveManager.get_counter(&"total_runs")==8 and SaveManager.get_counter(&"total_kills")==153 and service().get("_pending").is_empty(),"restored main applies both intents once")
	elif phase == "missing-recover":
		await restart_app(); snap("restart_missing")
		check(service().get("_pending").size()==2 and String(service().call("status_text"))!="","startup missing main preserves durable intents")
		check(DirAccess.rename_absolute(path_to("user://original-save.cfg"),path_to("user://save.cfg"))==OK,"restore original main after startup")
		unblock("user://save.cfg.tmp"); service().call("retry_pending"); snap("restart_restored")
		check(SaveManager.get_soul_stones()==135 and SaveManager.get_counter(&"total_runs")==8 and SaveManager.get_counter(&"total_kills")==153,"restart restore applies each intent once")
	elif phase == "journal-prepare" or phase == "journal-lock-prepare":
		await seed_fixture(); block("user://save.cfg.tmp"); await kill_captain(); await failed_result(301,42); snap("durable_reward_and_old_run")
		check(DirAccess.copy_absolute(path_to("user://pending_rewards.cfg"),path_to("user://original-journal.cfg"))==OK,"retain valid journal bytes")
		if phase == "journal-prepare":
			var corrupt := FileAccess.open("user://pending_rewards.cfg",FileAccess.WRITE); corrupt.store_string("[broken"); corrupt.close()
	elif phase == "journal-recover" or phase == "journal-lock-recover":
		snap("after_startup_unreadable_journal")
		if phase == "journal-lock-recover":
			var locked_journal := ConfigFile.new()
			check(FileAccess.file_exists("user://pending_rewards.cfg") and locked_journal.load("user://pending_rewards.cfg") == ERR_FILE_CANT_OPEN and not service().get("_journal_readable"), "real exclusive lock blocks first journal read")
			var release := FileAccess.open(out_dir.path_join("release-lock"),FileAccess.WRITE); release.store_string("release"); release.close()
			for i: int in range(200):
				if FileAccess.file_exists(out_dir.path_join("lock-released")): break
				OS.delay_msec(50)
			check(FileAccess.file_exists(out_dir.path_join("lock-released")),"release real exclusive file lock")
			var readable := false
			for i: int in range(60):
				if ConfigFile.new().load("user://pending_rewards.cfg") == OK:
					readable = true
					break
				OS.delay_msec(50)
			check(readable, "journal bytes become readable after lock process exits")
		else:
			check(DirAccess.copy_absolute(path_to("user://original-journal.cfg"),path_to("user://pending_rewards.cfg"))==OK,"restore valid journal bytes")
		service().call("retry_pending"); snap("journal_restored_main_still_blocked")
		check(service().get("_pending").size()==2 and service().get("_journal_readable"),"restored journal reloads original reward and run")
		await setup_run(); await kill_captain(); await failed_result(22,3); snap("new_reward_and_run_while_main_blocked")
		var permitted: bool = service().call("prepare_exit")
		observations.append({"label":"exit_after_journal_restored","permitted":permitted})
		check(permitted,"restored readable journal persists both intents before exit")
		unblock("user://save.cfg.tmp"); service().call("retry_pending"); snap("main_restored")
		check(SaveManager.get_soul_stones()==170 and SaveManager.get_counter(&"total_runs")==9 and SaveManager.get_counter(&"total_kills")==156 and SaveManager.get_last_run_summary().get("kill_count")==3 and service().get("_pending").is_empty(),"merged rewards and runs apply once in completion order")
	elif phase == "journal-replay":
		await restart_app(); snap("next_restart_recovers_original")
		check(SaveManager.get_soul_stones()==170 and SaveManager.get_counter(&"total_runs")==9 and SaveManager.get_counter(&"total_kills")==156 and SaveManager.get_last_run_summary().get("kill_count")==3,"second restart keeps both rewards and runs exactly once")
	elif phase == "summary-order" or phase == "summary-prepare":
		await seed_fixture(); block("user://save.cfg.tmp"); await failed_result(301,42); snap("old_result_pending")
		ui.transition_to("TITLE"); ui.transition_to("CHARACTER_SELECT"); ui._on_loadout_confirmed(&"mage")
		await ui._start_run(&"abandoned_dungeon"); await settle(); player=get_first_node_in_group(&"player")
		ui._run_scene_coordinator.get_run_scene_parent(self).process_mode=Node.PROCESS_MODE_DISABLED
		await create_timer(0.3,true).timeout
		unblock("user://save.cfg.tmp")
		# No frame between restoration and normal result submission: a player can finish before the next 1-second retry.
		ui._run_seconds=22; ui._kill_count=3; ui._on_boss_defeated(22)
		snap("new_result_committed_before_retry")
		check(SaveManager.get_last_run_summary().get("kill_count")==3,"newer result initially last summary")
		if phase == "summary-order":
			service().call("retry_pending"); snap("older_pending_result_applied")
			check(SaveManager.get_last_run_summary().get("kill_count")==3 and SaveManager.get_counter(&"total_runs")==9 and SaveManager.get_counter(&"total_kills")==156,"older result increases counters but newer summary remains last")
	elif phase == "summary-recover":
		await restart_app(); service().call("retry_pending"); snap("older_result_replayed_after_restart")
		check(SaveManager.get_last_run_summary().get("kill_count")==3 and SaveManager.get_counter(&"total_runs")==9 and SaveManager.get_counter(&"total_kills")==156,"restarted replay counts old run while keeping newer summary")
		service().call("retry_pending")
		check(SaveManager.get_counter(&"total_runs")==9 and SaveManager.get_counter(&"total_kills")==156,"restarted replay is idempotent")
	elif phase == "legacy-future-summary":
		var legacy := ConfigFile.new()
		legacy.set_value("run_history", "last_run_summary", {"kill_count": 99, "ended_at_unix": 4102444800.0})
		check(legacy.save(SaveManager.SAVE_PATH)==OK, "seed old future-dated summary without sequence")
		var newer: Dictionary = RunProgressionService.record_run_result("RESULT_DEFEAT", {"kill_count": 3, "run_seconds": 22.0}, "newer-run")
		check(bool(newer.get("saved", false)) and SaveManager.get_last_run_summary().get("kill_count")==3 and int(SaveManager.get_last_run_summary().get("run_sequence", 0))>0,"new run follows legacy summary regardless of system clock")
	elif phase == "reset-prepare":
		await seed_fixture(); block("user://save.cfg.tmp"); await kill_captain(); await failed_result(301,42); snap("old_pending")
		unblock("user://save.cfg.tmp"); block("user://pending_rewards.cfg.tmp")
		var reset_ok: bool=SaveManager.reset_progress()
		check(reset_ok,"reset main succeeds despite journal cleanup collision"); snap("reset_before_crash")
	elif phase == "reset-recover":
		# _ready cleanup encounters intentionally retained journal .tmp collision.
		await restart_app(); snap("reset_restart")
		check(service().get("_pending").is_empty() and SaveManager.get_soul_stones()==0 and SaveManager.get_counter(&"total_runs")==0,"new epoch blocks stale replay after crash")
		unblock("user://pending_rewards.cfg.tmp"); service().call("retry_pending"); snap("cleanup_recovered")
	elif phase == "partial-prepare":
		await seed_fixture(); block("user://save.cfg.tmp"); await kill_captain(); snap("first_durable")
		block("user://pending_rewards.cfg.tmp"); await kill_captain(); snap("second_memory_only")
		check(not service().call("prepare_exit"),"partial journal failure blocks exit")
		unblock("user://pending_rewards.cfg.tmp")
		check(service().call("prepare_exit"),"journal restoration persists both and permits exit"); snap("both_durable")
	elif phase == "partial-recover":
		await restart_app(); snap("both_loaded_after_restart"); check(service().get("_pending").size()==2,"both receipts load after restart")
		unblock("user://save.cfg.tmp"); service().call("retry_pending"); snap("both_recovered")
		check(SaveManager.get_soul_stones()==170,"two real captains recovered exactly 70")
	elif phase == "new-user":
		check(not FileAccess.file_exists(SaveManager.SAVE_PATH) and not FileAccess.file_exists("user://pending_rewards.cfg"),"fresh user no main or journal")
		await setup_run(); await kill_captain(); ui._run_seconds=12; ui._kill_count=2; ui._on_boss_defeated(12)
		snap("new_user_committed")
		check(SaveManager.get_soul_stones()==35 and SaveManager.get_counter(&"total_runs")==1 and service().get("_pending").is_empty(),"fresh user permits normal first save")
	elif phase == "new-user-failed-first":
		check(not FileAccess.file_exists(SaveManager.SAVE_PATH), "fresh user starts without main")
		block("user://save.cfg.tmp")
		await setup_run(); await kill_captain()
		check(service().get("_pending").size()==1 and FileAccess.file_exists("user://pending_rewards.cfg"), "fresh user's failed first reward is journaled")
		unblock("user://save.cfg.tmp"); service().call("retry_pending")
		check(SaveManager.get_soul_stones()==35 and service().get("_pending").is_empty(), "fresh user recovers first save from its own journal")
	elif phase == "new-user-failed-prepare":
		check(not FileAccess.file_exists(SaveManager.SAVE_PATH), "fresh user starts without main before restart")
		block("user://save.cfg.tmp")
		await setup_run(); await kill_captain()
		check(service().get("_pending").size()==1 and FileAccess.file_exists("user://pending_rewards.cfg"), "fresh first failure survives process exit")
		unblock("user://save.cfg.tmp")
	elif phase == "new-user-failed-recover":
		await restart_app(); service().call("retry_pending")
		check(SaveManager.get_soul_stones()==35 and service().get("_pending").is_empty(), "fresh user's first journal recovers after process restart")
	elif phase == "new-user-base-prepare":
		block("user://save.cfg.tmp")
		await setup_run(); await kill_captain()
		check(service().get("_pending").size()==1, "fresh first reward remains pending")
		unblock("user://save.cfg.tmp")
		check(SaveManager.set_master_volume_percent(40.0) and FileAccess.file_exists(SaveManager.SAVE_PATH), "ordinary setting creates first main while reward remains pending")
		check(DirAccess.rename_absolute(path_to("user://save.cfg"),path_to("user://original-save.cfg"))==OK, "move first main away without changing its bytes")
		check(not SaveManager.save_value("settings", "language", "en") and not FileAccess.file_exists(SaveManager.SAVE_PATH), "pending reward now depends on first main")
		service().call("retry_pending")
		check(service().get("_pending").size()==1, "missing first main keeps pending reward")
	elif phase == "new-user-base-recover":
		await restart_app()
		check(not FileAccess.file_exists(SaveManager.SAVE_PATH) and service().get("_pending").size()==1 and String(service().call("status_text"))!="", "restart preserves first main dependency")
		check(DirAccess.rename_absolute(path_to("user://original-save.cfg"),path_to("user://save.cfg"))==OK, "restore first main after restart")
		service().call("retry_pending")
		check(SaveManager.get_soul_stones()==35 and SaveManager.get_master_volume_percent()==40.0 and service().get("_pending").is_empty(), "restored first main receives original reward exactly once")
	elif phase == "staged-first-save-prepare":
		block("user://save.cfg.tmp")
		await setup_run(); await kill_captain()
		unblock("user://save.cfg.tmp")
		var first_main := ConfigFile.new()
		first_main.set_value("settings", "master_volume", 40.0)
		check(first_main.save(SaveManager.SAVE_PATH + ".tmp") == OK, "prepare first main bytes in temporary file")
		check(bool(service().call("begin_first_save")), "stage first main dependency before rename")
		var staged := ConfigFile.new()
		check(staged.load("user://pending_rewards.cfg") == OK and String(staged.get_value("pending", "first_save_temp_sha256", "")) != "", "journal records recoverable temporary main hash")
		check(DirAccess.make_dir_absolute(path_to(SaveManager.SAVE_PATH)) == OK, "simulate first main rename collision")
		check(DirAccess.rename_absolute(path_to(SaveManager.SAVE_PATH + ".tmp"), path_to(SaveManager.SAVE_PATH)) != OK and FileAccess.file_exists(SaveManager.SAVE_PATH + ".tmp"), "failed rename retains recoverable temporary main")
		check(DirAccess.remove_absolute(path_to(SaveManager.SAVE_PATH)) == OK, "remove injected rename collision")
	elif phase == "staged-first-save-recover":
		await restart_app(); service().call("retry_pending")
		check(SaveManager.get_soul_stones() == 35 and SaveManager.get_master_volume_percent() == 40.0 and service().get("_pending").is_empty(), "restart completes staged first main and applies pending reward")
	elif phase == "staged-finalize-prepare":
		block("user://save.cfg.tmp")
		await setup_run(); await kill_captain()
		unblock("user://save.cfg.tmp")
		var first_main := ConfigFile.new()
		first_main.set_value("settings", "master_volume", 40.0)
		check(first_main.save(SaveManager.SAVE_PATH + ".tmp") == OK and bool(service().call("begin_first_save")), "stage first save before successful main rename")
		check(DirAccess.rename_absolute(path_to(SaveManager.SAVE_PATH + ".tmp"), path_to(SaveManager.SAVE_PATH)) == OK, "simulate main rename success before stage cleanup")
		var staged := ConfigFile.new()
		check(staged.load("user://pending_rewards.cfg") == OK and String(staged.get_value("pending", "first_save_temp_sha256", "")) != "", "stage metadata remains until restart")
	elif phase == "staged-finalize-recover":
		await restart_app(); service().call("retry_pending")
		var journal := ConfigFile.new()
		check(journal.load("user://pending_rewards.cfg") == OK and String(journal.get_value("pending", "first_save_temp_sha256", "")) == "", "startup clears completed stage")
		check(SaveManager.get_soul_stones() == 35 and SaveManager.get_master_volume_percent() == 40.0 and service().get("_pending").is_empty(), "completed first main applies pending reward once")
	elif phase == "staged-main-moved-prepare":
		block("user://save.cfg.tmp")
		await setup_run(); await kill_captain()
		unblock("user://save.cfg.tmp")
		var first_main := ConfigFile.new()
		first_main.set_value("settings", "master_volume", 40.0)
		check(first_main.save(SaveManager.SAVE_PATH + ".tmp") == OK and bool(service().call("begin_first_save")), "stage first save before interrupted cleanup")
		check(DirAccess.rename_absolute(path_to(SaveManager.SAVE_PATH + ".tmp"), path_to(SaveManager.SAVE_PATH)) == OK, "first main rename succeeds")
		block("user://pending_rewards.cfg.tmp")
		service().call("finish_first_save", true)
		var staged := ConfigFile.new()
		check(staged.load("user://pending_rewards.cfg") == OK and String(staged.get_value("pending", "first_save_temp_sha256", "")) != "", "stage cleanup failure leaves conservative journal marker")
		check(DirAccess.rename_absolute(path_to(SaveManager.SAVE_PATH), path_to("user://original-save.cfg")) == OK, "move committed first main after cleanup failure")
		unblock("user://pending_rewards.cfg.tmp")
	elif phase == "staged-main-moved-recover":
		await restart_app()
		check(not FileAccess.file_exists(SaveManager.SAVE_PATH) and service().get("_pending").size()==1 and not SaveManager.set_master_volume_percent(20.0), "missing committed main cannot be recreated from stale stage without tmp")
		check(DirAccess.rename_absolute(path_to("user://original-save.cfg"), path_to(SaveManager.SAVE_PATH)) == OK, "restore committed first main")
		service().call("retry_pending")
		check(SaveManager.get_soul_stones() == 35 and SaveManager.get_master_volume_percent() == 40.0 and service().get("_pending").is_empty(), "restored first main receives pending reward after stage cleanup failure")
	elif phase == "stage-write-failure-prepare":
		block("user://save.cfg.tmp")
		await setup_run(); await kill_captain()
		unblock("user://save.cfg.tmp"); block("user://pending_rewards.cfg.tmp")
		check(not SaveManager.set_master_volume_percent(40.0) and not FileAccess.file_exists(SaveManager.SAVE_PATH), "failed stage journal write and rollback never create untracked first main")
		unblock("user://pending_rewards.cfg.tmp")
	elif phase == "stage-write-failure-recover":
		await restart_app(); service().call("retry_pending")
		check(SaveManager.get_soul_stones() == 35 and service().get("_pending").is_empty(), "fresh user's reward recovers after failed stage and failed rollback write")
	elif phase == "reset-with-stage":
		block("user://save.cfg.tmp")
		await setup_run(); await kill_captain()
		unblock("user://save.cfg.tmp")
		var first_main := ConfigFile.new()
		first_main.set_value("settings", "master_volume", 40.0)
		check(first_main.save(SaveManager.SAVE_PATH + ".tmp") == OK and bool(service().call("begin_first_save")), "stage first save before explicit reset")
		check(SaveManager.reset_progress(), "explicit reset supersedes staged first save")
		var journal := ConfigFile.new()
		check(journal.load("user://pending_rewards.cfg") == OK and journal.get_value("pending", "entries", {}).is_empty() and String(journal.get_value("pending", "first_save_temp_sha256", "")) == "", "successful reset clears pending receipts and staged hash")
		check(SaveManager.get_soul_stones() == 0 and service().get("_pending").is_empty(), "successful reset never replays old first reward")
	elif phase == "old-journal-prepare":
		await seed_fixture(); block("user://save.cfg.tmp"); await kill_captain(); await failed_result(301,42)
		var old_journal := ConfigFile.new()
		check(old_journal.load("user://pending_rewards.cfg")==OK, "read durable journal before legacy-format conversion")
		var old_entries: Dictionary = old_journal.get_value("pending", "entries", {})
		for receipt_id: String in old_entries:
			old_entries[receipt_id].erase("requires_existing_save")
			if String(old_entries[receipt_id].get("kind", "")) == "run":
				old_entries[receipt_id]["summary"].erase("run_sequence")
		old_journal.set_value("pending", "entries", old_entries)
		check(old_journal.save("user://pending_rewards.cfg")==OK, "persist older journal shape without dependency or sequence fields")
		check(DirAccess.rename_absolute(path_to("user://save.cfg"),path_to("user://original-save.cfg"))==OK, "move original main before old journal replay")
	elif phase == "old-journal-recover":
		await restart_app()
		check(not FileAccess.file_exists(SaveManager.SAVE_PATH) and service().get("_pending").size()==2 and String(service().call("status_text"))!="", "old journal conservatively waits for missing main")
		check(DirAccess.rename_absolute(path_to("user://original-save.cfg"),path_to("user://save.cfg"))==OK, "restore old journal's main")
		unblock("user://save.cfg.tmp"); service().call("retry_pending")
		check(SaveManager.get_soul_stones()==135 and SaveManager.get_counter(&"total_runs")==8 and SaveManager.get_counter(&"total_kills")==153 and service().get("_pending").is_empty(), "old journal replays each receipt once")
	elif phase == "receipt-errors":
		var legacy:=ConfigFile.new(); legacy.set_value("currency","soul_stones",100); legacy.set_value("run_counters","total_runs",7); legacy.set_value("run_counters","total_kills",111)
		check(legacy.save(SaveManager.SAVE_PATH)==OK and SaveManager.get_progress_epoch()=="legacy","seed valid old save without pending receipt section")
		await setup_run(); block("user://save.cfg.tmp"); await failed_result(301,42)
		snap("legacy_result_failed_durable")
		print("NON_IO_ERROR_WINDOW_BEGIN three status emissions, no writes")
		for i: int in range(3): service().status_changed.emit()
		print("NON_IO_ERROR_WINDOW_END")
		observations.append({"label":"ui_after_null_receipt_read","state":ui.current_state,"recorded":ui._result_progression_recorded,"status_visible":ui._persistence_status_label.visible,"status":ui._persistence_status_label.text,"result_soul":ui._result_controller.get("_labels_by_state")["RESULT_VICTORY"]["soul"].text})
		check(ui.current_state=="RESULT_VICTORY" and not ui._result_progression_recorded and ui._persistence_status_label.visible,"result remains open, failed and awaiting persistence")
		unblock("user://save.cfg.tmp"); service().call("retry_pending"); await settle(); snap("legacy_result_recovers")
		check(SaveManager.get_counter(&"total_runs")==8 and ui._result_progression_recorded,"recovery succeeds despite logged get_value errors")
	elif phase == "settings-economy":
		var old:=ConfigFile.new(); old.set_value("currency","soul_stones",1000); old.set_value("permanent_upgrades","meta_health",2); old.set_value("custom","preserve","old unknown section"); old.set_value("settings","master_volume",55.0); old.set_value("settings","fullscreen",false); old.set_value("settings","language","zh"); old.set_value("run_counters","total_runs",7)
		check(old.save(SaveManager.SAVE_PATH)==OK,"valid legacy settings and growth save")
		await restart_app(); ui.transition_to("SETTINGS"); await settle()
		var settings: RefCounted=ui._settings_controller
		check(settings.get("_master_slider").value==55 and SaveManager.get_progress_epoch()=="legacy","existing settings loaded unchanged")
		var before: PackedByteArray=FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
		block("user://save.cfg.tmp")
		settings.call("_on_master_volume_changed",10.0); settings.call("_set_fullscreen",true); settings.call("_on_language_selected",1)
		var purchase: bool=SaveManager.purchase_permanent_upgrade(&"meta_health")
		var reset_ok: bool=SaveManager.reset_progress()
		check(not purchase and not reset_ok and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)==before,"failed settings growth reset all preserve original bytes")
		check(settings.get("_master_slider").value==55 and not settings.get("_fullscreen_button").button_pressed and SaveManager.get_language_id()=="zh","real settings controls roll back after failure")
		check(SaveManager.get_soul_stones()==1000 and SaveManager.get_permanent_upgrade_level(&"meta_health")==2,"purchase failure no charge or growth")
		unblock("user://save.cfg.tmp"); settings.call("_on_master_volume_changed",40.0)
		var cost: int=SaveManager.get_permanent_upgrade_cost(&"meta_health")
		check(SaveManager.purchase_permanent_upgrade(&"meta_health") and SaveManager.get_soul_stones()==1000-cost and SaveManager.get_permanent_upgrade_level(&"meta_health")==3,"normal purchase after recovery charges once")
		check(SaveManager.load_value("custom","preserve")=="old unknown section" and SaveManager.get_master_volume_percent()==40 and SaveManager.get_counter(&"total_runs")==7,"settings and normal growth preserve old metadata")
		var all_default: bool=true
		for character: Dictionary in GameData.get_character_pool():
			all_default=all_default and String(character.get("unlock",{}).get("type","default"))=="default"
		observations.append({"label":"settings_economy","balance":SaveManager.get_soul_stones(),"growth_level":SaveManager.get_permanent_upgrade_level(&"meta_health"),"cost":cost,"master_volume":SaveManager.get_master_volume_percent(),"unknown":SaveManager.load_value("custom","preserve"),"all_production_characters_default_unlocked":all_default})
		check(not SaveManager.purchase_character(&"mage") and all_default,"current content has no purchasable locked character; default mage no charge")
		snap("legacy_settings_growth_recovered")
	elif phase == "normal-save-with-pending":
		await seed_fixture(); block("user://save.cfg.tmp"); await kill_captain(); snap("reward_pending_before_card")
		unblock("user://save.cfg.tmp")
		var dispatcher: RefCounted=ui._run_choice_modal_controller.get("_command_dispatcher")
		var card_result: Dictionary=dispatcher.call("dispatch",UICommand.apply_choice_option({"id":"reward_soul_stones","payload":{"reward_kind":"elite","amount":20}}),{"player":player,"tree":self})
		check(card_result.get("consumed_reward",false) and SaveManager.get_soul_stones()==120 and service().get("_pending").size()==1,"normal card saves without consuming prior failed reward")
		ui._run_seconds=101; ui._kill_count=10; ui._on_boss_defeated(101); snap("result_saved_before_prior_soul_retry")
		check(SaveManager.get_last_run_summary().get("run_souls_earned")==55,"summary includes normal card20 plus pending captain35")
		service().call("retry_pending"); snap("all_rewards_recovered_after_normal_save")
		check(SaveManager.get_soul_stones()==155 and SaveManager.get_last_run_summary().get("run_souls_earned")==55 and SaveManager.get_counter(&"total_runs")==8,"normal transaction and deferred reward do not overwrite or duplicate")
	elif phase == "legacy-missing-writable":
		var legacy:=ConfigFile.new(); legacy.set_value("currency","soul_stones",100); legacy.set_value("run_counters","total_runs",7); legacy.set_value("run_counters","total_kills",111)
		check(legacy.save(SaveManager.SAVE_PATH)==OK and SaveManager.get_progress_epoch()=="legacy","seed valid ordinary player legacy save")
		await setup_run(); block("user://save.cfg.tmp"); await kill_captain(); await failed_result(301,42); snap("legacy_durable_before_missing")
		ui.transition_to("TITLE")
		check(DirAccess.rename_absolute(path_to("user://save.cfg"),path_to("user://original-save.cfg"))==OK,"temporary main absence retains original bytes")
		unblock("user://save.cfg.tmp"); service().call("retry_pending"); snap("legacy_new_empty_base_created")
		check(not FileAccess.file_exists(SaveManager.SAVE_PATH) and service().get("_pending").size()==2 and String(service().call("status_text"))!="","legacy missing main blocks replacement and preserves intents")
		if FileAccess.file_exists(SaveManager.SAVE_PATH): check(DirAccess.remove_absolute(path_to("user://save.cfg"))==OK,"discard incorrect replacement base")
		check(DirAccess.rename_absolute(path_to("user://original-save.cfg"),path_to("user://save.cfg"))==OK,"restore legitimate original main bytes")
		service().call("retry_pending"); snap("legacy_original_restored")
		check(SaveManager.get_soul_stones()==135 and SaveManager.get_counter(&"total_runs")==8 and SaveManager.get_counter(&"total_kills")==153 and service().get("_pending").is_empty(),"legacy main restoration applies old intents once")
	store_obs()
	if app != null: await finish()
	else: quit(1 if failures else 0)
