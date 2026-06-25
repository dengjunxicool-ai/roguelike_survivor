extends SceneTree


const SummonDefinitionScript: Script = preload("res://scripts/summons/summon_definition.gd")
const SummonManagerScript: Script = preload("res://scripts/summons/summon_manager.gd")


class SmokePlayer:
	extends Node2D

	var attack_power: float = 20.0
	var range: float = 540.0


class SmokeEnemy:
	extends Node2D

	var damage_packets: Array = []
	var statuses: Array[Dictionary] = []
	var dead: bool = false

	func _init() -> void:
		add_to_group(&"enemies")

	func take_damage(packet: Variant, _damage_type: Variant = &"") -> void:
		damage_packets.append(packet)

	func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
		statuses.append({"status": StringName(String(status_id)), "params": params.duplicate(true)})
		return true

	func is_dead() -> bool:
		return dead


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player: SmokePlayer = SmokePlayer.new()
	player.name = "SmokePlayer"
	root.add_child(player)

	var manager: Node = SummonManagerScript.new()
	manager.name = "SummonManager"
	player.add_child(manager)

	var definition: RefCounted = SummonDefinitionScript.from_dictionary({
		"id": "test_sprite",
		"max_count": 2,
		"duration": 5.0,
		"movement": {
			"move_speed": 240.0,
			"follow_distance": 80.0,
			"min_distance": 40.0,
			"leash_distance": 360.0,
			"teleport_distance": 720.0,
			"separation_radius": 32.0
		},
		"targeting": {
			"detect_range": 300.0,
			"retarget_interval": 0.25,
			"target_priority": "nearest_to_summon"
		},
		"attack": {
			"attack_type": "melee",
			"attack_range": 48.0,
			"attack_cooldown": 0.2,
			"damage_type": "fire",
			"damage_scale": 0.5,
			"on_hit_effects": [
				{"type": "apply_status", "status": "burning", "stacks": 1, "duration": 4.0}
			]
		}
	})

	var summon_a: Node2D = manager.call("spawn_summon", definition, {
		"owner": player,
		"player_power": player.attack_power,
		"parent": root,
		"target_group": &"enemies"
	}) as Node2D
	var summon_b: Node2D = manager.call("spawn_summon", definition, {
		"owner": player,
		"player_power": player.attack_power,
		"parent": root,
		"target_group": &"enemies"
	}) as Node2D
	var summon_c: Node2D = manager.call("spawn_summon", definition, {
		"owner": player,
		"player_power": player.attack_power,
		"parent": root,
		"target_group": &"enemies"
	}) as Node2D

	_expect(summon_a != null, "first summon spawns")
	_expect(summon_b != null, "second summon spawns")
	_expect(summon_c == null, "third summon is capped by max_count")
	_expect(summon_a.global_position.distance_to(summon_b.global_position) > 1.0, "multiple summons receive separated formation positions", {"a": summon_a.global_position, "b": summon_b.global_position})

	await physics_frame
	summon_a.call("_physics_process", 0.1)
	_expect(summon_a.global_position.distance_to(player.global_position) >= 35.0, "summon follows near owner without overlapping", summon_a.global_position)

	var enemy: SmokeEnemy = SmokeEnemy.new()
	enemy.global_position = summon_a.global_position + Vector2(180.0, 0.0)
	root.add_child(enemy)
	summon_a.call("_physics_process", 0.3)
	_expect(String(summon_a.get("state")) == "CHASE", "summon chases detected enemies outside attack range", summon_a.get("state"))

	enemy.global_position = summon_a.global_position + Vector2(24.0, 0.0)
	summon_a.call("_physics_process", 0.25)
	_expect(String(summon_a.get("state")) == "ATTACK", "summon attacks enemies inside attack range", summon_a.get("state"))
	_expect(enemy.damage_packets.size() > 0, "summon melee attack deals damage", enemy.damage_packets.size())
	_expect(enemy.statuses.size() > 0 and enemy.statuses[0].status == &"burning", "summon attack applies configured status", enemy.statuses)

	enemy.dead = true
	var replacement: SmokeEnemy = SmokeEnemy.new()
	replacement.global_position = summon_a.global_position + Vector2(120.0, 0.0)
	root.add_child(replacement)
	summon_a.call("_physics_process", 0.3)
	_expect(summon_a.get("target") == replacement, "summon retargets when current target dies", summon_a.get("target"))

	summon_a.global_position = player.global_position + Vector2(390.0, 0.0)
	summon_a.call("_physics_process", 0.05)
	_expect(String(summon_a.get("state")) == "RETURN", "summon returns when beyond leash distance", summon_a.get("state"))
	_expect(summon_a.get("target") == null, "summon clears target while returning")

	summon_a.global_position = player.global_position + Vector2(760.0, 0.0)
	summon_a.call("_physics_process", 0.05)
	_expect(summon_a.global_position.distance_to(player.global_position) < 140.0, "summon teleports back when beyond teleport distance", summon_a.global_position)

	var short_definition: RefCounted = SummonDefinitionScript.from_dictionary({
		"id": "short_lived_summon",
		"max_count": 1,
		"duration": 0.25,
		"movement": {"follow_distance": 80.0},
		"targeting": {"detect_range": 1.0},
		"attack": {"attack_range": 1.0, "damage_scale": 0.0}
	})
	var short_summon: Node2D = manager.call("spawn_summon", short_definition, {
		"owner": player,
		"player_power": player.attack_power,
		"parent": root,
		"target_group": &"enemies"
	}) as Node2D
	await create_timer(0.35).timeout
	_expect(not is_instance_valid(short_summon) or short_summon.is_queued_for_deletion(), "summon expires after configured duration")

	if not _failed:
		print("[verify_summon_system_behavior] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_summon_system_behavior] FAIL %s actual=%s" % [label, str(actual)])
