## 文件用途：提供状态持续时间推进、tick工作判断和总DOT伤害计算。
## 使用方式：管理器与状态快照查询静态调用；持续时间推进会原地修改运行字典。
extends RefCounted
class_name StatusEffectTickHelper


## 作用：从duration_remaining扣除本次更新时间。
## 使用：status原地修改，delta应为累计的有效运行秒数。
static func advance_duration(status: Dictionary, delta: float) -> void:
	status["duration_remaining"] = float(status.get("duration_remaining", 0.0)) - delta


## 作用：判断层数用尽或剩余时间非正。
## 使用：返回布尔值，移除和过期效果由管理器负责。
static func is_status_expired(status: Dictionary) -> bool:
	return int(status.get("stacks", 1)) <= 0 or float(status.get("duration_remaining", 0.0)) <= 0.0


## 作用：判断状态有正tick_damage或非空on_tick_effects。
## 使用：用于避免没有tick工作的调度。
static func has_status_tick_work(status: Dictionary) -> bool:
	return float(status.get("tick_damage", 0.0)) > 0.0 or not _get_array(status.get("on_tick_effects", [])).is_empty()


## 作用：优先读运行状态开关，否则读定义默认开关。
## 使用：返回每次tick是否消耗一层。
static func should_consume_stack_on_tick(status: Dictionary) -> bool:
	if status.has("consume_stack_on_tick"):
		return bool(status.get("consume_stack_on_tick", false))
	var definition: Dictionary = _get_dictionary(status.get("definition", {}))
	return bool(definition.get("consume_stack_on_tick", false))


## 作用：计算固定tick伤害乘层数及damage效果的Power缩放总值。
## 使用：只计damage效果，不应用阶级减伤和取整。
static func tick_damage_total(status: Dictionary) -> float:
	var stacks: float = float(maxi(int(status.get("stacks", 1)), 1))
	var total: float = float(status.get("tick_damage", 0.0)) * stacks
	var power: float = float(status.get("power", 0.0))
	for effect_variant: Variant in _get_array(status.get("on_tick_effects", [])):
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if str(effect.get("type", "")) != "damage":
			continue
		if effect.has("power_scale"):
			total += power * float(effect.get("power_scale", 0.0))
		elif effect.has("power_scale_per_stack"):
			total += power * float(effect.get("power_scale_per_stack", 0.0)) * stacks
	return total


## 作用：读取字典配置，非字典输入返回空字典。
## 使用：value为待检查配置；返回输入字典本身，调用方写入会影响原值。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## 作用：读取数组配置，非数组输入返回空数组。
## 使用：value为待检查配置；返回输入数组本身。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
