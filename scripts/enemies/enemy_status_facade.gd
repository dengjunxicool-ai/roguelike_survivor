extends RefCounted
class_name EnemyStatusFacade


const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")

var _owner: Node
var _manager: Node


## Params:
## - owner: Enemy node that owns the status manager child.
## Returns:
## - Nothing.
func setup(owner: Node) -> void:
	_owner = owner
	ensure_manager()


## Params:
## - None.
## Returns:
## - Active status manager node.
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
func is_movement_frozen() -> bool:
	var manager: Node = ensure_manager()
	return manager != null and bool(manager.call("is_movement_frozen"))


## Params:
## - base_speed: Enemy base movement speed.
## Returns:
## - Movement speed after status multipliers.
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
func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
	var manager: Node = ensure_manager()
	if manager == null or not manager.has_method("apply_status"):
		return false
	return bool(manager.call("apply_status", status_id, params))


## Params:
## - status_id: Status id to query.
## Returns:
## - True when the status is currently active.
func has_status(status_id: Variant) -> bool:
	var manager: Node = ensure_manager()
	return manager != null and bool(manager.call("has_status", status_id))


## Params:
## - status_id: Status id to query.
## Returns:
## - Current stack count.
func get_status_stack(status_id: Variant) -> int:
	var manager: Node = ensure_manager()
	if manager == null:
		return 0
	return int(manager.call("get_status_stack", status_id))


## Params:
## - None.
## Returns:
## - True when one shock stack was consumed.
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
func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
	var manager: Node = ensure_manager()
	if manager == null or not manager.has_method("consume_status_stack"):
		return false
	return bool(manager.call("consume_status_stack", status_id, stack_count))


## Params:
## - None.
## Returns:
## - Array of status dictionaries for UI display.
func get_status_snapshot() -> Array[Dictionary]:
	var manager: Node = ensure_manager()
	if manager == null or not manager.has_method("get_status_snapshot"):
		return []
	return manager.call("get_status_snapshot")


func consume_status_display_dirty() -> bool:
	var manager: Node = _manager if _manager != null and is_instance_valid(_manager) else null
	if manager == null or not manager.has_method("consume_status_display_dirty"):
		return false
	return bool(manager.call("consume_status_display_dirty"))


## Params:
## - None.
## Returns:
## - Nothing.
func clear_statuses() -> void:
	var manager: Node = ensure_manager()
	if manager != null and manager.has_method("clear_statuses"):
		manager.call("clear_statuses")
