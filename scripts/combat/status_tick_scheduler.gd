## 文件用途：登记拥有者/状态tick身份并推进各运行状态的tick_timer。
## 使用方式：StatusEffectManager持有调度对象，登记/注销保持状态生命周期一致；到期后管理器实际执行tick。
extends RefCounted
class_name StatusTickScheduler


var _registered_statuses: Dictionary = {}


## 作用：登记拥有者实例和状态ID组合。
## 使用：重复登记幂等，返回无值；_status参数当前不参与登记。
func register_status(owner: Object, status_id: StringName, _status: Dictionary) -> void:
	if owner == null or status_id == &"":
		return
	_registered_statuses[_status_key(owner, status_id)] = true


## 作用：移除拥有者对应状态的登记。
## 使用：owner或status_id缺失时无操作。
func unregister_status(owner: Object, status_id: StringName) -> void:
	if owner == null or status_id == &"":
		return
	_registered_statuses.erase(_status_key(owner, status_id))


## 作用：按拥有者实例前缀移除全部tick登记。
## 使用：清状态或重置时调用，不改状态字典。
func unregister_all_for_owner(owner: Object) -> void:
	if owner == null:
		return
	var owner_prefix: String = "%d|" % int(owner.get_instance_id())
	for key_variant: Variant in _registered_statuses.keys():
		var key: String = String(key_variant)
		if key.begins_with(owner_prefix):
			_registered_statuses.erase(key)


## 作用：仅对有tick工作的状态推进计时器并判断到期。
## 使用：delta须为正，间隔结合倍率且最少0.05秒；不执行伤害。
func advance_and_is_due(owner: Object, status_id: StringName, status: Dictionary, delta: float) -> bool:
	if owner == null or status_id == &"" or delta <= 0.0:
		return false
	if not _has_status_tick_work(status):
		unregister_status(owner, status_id)
		return false
	register_status(owner, status_id, status)
	var tick_interval: float = maxf(
		float(status.get("tick_interval", 1.0)) * float(status.get("tick_interval_multiplier", 1.0)),
		0.05
	)
	var tick_timer: float = float(status.get("tick_timer", tick_interval)) - delta
	status["tick_timer"] = tick_timer
	return tick_timer <= 0.0


## 作用：组合拥有者实例ID和状态ID生成登记键。
## 使用：owner须非空。
func _status_key(owner: Object, status_id: StringName) -> String:
	return "%d|%s" % [int(owner.get_instance_id()), String(status_id)]


## 作用：检查正tick伤害或非空tick效果列表。
## 使用：无工作时调度器会注销登记。
func _has_status_tick_work(status: Dictionary) -> bool:
	return float(status.get("tick_damage", 0.0)) > 0.0 or not _get_array(status.get("on_tick_effects", [])).is_empty()


## 作用：读取数组配置，非数组输入返回空数组。
## 使用：value为待检查配置；返回输入数组本身。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
