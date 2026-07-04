extends RefCounted
class_name TargetingService


const ENEMY_GROUP: StringName = &"enemies"
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")


static func find_target(caster: Node, mode: String, params: Dictionary = {}) -> Node2D:
	var targets: Array = find_targets(caster, mode, params)
	if targets.is_empty():
		return null

	return targets[0] as Node2D


static func find_targets(caster: Node, mode: String, params: Dictionary = {}) -> Array:
	var caster_node: Node2D = caster as Node2D
	match mode:
		"self":
			return [caster_node] if caster_node != null else []
		"nearest_enemy":
			var nearest_enemy: Node2D = _find_nearest_enemy(caster_node, params)
			return [nearest_enemy] if nearest_enemy != null else []
		"highest_hp_enemy":
			var highest_hp_enemy: Node2D = _find_highest_hp_enemy(params)
			return [highest_hp_enemy] if highest_hp_enemy != null else []
		"highest_health_or_nearest_elite":
			var elite_or_highest_health: Node2D = _find_nearest_elite_or_highest_hp(caster_node, params)
			return [elite_or_highest_health] if elite_or_highest_health != null else []
		"densest_enemy_cluster":
			var densest_cluster_enemy: Node2D = _find_densest_enemy_cluster_center(caster_node, params)
			return [densest_cluster_enemy] if densest_cluster_enemy != null else []
		"densest_conductive_or_enemy_cluster":
			var densest_conductive_cluster_enemy: Node2D = _find_densest_enemy_cluster_center(caster_node, _with_status_priority(params, &"conductive"))
			return [densest_conductive_cluster_enemy] if densest_conductive_cluster_enemy != null else []
		"conductive_first_nearest":
			var conductive_first_enemy: Node2D = _find_status_first_nearest(caster_node, params, &"conductive")
			return [conductive_first_enemy] if conductive_first_enemy != null else []
		"judgment_first_nearest":
			var judgment_first_enemy: Node2D = _find_status_first_nearest(caster_node, params, &"judgment")
			return [judgment_first_enemy] if judgment_first_enemy != null else []
		"judgment_stack_highest":
			return _find_status_stack_highest(caster_node, params, &"judgment")
		"instability_first_nearest":
			var instability_first_enemy: Node2D = _find_status_first_nearest(caster_node, params, &"instability")
			return [instability_first_enemy] if instability_first_enemy != null else []
		"instability_stack_highest":
			return _find_status_stack_highest(caster_node, params, &"instability")
		"cursed_first_nearest":
			var cursed_first_enemy: Node2D = _find_status_first_nearest(caster_node, params, &"cursed")
			return [cursed_first_enemy] if cursed_first_enemy != null else []
		"uncursed_first_nearest":
			var uncursed_first_enemy: Node2D = _find_missing_status_first_nearest(caster_node, params, &"cursed")
			return [uncursed_first_enemy] if uncursed_first_enemy != null else []
		"random_enemy":
			var random_enemy: Node2D = _find_random_enemy(params)
			return [random_enemy] if random_enemy != null else []
		"random_enemies_around_player":
			return _find_random_enemies_around(caster_node, params)
		"around_player":
			return _find_enemies_around(caster_node, params)
		_:
			return []


static func _find_nearest_enemy(caster: Node2D, params: Dictionary) -> Node2D:
	if caster == null:
		return null

	var max_range: float = float(params.get("range", params.get("radius", INF)))
	var max_distance_squared: float = max_range * max_range

	var nearest_enemy: Node2D = null
	var best_score: float = -INF
	var recent_damage_enemy: Node2D = null
	var best_recent_damage: float = 0.0
	var best_recent_distance_squared: float = INF

	for enemy: Node2D in _get_valid_enemies():
		var distance_squared: float = caster.global_position.distance_squared_to(enemy.global_position)
		if distance_squared > max_distance_squared:
			continue

		var recent_damage_priority: float = _get_recent_damage_priority(caster, enemy)
		if recent_damage_priority > 0.0:
			if recent_damage_priority > best_recent_damage or (is_equal_approx(recent_damage_priority, best_recent_damage) and distance_squared < best_recent_distance_squared):
				recent_damage_enemy = enemy
				best_recent_damage = recent_damage_priority
				best_recent_distance_squared = distance_squared
			continue

		var score: float = -distance_squared
		if enemy.is_in_group(&"boss_cores") or str(enemy.get_meta("enemy_type", "")) == "boss_core":
			score += max_distance_squared * 3.0
		elif str(enemy.get_meta("enemy_rank", "")) == "boss" or str(enemy.get_meta("enemy_rank", "")) == "elite":
			score += max_distance_squared * 0.65
		if score <= best_score:
			continue
		nearest_enemy = enemy
		best_score = score

	if recent_damage_enemy != null:
		return recent_damage_enemy
	return nearest_enemy


static func _get_recent_damage_priority(caster: Node2D, enemy: Node2D) -> float:
	if caster == null or not caster.has_method("get_recent_enemy_damage_priority"):
		return 0.0
	return float(caster.call("get_recent_enemy_damage_priority", enemy))


