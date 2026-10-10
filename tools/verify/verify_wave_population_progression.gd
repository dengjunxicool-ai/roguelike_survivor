extends SceneTree

const SpawnerScript: Script = preload("res://scripts/enemies/enemy_spawner.gd")
const DirectorScript: Script = preload("res://scripts/enemies/timeline/wave_director.gd")
const BossControllerScript: Script = preload("res://scripts/enemies/timeline/boss_encounter_controller.gd")
var _failed: bool = false

class BatchOwner:
	extends Node
	var _wave_spawned_count: int = 0
	var _wave_total_count: int = 140
	var _normal_spawn_cooldown: float = 2.0
	var _boss_minion_spawn_cooldown: float = 0.0
	var _max_normal_enemies_alive: int = 40
	var _spawn_batch_interval: float = 3.0
	var _spawn_warning_duration: float = 1.5
	var _max_spawn_batch_size: int = 15
	var alive: int = 0
	var spawn_calls: int = 0
	var last_limit: int = 0
	func _get_alive_enemy_count() -> int:
		return alive
	func _get_alive_normal_enemy_count() -> int:
		return alive
	func _get_alive_boss_minion_count() -> int:
		return alive
	func _get_wave_enemy_multipliers(_wave: Dictionary) -> Dictionary:
		return {}
	func _get_config_dictionary(_key: String) -> Dictionary:
		return {"minion_spawn": {"enabled": true, "spawn_interval": 3.0, "max_alive": 35}}
	func _spawn_batch_from_source(_source: Dictionary, _multipliers: Dictionary, _kind: StringName, limit: int) -> int:
		spawn_calls += 1
		last_limit = limit
		return limit

