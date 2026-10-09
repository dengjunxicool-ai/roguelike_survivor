## 文件用途：解析最大生命百分比伤害并应用目标阶级上限。
## 使用方式：百分比伤害独立管线使用，随后仍进入取整阶段。
extends RefCounted
class_name DamageTruePercentResolver


## 作用：优先读取 percent、percent_of_max_health，再使用原始值作为百分比。
## 使用：大于1的输入除以100；记录 percent，返回比例值。
static func resolve_true_percent(calculation_context: RefCounted) -> float:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	var percent: float = float(calculation_context.call("packet_value", "percent", calculation_context.call("packet_value", "percent_of_max_health", raw_amount)))
	if percent > 1.0:
		percent *= 0.01
	stages["percent"] = percent
	return percent


## 作用：将最大生命乘以非负百分比并记录原始百分比伤害。
## 使用：max_health 为目标最大生命，返回取上限前的浮点值。
static func apply_true_percent_stage(calculation_context: RefCounted, max_health: float, percent: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var damage: float = max_health * maxf(percent, 0.0)
	stages["max_health"] = max_health
	stages["after_true_percent"] = damage
	return damage


## 作用：用包中上限或目标快照默认上限裁剪最大生命百分比伤害。
## 使用：cap 大于0才裁剪；记录上限与 after_special，后续负责取整。
static func apply_true_percent_cap_stage(calculation_context: RefCounted, damage: float, max_health: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var profile: RefCounted = calculation_context.get("target_profile")
	var default_cap: float = float(profile.get("true_percent_cap"))
	var cap: float = float(calculation_context.call("packet_value", "true_percent_damage_cap", default_cap))
	if cap > 0.0:
		damage = minf(damage, max_health * cap)
	stages["true_percent_cap"] = cap
	stages["after_special"] = damage
	return damage
