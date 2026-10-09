## 固定角色/地图/种子/无额外永久成长的短局基线，不代表整局平衡验收。
extends SceneTree
const RunEnvironment = preload("res://tools/verify/verification_run_environment.gd")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var env: Dictionary = RunEnvironment.initialize("E:/codex/skill-rebalance/gameplay-baseline")
	if env.is_empty():
		quit(1)
		return
	var scene: Node = load("res://scenes/app/app_bootstrap.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var ui: Node = scene.get_node("UIManager")
	ui.call("transition_to", "TITLE")
	await process_frame
	ui.call("transition_to", "CHARACTER_SELECT")
	await process_frame
	ui.get("_character_loadout_controller").call("refresh", &"mage")
	await process_frame
	ui.call("_on_loadout_confirmed", &"mage")
	await process_frame
	await ui.call("_start_run", &"abandoned_dungeon")
	RunEnvironment.seed_gameplay_rngs(ui, env)
	Engine.time_scale = 5.0
	var elapsed: float = 0.0
	var frames: int = 0
	while elapsed < 30.0:
		await physics_frame
		frames += 1
		if String(ui.get("current_state")) != "RUNNING":
			break
		elapsed += 5.0 / 60.0
	var player: Node = get_first_node_in_group(&"player")
	var sample: Dictionary = {"character": "mage", "map": "abandoned_dungeon", "seed": env.seed, "permanent_growth": "fresh isolated save", "elapsed": elapsed, "frames": frames, "state": ui.get("current_state"), "enemies": get_nodes_in_group(&"enemies").size()}
	if player != null:
		sample["power"] = player.get("attack_power")
		sample["health"] = player.get("current_health")
	var file: FileAccess = FileAccess.open(String(env.report_dir).path_join("sample.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(sample, "\t"))
	file.close()
	print("[skill_rebalance_run_sample] OBSERVED " + JSON.stringify(sample))
	Engine.time_scale = 1.0
	paused = false
	scene.queue_free()
	await process_frame
	quit(0)
