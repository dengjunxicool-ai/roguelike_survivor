## 文件用途：验证敌人时间线的普通敌人清理、Boss 事件和 Boss 仆从来源计数。
## 使用方式：通过 tools/verify/run_isolated_godot.ps1 -Script res://scripts/debug/enemy_timeline_system_check.gd -OutputRoot E:/codex/<独立批次> 运行；实例化真实主场景，检查结束以退出码表示结果。
extends SceneTree


var _failed: bool = false
var _timeline_events: Array[String] = []


## 作用：将检查入口一次性连接到 process_frame，延后到场景树可用时执行。
## 使用：由 Godot 构造此 SceneTree 时自动调用。
func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


## 作用：等待首帧并执行异步检查，打印汇总并按失败标记退出。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 直接调用时须 await 等待异步流程完成。
func _run_checks() -> void:
	await process_frame
	await _run_checks_impl()
	print("[EnemyTimelineSystemCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


## 作用：装配真实主场景和玩家，重置 EnemySpawner 并监听时间线事件后执行三类检查。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 直接调用时须 await 等待异步流程完成。
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


## 作用：添加普通敌人与 Boss，调用普通敌人清理后确认 Boss 存活，并释放测试 Boss。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：main: Node, enemy_scene: PackedScene, spawner: Node。 直接调用时须 await 等待异步流程完成。
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


## 作用：强制普通阶段完成，处理 Boss 事件后检查激活标志、Boss 数量和时间线事件 ID。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：main: Node, spawner: Node。 直接调用时须 await 等待异步流程完成。
func _check_boss_event(main: Node, spawner: Node) -> void:
	var before_boss_count: int = _count_enemy_type("boss")
	spawner.set("_normal_phase_complete", true)
	spawner.call("_process_boss_event")
	await process_frame

	var after_boss_count: int = _count_enemy_type("boss")
	_expect(bool(spawner.get("_boss_active")), "boss encounter marks boss active")
	_expect(after_boss_count > before_boss_count, "boss encounter spawns boss")
	_expect(_timeline_events.has("boss:dungeon_heart"), "boss encounter emits timeline event")


## 作用：清零仆从冷却并推进 Boss 仆从生成，检查 boss_minion 来源实体数增加。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：spawner: Node。 直接调用时须 await 等待异步流程完成。
func _check_boss_minion_spawn(spawner: Node) -> void:
	var before_count: int = _count_enemy_type("boss_minion")
	spawner.set("_boss_minion_spawn_cooldown", 0.0)
	spawner.call("_process_boss_minion_spawn", 3.1)
	await process_frame
	var after_count: int = _count_enemy_type("boss_minion")
	_expect(after_count > before_count, "boss_event.minion_spawn spawns boss minions")


## 作用：按指定 ID 和分类构造禁用配置加载的敌人夹具，boss_minion 分别设置 normal 分类与来源标志。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：enemy_scene: PackedScene, enemy_id: StringName, enemy_type: String, position: Vector2。 返回 Node2D；具体值及空输入行为见作用说明。
func _make_enemy(enemy_scene: PackedScene, enemy_id: StringName, enemy_type: String, position: Vector2) -> Node2D:
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	enemy.set("enemy_id", enemy_id)
	enemy.set("load_config_from_data", false)
	enemy.set("_behavior", {"type": "chase_player"})
	enemy.set_meta("enemy_rank", "normal" if enemy_type == "boss_minion" else enemy_type)
	if enemy_type == "boss_minion":
		enemy.set_meta("spawn_source_type", "boss_minion")
	enemy.global_position = position
	return enemy


## 作用：按 enemy_rank 统计敌人类别，boss_minion 则使用 spawn_source_type 元数据计数。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：enemy_type: String。 返回 int；具体值及空输入行为见作用说明。
func _count_enemy_type(enemy_type: String) -> int:
	var count: int = 0
	for node: Node in get_nodes_in_group(&"enemy"):
		if enemy_type == "boss_minion":
			if String(node.get_meta("spawn_source_type", "")) == "boss_minion":
				count += 1
			continue
		if String(node.get_meta("enemy_rank", "normal")) == enemy_type:
			count += 1
	return count


## 作用：记录时间线信号 event_id，announcement 仅保留信号接口。
## 使用：由已连接的信号或采样 Callable 触发。 入参：event_id: String, _announcement: String。
func _on_timeline_event_started(event_id: String, _announcement: String) -> void:
	_timeline_events.append(event_id)


## 作用：检查 condition，成功打印 PASS，失败调用 _fail。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：condition: bool, message: String。
func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[EnemyTimelineSystemCheck] PASS %s" % message)
	else:
		_fail(message)


## 作用：设置失败状态并输出对应错误信息。
## 使用：由本脚本检查流程调用，使用已装配的场景夹具。 入参：message: String。
func _fail(message: String) -> void:
	_failed = true
	push_error("[EnemyTimelineSystemCheck] FAIL %s" % message)
