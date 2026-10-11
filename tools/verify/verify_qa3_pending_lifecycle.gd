extends "res://tools/verify/qa_app_fixture.gd"

const ENEMY_SCENE = preload("res://scenes/enemies/enemy.tscn")
const PacketBuilder = preload("res://scripts/combat/damage_packet_builder.gd")
var phase: String = "local"

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	# Restart phases intentionally retain a write obstruction from the prior process.
	if phase == "recover" or phase == "replay" or phase == "recover-unreadable": Engine.print_error_messages = false
	call_deferred("run")

func service() -> Node:
	return root.get_node("PendingSaves")

func path_to(relative: String) -> String:
	return ProjectSettings.globalize_path(relative)

func kill_captain() -> void:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.set("enemy_id", &"skeleton_captain")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(enemy)
	enemy.set("target", player)
	check(enemy.get("soul_drop") == 35, "real captain soul drop is 35")
	var packet: DamagePacket = PacketBuilder.from_skill_action_object({"amount": 1000000, "damage_type": &"direct_physical", "element": &"physical", "params": {"can_crit": false, "can_trigger_reaction": false, "uses_character_damage_multiplier": false, "uses_skill_level_coefficient": false, "ignore_defense": true, "ignore_resistance": true}, "context": {"caster": player, "target": enemy, "skill_id": &"fireball", "source_instance_id": &"qa_reward:lifecycle"}})
	enemy.call("take_damage", packet)
	enemy.call("take_damage", packet)
	await settle(6)
	check(not is_instance_valid(enemy), "enemy frees after duplicate lethal callback")