static func _find_highest_hp_enemy(params: Dictionary) -> Node2D:
	var max_range: float = float(params.get("range", INF))
	var origin: Node2D = params.get("origin") as Node2D
	var max_distance_squared: float = max_range * max_range
	var best_enemy: Node2D = null
	var best_score: float = -INF

	for enemy: Node2D in _get_valid_enemies():
		if origin != null and origin.global_position.distance_squared_to(enemy.global_position) > max_distance_squared:
			continue

		var score: float = float(_get_enemy_health(enemy))
		if enemy.is_in_group(&"boss_cores") or str(enemy.get_meta("enemy_type", "")) == "boss_core":
			score += 100000.0
		if score <= best_score:
			continue

		best_enemy = enemy
		best_score = score

	return best_enemy


static func _find_nearest_elite_or_highest_hp(caster: Node2D, params: Dictionary) -> Node2D:
	var max_range: float = float(params.get("range", INF))
	var origin: Node2D = params.get("origin") as Node2D
	if origin == null:
		origin = caster
	var max_distance_squared: float = max_range * max_range
	var nearest_elite: Node2D = null
	var nearest_elite_distance_squared: float = INF
	for enemy: Node2D in _get_valid_enemies():
		if origin != null:
			var distance_squared: float = origin.global_position.distance_squared_to(enemy.global_position)
			if distance_squared > max_distance_squared:
				continue
			if _is_strong_enemy(enemy) and distance_squared < nearest_elite_distance_squared:
				nearest_elite = enemy
				nearest_elite_distance_squared = distance_squared
	if nearest_elite != null:
		return nearest_elite
	return _find_highest_hp_enemy(params)


static func _find_densest_enemy_cluster_center(caster: Node2D, params: Dictionary) -> Node2D:
	var max_range: float = float(params.get("range", INF))
	var origin: Node2D = params.get("origin") as Node2D
	if origin == null:
		origin = caster
	var max_distance_squared: float = max_range * max_range
	var cluster_radius: float = float(params.get("cluster_radius", params.get("radius", 168.0)))
	var best_enemy: Node2D = null
	var best_count: int = -1
	var best_distance_squared: float = INF
	for enemy: Node2D in _get_valid_enemies():
		var distance_squared: float = origin.global_position.distance_squared_to(enemy.global_position) if origin != null else 0.0
		if origin != null and distance_squared > max_distance_squared:
			continue
		var nearby_count: int = _nearby_enemy_count(enemy.global_position, cluster_radius)
		if StringName(str(params.get("priority_status", ""))) != &"" and _has_any_status(enemy, [StringName(str(params.get("priority_status", "")))]):
			nearby_count += 1000
		if nearby_count > best_count or (nearby_count == best_count and distance_squared < best_distance_squared):
			best_enemy = enemy
			best_count = nearby_count
			best_distance_squared = distance_squared
	return best_enemy


static func _find_status_first_nearest(caster: Node2D, params: Dictionary, status_id: StringName) -> Node2D:
	if caster == null:
		return null
	var candidates: Array = _find_enemies_around(caster, params)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_has_status: bool = _has_any_status(a, [status_id])
		var b_has_status: bool = _has_any_status(b, [status_id])
		if a_has_status != b_has_status:
			return a_has_status
		return caster.global_position.distance_squared_to(a.global_position) < caster.global_position.distance_squared_to(b.global_position)
	)
	return candidates[0] as Node2D


static func _find_missing_status_first_nearest(caster: Node2D, params: Dictionary, status_id: StringName) -> Node2D:
	if caster == null:
		return null
	var candidates: Array = _find_enemies_around(caster, params)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_missing_status: bool = not _has_any_status(a, [status_id])
		var b_missing_status: bool = not _has_any_status(b, [status_id])
		if a_missing_status != b_missing_status:
			return a_missing_status
		return caster.global_position.distance_squared_to(a.global_position) < caster.global_position.distance_squared_to(b.global_position)
	)
	return candidates[0] as Node2D


static func _find_status_stack_highest(caster: Node2D, params: Dictionary, status_id: StringName) -> Array:
	if caster == null:
		return []
	var candidates: Array = _find_enemies_around(caster, params)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_stacks: int = _get_status_stack(a, status_id)
		var b_stacks: int = _get_status_stack(b, status_id)
		if a_stacks != b_stacks:
			return a_stacks > b_stacks
		return caster.global_position.distance_squared_to(a.global_position) < caster.global_position.distance_squared_to(b.global_position)
	)
	var count: int = int(params.get("count", candidates.size()))
	if count > 0 and count < candidates.size():
		return candidates.slice(0, count)
	return candidates


static func _with_status_priority(params: Dictionary, status_id: StringName) -> Dictionary:
	var copy: Dictionary = params.duplicate(true)
	copy["priority_status"] = status_id
	return copy


static func _find_random_enemy(params: Dictionary) -> Node2D:
	var enemies: Array = _get_valid_enemies()
	var max_range: float = float(params.get("range", INF))
	var origin: Node2D = params.get("origin") as Node2D
	if origin != null and max_range < INF:
		enemies = enemies.filter(func(enemy: Node2D) -> bool:
			return origin.global_position.distance_squared_to(enemy.global_position) <= max_range * max_range
		)

	if enemies.is_empty():
		return null

	return enemies[randi() % enemies.size()] as Node2D


