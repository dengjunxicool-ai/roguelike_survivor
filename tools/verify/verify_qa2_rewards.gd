extends "res://tools/verify/qa_app_fixture.gd"
const Pool = preload("res://scripts/upgrades/run_reward_pool.gd")
const Dispatch = preload("res://scripts/ui/ui_command_dispatcher.gd")
const Command = preload("res://scripts/ui/ui_command.gd")

func run() -> void:
	await setup_run()
	var pool := Pool.new()
	check(pool.generate_reward_options(player, "boss_blessing").size() == 3, "baseline has three Boss options")
	SaveManager.save_value("permanent_upgrades", "meta_combat_intuition", 1)
	player._apply_permanent_upgrade_modifiers()
	check(pool.generate_reward_options(player, "boss_blessing").size() == 4, "combat intuition adds fourth Boss option")
	check(pool.generate_reward_options(player, "elite").size() == 3, "combat intuition leaves elite count unchanged")
	var before_radius: float = player.get_effective_pickup_radius()
	SaveManager.save_value("permanent_upgrades", "meta_pickup", 1)
	player._apply_permanent_upgrade_modifiers()
	check(is_equal_approx(player.get_effective_pickup_radius() / before_radius, 1.04) and str(GameData.get_permanent_upgrade(&"meta_pickup").description).contains("4%"), "pickup display matches actual four percent per level")
	var relic_manager: Node = player.get_node("RelicManager")
	var relics: Array = GameData.get_relic_pool()
	var invalid_cards: int = 0
	var seeds: Array[int] = [19, 30, 69, 77]
	for run_seed: int in 16: seeds.append(run_seed)
	for owned_count: int in range(4):
		if owned_count > 0:
			check(relic_manager.add_relic(relics[owned_count - 1].id), "fixture adds relic " + str(owned_count))
		for run_seed: int in seeds:
			for kind: String in ["elite", "boss_blessing"]:
				pool._rng.seed = run_seed
				pool._upgrade_pool._rng.seed = run_seed
				var options: Array[Dictionary] = pool.generate_reward_options(player, kind)
				if options.size() != (4 if kind == "boss_blessing" else 3): invalid_cards += 1
				for option: Dictionary in options:
					var id: StringName = StringName(option.payload.get("relic_id", ""))
					if id == &"": continue
					if not relic_manager.can_add_relic() or relic_manager.has_relic(id): invalid_cards += 1
	check(invalid_cards == 0, "0-3 owned relics across twenty seeds including prior duplicate cases offer only claimable cards")
	# Exhausting candidates at a larger inventory limit also produces no relic card.
	relic_manager.max_relics = relics.size() + 1
	for relic: Dictionary in relics:
		if not relic_manager.has_relic(relic.id): relic_manager.add_relic(relic.id)
	check(pool._build_elite_reward_options(player).all(func(option: Dictionary) -> bool: return not option.payload.has("relic_id")), "exhausted relic definitions fall back to other rewards")
	var armor_option: Dictionary = {}
	for option: Dictionary in pool._build_boss_blessing_options(player):
		if option.id == "boss_control_blessing": armor_option = option
	check(not armor_option.is_empty(), "stable Boss reward id retained")
	check(str(armor_option.get("description", "")).contains("护甲") and not armor_option.get("tags", []).has("控制"), "Boss armor copy and tags match effect")
	var before_armor: float = player.armor
	var result: Dictionary = Dispatch.new().dispatch(Command.apply_choice_option(armor_option), {"player":player,"tree":self})
	check(result.get("handled", false) and is_equal_approx(player.armor, before_armor + 2), "Boss armor reward grants exactly two armor")
	var controller: RefCounted = ui._run_choice_modal_controller
	# Keep an experience card from opening a separate level-up modal during this card-pool test.
	player.experience_to_next_level = 1000000
	controller.queue_reward("boss_blessing")
	ui.transition_to("RUN_REWARD_MODAL")
	await settle(10)
	var reward_buttons: Array[Button] = buttons(ui._reward_options).filter(func(button: Button) -> bool: return button.is_visible_in_tree())
	check(reward_buttons.size() == 4, "all four Boss cards are visible after three-card prewarm")
	for button: Button in reward_buttons:
		print("[qa2_rewards] viewport=", root.size, " container=", ui._reward_options.get_global_rect(), " card=", button.get_global_rect())
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "Boss card lies inside viewport")
		var icon: Control = button.find_child("SkillCardIconTexture", true, false)
		var frame: Control = button.find_child("SkillCardIconFrame", true, false)
		check(frame.get_global_rect().encloses(icon.get_global_rect()), "Boss card icon fits its reserved slot")
	await capture("boss-four-options")
	if reward_buttons.size() == 4:
		await click(reward_buttons[3])
		check(controller.pending_reward_kinds.is_empty(), "fourth card is clickable and consumes reward")
	controller.queue_reward("elite")
	ui.transition_to("RUN_REWARD_MODAL")
	await settle(10)
	check(buttons(ui._reward_options).filter(func(button: Button) -> bool: return button.is_visible_in_tree()).size() == 3, "elite modal returns to three visible cards")
	ui.transition_to("TITLE")
	await settle()
	ui.transition_to("CHARACTER_SELECT")
	ui._on_loadout_confirmed(&"mage")
	await ui._start_run(&"abandoned_dungeon")
	await settle()
	var next_player: Node = get_first_node_in_group(&"player")
	check(pool.generate_reward_options(next_player, "boss_blessing").size() == 4, "saved combat intuition applies to fresh run")
	await finish()
