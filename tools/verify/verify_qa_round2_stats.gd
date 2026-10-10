extends "res://tools/verify/qa_app_fixture.gd"

const Dispatcher = preload("res://scripts/ui/ui_command_dispatcher.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Special = preload("res://scripts/skills/skill_special_rule_executor.gd")
const Handler = preload("res://scripts/skills/special_damage_rule_handler.gd")
const Fire = preload("res://scripts/skills/fire_skill_runtime.gd")
const Progression = preload("res://scripts/game/run_progression_service.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const ProjectileScene = preload("res://scenes/combat/fireball_projectile.tscn")

class KilledEnemy extends Node:
	var enemy_id: StringName

var tracker: Node

func run() -> void:
	await setup_run()
	tracker = ui._run_stats_tracker
	SaveManager.reset_progress()
	test_healing()
	test_named_elites()
	await test_projectile_hits()
	await finish()

func test_healing() -> void:
	var dispatcher = Dispatcher.new()
	player.current_health = player.max_health
	tracker.healing_used = 0
	dispatcher._apply_healing_reward({"heal_percent":0.25}, player, self)
	check(tracker.healing_used == 0, "R204 full-health reward records zero")
	Progression.record_run_result("RESULT_VICTORY", {"selected_character_id":"mage", "selected_map_id":"abandoned_dungeon", "run_stats":tracker.get_summary()})
	check(SaveManager.is_map_challenge_completed(&"abandoned_dungeon", &"clear_without_healing"), "R204 full-health reward allows no-heal challenge")
	SaveManager.reset_progress()
	player.current_health = player.max_health - 3
	dispatcher._apply_healing_reward({"heal_percent":0.25}, player, self)
	check(tracker.healing_used == 3 and player.current_health == player.max_health, "R204 reward records actual overflow healing exactly once")
	tracker.healing_used = 0
	player.current_health = player.max_health - 50
	var before: int = player.current_health
	check(player.apply_upgrade(&"level_up_upgrade:survival_heal"), "R204 production healing upgrade applied")
	check(player.current_health == before + 30 and tracker.healing_used == 30, "R204 healing upgrade records thirty actual HP")
	tracker.healing_used = 0
	player.current_health = player.max_health - 10
	Executor.new().execute_action({"type":"heal_owner", "params":{"amount":5}}, {"caster":player})
	check(tracker.healing_used == 5 and player.current_health == player.max_health - 5, "R204 skill action records five actual HP")
	Progression.record_run_result("RESULT_VICTORY", {"selected_character_id":"mage", "selected_map_id":"abandoned_dungeon", "run_seconds":150, "run_stats":tracker.get_summary()})
	check(not SaveManager.is_map_challenge_completed(&"abandoned_dungeon", &"clear_without_healing"), "R204 healed run cannot persist no-heal challenge")
	tracker.healing_used = 0
	player._apply_modifiers({"max_hp_add":5, "max_hp_multiplier_add":0.1})
	check(tracker.healing_used == 0, "R204 max HP growth is excluded from healing")
	player.current_health = player.max_health - 20
	Special.new()._heal_player(player, 4)
	check(tracker.healing_used == 4, "R204 holy and toxic family restoration records actual HP")
	Handler.execute_holy_shield_expire({"holy_shield_expire_heal":{"amount":5}}, {"player":player})
	check(tracker.healing_used == 9, "R204 holy shield expiry adds healing once")
	player.current_health = 0
	var passive := RefCounted.new()
	var revived: int = maxi(roundi(player.max_health * 0.45), 1)
	Fire._apply_revive_once({"revive_health_ratio":0.45}, {"player":player, "passive_skill_instance":passive}, Executor.new())
	check(player.current_health == revived and tracker.healing_used == 9 + revived, "R204 fire revival records restored HP")
	Fire._apply_revive_once({"revive_health_ratio":0.45}, {"player":player, "passive_skill_instance":passive}, Executor.new())
	check(tracker.healing_used == 9 + revived, "R204 consumed revival cannot record twice")
	if player.has_method("heal"):
		tracker.healing_used = 0
		player.current_health = player.max_health - 2
		check(player.heal(9) == 2 and tracker.healing_used == 2, "R204 Player.heal returns actual restored HP")
		check(player.heal(-5) == 0 and tracker.healing_used == 2, "R204 nonpositive heal does nothing")
	else:
		check(false, "R204 unified Player.heal API exists")

func test_named_elites() -> void:
	var ids: Array[String] = ["toxic_matriarch", "lava_golem", "shadow_hunter"]
	for killed_id: String in ids:
		tracker.reset_run(&"mage", &"toxic_fog_graveyard")
		var enemy := KilledEnemy.new()
		enemy.enemy_id = StringName(killed_id)
		enemy.set_meta("enemy_rank", "elite")
		tracker.record_enemy_killed(enemy)
		var snapshot: Dictionary = tracker.get_summary()
		check(snapshot.get("enemy_kill_counts", {}).get(killed_id, 0) == 1, "R205 stores actual killed ID " + killed_id)
		for goal_id: String in ids:
			check(Progression._map_objective_met(StringName("defeat_" + goal_id), {"victory":true, "run_stats":snapshot}) == (goal_id == killed_id), "R205 " + killed_id + " matches only " + goal_id)
			check(not Progression._map_objective_met(StringName("defeat_" + goal_id), {"victory":false, "run_stats":snapshot}), "R205 defeat cannot award " + goal_id)
		var maps: Dictionary = {"toxic_matriarch":"toxic_fog_graveyard", "lava_golem":"lava_temple", "shadow_hunter":"abyss_corridor"}
		SaveManager.reset_progress()
		Progression.record_run_result("RESULT_VICTORY", {"selected_character_id":"mage", "selected_map_id":maps[killed_id], "run_stats":snapshot})
		check(SaveManager.is_map_challenge_completed(StringName(maps[killed_id]), StringName("defeat_" + killed_id)), "R205 target kill persists correct objective " + killed_id)
		var another := KilledEnemy.new()
		another.enemy_id = StringName(killed_id)
		another.set_meta("enemy_rank", "elite")
		tracker.record_enemy_killed(another)
		another.free()
		check(tracker.get_summary().get("enemy_kill_counts", {}).get(killed_id, 0) == 2, "R205 counts multiple deaths per enemy ID")
		enemy.free()
	tracker.reset_run(&"mage", &"toxic_fog_graveyard")
	var cleanup := KilledEnemy.new()
	cleanup.enemy_id = &"toxic_matriarch"
	cleanup.set_meta("enemy_rank", "elite")
	tracker.record_monster_lifecycle(cleanup, &"death")
	check(not Progression._map_objective_met(&"defeat_toxic_matriarch", {"victory":true, "run_stats":tracker.get_summary()}), "R205 lifecycle cleanup does not count as kill")
	cleanup.free()
	var unrelated := KilledEnemy.new()
	unrelated.enemy_id = &"shadow_hunter"
	unrelated.set_meta("enemy_rank", "elite")
	tracker.record_enemy_killed(unrelated)
	unrelated.free()
	Progression.record_run_result("RESULT_VICTORY", {"selected_character_id":"mage", "selected_map_id":"toxic_fog_graveyard", "run_stats":tracker.get_summary()})
	check(not SaveManager.is_map_challenge_completed(&"toxic_fog_graveyard", &"defeat_toxic_matriarch"), "R205 unrelated kill cannot persist named target objective")
	tracker.reset_run(&"mage", &"abyss_corridor")
	check(tracker.get_summary().get("enemy_kill_counts", {}).is_empty(), "R205 run reset clears named kills")

func make_enemy(world: Node2D, pos: Vector2) -> Node2D:
	var enemy: Node2D = EnemyScene.instantiate()
	enemy.enemy_id = &"slime"
	enemy.load_config_from_data = false
	enemy.max_health = 10000
	enemy._behavior = {"type":"chase_player"}
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = pos
	return enemy

func projectile(world: Node2D, pos: Vector2, pierce_count: int) -> Node:
	var shot: Node2D = ProjectileScene.instantiate()
	world.add_child(shot)
	shot.position = pos
	shot.setup({"caster":player, "source_id":&"primary_attack_fireball", "damage":5, "speed":600, "direction":Vector2.RIGHT, "pierce":pierce_count, "lifetime":1.0, "target_group":&"enemies"})
	return shot

func objective() -> bool:
	return Progression._map_objective_met(&"clear_with_pierce_or_bounce", {"victory":true, "run_stats":tracker.get_summary()})

func test_projectile_hits() -> void:
	tracker.reset_run(&"mage", &"abyss_corridor")
	for index: int in range(20): tracker.record_status_applied(&"shock")
	for index: int in range(20): tracker.record_status_applied(&"overload")
	check(not objective(), "R206 twenty shock and overload events cannot replace projectile usage")
	Progression.record_run_result("RESULT_VICTORY", {"selected_character_id":"mage", "selected_map_id":"abyss_corridor", "run_stats":tracker.get_summary()})
	check(not SaveManager.is_map_challenge_completed(&"abyss_corridor", &"clear_with_pierce_or_bounce"), "R206 pure lightning statuses cannot persist challenge")
	SaveManager.reset_progress()
	tracker.reset_run(&"mage", &"abyss_corridor")
	var world := Node2D.new()
	root.add_child(world)
	var first := make_enemy(world, Vector2(80,-4000))
	var second := make_enemy(world, Vector2(160,-4000))
	var shot: Node = projectile(world, Vector2(0,-4000), 1)
	check(not objective(), "R206 equipped pierce without hit does not qualify")
	for index: int in range(20):
		await physics_frame
		if first.current_health < 10000: break
	check(first.current_health < 10000, "R206 real projectile collision damages first enemy")
	check(not objective(), "R206 first contact does not consume actual extra-target pierce")
	for index: int in range(20):
		await physics_frame
		if second.current_health < 10000: break
	check(second.current_health < 10000, "R206 real projectile collision damages pierced second enemy")
	check(tracker.get_summary().get("pierce_hit_count", 0) == 1 and objective(), "R206 one actual extra-target pierce qualifies")
	check(not Progression._map_objective_met(&"clear_with_pierce_or_bounce", {"victory":false, "run_stats":tracker.get_summary()}), "R206 defeat cannot award used pierce challenge")
	Progression.record_run_result("RESULT_VICTORY", {"selected_character_id":"mage", "selected_map_id":"abyss_corridor", "run_stats":tracker.get_summary()})
	check(SaveManager.is_map_challenge_completed(&"abyss_corridor", &"clear_with_pierce_or_bounce"), "R206 actual pierced hit persists challenge")
	tracker.reset_run(&"mage", &"abyss_corridor")
	check(tracker.get_summary().get("pierce_hit_count", 0) == 0 and not objective(), "R206 next run clears projectile usage")
	var bounce_shot: Node = projectile(world, Vector2(0,-4300), 0)
	bounce_shot.set_physics_process(false)
	var before: int = second.current_health
	var bounced: Dictionary = Handler.execute_lightning_chain_bounce({"lightning_chain_bounce":{"bounce_count":1, "range":150}}, {"target":first, "parent":world, "caster":player, "projectile":bounce_shot}, 5)
	check(bounced.get("bounces_used", 0) == 1 and second.current_health < before, "R206 production chain bounce damages a new enemy")
	check(tracker.get_summary().get("bounce_hit_count", 0) == 1 and objective(), "R206 actual bounced hit independently qualifies")
	Handler.execute_lightning_chain_bounce({"lightning_chain_bounce":{"bounce_count":1, "range":150}}, {"target":first, "parent":world, "caster":player, "projectile":bounce_shot}, 5)
	check(tracker.get_summary().get("bounce_hit_count", 0) == 1, "R206 exhausted chain does not count another bounce")
	tracker.reset_run(&"mage", &"abyss_corridor")
	var returning: Node = projectile(world, Vector2(0,-4600), 2)
	returning.set_physics_process(false)
	returning._on_body_entered(first)
	returning._begin_return()
	returning._on_body_entered(first)
	check(not objective(), "R206 first returning contact is not an extra pierced target")
	returning.queue_free()
	tracker.reset_run(&"mage", &"abyss_corridor")
	var reused: Node = projectile(world, Vector2(0,-4600), 2)
	reused.set_physics_process(false)
	reused._on_body_entered(first)
	reused.prepare_for_pool_spawn({"caster":player, "source_id":&"primary_attack_fireball", "pierce":1})
	reused.set_physics_process(false)
	reused._on_body_entered(second)
	check(not objective(), "R206 pooled projectile clears previous pending extra hit")
	reused._on_body_entered(first)
	reused._on_body_entered(first)
	check(tracker.get_summary().get("pierce_hit_count", 0) == 1, "R206 duplicate collision counts extra target once")
	reused.queue_free()
	tracker.reset_run(&"mage", &"abyss_corridor")
	var hostile: Node = projectile(world, Vector2(0,-4600), 1)
	hostile.set_physics_process(false)
	hostile.caster = first
	hostile.damage_packet["uses_character_damage_multiplier"] = false
	hostile._on_body_entered(first)
	hostile._on_body_entered(second)
	check(not objective(), "R206 hostile projectile cannot award player challenge")
	hostile.queue_free()
	if is_instance_valid(shot): shot.queue_free()
	world.queue_free()
	await settle(2)
