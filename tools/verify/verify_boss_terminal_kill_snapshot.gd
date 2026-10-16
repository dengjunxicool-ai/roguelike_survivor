extends "res://tools/verify/qa_app_fixture.gd"

const ENEMY = preload("res://scenes/enemies/enemy.tscn")
const BOSS = preload("res://scenes/enemies/boss.tscn")

func damage(enemy: Node) -> void:
	enemy.take_damage(DamagePacket.from_dictionary({"raw_amount": 100000, "damage_origin": "primary_attack", "damage_type": "direct_magical", "source_id": "terminal_kill_check", "source_skill_id": "fireball", "source_instance_id": str(player.get_instance_id()), "can_crit": false, "can_trigger_reaction": false}, player, enemy))

func add_enemy(scene: PackedScene, id: StringName, boss: bool) -> Node:
	var enemy: Node = scene.instantiate()
	enemy.enemy_id = id
	ui._run_scene_coordinator.get_run_scene_parent(self).add_child(enemy)
	enemy.set_physics_process(false)
	if boss:
		var spawner: Node = get_first_node_in_group(&"enemy_spawner")
		spawner._boss_encounter_controller.on_boss_spawned(enemy)
	# This is production order: boss victory listener precedes UI death accounting.
	ui._run_scene_ui_bridge.connect_enemy_death_signals(self, ui)
	return enemy

func run() -> void:
	var path: String = ProjectSettings.globalize_path(SaveManager.SAVE_PATH).replace("\\", "/")
	check(path.to_lower().begins_with("e:/codex/"), "test save stays isolated on E drive")
	if not path.to_lower().begins_with("e:/codex/"): quit(1); return
	check(SaveManager.reset_progress(), "fresh isolated progression")
	await setup_run()
	var tracker: Node = ui._run_stats_tracker
	var ordinary: Node = add_enemy(ENEMY, &"small_slime", false)
	damage(ordinary)
	check(ui._kill_count == 1 and tracker.kill_count == 1, "normal death increments both live counters exactly once")
	ui._on_enemy_died(ordinary)
	check(ui._kill_count == 1 and tracker.kill_count == 1, "duplicate ordinary death callback does not count twice")
	var boss: Node = add_enemy(BOSS, &"dungeon_heart", true)
	damage(boss)
	check(boss._is_dead and boss.current_health <= 0, "real damage pipeline kills the boss")
	check(ui.current_state == "RESULT_VICTORY", "real boss death enters victory synchronously")
	check(tracker.kill_count == 2 and ui._kill_count == 2, "live counters include ordinary enemy and boss")
	var frozen: Dictionary = ui._frozen_result_state
	check(int(frozen.get("kill_count", -1)) == 2, "frozen result includes final boss kill")
	check(int(frozen.get("run_stats", {}).get("kill_count", -1)) == 2, "frozen stats include final boss kill")
	check(bool(frozen.get("run_stats", {}).get("boss_defeated", false)), "frozen stats carry real boss defeated flag")
	check(SaveManager.get_counter(&"total_kills") == 2, "permanent total kills includes boss")
	check(int(SaveManager.get_last_run_summary().get("kill_count", -1)) == 2, "persisted result includes boss")
	var labels: Dictionary = ui._result_controller._labels_by_state["RESULT_VICTORY"]
	check(labels.kill.text.contains("2"), "rendered result kill label includes boss")
	ui._on_enemy_died(boss)
	ui._on_boss_defeated(300.0)
	ui._refresh_result_screen("RESULT_VICTORY")
	check(ui._kill_count == 2 and tracker.kill_count == 2, "duplicate death callback cannot count boss twice")
	check(SaveManager.get_counter(&"total_runs") == 1 and SaveManager.get_counter(&"total_kills") == 2, "duplicate terminal refresh remains idempotent")
	ui._on_player_died()
	check(ui.current_state == "RESULT_VICTORY", "later player signal cannot overwrite first terminal victory")
	# A second real run proves the per-run accounting is reset and defeat stays locked.
	ui.transition_to("CHARACTER_SELECT")
	ui._on_loadout_confirmed(&"mage")
	await ui._start_run(&"abandoned_dungeon")
	await create_timer(0.3, true).timeout
	player = get_first_node_in_group(&"player")
	ui._run_scene_coordinator.get_run_scene_parent(self).process_mode = Node.PROCESS_MODE_DISABLED
	var second: Node = add_enemy(ENEMY, &"small_slime", false)
	damage(second)
	check(ui._kill_count == 1 and ui._run_stats_tracker.kill_count == 1, "new run starts independent death accounting")
	ui._on_player_died()
	var late_boss: Node = add_enemy(BOSS, &"dungeon_heart", true)
	damage(late_boss)
	check(ui.current_state == "RESULT_DEFEAT", "late real boss death cannot overwrite first terminal defeat")
	check(int(ui._frozen_result_state.get("kill_count", -1)) == 1, "late death cannot rewrite frozen defeat counts")
	ui.transition_to("CHARACTER_SELECT")
	ui._on_loadout_confirmed(&"mage")
	await ui._start_run(&"abandoned_dungeon")
	await create_timer(0.3, true).timeout
	player = get_first_node_in_group(&"player")
	ui._run_scene_coordinator.get_run_scene_parent(self).process_mode = Node.PROCESS_MODE_DISABLED
	var living_boss: Node = add_enemy(BOSS, &"dungeon_heart", true)
	ui._on_boss_defeated(300.0)
	check(living_boss.current_health > 0 and ui._kill_count == 0 and ui._run_stats_tracker.kill_count == 0, "manual victory signal cannot manufacture a kill for a living boss")
	ui._teardown_run_scene()
	await settle(2)
	if FileAccess.file_exists(path): check(DirAccess.remove_absolute(path) == OK, "isolated test save cleaned")
	await finish()
