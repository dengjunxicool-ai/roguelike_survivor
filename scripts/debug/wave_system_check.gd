extends SceneTree


const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")

var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	await process_frame
	await _run_checks_impl()
	quit(1 if _failed else 0)


func _run_checks_impl() -> void:
	var main_scene: PackedScene = load("res://scenes/app/main.tscn") as PackedScene
	if main_scene == null:
		_fail("main scene missing")
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var player: Node2D = main.get_node_or_null("Player") as Node2D
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if player == null or spawner == null:
		_fail("main scene missing Player or EnemySpawner")
		return

	_apply_default_map_background(main)
	player.call("reset_for_loadout", CharacterLoadoutServiceScript.build_loadout(&"mage"))
	spawner.call("reset_for_run")
	spawner.call("_process_discrete_wave", 0.0)
	await physics_frame
	await physics_frame

	await _check_player_bounds(main, player)
	_check_camera_limits(player)
	_check_wave_started(spawner)
	_check_wave_spawn_cap(spawner)
	await _check_wave_end_collects_experience(main, player, spawner)
	await _check_wave_transition_collects_deferred_experience(main, player, spawner)
	await _check_wave_timeout_keeps_enemies(main, spawner)
	print("[WaveSystemCheck] done failed=%s" % str(_failed))


func _apply_default_map_background(main: Node) -> void:
	var background: Sprite2D = main.get_node_or_null("DungeonBackground") as Sprite2D
	if background == null:
		return

	var texture: Texture2D = load("res://assets/ui/maps/abandoned_dungeon.png") as Texture2D
	background.texture = texture
	background.centered = false
	background.position = Vector2.ZERO
	background.scale = Vector2.ONE


func _check_player_bounds(main: Node, player: Node2D) -> void:
	var background: Sprite2D = main.get_node_or_null("DungeonBackground") as Sprite2D
	if background == null or background.texture == null:
		_fail("background missing")
		return

	player.global_position = Vector2(-10000.0, -10000.0)
	if player.has_method("_refresh_movement_bounds"):
		player.call("_refresh_movement_bounds")
	if player.has_method("_clamp_to_movement_bounds"):
		player.call("_clamp_to_movement_bounds")
	await physics_frame
	var texture_size: Vector2 = background.texture.get_size() * background.global_scale.abs()
	var top_left: Vector2 = background.global_position
	if background.centered:
		top_left -= texture_size * 0.5
	var bounds: Rect2 = Rect2(top_left, texture_size)
	_expect(bounds.has_point(player.global_position), "player clamped inside background bounds")


func _check_camera_limits(player: Node2D) -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		_fail("player camera missing")
		return
	_expect(camera.enabled, "player camera is enabled")
	_expect(camera.zoom.x > 1.0 and camera.zoom.y > 1.0, "player camera is close enough for run exploration")
	_expect(camera.limit_right > camera.limit_left and camera.limit_bottom > camera.limit_top, "camera limits are set")


func _check_wave_started(spawner: Node) -> void:
	_expect(int(spawner.get("_current_wave_index")) == 0, "first wave started")
	var current_wave: Dictionary = spawner.call("_get_current_wave")
	var expected_duration: float = float(current_wave.get("duration_seconds", 0.0))
	_expect(is_equal_approx(float(spawner.get("_wave_duration")), expected_duration), "wave duration matches config")
	_expect(int(spawner.get("_wave_total_count")) > 0, "wave has fixed total count")


func _check_wave_spawn_cap(spawner: Node) -> void:
	var total_count: int = int(spawner.get("_wave_total_count"))
	spawner.set("_wave_spawned_count", total_count)
	var before_count: int = get_nodes_in_group("enemy").size()
	spawner.call("_process_wave_spawn", 0.2, spawner.call("_get_current_wave"))
	var after_count: int = get_nodes_in_group("enemy").size()
	_expect(after_count == before_count, "wave does not spawn after total count reached")


func _check_wave_end_collects_experience(main: Node, player: Node2D, spawner: Node) -> void:
	var crystal_scene: PackedScene = load("res://scenes/drops/experience_crystal.tscn") as PackedScene
	var crystal: Node2D = crystal_scene.instantiate() as Node2D
	main.add_child(crystal)
	crystal.global_position = player.global_position + Vector2(120, 0)
	if crystal.has_method("set_experience_amount"):
		crystal.call("set_experience_amount", 5)
	await process_frame

	var before_exp: int = int(player.get("current_experience"))
	var before_level: int = int(player.get("level"))
	spawner.call("_finish_wave", true)
	for frame_index in range(4):
		await process_frame
	var after_exp: int = int(player.get("current_experience"))
	var after_level: int = int(player.get("level"))
	_expect(after_level > before_level or after_exp > before_exp, "wave end auto-collects experience crystals")
	_expect(get_nodes_in_group("experience_crystal").is_empty(), "wave end removes collected crystals")
	spawner.call("_start_wave", 0)


func _check_wave_transition_collects_deferred_experience(main: Node, player: Node2D, spawner: Node) -> void:
	var crystal_scene: PackedScene = load("res://scenes/drops/experience_crystal.tscn") as PackedScene
	var crystal: Node2D = crystal_scene.instantiate() as Node2D
	crystal.global_position = player.global_position + Vector2(140, 0)
	if crystal.has_method("set_experience_amount"):
		crystal.call("set_experience_amount", 7)

	var before_exp: int = int(player.get("current_experience"))
	var before_level: int = int(player.get("level"))
	main.call_deferred("add_child", crystal)
	spawner.call("_finish_wave", true)
	await process_frame
	spawner.call("_process_discrete_wave", 0.1)
	await process_frame

	var after_exp: int = int(player.get("current_experience"))
	var after_level: int = int(player.get("level"))
	_expect(after_level > before_level or after_exp > before_exp, "wave transition collects deferred experience crystals")
	_expect(get_nodes_in_group("experience_crystal").is_empty(), "wave transition removes deferred crystals")
	spawner.call("_start_wave", 0)


func _check_wave_timeout_keeps_enemies(main: Node, spawner: Node) -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	main.add_child(enemy)
	enemy.set_meta("enemy_type", "normal")
	enemy.global_position = Vector2(768, 512)
	await process_frame

	spawner.set("_wave_elapsed_time", float(spawner.get("_wave_duration")) + 0.1)
	spawner.call("_process_discrete_wave", 0.1)
	await process_frame

	var normal_count: int = 0
	for node: Node in get_nodes_in_group("enemy"):
		if String(node.get_meta("enemy_type", "normal")) == "normal":
			normal_count += 1
	_expect(normal_count > 0, "wave timeout keeps normal enemies")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[WaveSystemCheck] PASS %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	push_error("[WaveSystemCheck] FAIL %s" % message)
