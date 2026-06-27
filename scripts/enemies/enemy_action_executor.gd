extends RefCounted
class_name EnemyActionExecutor


const EnemySpawnRequestScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_request.gd")
const EnemySpawnServiceScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
const EnemyDamagePacketBuilderScript: Script = preload("res://scripts/enemies/combat/enemy_damage_packet_builder.gd")

var _owner: Node2D
var _spawn_service: RefCounted = EnemySpawnServiceScript.new()


func setup(owner: Node2D) -> void:
	_owner = owner
	_sync_spawn_service()


func explode(behavior: Dictionary) -> bool:
	if _owner == null:
		return false

	var explosion_damage: int = int(behavior.get("explosion_damage", _get_int("contact_damage")))
	var explosion_radius: float = float(behavior.get("explosion_radius", 76.0))
	spawn_damage_area(0, 0.12, 0.1, explosion_radius, Color(1.0, 0.35, 0.08, 0.45))
	damage_targets_in_radius(explosion_damage, explosion_radius)
	return true


func apply_death_effect(death_effect: Dictionary) -> void:
	match String(death_effect.get("type", "")):
		"poison_pool":
			spawn_damage_area(
				int(death_effect.get("damage", 4)),
				float(death_effect.get("duration", 3.0)),
				float(death_effect.get("tick_interval", 0.5)),
				float(death_effect.get("area_radius", 52.0)),
				Color(0.35, 0.95, 0.2, 0.32)
			)
		"spawn_enemies":
			spawn_death_enemies(
				StringName(String(death_effect.get("enemy_id", "small_slime"))),
				int(death_effect.get("count", 1))
			)


func spawn_enemy_projectile(
	direction: Vector2,
	projectile_damage: int,
	projectile_speed: float,
	projectile_pierce: int = 0,
	projectile_radius: float = 8.0,
	behavior: Dictionary = {}
) -> void:
	if _owner == null or _owner.get("enemy_projectile_scene") == null or _owner.get_parent() == null:
		return

	var projectile_scene: PackedScene = _owner.get("enemy_projectile_scene") as PackedScene
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	var normalized_direction: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_owner.get_parent().add_child(projectile)
	projectile.add_to_group(&"enemy_projectiles")
	projectile.add_to_group(&"enemy_projectile")
	projectile.global_position = _owner.global_position + normalized_direction * float(behavior.get("projectile_spawn_offset", 20.0))
	if projectile.has_method("setup"):
		projectile.call(&"setup", {
			"direction": normalized_direction,
			"damage": projectile_damage,
			"speed": projectile_speed,
			"target_group": _owner.get("target_group"),
			"pierce": projectile_pierce,
			"radius": projectile_radius,
			"lifetime": float(behavior.get("projectile_lifetime", 3.0)),
			"source_id": _get_damage_source_id(),
			"damage_packet": EnemyDamagePacketBuilderScript.build(_owner, projectile_damage, "projectile", &"enemy_projectile", behavior),
			"visual_color": behavior.get("projectile_color", [1.0, 0.9, 0.08, 1.0]),
			"visual": _get_dictionary(behavior.get("projectile_visual", {}))
		})


func spawn_damage_area(
	area_damage: int,
	area_duration: float,
	area_tick_interval: float,
	area_radius: float,
	visual_color: Color
) -> void:
	if _owner != null:
		spawn_damage_area_at(_owner.global_position, area_damage, area_duration, area_tick_interval, area_radius, visual_color)


func spawn_damage_area_at(
	area_position: Vector2,
	area_damage: int,
	area_duration: float,
	area_tick_interval: float,
	area_radius: float,
	visual_color: Color
) -> void:
	if _owner == null or _owner.get("damage_area_scene") == null or _owner.get_parent() == null:
		return

	var damage_area_scene: PackedScene = _owner.get("damage_area_scene") as PackedScene
	var damage_area: Node2D = damage_area_scene.instantiate() as Node2D
	if damage_area == null:
		return

	_owner.get_parent().add_child(damage_area)
	damage_area.global_position = area_position
	if damage_area.has_method("setup"):
		damage_area.call(&"setup", {
			"damage": area_damage,
			"duration": area_duration,
			"tick_interval": area_tick_interval,
			"target_group": _owner.get("target_group"),
			"area_radius": area_radius,
			"visual_color": visual_color,
			"source_id": StringName(_get_damage_source_id()),
			"source_type": &"area",
			"damage_packet": _build_enemy_damage_packet(area_damage, "area", "enemy_area")
		})


