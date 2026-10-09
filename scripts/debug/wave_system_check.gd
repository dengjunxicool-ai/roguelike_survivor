## 文件用途：验证真实波次、玩家地图边界和相机可见区域，以及波末拾取、延迟经验幂等和超时保留敌人。
## 使用方式：通过 tools/verify/run_isolated_godot.ps1 -Script res://scripts/debug/wave_system_check.gd -OutputRoot E:/codex/<独立批次> 运行；实例化真实主场景，检查结束以退出码表示结果。
extends SceneTree


const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")

var _failed: bool = false


## 作用：一次性连接 process_frame，延后启动场景检查。
## 使用：由 Godot 构造此 SceneTree 时自动调用。
func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


## 作用：等待一帧后执行异步波次验证，以 _failed 决定进程退出码。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 直接调用时须 await 等待异步流程完成。
func _run_checks() -> void:
	await process_frame
	await _run_checks_impl()
	quit(1 if _failed else 0)


## 作用：装配真实主场景和法师 loadout，显式推进波次并冻结自动处理，顺序检查边界、相机和奖励。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 直接调用时须 await 等待异步流程完成。
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
	# These checks drive wave transitions explicitly, not by wall-clock timing.
	spawner.set_process(false)
	player.set_physics_process(false)

	await _check_player_bounds(main, player)
	await _check_camera_limits(main, player)
	_check_wave_started(spawner)
	_check_wave_spawn_cap(spawner)
	await _check_wave_end_collects_experience(main, player, spawner)
	await _check_wave_transition_collects_deferred_experience(main, player, spawner)
	await _check_wave_timeout_keeps_enemies(main, spawner)
	print("[WaveSystemCheck] done failed=%s" % str(_failed))


## 作用：把主场景地牢背景设置为废弃地牢纹理、左上锚点和原始缩放。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：main: Node。
func _apply_default_map_background(main: Node) -> void:
	var background: Sprite2D = main.get_node_or_null("DungeonBackground") as Sprite2D
	if background == null:
		return

	var texture: Texture2D = load("res://assets/ui/maps/abandoned_dungeon.png") as Texture2D
	background.texture = texture
	background.centered = false
	background.position = Vector2.ZERO
	background.scale = Vector2.ONE


## 作用：把玩家移到地图外，再调用边界刷新和夹取，等待物理帧后确认玩家回到背景范围。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：main: Node, player: Node2D。 直接调用时须 await 等待异步流程完成。
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


