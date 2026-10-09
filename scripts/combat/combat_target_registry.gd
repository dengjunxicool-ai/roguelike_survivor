## 文件用途：集中维护目标弱引用并为高密度敌人提供每物理帧更新的空间网格查询。
## 使用方式：敌人出现/离场调用register_enemy/unregister_enemy；技能与召唤通过get_or_create查询可攻击目标。
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


## 作用：在场景树根复用或创建注册表节点。
## 使用：context可提供树，无context使用主循环；无树返回null。
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


## 作用：把敌人同时登记到enemies和enemy索引。
## 使用：生成生命周期调用，弱引用不阻止释放。
func register_enemy(enemy: Node) -> void:
	register_target(enemy, ENEMY_GROUP)
	register_target(enemy, LEGACY_ENEMY_GROUP)


## 作用：从两个敌人索引移除目标并使网格失效。
## 使用：敌人离场/死亡清理时调用。
func unregister_enemy(enemy: Node) -> void:
	unregister_target(enemy, ENEMY_GROUP)
	unregister_target(enemy, LEGACY_ENEMY_GROUP)


## 作用：按实例ID在指定组保存弱引用并标记敌人网格脏。
## 使用：group非空、target非空，重复注册覆盖同ID。
func register_target(target: Node, group: StringName) -> void:
	if target == null or group == &"":
		return
	var targets: Dictionary = _targets_by_group.get(group, {})
	targets[int(target.get_instance_id())] = weakref(target)
	_targets_by_group[group] = targets
	if _is_enemy_group(group):
		_enemy_grid_dirty = true


## 作用：从指定组删实例，空组删整个索引并标记网格脏。
## 使用：不会释放目标节点。
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


## 作用：返回存活且已显现的二维目标，并清理失效/死亡弱引用。
## 使用：group决定索引；spawn_reveal_pending目标暂不返回。
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
		if not _is_available_target(target):
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


## 作用：在圆内查询目标，高密度敌人使用网格，结果过多时按距离截取。
## 使用：radius正数，max_results=0不限制；enemy别名共用主索引。
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
		## 作用：排序时比较两个目标到本次查询中心的平方距离。
		## 使用：sort_custom传入a、b节点，返回a是否更近，用于取最近目标。
		result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
		)
		return result.slice(0, max_results)
	return result


## 作用：在指定组和范围寻找距离最小的目标，并排除指定节点。
## 使用：radius=INF查全组，未找到返回null。
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


## 作用：统计当前可用目标数量。
## 使用：内部get_targets也会清理陈旧引用。
func count_targets(group: StringName = ENEMY_GROUP) -> int:
	return get_targets(group).size()


## 作用：网格脏或物理帧变化时重新按目标位置分桶。
## 使用：可传已查询目标避免重复扫描，默认查询主敌人组。
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


## 作用：线性过滤圆内目标，超过结果上限时返回最近项。
## 使用：targets为已验证节点列表，radius为世界距离。
func _filter_targets_in_radius(targets: Array[Node2D], origin: Vector2, radius: float, max_results: int = 0) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_squared: float = radius * radius
	for target: Node2D in targets:
		if target == null:
			continue
		if origin.distance_squared_to(target.global_position) <= radius_squared:
			result.append(target)
	if max_results > 0 and result.size() > max_results:
		## 作用：排序时比较两个目标到本次查询中心的平方距离。
		## 使用：sort_custom传入a、b节点，返回a是否更近，用于取最近目标。
		result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
		)
		return result.slice(0, max_results)
	return result


## 作用：从WeakRef取目标，普通节点引用直接转换。
## 使用：已释放弱引用返回null。
func _target_from_ref(reference: Variant) -> Node:
	if reference is WeakRef:
		return (reference as WeakRef).get_ref() as Node
	return reference as Node


## 作用：排除空/释放中/死亡标记或生命非正目标。
## 使用：不检查显现状态，由可用性查询另外处理。
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


## 作用：判断目标没有处于spawn_reveal_pending警示阶段。
## 使用：未显现敌人仍登记但不作为技能目标。
func _is_available_target(target: Node) -> bool:
	return target != null and not bool(target.get_meta("spawn_reveal_pending", false))


## 作用：识别enemies或enemy索引名。
## 使用：用于选择共享网格和脏标记。
func _is_enemy_group(group: StringName) -> bool:
	return group == ENEMY_GROUP or group == LEGACY_ENEMY_GROUP


## 作用：按128像素格尺寸将世界坐标向下取整为网格坐标。
## 使用：负坐标保持正确分桶，返回Vector2i。
func _spatial_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / DEFAULT_CELL_SIZE),
		floori(position.y / DEFAULT_CELL_SIZE)
	)
