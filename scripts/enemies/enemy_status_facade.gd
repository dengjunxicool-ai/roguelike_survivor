## 文件用途：桥接敌人节点与统一状态效果管理服务。
## 使用方式：setup 绑定 enemy；EnemyBase 通过此门面施加、更新、查询或清理状态。

extends RefCounted
class_name EnemyStatusFacade


const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")

var _owner: Node
var _manager: Node


## Params:
## - owner: Enemy node that owns the status manager child.
## Returns:
## - Nothing.
## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node) -> void:
	_owner = owner
	ensure_manager()


## Params:
## - None.
## Returns:
## - Active status manager node.
## 作用：确保管理服务。
## 使用：本文件由 setup、is_movement_frozen、get_effective_move_speed 调用；返回 Node 对象/值。
func ensure_manager() -> Node:
	if _manager != null and is_instance_valid(_manager):
		return _manager
	if _owner == null:
		return null

	_manager = _owner.get_node_or_null("StatusEffectManager")
	if _manager != null:
		return _manager

	_manager = StatusEffectManagerScript.new()
	_manager.name = "StatusEffectManager"
	_owner.add_child(_manager)
	return _manager


## Params:
## - delta: Elapsed frame time in seconds.
## Returns:
## - Nothing.
## 作用：更新状态效果效果列表。
## 使用：供本模块调用者使用；输入 delta（delta）。
func update_status_effects(delta: float) -> void:
	var manager: Node = _manager if _manager != null and is_instance_valid(_manager) else null
	if manager == null:
		return
	if manager.has_method("has_active_statuses") and not bool(manager.call("has_active_statuses")):
		return
	if manager.has_method("should_update_status_effects") and not bool(manager.call("should_update_status_effects", delta)):
		return
	if manager.has_method("consume_pending_status_update_delta"):
		delta = float(manager.call("consume_pending_status_update_delta"))
	if manager.has_method("update_status_effects"):
		manager.call("update_status_effects", delta)


## Params:
## - None.
## Returns:
## - True when movement should be blocked by a status.
## 作用：判断移动冻结，返回布尔判断结果；具体处理委托给 manager.is_movement_frozen。
## 使用：供本模块调用者使用。
func is_movement_frozen() -> bool:
	var manager: Node = ensure_manager()
	return manager != null and bool(manager.call("is_movement_frozen"))


## Params:
## - base_speed: Enemy base movement speed.
## Returns:
## - Movement speed after status multipliers.
## 作用：获取生效移动速度，供当前模块后续逻辑使用；具体处理委托给 manager.get_move_speed_multiplier。
## 使用：供本模块调用者使用；输入 base_speed（基础速度）；返回计算或读取的数值。
func get_effective_move_speed(base_speed: float) -> float:
	var manager: Node = ensure_manager()
	var multiplier: float = 1.0
	if manager != null and manager.has_method("get_move_speed_multiplier"):
		multiplier = float(manager.call("get_move_speed_multiplier"))
	return base_speed * multiplier


## Params:
## - damage_type: Incoming damage type or element.
## Returns:
## - Damage taken multiplier from active statuses.
## 作用：获取承伤倍率，供当前模块后续逻辑使用；具体处理委托给 manager.get_damage_taken_multiplier。
## 使用：供本模块调用者使用；输入 damage_type（伤害类型）；返回计算或读取的数值。
func get_damage_taken_multiplier(damage_type: Variant) -> float:
	var manager: Node = ensure_manager()
	if manager != null and manager.has_method("get_damage_taken_multiplier"):
		return float(manager.call("get_damage_taken_multiplier", damage_type))
	return 1.0


## Params:
## - status_id: Status id to apply.
## - params: Additional status parameters.
## Returns:
## - True when the status manager accepted the status.
## 作用：应用状态效果；具体处理委托给 manager.apply_status。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）、params（参数）；返回是否满足条件或执行成功。
func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
	var manager: Node = ensure_manager()
	if manager == null or not manager.has_method("apply_status"):
		return false
	return bool(manager.call("apply_status", status_id, params))


## Params:
## - status_id: Status id to query.
## Returns:
## - True when the status is currently active.
## 作用：是否包含状态效果，返回布尔判断结果；具体处理委托给 manager.has_status。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）。
func has_status(status_id: Variant) -> bool:
	var manager: Node = ensure_manager()
	return manager != null and bool(manager.call("has_status", status_id))


## Params:
## - status_id: Status id to query.
## Returns:
## - Current stack count.
## 作用：获取状态效果叠层，供当前模块后续逻辑使用；具体处理委托给 manager.get_status_stack。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）；返回计算或读取的数值。
func get_status_stack(status_id: Variant) -> int:
	var manager: Node = ensure_manager()
	if manager == null:
		return 0
	return int(manager.call("get_status_stack", status_id))


## Params:
## - None.
## Returns:
## - True when one shock stack was consumed.
## 作用：消耗感电叠层；具体处理委托给 manager.consume_shock_stack。
## 使用：供本模块调用者使用；返回是否满足条件或执行成功。
func consume_shock_stack() -> bool:
	var manager: Node = ensure_manager()
	if manager == null:
		return false
	return bool(manager.call("consume_shock_stack"))


## Params:
## - status_id: Status id whose stacks should be consumed.
## - stack_count: Number of stacks to consume.
## Returns:
## - True when the status manager consumed stacks.
## 作用：消耗状态效果叠层；具体处理委托给 manager.consume_status_stack。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）、stack_count（叠层数量）；返回是否满足条件或执行成功。
func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
	var manager: Node = ensure_manager()
	if manager == null or not manager.has_method("consume_status_stack"):
		return false
	return bool(manager.call("consume_status_stack", status_id, stack_count))


## Params:
## - None.
## Returns:
## - Array of status dictionaries for UI display.
## 作用：获取状态效果快照，供当前模块后续逻辑使用；具体处理委托给 manager.get_status_snapshot。
## 使用：供本模块调用者使用；返回 Array[Dictionary] 列表。
func get_status_snapshot() -> Array[Dictionary]:
	var manager: Node = ensure_manager()
	if manager == null or not manager.has_method("get_status_snapshot"):
		return []
	return manager.call("get_status_snapshot")


## 作用：消耗状态效果展示脏标记；具体处理委托给 manager.consume_status_display_dirty。
## 使用：供本模块调用者使用；返回是否满足条件或执行成功。
func consume_status_display_dirty() -> bool:
	var manager: Node = _manager if _manager != null and is_instance_valid(_manager) else null
	if manager == null or not manager.has_method("consume_status_display_dirty"):
		return false
	return bool(manager.call("consume_status_display_dirty"))


## Params:
## - None.
## Returns:
## - Nothing.
## 作用：清除状态效果组；具体处理委托给 manager.clear_statuses。
## 使用：供本模块调用者使用。
func clear_statuses() -> void:
	var manager: Node = ensure_manager()
	if manager != null and manager.has_method("clear_statuses"):
		manager.call("clear_statuses")