## 作用：检查活跃相机、正数缩放，在三种视口和地图角落确认 limits 与完整可见世界均位于背景内。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：main: Node, player: Node2D。 直接调用时须 await 等待异步流程完成。
func _check_camera_limits(main: Node, player: Node2D) -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		_fail("player camera missing")
		return
	_expect(camera.enabled, "player camera is enabled")
	_expect(camera == root.get_camera_2d(), "player camera is the active run camera")
	_expect(is_finite(camera.zoom.x) and is_finite(camera.zoom.y) and camera.zoom.x > 0.0 and camera.zoom.y > 0.0, "camera zoom defines a finite positive visible world")
	var background: Sprite2D = main.get_node("DungeonBackground") as Sprite2D
	var original_size: Vector2i = root.size
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(900, 1440)]:
		root.size = viewport_size
		background.call("refresh_layout")
		await process_frame
		await process_frame
		var bounds: Rect2 = Rect2(background.global_position, background.texture.get_size() * background.global_scale.abs())
		_expect(camera.limit_left == floori(bounds.position.x) and camera.limit_top == floori(bounds.position.y) and camera.limit_right == ceili(bounds.end.x) and camera.limit_bottom == ceili(bounds.end.y), "camera limits match resized background %s" % viewport_size)
		var visible_size: Vector2 = root.get_visible_rect().size / camera.zoom
		_expect(bounds.size.x >= visible_size.x and bounds.size.y >= visible_size.y, "background covers visible world %s" % viewport_size)
		for destination: Vector2 in [bounds.get_center(), bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
			player.global_position = destination
			player.call("_clamp_to_movement_bounds")
			camera.reset_smoothing()
			camera.force_update_scroll()
			await physics_frame
			await process_frame
			var visible_world: Rect2 = Rect2(camera.get_screen_center_position() - visible_size * 0.5, visible_size)
			_expect(bounds.grow(1.0).encloses(visible_world), "camera visible world stays inside map at %s / %s" % [viewport_size, destination])
	root.size = original_size
	background.call("refresh_layout")
	await process_frame


## 作用：检查首波索引、持续时间与配置一致且总生成预算为正。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：spawner: Node。
func _check_wave_started(spawner: Node) -> void:
	_expect(int(spawner.get("_current_wave_index")) == 0, "first wave started")
	var current_wave: Dictionary = spawner.call("_get_current_wave")
	var expected_duration: float = float(current_wave.get("duration_seconds", 0.0))
	_expect(is_equal_approx(float(spawner.get("_wave_duration")), expected_duration), "wave duration matches config")
	_expect(int(spawner.get("_wave_total_count")) > 0, "wave has fixed total count")


## 作用：将已生成计数设到波次总量后推进生成，确认不再新增敌人。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：spawner: Node。
func _check_wave_spawn_cap(spawner: Node) -> void:
	var total_count: int = int(spawner.get("_wave_total_count"))
	spawner.set("_wave_spawned_count", total_count)
	var before_count: int = get_nodes_in_group("enemy").size()
	spawner.call("_process_wave_spawn", 0.2, spawner.call("_get_current_wave"))
	var after_count: int = get_nodes_in_group("enemy").size()
	_expect(after_count == before_count, "wave does not spawn after total count reached")


## 作用：生成经验晶体后结束波次，等待奖励物理队列确认经验或等级增长及晶体清除，再重启首波。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：main: Node, player: Node2D, spawner: Node。 直接调用时须 await 等待异步流程完成。
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
	for frame_index in range(8):
		await physics_frame
		await process_frame
		if int(player.get("level")) > before_level or int(player.get("current_experience")) > before_exp:
			break
	var after_exp: int = int(player.get("current_experience"))
	var after_level: int = int(player.get("level"))
	_expect(after_level > before_level or after_exp > before_exp, "wave end auto-collects experience crystals")
	_expect(get_nodes_in_group("experience_crystal").is_empty(), "wave end removes collected crystals")
	spawner.call("_start_wave", 0)


## 作用：延迟挂入晶体同时结束波次，确认过渡收集有效且重复收集不重复发经验，随后重启首波。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：main: Node, player: Node2D, spawner: Node。 直接调用时须 await 等待异步流程完成。
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
	# Collection queues XP; PickupManager publishes rewards on a physics tick.
	for frame_index in range(8):
		await physics_frame
		await process_frame
		if int(player.get("level")) > before_level or int(player.get("current_experience")) > before_exp:
			break

	var after_exp: int = int(player.get("current_experience"))
	var after_level: int = int(player.get("level"))
	_expect(after_level > before_level or after_exp > before_exp, "wave transition collects deferred experience crystals")
	_expect(get_nodes_in_group("experience_crystal").is_empty(), "wave transition removes deferred crystals")
	for frame_index in range(2):
		spawner.call("_collect_all_experience_crystals")
		await physics_frame
		await process_frame
	_expect(int(player.get("current_experience")) == after_exp and int(player.get("level")) == after_level, "repeated wave collection does not grant deferred experience twice")
	spawner.call("_start_wave", 0)


## 作用：构造普通敌人并把波次时间推进到超时，检查场上仍保留普通敌人。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：main: Node, spawner: Node。 直接调用时须 await 等待异步流程完成。
func _check_wave_timeout_keeps_enemies(main: Node, spawner: Node) -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	main.add_child(enemy)
	enemy.set_meta("enemy_rank", "normal")
	enemy.global_position = Vector2(768, 512)
	await process_frame

	spawner.set("_wave_elapsed_time", float(spawner.get("_wave_duration")) + 0.1)
	spawner.call("_process_discrete_wave", 0.1)
	await process_frame

	var normal_count: int = 0
	for node: Node in get_nodes_in_group("enemy"):
		if String(node.get_meta("enemy_rank", "normal")) == "normal":
			normal_count += 1
	_expect(normal_count > 0, "wave timeout keeps normal enemies")


## 作用：condition 为真输出 PASS，否则记录检查失败。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：condition: bool, message: String。
func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[WaveSystemCheck] PASS %s" % message)
	else:
		_fail(message)


## 作用：设置 _failed 并用 push_error 输出检查失败信息。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：message: String。
func _fail(message: String) -> void:
	_failed = true
	push_error("[WaveSystemCheck] FAIL %s" % message)
