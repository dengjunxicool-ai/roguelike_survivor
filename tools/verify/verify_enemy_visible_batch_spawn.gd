extends SceneTree


const WaveDirectorScript: Script = preload("res://scripts/enemies/timeline/wave_director.gd")
const BossEncounterControllerScript: Script = preload("res://scripts/enemies/timeline/boss_encounter_controller.gd")
const EnemySpawnServiceScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
const TargetingServiceScript: Script = preload("res://scripts/skills/targeting_service.gd")

var _failed: bool = false


class BatchOwner:
	extends Node

	var _wave_spawned_count: int = 0
	var _wave_total_count: int = 100
	var _normal_spawn_cooldown: float = 0.0
	var _boss_minion_spawn_cooldown: float = 0.0
	var _max_normal_enemies_alive: int = 100
	var _spawn_batch_interval: float = 15.0
	var _max_spawn_batch_size: int = 15
	var spawn_interval: float = 0.5
	var alive_normal: int = 0
	var alive_boss_minions: int = 0
	var spawn_calls: int = 0
	var last_limit: int = -1
	var boss_event: Dictionary = {
		"minion_spawn": {
			"enabled": true,
			"max_alive": 40,
			"spawn_interval": 3.0,
			"groups": [{"enemy_ids": ["small_slime"], "weight": 100}]
		}
	}

	func _get_alive_normal_enemy_count() -> int:
		return alive_normal

	func _get_alive_boss_minion_count() -> int:
		return alive_boss_minions

	func _pick_enemy_group(_source: Dictionary) -> Dictionary:
		return {"enemy_ids": ["small_slime"], "weight": 100}

	func _get_wave_enemy_multipliers(_wave: Dictionary) -> Dictionary:
		return {}

	func _get_config_dictionary(key: String) -> Dictionary:
		return boss_event if key == "boss_event" else {}

	func _spawn_from_group_config(_group: Dictionary, _multipliers: Dictionary = {}, _override: StringName = &"", limit: int = -1) -> int:
		spawn_calls += 1
		last_limit = limit
		return maxi(limit, 1)

	func _spawn_batch_from_source(_source: Dictionary, _multipliers: Dictionary = {}, _override: StringName = &"", limit: int = -1) -> int:
		spawn_calls += 1
		last_limit = limit
		return maxi(limit, 1)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_wave_batch_limit_and_interval()
	_test_boss_minion_batch_limit_and_interval()
	await _test_visible_spawn_and_reveal()
	if not _failed:
		print("[verify_enemy_visible_batch_spawn] PASS")
	quit(1 if _failed else 0)


func _test_wave_batch_limit_and_interval() -> void:
	var owner := BatchOwner.new()
	root.add_child(owner)
	var director: RefCounted = WaveDirectorScript.new()
	director.call("setup", owner)
	var wave: Dictionary = {
		"max_alive": 100,
		"spawn_interval": 0.5,
		"groups": [{"enemy_ids": ["small_slime"], "weight": 100}]
	}
	director.call("process_wave_spawn", 0.0, wave)
	_expect(owner.last_limit == 15, "normal wave batch is capped at 15", owner.last_limit)
	_expect(is_equal_approx(owner._normal_spawn_cooldown, 15.0), "normal wave batch starts a 15 second cooldown", owner._normal_spawn_cooldown)
	var calls_after_first_batch: int = owner.spawn_calls
	director.call("process_wave_spawn", 14.99, wave)
	_expect(owner.spawn_calls == calls_after_first_batch, "normal wave cannot start another batch before 15 seconds", owner.spawn_calls)
	director.call("process_wave_spawn", 0.01, wave)
	_expect(owner.spawn_calls == calls_after_first_batch + 1, "normal wave can start the next batch after 15 seconds", owner.spawn_calls)
	owner.queue_free()


func _test_boss_minion_batch_limit_and_interval() -> void:
	var owner := BatchOwner.new()
	root.add_child(owner)
	var controller: RefCounted = BossEncounterControllerScript.new()
	controller.call("setup", owner)
	controller.call("process_boss_minion_spawn", 0.0)
	_expect(owner.last_limit == 15, "Boss minion batch is capped at 15", owner.last_limit)
	_expect(is_equal_approx(owner._boss_minion_spawn_cooldown, 15.0), "Boss minion batch starts a 15 second cooldown", owner._boss_minion_spawn_cooldown)
	var calls_after_first_batch: int = owner.spawn_calls
	controller.call("process_boss_minion_spawn", 14.99)
	_expect(owner.spawn_calls == calls_after_first_batch, "Boss minions cannot start another batch before 15 seconds", owner.spawn_calls)
	controller.call("process_boss_minion_spawn", 0.01)
	_expect(owner.spawn_calls == calls_after_first_batch + 1, "Boss minions can start the next batch after 15 seconds", owner.spawn_calls)
	owner.queue_free()


func _test_visible_spawn_and_reveal() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var player := Node2D.new()
	player.global_position = Vector2(1000.0, 1000.0)
	player.add_to_group(&"player")
	root.add_child(player)
	var camera := Camera2D.new()
	camera.zoom = Vector2(4.0, 4.0)
	camera.enabled = true
	player.add_child(camera)
	await process_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var service: RefCounted = EnemySpawnServiceScript.new()
	service.call("setup", owner, load("res://scenes/enemies/enemy.tscn"), null, &"player", rng)
	_expect(service.has_method("set_visible_spawn_rules"), "spawn service exposes visible-area spawn rules")
	if service.has_method("set_visible_spawn_rules"):
		service.call("set_visible_spawn_rules", true, 24.0, 80.0, 0.05)
	var enemy: Node2D = service.call("spawn", {
		"enemy_id": &"small_slime",
		"source_type": "wave",
		"visible_spawn_warning": true
	}) as Node2D
	_expect(enemy != null, "visible warning request creates an enemy")
	if enemy != null:
		var screen_position: Vector2 = enemy.get_viewport().get_canvas_transform() * enemy.global_position
		var safe_screen_rect: Rect2 = enemy.get_viewport().get_visible_rect().grow(-24.0)
		_expect(safe_screen_rect.has_point(screen_position), "warning spawn position stays inside the visible area", screen_position)
		_expect(bool(enemy.get_meta("spawn_reveal_pending", false)), "enemy remains pending during the warning reveal")
		_expect(enemy.process_mode == Node.PROCESS_MODE_DISABLED, "pending enemy behavior is disabled", enemy.process_mode)
		_expect(enemy.collision_layer == 0 and enemy.collision_mask == 0, "pending enemy collision is disabled", [enemy.collision_layer, enemy.collision_mask])
		_expect(not TargetingServiceScript.is_valid_target(enemy), "pending enemy cannot be selected as a combat target")
		await create_timer(0.2).timeout
		_expect(not bool(enemy.get_meta("spawn_reveal_pending", false)), "enemy activates after the reveal")
		_expect(enemy.process_mode != Node.PROCESS_MODE_DISABLED, "enemy behavior resumes after the reveal", enemy.process_mode)
		_expect(enemy.collision_layer != 0, "enemy collision returns after the reveal", enemy.collision_layer)
		_expect(TargetingServiceScript.is_valid_target(enemy), "activated enemy becomes a valid combat target")
		enemy.queue_free()
	player.queue_free()
	owner.queue_free()


func _expect(condition: bool, label: String, actual: Variant = null) -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_enemy_visible_batch_spawn] FAIL %s actual=%s" % [label, str(actual)])
