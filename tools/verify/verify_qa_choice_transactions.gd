extends "res://tools/verify/qa_app_fixture.gd"
const Dispatcher = preload("res://scripts/ui/ui_command_dispatcher.gd")
const Command = preload("res://scripts/ui/ui_command.gd")
const Repo = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const Builder = preload("res://scripts/upgrades/skill_learn_option_builder.gd")
const Pool = preload("res://scripts/upgrades/run_reward_pool.gd")
const Slots = preload("res://scripts/skills/skill_slot_policy.gd")
func replacement_view() -> Node:
	return _find_view(root)
func _find_view(node: Node) -> Node:
	if node is SkillReplacementView: return node
	for child: Node in node.get_children():
		var found: Node = _find_view(child)
		if found != null: return found
	return null
func run() -> void:
	await setup_run()
	player.level = 12
	for id in [&"fire_cast_meteor_rain", &"fire_cast_lava_rift", &"fire_cast_scorching_vortex", &"fire_summon_crimson_dragon", &"fire_summon_ember_fox_pack"]:
		check(manager.add_skill(id), "fill slot " + str(id))
	var option: Dictionary = Builder.build_option_data(GameData.get_skill(&"holy_summon_shield_guardian"), Repo.resolve_upgrade(&"learn_skill_holy_summon_shield_guardian"), "epic")
	var dispatch: RefCounted = Dispatcher.new()
	player.current_health = player.max_health / 2
	var before_hp: int = player.current_health
	var bad := {"id":"invalid_combo", "payload":{"reward_kind":"elite", "heal_percent":0.5,"upgrade_id":"missing_qa_upgrade"}}
	var result: Dictionary = dispatch.dispatch(Command.apply_choice_option(bad), {"player":player,"tree":self})
	check(not result.get("handled",false) and not result.get("consumed_reward",false), "invalid reward rejected without consumption")
	check(player.current_health == before_hp, "invalid composite reward does not partially heal")
	var ordinary: Dictionary = option.duplicate(true)
	var choice: RefCounted = ui._run_choice_modal_controller
	choice.add_pending_level(1)
	ui.transition_to("LEVEL_UP_MODAL")
	await settle()
	choice._select_upgrade_option(ordinary, "RUNNING", true)
	await settle()
	var view: Node = replacement_view()
	check(view != null and paused, "ordinary replacement stays paused")
	if view != null:
		check(view.layer > ui.layer, "replacement draws above choice UI")
		await capture("replacement-overlay")
		var count: int = choice.pending_level_up_count
		var rng_before: int = choice._upgrade_pool._rng.state
		var candidates_before: Array[String] = []
		for card: Button in choice._choice_card_buttons:
			candidates_before.append(card.tooltip_text)
		ui._reroll_skill_choices()
		var candidates_after: Array[String] = []
		for card: Button in choice._choice_card_buttons:
			candidates_after.append(card.tooltip_text)
		check(choice._upgrade_pool._rng.state == rng_before and candidates_before == candidates_after, "replacement confirmation blocks skill reroll")
		check(choice.pending_level_up_count == count and replacement_view() == view, "blocked reroll preserves replacement transaction")
		choice._select_upgrade_option(ordinary,"RUNNING",true)
		await settle()
		check(replacement_view() == view, "duplicate click keeps one transaction")
		await click(buttons(view)[-1])
		check(replacement_view() == null and paused and choice.pending_level_up_count == count, "cancel retains original choice and opportunity")
		check(not player.get_meta("ordinary_replacement_used",false), "cancel does not consume replacement opportunity")
	choice._select_upgrade_option(ordinary,"RUNNING",true)
	await settle()
	choice.reset_run()
	await settle()
	check(replacement_view() == null, "run reset cancels and removes pending replacement")
	check(not player.get_meta("ordinary_replacement_used",false), "run reset does not spend replacement opportunity")
	var pool: RefCounted = Pool.new()
	var reward: Dictionary = {}
	for seed_value: int in 100:
		pool._rng.seed = seed_value
		pool._upgrade_pool._rng.seed = seed_value + 1000
		for candidate: Dictionary in pool.generate_reward_options(player,"elite"):
			var id: StringName = StringName(candidate.payload.get("learn_skill_id",""))
			if id != &"" and Slots.counts_active_capacity(GameData.get_skill(id)):
				reward = candidate
				break
		if not reward.is_empty(): break
	check(not reward.is_empty(),"natural full-slot reward generates replaceable skill")
	if reward.is_empty():
		await finish()
		return
	var new_id: StringName = StringName(reward.payload.learn_skill_id)
	choice.pending_level_up_count = 0
	ui.transition_to("RUNNING")
	await settle()
	choice.pending_reward_kinds.append("elite")
	ui.transition_to("RUN_REWARD_MODAL")
	await settle()
	choice._select_upgrade_option(reward,"RUNNING",false)
	await settle()
	view = replacement_view()
	check(view != null and choice.pending_reward_kinds.size() == 1 and paused, "full-slot reward waits for replacement before consumption")
	if view != null:
		await click(buttons(view)[-1])
		check(choice.pending_reward_kinds.size() == 1 and paused and replacement_view() == null,"reward cancel preserves queue and pause")
		player.set_meta("ordinary_replacement_used",true)
		choice._select_upgrade_option(reward,"RUNNING",false)
		await settle()
		check(choice.pending_reward_kinds.size() == 1 and replacement_view() == null,"exhausted replacement opportunity cannot consume reward")
		player.set_meta("ordinary_replacement_used",false)
		choice._select_upgrade_option(reward,"RUNNING",false)
		await settle()
		view = replacement_view()
		await click(buttons(view)[0])
		check(manager.has_learned_skill(new_id), "actual mouse confirms new reward skill")
		check(not manager.has_skill(&"fire_cast_meteor_rain"), "only chosen ordinary slot removed")
		var learned: RefCounted = manager.get_skill(new_id)
		check(learned != null and learned.current_rarity == reward.rarity, "reward rarity preserved")
		check(choice.pending_reward_kinds.is_empty() and ui.current_state == "RUNNING" and not paused, "commit consumes reward and restores gameplay")
		check(replacement_view() == null and player.get_meta("ordinary_replacement_used",false), "committed view and transaction cleaned")
		check(manager._count_capacity_active_skills() == 5,"replacement preserves ordinary slot count")
	await finish()
