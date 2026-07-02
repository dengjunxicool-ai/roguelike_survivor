extends RefCounted
class_name SummonTargetingComponent


var owner: Node2D
var target_group: StringName = &"enemies"
var detect_range: float = 300.0
var retarget_interval: float = 0.25
var target_priority: String = "nearest_to_summon"
var _retarget_timer: float = 0.0


func setup(config: Dictionary, summon_owner: Node2D, group: StringName) -> void:
	owner = summon_owner
	target_group = group
	detect_range = maxf(float(config.get("detect_range", detect_range)), 1.0)
	retarget_interval = maxf(float(config.get("retarget_interval", retarget_interval)), 0.05)
	target_priority = str(config.get("target_priority", target_priority))
	_retarget_timer = 0.0


func update(delta: float, summon: Node2D, current_target: Variant, leash_distance: float) -> Node2D:
	_retarget_timer -= delta
	if is_target_valid(current_target, leash_distance):
		return current_target as Node2D
	if _retarget_timer > 0.0:
		return null
	_retarget_timer = retarget_interval
	return find_target(summon)


func force_retarget(summon: Node2D) -> Node2D:
	_retarget_timer = retarget_interval
	return find_target(summon)


func is_target_valid(target: Variant, leash_distance: float) -> bool:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	var target_node: Node2D = target as Node2D
	if target_node == null:
		return false
	if target_node.has_method("is_dead") and bool(target_node.call("is_dead")):
		return false
	if owner != null and is_instance_valid(owner) and owner.global_position.distance_to(target_node.global_position) > maxf(leash_distance, detect_range):
		return false
	return true


func find_target(summon: Node2D) -> Node2D:
	if summon == null:
		return null
	var tree: SceneTree = _get_scene_tree(summon)
	if tree == null:
		return null
	var candidates: Array[Node2D] = _collect_target_candidates(tree, summon)
	if candidates.is_empty():
		return null
	var priority_status_id: StringName = _get_priority_status_id()
	if priority_status_id != &"":
		return _select_status_priority_target(candidates, summon.global_position, priority_status_id)
	return _select_nearest_target(candidates, _get_default_target_origin(summon))


func _get_scene_tree(summon: Node2D) -> SceneTree:
	var tree: SceneTree = summon.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	return tree


func _collect_target_candidates(tree: SceneTree, summon: Node2D) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	var range_squared: float = detect_range * detect_range
	for node: Node in tree.get_nodes_in_group(target_group):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		if summon.global_position.distance_squared_to(enemy.global_position) <= range_squared:
			candidates.append(enemy)
	return candidates


func _get_priority_status_id() -> StringName:
	match target_priority:
		"frozen_first_then_nearest":
			return &"frozen"
		"conductive_first_then_nearest":
			return &"conductive"
		"judgment_first_then_nearest":
			return &"judgment"
		"instability_first_then_nearest":
			return &"instability"
		"cursed_first_then_nearest":
			return &"cursed"
		_:
			return &""


func _select_status_priority_target(candidates: Array[Node2D], origin: Vector2, priority_status_id: StringName) -> Node2D:
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_has_priority: bool = _has_status(a, priority_status_id)
		var b_has_priority: bool = _has_status(b, priority_status_id)
		if a_has_priority != b_has_priority:
			return a_has_priority
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return candidates[0]


func _select_nearest_target(candidates: Array[Node2D], origin: Vector2) -> Node2D:
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return candidates[0]


func _get_default_target_origin(summon: Node2D) -> Vector2:
	return owner.global_position if target_priority == "nearest_to_owner" and owner != null else summon.global_position


func _has_status(target: Node, status_id: StringName) -> bool:
	if target == null:
		return false
	if target.has_method("has_status"):
		return bool(target.call("has_status", status_id))
	var manager: Node = target.get_node_or_null("StatusEffectManager")
	if manager != null and manager.has_method("has_status"):
		return bool(manager.call("has_status", status_id))
	if target.has_meta("statuses"):
		var statuses: Variant = target.get_meta("statuses")
		if statuses is Array:
			return (statuses as Array).has(status_id) or (statuses as Array).has(str(status_id))
		if statuses is Dictionary:
			return (statuses as Dictionary).has(status_id) or (statuses as Dictionary).has(str(status_id))
	return false