class DeadEnemy:
	extends Node2D
	func is_dead() -> bool:
		return true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_empty_field_and_unlimited_population()
	await _test_real_growth_and_pending_reveal()
	print("[verify_wave_population_progression] %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _test_empty_field_and_unlimited_population() -> void:
	var owner := BatchOwner.new()
	root.add_child(owner)
	var director: RefCounted = DirectorScript.new()
	director.call("setup", owner)
	var wave: Dictionary = {"max_alive": 35, "spawn_batch_interval_seconds": 3.0}
	director.call("process_wave_spawn", 0.0, wave)
	_expect(owner.spawn_calls == 1, "empty battlefield bypasses the remaining cooldown")
	owner.alive = 100
	owner._normal_spawn_cooldown = 0.0
	director.call("process_wave_spawn", 0.0, wave)
	_expect(owner.spawn_calls == 2 and owner.last_limit == 15, "100 living enemies do not suppress or truncate the next batch")
	owner._normal_spawn_cooldown = 2.0
	director.call("process_wave_spawn", 0.0, wave)
	_expect(owner.spawn_calls == 2, "occupied or warning-pending field still respects batch pacing")
	var controller: RefCounted = BossControllerScript.new()
	controller.call("setup", owner)
	controller.call("process_boss_minion_spawn", 0.0)
	_expect(owner.spawn_calls == 3 and owner.last_limit == 15, "Boss minions have no alive population cap")
	owner._wave_total_count = 210
	owner._wave_spawned_count = 0
	owner._normal_spawn_cooldown = 0.0
	var elapsed: float = 0.0
	wave = {"duration_seconds": 20.0, "spawn_batch_interval_seconds": 2.0}
	director.call("process_wave_spawn", 0.0, wave)
	while elapsed < 18.5 and owner._wave_spawned_count < owner._wave_total_count:
		elapsed += 1.0 / 60.0
		director.call("process_wave_spawn", 1.0 / 60.0, wave)
	_expect(owner._wave_spawned_count == 210 and elapsed < 18.5, "density-modified budget is delivered fully with time left for all warnings")
	director.call("process_wave_spawn", 10.0, wave)
	_expect(owner._wave_spawned_count == 210, "delivery never exceeds the finite wave budget")
	owner.queue_free()
	await process_frame

func _test_real_growth_and_pending_reveal() -> void:
	root.size=Vector2i(1920,1080)
	root.set_meta("debug_manual_spawn_only", true)
	var player := Node2D.new()
	player.position = Vector2(1000, 1000)
	player.add_to_group(&"player")
	root.add_child(player)
	var camera := Camera2D.new()
	player.add_child(camera)
	var spawner: Node = SpawnerScript.new()
	root.add_child(spawner)
	await process_frame
	var previous_total: int = 0
	var previous_health: int = 0
	var previous_damage: int = 0
	for index: int in range(8):
		var wave: Dictionary = spawner.call("_get_wave_at_index", index)
		spawner.set("_normal_spawn_cooldown", 15.0)
		spawner.call("_start_wave", index)
		var total: int = int(spawner.get("_wave_total_count"))
		_expect(total == int(wave.get("total_count", -1)) and total > previous_total, "wave %d keeps its authored increasing population" % (index + 1))
		_expect(is_zero_approx(float(spawner.get("_normal_spawn_cooldown"))), "new wave does not inherit the previous cooldown")
		var enemy: Node2D = spawner.call("spawn_enemy", EnemySpawnRequest.create(&"small_slime", {"source_type": "map_event", "multipliers": wave.enemy_multipliers}))
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		var health: int = int(enemy.get("max_health"))
		var damage: int = int(enemy.get("contact_damage"))
		_expect(health > previous_health and damage >= previous_damage, "wave %d applies growing real health and damage" % (index + 1))
		previous_total = total
		previous_health = health
		previous_damage = damage
		enemy.queue_free()
	await process_frame
	spawner.call("_start_wave", 7)
	var source: Dictionary = {"groups": [{"enemy_ids": ["small_slime"], "weight": 100}]}
	var spawned: int = int(spawner.call("_spawn_batch_from_source", source, {}, &"wave", 100))
	_expect(spawned == 100, "all 100 warning requests create their enemies")
	var pending: Array[Node] = get_nodes_in_group(&"enemy")
	spawner.set("_normal_spawn_cooldown", 2.0)
	spawner.call("_process_wave_spawn", 0.0, spawner.call("_get_current_wave"))
	_expect(get_nodes_in_group(&"enemy").size() == 100, "pending real warnings prevent repeated empty-field batches")
	var dead := DeadEnemy.new()
	root.add_child(dead)
	dead.add_to_group(&"enemy")
	var queued := Node2D.new()
	root.add_child(queued)
	queued.add_to_group(&"enemy")
	queued.queue_free()
	_expect(int(spawner.call("_get_alive_enemy_count")) == 100, "dead and queued enemies are excluded from field occupancy")
	dead.queue_free()
	player.position += Vector2(5000, 5000)
	spawner.call("_despawn_far_enemies")
	var deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		var remaining: int = 0
		for enemy: Node in pending:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				if bool(enemy.get_meta("spawn_reveal_pending", false)):
					remaining += 1
				else:
					enemy.process_mode = Node.PROCESS_MODE_DISABLED
		if remaining == 0:
			break
		await process_frame
	var revealed: int = 0
	for enemy: Node in pending:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not bool(enemy.get_meta("spawn_reveal_pending", false)):
			revealed += 1
	_expect(revealed == 100, "moving away during warning does not cull promised spawns (%d/100)" % revealed)
	spawner.call("_despawn_far_enemies")
	await process_frame
	_expect(get_nodes_in_group(&"enemy").is_empty(), "active distant enemies can still be cleaned up")
	spawner.queue_free()
	player.queue_free()
	root.remove_meta("debug_manual_spawn_only")
	await process_frame

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[verify_wave_population_progression] PASS " + label)
	else:
		_failed = true
		push_error("[verify_wave_population_progression] FAIL " + label)
