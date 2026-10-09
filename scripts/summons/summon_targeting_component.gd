## 文件用途：以可配置间隔和距离为召唤选择最近目标，支持指定状态优先。
## 使用方式：SummonController.setup初始化，update每物理帧保留/刷新目标；候选来自CombatTargetRegistry。
extends RefCounted
class_name SummonTargetingComponent


const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

var owner: Node2D
var target_group: StringName = &"enemies"
var detect_range: float = 300.0
var retarget_interval: float = 0.2
var target_priority: String = "nearest_to_summon"
var _retarget_timer: float = 0.0


## 作用：保存owner与目标组并配置检测半径、重选间隔和优先策略。
## 使用：计时器清零使下次update立即选目标。
func setup(config: Dictionary, summon_owner: Node2D, group: StringName) -> void:
	owner = summon_owner
	target_group = group
	detect_range = maxf(float(config.get("detect_range", detect_range)), 1.0)
	retarget_interval = maxf(float(config.get("retarget_interval", retarget_interval)), 0.05)
	target_priority = str(config.get("target_priority", target_priority))
	_retarget_timer = 0.0


## 作用：当前目标有效且重选间隔未到时保留，否则寻找新目标。
## 使用：delta推进timer，leash_distance控制主人距离；未找到替代仍保留有效旧目标。
func update(delta: float, summon: Node2D, current_target: Variant, leash_distance: float) -> Node2D:
	_retarget_timer -= delta
	if is_target_valid(current_target, leash_distance):
		if _retarget_timer > 0.0:
			return current_target as Node2D
		_retarget_timer = retarget_interval
		var refreshed_target: Node2D = find_target(summon)
		return refreshed_target if refreshed_target != null else current_target as Node2D
	_retarget_timer = retarget_interval
	return find_target(summon)


## 作用：重置重选计时器并立即重新找目标。
## 使用：summon为查询位置来源，返回新目标或null。
func force_retarget(summon: Node2D) -> Node2D:
	_retarget_timer = retarget_interval
	return find_target(summon)


## 作用：排除无效/死亡目标并检查到主人距离不超过检测/牵引较大值。
## 使用：不检查目标组，由候选来源保证；owner可空。
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


## 作用：收集召唤检测范围目标，按状态优先或选最近策略返回首项。
## 使用：无候选返回null，候选排序会改变临时数组。
func find_target(summon: Node2D) -> Node2D:
	if summon == null:
		return null
	var candidates: Array[Node2D] = _collect_target_candidates(summon)
	if candidates.is_empty():
		return null
	var priority_status_id: StringName = _get_priority_status_id()
	if priority_status_id != &"":
		return _select_status_priority_target(candidates, summon.global_position, priority_status_id)
	return _select_nearest_target(candidates, _get_default_target_origin(summon))


## 作用：查询注册表检测圆并再次过滤死亡和距离。
## 使用：summon必须有效，返回二维候选数组。
func _collect_target_candidates(summon: Node2D) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	var range_squared: float = detect_range * detect_range
	var registry: Node = CombatTargetRegistryScript.get_or_create(summon)
	var targets: Array = registry.call("get_targets_in_radius", summon.global_position, detect_range, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in targets:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		if summon.global_position.distance_squared_to(enemy.global_position) <= range_squared:
			candidates.append(enemy)
	return candidates


## 作用：把frozen/conductive/judgment/instability/cursed优先策略映射为状态ID。
## 使用：普通最近策略返回空ID。
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


## 作用：原地排序候选，使有指定状态者优先，再按到origin距离排序。
## 使用：candidates必须非空，返回第一项。
func _select_status_priority_target(candidates: Array[Node2D], origin: Vector2, priority_status_id: StringName) -> Node2D:
	## 作用：排序时优先比较目标指定状态，状态一致再比较距离。
	## 使用：sort_custom传入a、b候选，返回a是否应排在b前。
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_has_priority: bool = _has_status(a, priority_status_id)
		var b_has_priority: bool = _has_status(b, priority_status_id)
		if a_has_priority != b_has_priority:
			return a_has_priority
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return candidates[0]


## 作用：原地按距离升序排序并返回第一项。
## 使用：candidates必须非空，origin通常是召唤或主人位置。
func _select_nearest_target(candidates: Array[Node2D], origin: Vector2) -> Node2D:
	## 作用：排序时比较两个目标到本次查询中心的平方距离。
	## 使用：sort_custom传入a、b节点，返回a是否更近，用于取最近目标。
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return candidates[0]


## 作用：nearest_to_owner策略使用主人位置，否则使用召唤位置。
## 使用：owner缺失自动回退召唤。
func _get_default_target_origin(summon: Node2D) -> Vector2:
	return owner.global_position if target_priority == "nearest_to_owner" and owner != null else summon.global_position


## 作用：优先查公开状态接口，再查管理器，最后查statuses元数据。
## 使用：支持数组或字典元数据，找不到返回false。
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