func damage_targets_in_radius(area_damage: int, area_radius: float) -> void:
	if _owner == null or area_damage <= 0:
		return

	var radius_squared: float = area_radius * area_radius
	for target_node: Node in _owner.get_tree().get_nodes_in_group(_owner.get("target_group")):
		var target_body: Node2D = target_node as Node2D
		if target_body == null:
			continue
		if _owner.global_position.distance_squared_to(target_body.global_position) > radius_squared:
			continue
		if target_body.has_method("take_damage"):
			target_body.call(&"take_damage", EnemyDamagePacketBuilderScript.build(_owner, area_damage, "area", &"enemy_area", {
				"target": target_body,
				"damage_origin": "field",
				"damage_type": "area_direct",
				"element": "physical"
			}))


func spawn_death_enemies(spawn_enemy_id: StringName, count: int) -> void:
	if _owner != null:
		spawn_enemies_around(spawn_enemy_id, count, _owner.global_position, 28.0)


func spawn_enemies_around(spawn_enemy_id: StringName, count: int, center: Vector2, radius: float = 48.0) -> void:
	if _owner == null or spawn_enemy_id == &"" or count <= 0 or _owner.get_parent() == null:
		return

	_sync_spawn_service()
	for spawn_index in range(count):
		var position: Vector2 = center + Vector2.RIGHT.rotated(TAU * float(spawn_index) / float(count)) * radius
		var request: Dictionary = EnemySpawnRequestScript.summon(spawn_enemy_id, position, {
			"hp": float(_owner.get("health_multiplier")),
			"damage": float(_owner.get("damage_multiplier")),
			"move_speed": float(_owner.get("move_speed_multiplier")) if _owner.get("move_speed_multiplier") != null else 1.0,
			"exp": 0.25
		}, String(_owner.get("enemy_id")))
		request["parent"] = _owner.get_parent()
		_spawn_service.call("spawn", request)


func spawn_corrupted_cores(count: int, hp: int) -> bool:
	if _owner == null or count <= 0 or _owner.get_parent() == null:
		return false
	_sync_spawn_service()
	for spawn_index in range(count):
		var owner_resistances: Variant = _owner.get("resistances")
		var resistances: Dictionary = (owner_resistances as Dictionary).duplicate(true) if owner_resistances is Dictionary else {}
		var position: Vector2 = _owner.global_position + Vector2.RIGHT.rotated(TAU * float(spawn_index) / float(count)) * 150.0
		var request: Dictionary = EnemySpawnRequestScript.boss_core(&"skeleton", position, hp, int(_owner.get("armor")), resistances)
		request["parent"] = _owner.get_parent()
		var core: Node2D = _spawn_service.call("spawn", request) as Node2D
		if core == null:
			continue
		var tracker: Node = RunStatsTracker.get_active(_owner.get_tree()) if _owner.get_tree() != null else null
		if tracker != null and tracker.has_method("record_boss_core_spawned"):
			tracker.call("record_boss_core_spawned", core)
	return true


func _get_int(property: StringName) -> int:
	if _owner == null:
		return 0
	return int(_owner.get(property))


func _get_damage_source_id() -> String:
	if _owner == null:
		return "enemy"
	var rank: String = String(_owner.get_meta("enemy_rank", _owner.get_meta("enemy_type", "normal")))
	return "boss" if rank == "boss" else "enemy"


func _sync_spawn_service() -> void:
	if _spawn_service == null:
		_spawn_service = EnemySpawnServiceScript.new()
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	_spawn_service.call("setup", _owner, enemy_scene, null, StringName(String(_owner.get("target_group"))) if _owner != null else &"player")


func _build_enemy_damage_packet(amount: int, source_type: String, source_skill_id: String) -> Dictionary:
	return EnemyDamagePacketBuilderScript.build(_owner, amount, source_type, StringName(source_skill_id), {
		"damage_origin": "field" if source_type == "area" else "primary_attack",
		"damage_type": "area_direct" if source_type == "area" else "direct_physical",
		"element": "physical"
	})


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
