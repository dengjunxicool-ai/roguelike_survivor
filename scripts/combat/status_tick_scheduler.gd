extends RefCounted
class_name StatusTickScheduler


var _registered_statuses: Dictionary = {}


func register_status(owner: Object, status_id: StringName, _status: Dictionary) -> void:
	if owner == null or status_id == &"":
		return
	_registered_statuses[_status_key(owner, status_id)] = true


func unregister_status(owner: Object, status_id: StringName) -> void:
	if owner == null or status_id == &"":
		return
	_registered_statuses.erase(_status_key(owner, status_id))


func unregister_all_for_owner(owner: Object) -> void:
	if owner == null:
		return
	var owner_prefix: String = "%d|" % int(owner.get_instance_id())
	for key_variant: Variant in _registered_statuses.keys():
		var key: String = String(key_variant)
		if key.begins_with(owner_prefix):
			_registered_statuses.erase(key)


func advance_and_is_due(owner: Object, status_id: StringName, status: Dictionary, delta: float) -> bool:
	if owner == null or status_id == &"" or delta <= 0.0:
		return false
	if not _has_status_tick_work(status):
		unregister_status(owner, status_id)
		return false
	register_status(owner, status_id, status)
	var tick_interval: float = maxf(
		float(status.get("tick_interval", 0.5)) * float(status.get("tick_interval_multiplier", 1.0)),
		0.05
	)
	var tick_timer: float = float(status.get("tick_timer", tick_interval)) - delta
	status["tick_timer"] = tick_timer
	return tick_timer <= 0.0


func _status_key(owner: Object, status_id: StringName) -> String:
	return "%d|%s" % [int(owner.get_instance_id()), String(status_id)]


func _has_status_tick_work(status: Dictionary) -> bool:
	return float(status.get("tick_damage", 0.0)) > 0.0 or not _get_array(status.get("on_tick_effects", [])).is_empty()


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
