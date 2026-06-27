extends SceneTree


class SmokeEnemy:
	extends Node2D

	var damage_packets: Array = []

	func _init() -> void:
		add_to_group(&"enemies")

	func take_damage(packet: Variant, _damage_type: Variant = &"") -> void:
		damage_packets.append(packet)


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var vortex_scene: PackedScene = load("res://scenes/scorching_vortex_area.tscn") as PackedScene
	_expect(vortex_scene != null, "loads ScorchingVortexArea scene")
	if vortex_scene == null:
		quit(1)
		return

	var vortex: Node2D = vortex_scene.instantiate() as Node2D
	vortex.global_position = Vector2.ZERO
	root.add_child(vortex)

	var hit_enemy: SmokeEnemy = SmokeEnemy.new()
	hit_enemy.global_position = Vector2(16.0, 0.0)
	root.add_child(hit_enemy)

	var dense_a: SmokeEnemy = SmokeEnemy.new()
	dense_a.global_position = Vector2(220.0, 0.0)
	root.add_child(dense_a)
	var dense_b: SmokeEnemy = SmokeEnemy.new()
	dense_b.global_position = Vector2(245.0, 12.0)
	root.add_child(dense_b)
	var dense_c: SmokeEnemy = SmokeEnemy.new()
	dense_c.global_position = Vector2(230.0, -18.0)
	root.add_child(dense_c)

	vortex.call("setup", {
		"damage": 7,
		"radius": 64.0,
		"duration": 4.0,
		"tick_interval": 0.5,
		"target_group": &"enemies",
		"move_direction": Vector2.RIGHT,
		"move_speed": 160.0,
		"hit_stop_duration": 0.35,
		"density_seek_radius": 320.0,
		"density_cluster_radius": 96.0
	})
	await physics_frame
	_expect(hit_enemy.damage_packets.size() > 0, "vortex applies an immediate tick at the spawn point", hit_enemy.damage_packets.size())

	var position_after_setup: Vector2 = vortex.global_position
	vortex.call("_physics_process", 0.1)
	_expect(vortex.global_position.distance_to(position_after_setup) <= 0.01, "vortex stays briefly after hitting an enemy", {"before": position_after_setup, "after": vortex.global_position})

	vortex.call("_physics_process", 0.4)
	var move_direction: Vector2 = vortex.get("move_direction")
	_expect(move_direction.dot(Vector2.RIGHT) > 0.85, "vortex redirects toward the densest nearby enemy cluster", move_direction)

	vortex.queue_free()
	await process_frame

	var swept_vortex: Node2D = vortex_scene.instantiate() as Node2D
	swept_vortex.global_position = Vector2.ZERO
	root.add_child(swept_vortex)
	var swept_enemy: SmokeEnemy = SmokeEnemy.new()
	swept_enemy.global_position = Vector2(75.0, 0.0)
	root.add_child(swept_enemy)
	swept_vortex.call("setup", {
		"damage": 7,
		"radius": 24.0,
		"duration": 1.0,
		"tick_interval": 0.5,
		"target_group": &"enemies",
		"move_direction": Vector2.RIGHT,
		"move_speed": 240.0,
		"hit_stop_duration": 0.0,
		"density_seek_radius": 64.0,
		"density_cluster_radius": 32.0
	})
	await physics_frame
	swept_enemy.damage_packets.clear()
	swept_vortex.call("_physics_process", 0.5)
	_expect(swept_enemy.damage_packets.size() > 0, "vortex damages enemies swept through between normal ticks", swept_enemy.damage_packets.size())
	swept_vortex.queue_free()
	swept_enemy.queue_free()
	await process_frame
	if not _failed:
		print("[verify_scorching_vortex_area_behavior] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_scorching_vortex_area_behavior] FAIL %s actual=%s" % [label, str(actual)])
