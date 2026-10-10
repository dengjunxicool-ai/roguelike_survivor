extends SceneTree

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player := Node2D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	player.position = Vector2(500, 0)
	var boss: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate()
	boss.set("enemy_id", &"dungeon_heart")
	world.add_child(boss)
	boss.set("target", player)
	boss.call("_process_boss_phase_skills")
	boss.set("current_health", 1000)
	boss.call("_process_boss_phase_skills")
	await process_frame
	_expect(_areas(world).size() == 1, "phase transition retains shared red-circle cooldown and cast spacing")
	var scheduler: RefCounted = boss.get("_boss_mechanic_scheduler")
	_expect(scheduler != null, "Boss owns a persistent mechanic scheduler")
	if scheduler != null:
		boss.call("_update_boss_skill_cooldowns", 0.4)
		boss.call("_process_boss_phase_skills")
		_expect(scheduler.get("_tokens").size() == 2, "warning mechanics occupy two phase-three slots")
		boss.call("_update_boss_skill_cooldowns", 10.0)
		boss.call("_process_boss_phase_skills")
		await process_frame
		_expect(scheduler.get("_tokens").size() == 2 and _areas(world).size() == 1, "cap and area-denial limit persist across frames")
		scheduler.call("reset")
		_expect(scheduler.get("_tokens").is_empty(), "reset releases every owned mechanic")
		boss.set("damage_area_scene", null)
		boss.set("enemy_projectile_scene", null)
		boss.set("_boss_skill_cooldowns", {})
		boss.set("_behavior", {"phases": [{"hp_percent_min": 0.0, "hp_percent_max": 1.1, "skills": [{"skill_id": "red_circle", "type": "delayed_area_blast", "cooldown": 5.0}]}]})
		boss.call("_process_boss_phase_skills")
		_expect(boss.get("_boss_skill_cooldowns").is_empty() and scheduler.get("_tokens").is_empty(), "failed creation leaves no cooldown or token")
		var area: Node = load("res://scenes/combat/damage_area.tscn").instantiate()
		world.add_child(area)
		area.call("setup", {"use_enemy_lifecycle": true, "warning_time": 1.0})
		var token: int = scheduler.call("try_reserve", &"test", &"area_denial", 1)
		scheduler.call("attach", token, area)
		scheduler.call("commit", token)
		var old_generation: int = area.get("spawn_generation")
		area.call("prepare_for_pool_despawn")
		scheduler.call("tick", 0.4)
		area.call("prepare_for_pool_spawn", {"use_enemy_lifecycle": true, "warning_time": 1.0})
		var next: int = scheduler.call("try_reserve", &"next", &"area_denial", 1)
		scheduler.call("attach", next, area)
		scheduler.call("commit", next)
		area.emit_signal("enemy_attack_finished", old_generation)
		_expect(scheduler.get("_tokens").size() == 1, "stale pooled generation cannot release current token")
		boss.call("_finish_death", "test")
		_expect(scheduler.get("_tokens").is_empty(), "Boss death releases mechanics")
	world.queue_free()
	await process_frame
	print("[BossMechanicConcurrency] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _areas(world: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in world.get_children():
		if child is DamageArea and not child.is_queued_for_deletion() and child.get("_attack_finished") == false:
			found.append(child)
		found.append_array(_areas(child))
	return found

func _expect(ok: bool, message: String) -> void:
	if ok:
		print("[BossMechanicConcurrency] PASS " + message)
	else:
		_failed = true
		push_error("[BossMechanicConcurrency] FAIL " + message)
