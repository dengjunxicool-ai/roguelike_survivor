extends SceneTree


var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	await process_frame
	await _run_checks_impl()
	print("[EnemySkillSystemCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


func _run_checks_impl() -> void:
	var main_scene: PackedScene = load("res://scenes/app/main.tscn") as PackedScene
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	if main_scene == null or enemy_scene == null:
		_fail("required scenes exist")
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var player: Node2D = main.get_node_or_null("Player") as Node2D
	if player == null:
		_fail("main scene has player")
		return
	player.global_position = Vector2(512, 512)

	await _check_enemy_overlap_escape(main, enemy_scene, player)
	await _check_projectile_action(main, enemy_scene)
	await _check_damage_area_action(main, enemy_scene)
	await _check_self_explode_action(main, enemy_scene, player)
	await _check_summon_action(main, enemy_scene)
	await _check_contact_status_action(main, enemy_scene, player)
	await _check_boss_phase_actions(main, enemy_scene)


func _check_projectile_action(main: Node, enemy_scene: PackedScene) -> void:
	var enemy: Node2D = await _spawn_enemy(main, enemy_scene, &"archer_skeleton", Vector2(420, 512))
	var before_count: int = get_nodes_in_group("enemy_projectile").size()
	var executed: bool = bool(enemy.call("_execute_enemy_skill_action", "projectile", {"direction": Vector2.RIGHT}))
	await process_frame
	var after_count: int = get_nodes_in_group("enemy_projectile").size()
	_expect(executed and after_count > before_count, "projectile action spawns enemy projectile")


func _check_enemy_overlap_escape(main: Node, enemy_scene: PackedScene, player: Node2D) -> void:
	var blocker: Node2D = await _spawn_enemy(main, enemy_scene, &"skeleton", player.global_position + Vector2(0, -46))
	var blocker_position: Vector2 = blocker.global_position
	(player as CharacterBody2D).velocity = Vector2.UP * 220.0
	player.call("_limit_actor_motion", 0.2)
	var player_unblocked: bool = is_equal_approx((player as CharacterBody2D).velocity.length(), 220.0)
	(player as CharacterBody2D).velocity = Vector2.ZERO
	_expect(player_unblocked and blocker.global_position == blocker_position, "player movement is not body-blocked by enemy collision")
	blocker.queue_free()
	await process_frame

	var moving_enemy: Node2D = await _spawn_enemy(main, enemy_scene, &"skeleton", player.global_position + Vector2(120, 0))
	var enemy_blocker: Node2D = await _spawn_enemy(main, enemy_scene, &"skeleton", player.global_position + Vector2(74, 0))
	moving_enemy.set("velocity", Vector2.LEFT * 120.0)
	moving_enemy.call("_limit_actor_motion", 0.5, false)
	_expect((moving_enemy as CharacterBody2D).velocity.length() < 120.0 and enemy_blocker.global_position.distance_to(moving_enemy.global_position) > 0.0, "enemy movement is blocked by enemy collision")
	moving_enemy.queue_free()
	enemy_blocker.queue_free()
	await process_frame


func _check_damage_area_action(main: Node, enemy_scene: PackedScene) -> void:
	var enemy: Node2D = await _spawn_enemy(main, enemy_scene, &"toxic_matriarch", Vector2(460, 512))
	var before_count: int = _count_damage_areas(main)
	var executed: bool = bool(enemy.call("_execute_enemy_skill_action", "damage_area", {"position": Vector2(512, 512)}))
	await process_frame
	var after_count: int = _count_damage_areas(main)
	_expect(executed and after_count > before_count, "damage_area action spawns damage area")


func _check_self_explode_action(main: Node, enemy_scene: PackedScene, player: Node2D) -> void:
	var enemy: Node2D = await _spawn_enemy(main, enemy_scene, &"bomber", player.global_position + Vector2(24, 0))
	var before_area_count: int = _count_damage_areas(main)
	var before_health: int = int(player.get("current_health"))
	var executed: bool = bool(enemy.call("_execute_enemy_skill_action", "self_explode"))
	for frame_index: int in range(12):
		await process_frame
	var damaged_player: bool = int(player.get("current_health")) < before_health
	_expect(executed and damaged_player and not is_instance_valid(enemy) and _count_damage_areas(main) >= before_area_count, "self_explode damages and removes bomber safely")


func _check_summon_action(main: Node, enemy_scene: PackedScene) -> void:
	var enemy: Node2D = await _spawn_enemy(main, enemy_scene, &"skeleton_priest", Vector2(560, 512))
	var before_count: int = get_nodes_in_group("enemy").size()
	var executed: bool = bool(enemy.call("_execute_enemy_skill_action", "summon", {"center": enemy.global_position}))
	await process_frame
	var after_count: int = get_nodes_in_group("enemy").size()
	_expect(executed and after_count > before_count, "summon action spawns summoned enemy")


func _check_contact_status_action(main: Node, enemy_scene: PackedScene, player: Node2D) -> void:
	var enemy: Node2D = await _spawn_enemy(main, enemy_scene, &"toxic_bug", Vector2(600, 512))
	var executed: bool = bool(enemy.call("_execute_enemy_skill_action", "contact_status", {"target": player}))
	await process_frame
	_expect(executed and player.has_method("has_status") and bool(player.call("has_status", &"poison")), "contact_status action applies poison")


func _check_boss_phase_actions(main: Node, enemy_scene: PackedScene) -> void:
	var boss: Node2D = await _spawn_enemy(main, enemy_scene, &"dungeon_heart", Vector2(620, 512))
	var before_area_count: int = _count_damage_areas(main)
	var area_executed: bool = bool(boss.call("_execute_boss_skill", {
		"skill_id": "red_circle",
		"type": "delayed_area_blast",
		"radius": 78,
		"damage": 12,
		"delay": 0.2
	}))
	await process_frame
	_expect(area_executed and _count_damage_areas(main) > before_area_count, "boss phase area skill uses enemy skill action")

	var before_projectile_count: int = get_nodes_in_group("enemy_projectile").size()
	var projectile_executed: bool = bool(boss.call("_execute_boss_skill", {
		"skill_id": "ring_bullets",
		"type": "ring_projectiles",
		"projectile_count": 6,
		"damage": 8,
		"speed": 180
	}))
	await process_frame
	_expect(projectile_executed and get_nodes_in_group("enemy_projectile").size() > before_projectile_count, "boss phase ring skill uses enemy skill action")


func _spawn_enemy(main: Node, enemy_scene: PackedScene, enemy_id: StringName, position: Vector2) -> Node2D:
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	enemy.set("enemy_id", enemy_id)
	enemy.global_position = position
	main.add_child(enemy)
	await process_frame
	return enemy


func _count_damage_areas(root_node: Node) -> int:
	var count: int = 0
	for child: Node in root_node.get_children():
		if child is DamageArea:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[EnemySkillSystemCheck] PASS %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	push_error("[EnemySkillSystemCheck] FAIL %s" % message)