func run() -> void:
	check(path_to("user://").replace("\\", "/").begins_with("E:/codex/"), "userdata stays on E drive")
	if phase == "recover" or phase == "replay" or phase == "recover-unreadable":
		await recover_or_replay()
		return
	check(SaveManager.reset_progress() and SaveManager.add_soul_stones(100) == 100, "seed legitimate currency")
	check(SaveManager.save_value("run_counters", "total_runs", 7) and SaveManager.save_value("run_counters", "total_kills", 111), "seed previous counters")
	await setup_run()
	check(DirAccess.make_dir_absolute(path_to(SaveManager.SAVE_PATH + ".tmp")) == OK, "block main atomic temporary path")
	Engine.print_error_messages = false
	await kill_captain()
	check(SaveManager.get_soul_stones() == 100, "blocked reward leaves old balance intact")
	ui._run_seconds = 301.0
	ui._kill_count = 42
	ui._on_boss_defeated(301.0)
	await settle()
	check(ui._get_result_state().get("run_souls_earned", -1) == 35 and SaveManager.get_soul_stones() == 100, "frozen same-run earned souls include pending reward while wallet stays unchanged")
	check(service().get("_pending").size() == 2, "run and freed enemy queued at application scope")
	check(bool(service().call("prepare_exit")), "writable journal permits safe process exit")
	check(FileAccess.file_exists("user://pending_rewards.cfg"), "journal exists independently from blocked save")
	ui.transition_to("TITLE")
	check(service().get("_pending").size() == 2, "return to menu preserves pending intents")
	ui.transition_to("CHARACTER_SELECT")
	ui._on_loadout_confirmed(&"mage")
	await ui._start_run(&"abandoned_dungeon")
	await settle()
	player = get_first_node_in_group(&"player")
	ui._run_scene_coordinator.get_run_scene_parent(self).process_mode = Node.PROCESS_MODE_DISABLED
	check(service().get("_pending").size() == 2, "new run preserves previous run and enemy intents")
	if phase == "prepare" or phase == "prepare-unreadable":
		if phase == "prepare-unreadable":
			check(DirAccess.copy_absolute(path_to(SaveManager.SAVE_PATH), path_to("user://qa3-readable-save.cfg")) == OK, "retain legitimate save for read-fault recovery")
			var corrupt := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
			corrupt.store_string("[broken")
			corrupt.close()
			service().call("retry_pending")
			check(service().get("_pending").size() == 2, "unreadable main never deletes durable pending intents")
		Engine.print_error_messages = true
		print("PREPARED restart recovery fixture with main save still blocked")
		await finish()
		return
	check(DirAccess.remove_absolute(path_to(SaveManager.SAVE_PATH + ".tmp")) == OK, "restore main save")
	var previous_save: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var damaged := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	damaged.store_string("[broken")
	damaged.close()
	service().call("retry_pending")
	service().call("discard_previous_epoch")
	check(SaveManager.get_progress_epoch() == "" and service().get("_pending").size() == 2, "read error pauses epoch invalidation and retry")
	var pending_on_disk := ConfigFile.new()
	check(pending_on_disk.load("user://pending_rewards.cfg") == OK and pending_on_disk.get_value("pending", "entries", {}).size() == 2, "read error preserves durable journal")
	var restored := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	restored.store_string(previous_save)
	restored.close()
	service().call("retry_pending")
	check(SaveManager.get_soul_stones() == 135 and SaveManager.get_counter(&"total_runs") == 8, "cross-menu and new-run recovery applies once")
	check(SaveManager.get_counter(&"total_kills") == 153, "frozen old terminal kills survive new run")
	check(SaveManager.get_last_run_summary().get("run_souls_earned", -1) == 35, "recovered prior run summary preserves earned captain reward")
	ui._on_boss_defeated(0.0)
	await settle()
	check(ui._run_souls_earned == 0 and SaveManager.get_last_run_summary().get("run_souls_earned", -1) == 0, "previous run reward is excluded from new run earned souls")
	service().call("retry_pending")
	check(SaveManager.get_soul_stones() == 135 and SaveManager.get_counter(&"total_runs") == 9, "repeated retry does not duplicate either completed run")
	# Journal failure alone cannot block a successful main transaction.
	check(DirAccess.make_dir_absolute(path_to("user://pending_rewards.cfg.tmp")) == OK, "block journal temporary path")
	var reward_id: String = SaveManager.new_receipt_id("test")
	service().call("award_souls", 5, reward_id)
	service().call("award_souls", 5, reward_id)
	check(SaveManager.get_soul_stones() == 140, "main success with blocked journal and duplicate receipt adds once")
	check(DirAccess.make_dir_absolute(path_to(SaveManager.SAVE_PATH + ".tmp")) == OK, "block both storage paths")
	service().call("award_souls", 9, SaveManager.new_receipt_id("blocked"))
	check(not bool(service().call("prepare_exit")), "both write failures prevent requested quit")
	check(String(service().call("status_text")).contains("本次运行"), "UI explicitly identifies non-durable pending state")
	check(ui._persistence_status_label.visible and ui._persistence_status_label.text.contains("本次运行"), "real UI exposes pending state")
	ui._quit_game()
	await settle(2)
	check(is_instance_valid(app) and app.is_inside_tree(), "real UI quit stays open while both stores fail")
	check(DirAccess.remove_absolute(path_to(SaveManager.SAVE_PATH + ".tmp")) == OK, "restore main path while journal blocked")
	service().call("retry_pending")
	check(SaveManager.get_soul_stones() == 149 and bool(service().call("prepare_exit")), "main success allows exit even if journal cleanup fails")
	check(DirAccess.remove_absolute(path_to("user://pending_rewards.cfg.tmp")) == OK, "restore journal cleanup")
	# Reset changes the epoch even if journal cleanup cannot persist.
	check(DirAccess.make_dir_absolute(path_to(SaveManager.SAVE_PATH + ".tmp")) == OK, "block main for reset case")
	service().call("award_souls", 50, SaveManager.new_receipt_id("reset"))
	check(DirAccess.remove_absolute(path_to(SaveManager.SAVE_PATH + ".tmp")) == OK, "restore main for reset")
	check(DirAccess.make_dir_absolute(path_to("user://pending_rewards.cfg.tmp")) == OK, "block journal during reset")
	check(SaveManager.reset_progress(), "reset successfully changes durable progress epoch")
	check(DirAccess.remove_absolute(path_to("user://pending_rewards.cfg.tmp")) == OK, "restore journal after reset")
	service().call("retry_pending")
	check(SaveManager.get_soul_stones() == 0 and service().get("_pending").is_empty(), "reset invalidates old pending rewards")
	Engine.print_error_messages = true
	await finish()

