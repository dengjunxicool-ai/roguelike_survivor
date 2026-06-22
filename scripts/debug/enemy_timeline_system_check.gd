extends SceneTree


var _failed: bool = false
var _timeline_events: Array[String] = []


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	await process_frame
	await _run_checks_impl()
	print("[EnemyTimelineSystemCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


func _run_checks_impl() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn") as PackedScene
	if main_scene == null or enemy_scene == null:
		_fail("required scenes exist")
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var player: Node2D = main.get_node_or_null("Player") as Node2D
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if player == null or spawner == null:
		_fail("main scene missing Player or EnemySpawner")
		return

	player.global_position = Vector2(512, 512)
	spawner.call("reset_for_run")
	if spawner.has_signal(&"timeline_event_started"):
		spawner.connect(&"timeline_event_started", Callable(self, "_on_timeline_event_started"))

	await _check_cleanup_keeps_boss(main, enemy_scene, spawner)
	await _check_boss_event(main, spawner)
	await _check_boss_minion_spawn(spawner)


func _check_cleanup_keeps_boss(main: Node, enemy_scene: PackedScene, spawner: Node) -> void:
	var normal_enemy: Node2D = _make_enemy(enemy_scene, &"small_slime", "normal", Vector2(460, 512))
	var boss_enemy: Node2D = _make_enemy(enemy_scene, &"dungeon_heart", "boss", Vector2(560, 512))
	main.add_child(normal_enemy)
	main.add_child(boss_enemy)
	await process_frame

	spawner.call("_clear_normal_enemies")
	await process_frame
	_expect(not is_instance_valid(normal_enemy) and is_instance_valid(boss_enemy), "cleanup removes normal enemies and keeps boss")
	if is_instance_valid(boss_enemy):
		boss_enemy.queue_free()
	await process_frame


func _check_boss_event(main: Node, spawner: Node) -> void:
	var before_boss_count: int = _count_enemy_type("boss")
	spawner.set("_normal_phase_complete", true)
	spawner.call("_process_boss_event")
	await process_frame

	var after_boss_count: int = _count_enemy_type("boss")
	_expect(bool(spawner.get("_boss_active")), "boss encounter marks boss active")
	_expect(after_boss_count > before_boss_count, "boss encounter spawns boss")
	_expect(_timeline_events.has("boss:dungeon_heart"), "boss encounter emits timeline event")


func _check_boss_minion_spawn(spawner: Node) -> void:
	var before_count: int = _count_enemy_type("boss_minion")
	spawner.set("_boss_minion_spawn_cooldown", 0.0)
	spawner.call("_process_boss_minion_spawn", 3.1)
	await process_frame
	var after_count: int = _count_enemy_type("boss_minion")
	_expect(after_count > before_count, "boss_event.minion_spawn spawns boss minions")


func _make_enemy(enemy_scene: PackedScene, enemy_id: StringName, enemy_type: String, position: Vector2) -> Node2D:
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	enemy.set("enemy_id", enemy_id)
	enemy.set("load_config_from_data", false)
	enemy.set("_behavior", {"type": "chase_player"})
	enemy.set_meta("enemy_type", enemy_type)
	enemy.global_position = position
	return enemy


func _count_enemy_type(enemy_type: String) -> int:
	var count: int = 0
	for node: Node in get_nodes_in_group(&"enemy"):
		if String(node.get_meta("enemy_type", "normal")) == enemy_type:
			count += 1
	return count


func _on_timeline_event_started(event_id: String, _announcement: String) -> void:
	_timeline_events.append(event_id)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[EnemyTimelineSystemCheck] PASS %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	push_error("[EnemyTimelineSystemCheck] FAIL %s" % message)
