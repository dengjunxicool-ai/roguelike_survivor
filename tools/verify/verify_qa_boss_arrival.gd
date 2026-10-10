extends "res://tools/verify/qa_app_fixture.gd"
func run() -> void:
	await setup_run()
	var spawner: Node = get_first_node_in_group(&"enemy_spawner")
	var tracker: Node = ui._run_stats_tracker
	# Do not yield or refresh HUD between activation and defeat.
	tracker.boss_phase_started_at = -1.0
	tracker.set_run_time(137.0)
	spawner._elapsed_time = 137.0
	spawner._on_spawn_activated({"run_generation":spawner._run_generation,"source_type":"boss"},null)
	ui._on_player_died()
	var saved: Dictionary = SaveManager.get_last_run_summary()
	check(saved.get("reached_boss",false),"same-frame boss activation and defeat persists arrival")
	check(not saved.get("victory",true),"arrival does not turn defeat into victory")
	check(SaveManager.get_counter(&"boss_kills") == 0,"arrival does not count boss kill")
	await finish()