func recover_or_replay() -> void:
	app = APP.instantiate()
	root.add_child(app)
	await settle()
	ui = app.get_node("UIManager")
	var journal := ConfigFile.new()
	check(journal.load("user://pending_rewards.cfg") == OK, "new process can load previous journal")
	var entries: Dictionary = journal.get_value("pending", "entries", {})
	check(entries.size() == 2, "both intents survived actual process exit")
	if phase == "recover-unreadable":
		check(SaveManager.get_progress_epoch() == "" and service().get("_pending").size() == 2, "restart with unreadable main preserves pending epoch")
		service().call("retry_pending")
		check(journal.load("user://pending_rewards.cfg") == OK and journal.get_value("pending", "entries", {}).size() == 2, "restart read error does not clear durable journal")
		check(DirAccess.copy_absolute(path_to("user://qa3-readable-save.cfg"), path_to(SaveManager.SAVE_PATH)) == OK, "restore readable main after restart")
		check(DirAccess.remove_absolute(path_to(SaveManager.SAVE_PATH + ".tmp")) == OK, "restore main write path after unreadable restart")
		service().call("retry_pending")
		check(SaveManager.get_soul_stones() == 135 and SaveManager.get_counter(&"total_runs") == 8 and SaveManager.get_counter(&"total_kills") == 153, "readability recovery after restart applies both intents once")
		check(SaveManager.get_last_run_summary().get("run_souls_earned", -1) == 35, "readability recovery after restart preserves earned captain souls")
		Engine.print_error_messages = true
		await finish()
		return
	var run_id: String = ""
	for receipt_id: String in entries:
		if entries[receipt_id]["kind"] == "run": run_id = receipt_id
	if phase == "recover":
		check(SaveManager.get_soul_stones() == 100 and SaveManager.get_counter(&"total_runs") == 7, "restart keeps old valid save while blocked")
		check(DirAccess.make_dir_absolute(path_to("user://pending_rewards.cfg.tmp")) == OK, "inject journal cleanup failure")
		check(DirAccess.remove_absolute(path_to(SaveManager.SAVE_PATH + ".tmp")) == OK, "recover main after restart")
	else:
		check(SaveManager.get_soul_stones() == 135 and SaveManager.get_counter(&"total_runs") == 8, "restart from stale journal retains prior commit")
	service().call("retry_pending")
	check(SaveManager.get_soul_stones() == 135, "restart reward recovered exactly once")
	check(SaveManager.get_counter(&"total_runs") == 8 and SaveManager.get_counter(&"total_kills") == 153, "restart frozen run recovered exactly once")
	check(SaveManager.get_last_run_summary().get("run_souls_earned", -1) == 35, "restart summary retains its earned captain souls")
	var result: Dictionary = service().call("submit_run", "RESULT_VICTORY", entries[run_id]["summary"], run_id)
	check(bool(result.get("saved", false)) and result.get("progression_unlocks", []).has("角色：游侠"), "receipt retains unlock text despite stale journal cleanup")
	check(SaveManager.get_counter(&"total_runs") == 8, "duplicate submit uses receipt")
	check(result.get("run_souls_earned", -1) == 35, "duplicate receipt retains earned souls without adding again")
	if phase == "replay":
		check(DirAccess.remove_absolute(path_to("user://pending_rewards.cfg.tmp")) == OK, "recover journal cleanup after second restart")
		service().call("retry_pending")
		check(journal.load("user://pending_rewards.cfg") == OK and journal.get_value("pending", "entries", {}).is_empty(), "durable journal cleanup eventually completes")
	Engine.print_error_messages = true
	await finish()
