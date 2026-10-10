extends "res://tools/verify/qa_app_fixture.gd"

const Dispatcher = preload("res://scripts/ui/ui_command_dispatcher.gd")

func run() -> void:
	await setup_run()
	var save_path: String = ProjectSettings.globalize_path("user://save.cfg").replace("\\", "/")
	if not save_path.begins_with("E:/codex/"):
		check(false, "reward failure test uses E drive isolated save")
		await finish()
		return
	check(SaveManager.reset_progress() and SaveManager.add_soul_stones(10) == 10, "reward failure test starts with ten souls")
	var temporary_path: String = save_path + ".tmp"
	check(DirAccess.make_dir_absolute(temporary_path) == OK, "reward failure test blocks temporary save with a directory")
	var dispatcher = Dispatcher.new()
	var direct: Dictionary = dispatcher.dispatch({"type":"add_soul_stones", "amount":5})
	check(not direct.get("handled", false) and direct.get("added", -1) == 0 and direct.get("total", -1) == 10, "direct currency command reports zero added when saving fails")
	var option: Dictionary = {"id":"reward_soul_stones", "payload":{"reward_kind":"elite", "amount":5}}
	var tracker: Node = ui._run_stats_tracker
	var before_rewards: int = tracker.elite_rewards_taken
	var result: Dictionary = dispatcher.dispatch({"type":"apply_choice_option", "option":option}, {"player":player, "tree":self})
	check(not result.get("handled", false) and not result.get("consumed_reward", false), "failed currency save rejects soul reward without consuming it")
	check(SaveManager.get_soul_stones() == 10 and tracker.elite_rewards_taken == before_rewards, "failed soul reward leaves currency and statistics unchanged")
	player.current_health = player.max_health - 20
	var before_health: int = player.current_health
	var mixed_heal: Dictionary = option.duplicate(true)
	mixed_heal.payload.heal_percent = 0.25
	result = dispatcher.dispatch({"type":"apply_choice_option", "option":mixed_heal}, {"player":player, "tree":self})
	check(not result.get("handled", false) and player.current_health == before_health, "failed currency save applies no secondary healing")
	var mixed_upgrade: Dictionary = option.duplicate(true)
	mixed_upgrade.payload.upgrade_id = "survival_heal"
	result = dispatcher.dispatch({"type":"apply_choice_option", "option":mixed_upgrade}, {"player":player, "tree":self})
	check(not result.get("handled", false) and player.current_health == before_health, "unsupported mixed soul and upgrade reward is rejected before either effect")
	var modal: RefCounted = ui._run_choice_modal_controller
	modal.pending_reward_kinds.assign(["elite"])
	modal._select_upgrade_option(option, "RUNNING", false)
	check(modal.pending_reward_kinds == ["elite"], "modal retains failed soul reward for retry")
	check(DirAccess.remove_absolute(temporary_path) == OK, "reward failure test removes E drive directory fault")
	modal._select_upgrade_option(option, "RUNNING", false)
	check(SaveManager.get_soul_stones() == 15 and modal.pending_reward_kinds.is_empty(), "retry saves souls and consumes one reward")
	check(tracker.elite_rewards_taken == before_rewards + 1, "retry records one successful reward only")
	await finish()
