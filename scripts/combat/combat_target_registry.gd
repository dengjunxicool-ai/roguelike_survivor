extends Node
class_name CombatTargetRegistry


const REGISTRY_NAME: StringName = &"CombatTargetRegistry"
const ENEMY_GROUP: StringName = &"enemies"
const LEGACY_ENEMY_GROUP: StringName = &"enemy"
const DEFAULT_CELL_SIZE: float = 128.0
const GRID_QUERY_MIN_TARGETS: int = 96

var _targets_by_group: Dictionary = {}
var _enemy_grid: Dictionary = {}
var _enemy_grid_frame: int = -1
var _enemy_grid_dirty: bool = true


static func get_or_create(context: Node = null) -> Node:
	var tree: SceneTree = null
	if context != null:
		tree = context.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null

	var registry: Node = tree.root.get_node_or_null(NodePath(String(REGISTRY_NAME)))
	if registry != null:
		return registry

	var registry_script: Script = load("res://scripts/combat/combat_target_registry.gd") as Script
	if registry_script == null:
		return null
	registry = registry_script.new() as Node
	registry.name = String(REGISTRY_NAME)
	tree.root.add_child(registry)
	return registry


func register_enemy(enemy: Node) -> void:
	register_target(enemy, ENEMY_GROUP)
	register_target(enemy, LEGACY_ENEMY_GROUP)


func unregister_enemy(enemy: Node) -> void:
	unregister_target(enemy, ENEMY_GROUP)
	unregister_target(enemy, LEGACY_ENEMY_GROUP)


func register_target(target: Node, group: StringName) -> void:
	if target == null or group == &"":
		return
	var targets: Dictionary = _targets_by_group.get(group, {})
	targets[int(target.get_instance_id())] = weakref(target)
	_targets_by_group[group] = targets
	if _is_enemy_group(group):
		_enemy_grid_dirty = true


func unregister_target(target: Node, group: StringName) -> void:
	if target == null or group == &"":
		return
	var targets: Dictionary = _targets_by_group.get(group, {})
	targets.erase(int(target.get_instance_id()))
	if targets.is_empty():
		_targets_by_group.erase(group)
	else:
		_targets_by_group[group] = targets
	if _is_enemy_group(group):
		_enemy_grid_dirty = true


func get_targets(group: StringName = ENEMY_GROUP) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var targets: Dictionary = _targets_by_group.get(group, {})
	if targets.is_empty():
		return result

	var stale_ids: Array[int] = []
	for id_variant: Variant in targets.keys():
		var target: Node2D = _target_from_ref(targets[id_variant]) as Node2D
		if not _is_live_target(target):
			stale_ids.append(int(id_variant))
			continue
		result.append(target)

	for stale_id: int in stale_ids:
		targets.erase(stale_id)
	if stale_ids.size() > 0:
		if targets.is_empty():
			_targets_by_group.erase(group)
		else:
			_targets_by_group[group] = targets
		if _is_enemy_group(group):
			_enemy_grid_dirty = true
	return result


func get_targets_in_radius(origin: Vector2, radius: float, group: StringName = ENEMY_GROUP, max_results: int = 0) -> Array[Node2D]:
	if radius <= 0.0:
		return []
	if not _is_enemy_group(group):
		return _filter_targets_in_radius(get_targets(group), origin, radius, max_results)

	var all_targets: Array[Node2D] = get_targets(ENEMY_GROUP)
	if all_targets.size() < GRID_QUERY_MIN_TARGETS:
		return _filter_targets_in_radius(all_targets, origin, radius, max_results)

	_ensure_enemy_grid(all_targets)
	var result: Array[Node2D] = []
	var radius_squared: float = radius * radius
	var cell_radius: int = ceili(radius / DEFAULT_CELL_SIZE)
	var origin_cell: Vector2i = _spatial_cell(origin)
	for x: int in range(origin_cell.x - cell_radius, origin_cell.x + cell_radius + 1):
		for y: int in range(origin_cell.y - cell_radius, origin_cell.y + cell_radius + 1):
			var bucket: Array = _enemy_grid.get(Vector2i(x, y), [])
			for target_variant: Variant in bucket:
				var target: Node2D = target_variant as Node2D
				if not _is_live_target(target):
					continue
				if origin.distance_squared_to(target.global_position) <= radius_squared:
					result.append(target)

	if max_results > 0 and result.size() > max_results:
		result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
		)
		return result.slice(0, max_results)
	return result


func find_nearest(origin: Vector2, radius: float = INF, group: StringName = ENEMY_GROUP, excluded: Node = null) -> Node2D:
	var candidates: Array[Node2D] = get_targets(group) if radius == INF else get_targets_in_radius(origin, radius, group)
	var best: Node2D = null
	var best_distance_squared: float = INF
	for candidate: Node2D in candidates:
		if candidate == null or candidate == excluded:
			continue
		var distance_squared: float = origin.distance_squared_to(candidate.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = candidate
	return best


func count_targets(group: StringName = ENEMY_GROUP) -> int:
	return get_targets(group).size()


func _ensure_enemy_grid(targets: Array[Node2D] = []) -> void:
	var frame: int = int(Engine.get_physics_frames())
	if not _enemy_grid_dirty and _enemy_grid_frame == frame:
		return
	_enemy_grid.clear()
	_enemy_grid_frame = frame
	_enemy_grid_dirty = false
	var enemies: Array[Node2D] = targets if not targets.is_empty() else get_targets(ENEMY_GROUP)
	for enemy: Node2D in enemies:
		var cell: Vector2i = _spatial_cell(enemy.global_position)
		var bucket: Array = _enemy_grid.get(cell, [])
		bucket.append(enemy)
		_enemy_grid[cell] = bucket


func _filter_targets_in_radius(targets: Array[Node2D], origin: Vector2, radius: float, max_results: int = 0) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_squared: float = radius * radius
	for target: Node2D in targets:
		if target == null:
			continue
		if origin.distance_squared_to(target.global_position) <= radius_squared:
			result.append(target)
	if max_results > 0 and result.size() > max_results:
		result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
		)
		return result.slice(0, max_results)
	return result


func _target_from_ref(reference: Variant) -> Node:
	if reference is WeakRef:
		return (reference as WeakRef).get_ref() as Node
	return reference as Node


func _is_live_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return false
	var is_dead_variant: Variant = target.get("_is_dead")
	if is_dead_variant != null and bool(is_dead_variant):
		return false
	var health_variant: Variant = target.get("current_health")
	if health_variant != null and int(health_variant) <= 0:
		return false
	return true


func _is_enemy_group(group: StringName) -> bool:
	return group == ENEMY_GROUP or group == LEGACY_ENEMY_GROUP


func _spatial_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / DEFAULT_CELL_SIZE),
		floori(position.y / DEFAULT_CELL_SIZE)
	)
