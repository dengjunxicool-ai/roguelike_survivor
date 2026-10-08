extends RefCounted


static func initialize(default_report_dir: String) -> Dictionary:
	var save_path: String = ProjectSettings.globalize_path("user://save.cfg").replace("\\", "/").simplify_path()
	if not save_path.to_lower().begins_with("e:/codex/"):
		push_error("Verification requires an isolated user directory under E:/codex before loading SaveManager")
		return {}
	if FileAccess.file_exists(save_path):
		push_error("Verification requires a fresh isolated save directory: " + save_path)
		return {}
	var report_dir: String = default_report_dir
	var seed_value: int = 618
	var revision: String = "unspecified"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="):
			report_dir = argument.trim_prefix("--report-dir=").replace("\\", "/").simplify_path()
			if not report_dir.to_lower().begins_with("e:/codex/"):
				push_error("Explicit verification report directory must be under E:/codex")
				return {}
		elif argument.begins_with("--seed="):
			var seed_argument: String = argument.trim_prefix("--seed=")
			if not seed_argument.is_valid_int():
				push_error("Verification seed must be an integer")
				return {}
			seed_value = int(seed_argument)
		elif argument.begins_with("--revision="):
			revision = argument.trim_prefix("--revision=")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir)) != OK:
		push_error("Cannot create verification report directory: " + report_dir)
		return {}
	seed(seed_value)
	var environment: Dictionary = {"report_dir": report_dir, "save_path": save_path, "seed": seed_value, "revision": revision, "rng_seeds": {"global": seed_value}, "spawn_seed_applied": false}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var listener: Callable = _on_node_added.bind(environment)
	environment["spawn_seed_listener"] = listener
	tree.node_added.connect(listener)
	return environment


static func _on_node_added(node: Node, environment: Dictionary) -> void:
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path.ends_with("/enemy_spawner.gd"):
		node.ready.connect(_seed_spawner.bind(node, environment), CONNECT_ONE_SHOT)


static func _seed_spawner(spawner: Node, environment: Dictionary) -> void:
	var rng: RandomNumberGenerator = spawner.get("_rng") as RandomNumberGenerator
	rng.seed = int(environment.seed) + 1
	environment.rng_seeds["enemy_spawner"] = rng.seed
	environment["spawn_seed_applied"] = true


static func seed_gameplay_rngs(ui: Node, environment: Dictionary) -> bool:
	# The spawner is seeded in its ready signal, before its first process tick.
	# Other pools are seeded after real run setup, before the first gameplay choice.
	var tree: SceneTree = ui.get_tree()
	if tree.node_added.is_connected(environment.spawn_seed_listener):
		tree.node_added.disconnect(environment.spawn_seed_listener)
	if not bool(environment.spawn_seed_applied):
		push_error("Spawner must be seeded before the first wave")
		return false
	var coordinator: RefCounted = ui.get("_run_scene_coordinator") as RefCounted
	var choice: RefCounted = ui.get("_run_choice_modal_controller") as RefCounted
	var reward_pool: RefCounted = choice.get("_reward_pool") as RefCounted
	var targets: Dictionary = {
		"map_variable": coordinator.get("_map_variable_runtime"),
		"choice_modal": choice,
		"upgrade_pool": choice.get("_upgrade_pool"),
		"reward_pool": reward_pool,
		"reward_upgrade_pool": reward_pool.get("_upgrade_pool")
	}
	var offset: int = 2
	for name: String in targets:
		var rng: RandomNumberGenerator = targets[name].get("_rng") as RandomNumberGenerator
		if rng == null:
			push_error("Missing benchmark RNG: " + name)
			return false
		rng.seed = int(environment.seed) + offset
		environment.rng_seeds[name] = rng.seed
		offset += 1
	return true


static func cleanup_save(environment: Dictionary) -> bool:
	var path: String = String(environment.get("save_path", "")).replace("\\", "/").simplify_path()
	if not path.to_lower().begins_with("e:/codex/"):
		return false
	return not FileAccess.file_exists(path) or DirAccess.remove_absolute(path) == OK


static func configure_rendered_viewport() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	# Windows queues the restore from maximized mode. Resize after it settles.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await tree.process_frame
	await tree.process_frame
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var deadline: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == Vector2i(1280, 720) and tree.root.size == Vector2i(1280, 720):
			return true
	push_error("Verification viewport did not settle at 1280x720")
	return false
