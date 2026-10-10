extends "res://tools/verify/qa_app_fixture.gd"
const Pool = preload("res://scripts/upgrades/run_reward_pool.gd")
const Repo = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const Dispatch = preload("res://scripts/ui/ui_command_dispatcher.gd")
const Command = preload("res://scripts/ui/ui_command.gd")
const Query = preload("res://scripts/modifiers/modifier_query.gd")
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
func damage_amount(target: Node, origin: String, percent: bool = false) -> int:
	var packet := DamagePacket.from_dictionary({"raw_amount":0.01 if percent else 10000.0,"source_skill_id":"qa_blessing","source_instance_id":"qa_blessing:1","damage_origin":origin,"damage_type":"true_percent_damage" if percent else "direct_magical","element":"neutral","can_crit":false,"uses_character_damage_multiplier":false,"ignore_defense":true,"ignore_resistance":true,"ignore_vulnerability":true},player,target)
	return DamageSystem.calculate(packet,target).amount
func run() -> void:
	await setup_run()
	player.level = 12
	var pool: RefCounted = Pool.new()
	player.current_health = 15
	var misses: int = 0
	var learning_cards: int = 0
	for seed_value: int in 100:
		for kind: String in ["elite","boss_blessing"]:
			pool._rng.seed = seed_value
			pool._upgrade_pool._rng.seed = seed_value + 1000
			var options: Array[Dictionary] = pool.generate_reward_options(player,kind)
			if not pool._has_tag(options,"生存" if kind == "elite" else "Boss"): misses += 1
			check(options.size() == 3, "three rewards " + kind + " " + str(seed_value))
			var ids: Array = []
			for option: Dictionary in options:
				check(not ids.has(option.id),"visible rewards contain no duplicates")
				ids.append(option.id)
				var id: StringName = StringName(option.payload.get("upgrade_id",""))
				if id != &"": check(not Repo.resolve_upgrade(id).is_empty(), "generated upgrade reference resolves " + str(id))
	check(misses == 0,"guarantees survive final three-card selection")
	player.current_health = player.max_health
	for seed_value: int in 32:
		pool._rng.seed = seed_value
		pool._upgrade_pool._rng.seed = seed_value + 1000
		for option: Dictionary in pool.generate_reward_options(player,"elite"):
			if option.payload.get("learn_skill_id","") != "": learning_cards += 1
	check(learning_cards > 0,"natural reward pool retains dynamically defined learning cards")
	player.current_health = 15
	var original_max: int = player.max_health
	player.max_health = 1000
	for hp: int in [399,400,401]:
		player.current_health = hp
		var candidates: Array[Dictionary] = [{"id":"neutral","tags":[],"payload":{"reward_kind":"elite","amount":1}}]
		pool._ensure_reward_guarantees(player,"elite",candidates)
		check(pool._has_tag(candidates,"生存") == (hp < 400),"survival guarantee boundary " + str(hp))
	player.max_health = original_max
	player.current_health = 15
	var targets: Dictionary = {}
	var baseline: Dictionary = {}
	for rank: String in ["normal","elite","boss"]:
		var target: Node = F.Target.new()
		target.set_meta("enemy_rank",rank)
		root.add_child(target)
		targets[rank] = target
		for origin: String in ["primary_attack","status_dot","reaction"]:
			baseline[rank+origin] = damage_amount(target,origin)
			check(baseline[rank+origin] > 0, "production damage fixture is valid " + rank + origin)
	var percent_before: int = damage_amount(targets.boss,"status_dot",true)
	var dispatch: RefCounted = Dispatch.new()
	for option: Dictionary in pool._build_boss_blessing_options(player):
		if option.id != "boss_risk_reward": continue
		check(dispatch.dispatch(Command.apply_choice_option(option),{"player":player,"tree":self}).get("consumed_reward",false),"risk blessing remains applicable")
		check(is_equal_approx(player.boss_hp_multiplier_add,0.2) and is_equal_approx(get_first_node_in_group(&"enemy_spawner")._boss_health_multiplier_bonus,0.2),"risk blessing retains boss health bonus")
	for option: Dictionary in pool._build_boss_blessing_options(player):
		if option.id not in ["boss_damage_blessing","boss_status_blessing"]: continue
		var result: Dictionary = dispatch.dispatch(Command.apply_choice_option(option), {"player":player,"tree":self})
		check(result.get("consumed_reward",false), "valid boss blessing applies " + str(option.id))
		var store: Node = player.get_node("ModifierStore")
		for origin: String in ["primary_attack","status_dot","reaction"]:
			for rank: String in ["normal","elite","boss"]:
				var query: RefCounted = Query.for_damage(DamagePacket.from_dictionary({"raw_amount":100,"damage_origin":origin}),player).with_target_type(rank)
				var snapshot: Dictionary = store.collect(query)
				var bonus: float = float(snapshot.get("boss_damage_multiplier_add",0))
				var expected: float = 0.15 if rank == "boss" else 0.0
				if option.id == "boss_status_blessing" and rank == "boss" and origin in ["status_dot","reaction"]: expected = 0.30
				check(is_equal_approx(bonus,expected), "boss/source filter " + str(option.id) + " " + origin + " " + rank)
				var calculated: int = damage_amount(targets[rank],origin)
				check(absi(calculated-roundi(float(baseline[rank+origin])*(1.0+expected))) <= 1,"production damage amount " + str(option.id) + " " + origin + " " + rank)
				check(is_zero_approx(float(snapshot.get("dot_damage_multiplier_add",0))) and is_zero_approx(float(snapshot.get("reaction_damage_multiplier_add",0))),"compound scope does not double-count output bonus")
	check(damage_amount(targets.boss,"status_dot",true) == percent_before,"boss blessings do not amplify true percent damage")
	var fallback: Array[Dictionary] = [{"id":"neutral","tags":[],"payload":{"reward_kind":"boss_blessing","amount":1}}]
	pool._ensure_reward_guarantees(player,"boss_blessing",fallback)
	check(fallback[0].id == "boss_heal_guarantee" and fallback[0].payload.has("heal_percent"),"capped Boss upgrade has claimable healing fallback")
	for target: Node in targets.values(): target.free()
	var armor_option: Dictionary = {}
	for option: Dictionary in pool._build_elite_reward_options(player):
		if option.payload.get("upgrade_id","") == "survival_defense": armor_option = option; break
	check(not armor_option.is_empty() and not str(armor_option.get("description","")).contains("护盾") and str(armor_option.get("description","")).contains("护甲"), "armor reward copy matches actual effect")
	if not armor_option.is_empty():
		var before: float = player.armor
		dispatch.dispatch(Command.apply_choice_option(armor_option), {"player":player,"tree":self})
		check(is_equal_approx(player.armor,before+2.0),"armor reward adds exactly two")
	# Capped upgrades must not produce dead fixed reward cards.
	for i: int in 5: player.apply_upgrade(&"level_up_upgrade:survival_defense")
	for option: Dictionary in pool._build_elite_reward_options(player):
		check(option.payload.get("upgrade_id","") != "survival_defense", "capped armor omitted from fixed rewards")
	await finish()