static func _find_random_enemies_around(caster: Node2D, params: Dictionary) -> Array:
	var enemies: Array = _find_enemies_around(caster, params)
	enemies.shuffle()

	var count: int = int(params.get("count", enemies.size()))
	if count <= 0 or count >= enemies.size():
		return enemies

	return enemies.slice(0, count)


static func _find_enemies_around(caster: Node2D, params: Dictionary) -> Array:
	if caster == null:
		return []

	var radius: float = float(params.get("radius", params.get("range", INF)))
	var radius_squared: float = radius * radius
	var enemies: Array = []
	for enemy: Node2D in _get_valid_enemies():
		if caster.global_position.distance_squared_to(enemy.global_position) <= radius_squared:
			enemies.append(enemy)

	return enemies


static func _get_valid_enemies() -> Array:
	var enemies: Array = []
	var registry: Node = CombatTargetRegistryScript.get_or_create(null)
	var candidates: Array = registry.call("get_targets", ENEMY_GROUP) if registry != null and registry.has_method("get_targets") else []
	for node: Node in candidates:
		var enemy: Node2D = node as Node2D
		if _is_valid_enemy(enemy):
			enemies.append(enemy)

	return enemies


static func is_valid_target(enemy: Node2D) -> bool:
	return _is_valid_enemy(enemy)


static func _is_valid_enemy(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false

	if enemy.has_method("get_runtime_state") and str(enemy.call("get_runtime_state")) == "dead":
		return false

	var current_health_variant: Variant = enemy.get("current_health")
	if current_health_variant != null and int(current_health_variant) <= 0:
		return false

	var is_dead_variant: Variant = enemy.get("_is_dead")
	if is_dead_variant != null and bool(is_dead_variant):
		return false

	if not _is_enemy_inside_active_camera_view(enemy):
		return false

	return true


static func _is_enemy_inside_active_camera_view(enemy: Node2D) -> bool:
	if enemy == null:
		return false

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return true

	var viewport: Viewport = tree.root
	var camera: Camera2D = viewport.get_camera_2d()
	if camera == null:
		return true

	var visible_size: Vector2 = viewport.get_visible_rect().size
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return true

	var camera_zoom: Vector2 = camera.zoom.abs()
	var world_size: Vector2 = Vector2(
		visible_size.x / maxf(camera_zoom.x, 0.001),
		visible_size.y / maxf(camera_zoom.y, 0.001)
	)
	var screen_center: Vector2 = camera.get_screen_center_position()
	var world_rect: Rect2 = Rect2(screen_center - world_size * 0.5, world_size)
	return world_rect.has_point(enemy.global_position)


static func _get_enemy_health(enemy: Node2D) -> int:
	var current_health_variant: Variant = enemy.get("current_health")
	if current_health_variant != null:
		return int(current_health_variant)

	var max_health_variant: Variant = enemy.get("max_health")
	if max_health_variant != null:
		return int(max_health_variant)

	return 0


static func _nearby_enemy_count(center: Vector2, radius: float) -> int:
	var radius_squared: float = radius * radius
	var count: int = 0
	var registry: Node = CombatTargetRegistryScript.get_or_create(null)
	var candidates: Array = registry.call("get_targets_in_radius", center, radius, ENEMY_GROUP) if registry != null and registry.has_method("get_targets_in_radius") else []
	for enemy: Node2D in candidates:
		if not _is_valid_enemy(enemy):
			continue
		if center.distance_squared_to(enemy.global_position) <= radius_squared:
			count += 1
	return count


static func _has_any_status(enemy: Node, statuses: Array[StringName]) -> bool:
	if enemy == null or not enemy.has_method("has_status"):
		return false
	for status_id: StringName in statuses:
		if bool(enemy.call("has_status", status_id)):
			return true
	return false


static func _get_status_stack(enemy: Node, status_id: StringName) -> int:
	if enemy == null or status_id == &"":
		return 0
	if enemy.has_method("get_status_stack"):
		return int(enemy.call("get_status_stack", status_id))
	var manager: Node = enemy.get_node_or_null("StatusEffectManager")
	if manager != null and manager.has_method("get_status_stack"):
		return int(manager.call("get_status_stack", status_id))
	return 1 if _has_any_status(enemy, [status_id]) else 0


static func _is_strong_enemy(enemy: Node) -> bool:
	var rank: String = str(enemy.get_meta("enemy_rank", enemy.get_meta("enemy_type", "")))
	return rank == "elite" or rank == "boss" or rank == "boss_core"


static func _get_enemy_armor(enemy: Node) -> int:
	var value: Variant = enemy.get("armor")
	return int(value) if value != null else 0


static func _is_between_player_and_enemy(caster: Node, enemy: Node2D) -> bool:
	var caster_node: Node2D = caster as Node2D
	if caster_node == null:
		return false
	return caster_node.global_position.distance_squared_to(enemy.global_position) <= 220.0 * 220.0
