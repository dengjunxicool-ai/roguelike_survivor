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


func update(delta: float, summon: Node2D, current_target: Node2D, leash_distance: float) -> Node2D:
	_retarget_timer -= delta
	if is_target_valid(current_target, leash_distance):
		return current_target
	if _retarget_timer > 0.0:
		return null
	_retarget_timer = retarget_interval
	return find_target(summon)


func force_retarget(summon: Node2D) -> Node2D:
	_retarget_timer = retarget_interval
	return find_target(summon)


func is_target_valid(target: Node2D, leash_distance: float) -> bool:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return false
	if owner != null and owner.global_position.distance_to(target.global_position) > maxf(leash_distance, detect_range):
		return false
	return true


func find_target(summon: Node2D) -> Node2D:
	if summon == null:
		return null
	var tree: SceneTree = summon.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
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
	if candidates.is_empty():
		return null
	if target_priority == "frozen_first_then_nearest":
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			var a_frozen: bool = _has_status(a, &"frozen")
			var b_frozen: bool = _has_status(b, &"frozen")
			if a_frozen != b_frozen:
				return a_frozen
			return summon.global_position.distance_squared_to(a.global_position) < summon.global_position.distance_squared_to(b.global_position)
		)
		return candidates[0]
	if target_priority == "conductive_first_then_nearest":
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			var a_conductive: bool = _has_status(a, &"conductive")
			var b_conductive: bool = _has_status(b, &"conductive")
			if a_conductive != b_conductive:
				return a_conductive
			return summon.global_position.distance_squared_to(a.global_position) < summon.global_position.distance_squared_to(b.global_position)
		)
		return candidates[0]
	if target_priority == "judgment_first_then_nearest":
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			var a_judgment: bool = _has_status(a, &"judgment")
			var b_judgment: bool = _has_status(b, &"judgment")
			if a_judgment != b_judgment:
				return a_judgment
			return summon.global_position.distance_squared_to(a.global_position) < summon.global_position.distance_squared_to(b.global_position)
		)
		return candidates[0]
	if target_priority == "instability_first_then_nearest":
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			var a_instability: bool = _has_status(a, &"instability")
			var b_instability: bool = _has_status(b, &"instability")
			if a_instability != b_instability:
				return a_instability
			return summon.global_position.distance_squared_to(a.global_position) < summon.global_position.distance_squared_to(b.global_position)
		)
		return candidates[0]
	if target_priority == "cursed_first_then_nearest":
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			var a_cursed: bool = _has_status(a, &"cursed")
			var b_cursed: bool = _has_status(b, &"cursed")
			if a_cursed != b_cursed:
				return a_cursed
			return summon.global_position.distance_squared_to(a.global_position) < summon.global_position.distance_squared_to(b.global_position)
		)
		return candidates[0]
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var origin: Vector2 = owner.global_position if target_priority == "nearest_to_owner" and owner != null else summon.global_position
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return candidates[0]


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
