## 文件用途：将配置中的范围单位转换为场景像素距离，并提供一致的展示半径。
## 使用方式：动作分派前调用 resolve_action_params，数值和方向配置保留在参数副本；范围单位来自 GameData 配置。
extends RefCounted
class_name SkillRangeUnit


## 作用：读取 GameData 技能系统配置中每个范围单位对应的像素数。
## 使用：由本文件 resolve_pixels 调用。
static func get_range_unit_px() -> float:
	return float(GameData.get_skill_system_config()["range_unit_px"])


## 作用：把范围单位数乘以统一像素单位，返回像素距离。
## 使用：由本文件 display_radius/_resolve_unit_field 调用。
static func resolve_pixels(value: Variant) -> float:
	return float(value) * get_range_unit_px()


## 作用：深拷贝动作参数，逐项补齐 _r 范围字段对应的像素字段，不覆盖已有像素值。
## 使用：params 为动作或状态参数。
static func resolve_action_params(params: Dictionary) -> Dictionary:
	var resolved: Dictionary = params.duplicate(true)
	_resolve_unit_field(resolved, "radius_r", "radius")
	_resolve_unit_field(resolved, "collision_radius_r", "collision_radius")
	_resolve_unit_field(resolved, "area_radius_r", "area_radius")
	_resolve_unit_field(resolved, "range_r", "range")
	_resolve_unit_field(resolved, "detect_range_r", "detect_range")
	_resolve_unit_field(resolved, "cluster_radius_r", "cluster_radius")
	_resolve_unit_field(resolved, "length_r", "length")
	_resolve_unit_field(resolved, "width_r", "width")
	_resolve_unit_field(resolved, "pull_radius_r", "radius")
	_resolve_unit_field(resolved, "spawn_offset_r", "spawn_offset")
	_resolve_unit_field(resolved, "position_offset_distance_r", "position_offset_distance")
	_resolve_unit_field(resolved, "orbit_radius_r", "orbit_radius")
	_resolve_unit_field(resolved, "pulse_radius_r", "pulse_radius")
	_resolve_unit_field(resolved, "attack_range_r", "attack_range")
	_resolve_unit_field(resolved, "expand_from_radius_r", "expand_from_radius")
	_resolve_unit_field(resolved, "expand_to_radius_r", "expand_to_radius")
	return resolved


## 作用：优先把展示字段的 _r 值转成像素，否则读取已有像素值。
## 使用：动作分派前调用 resolve_action_params，数值和方向配置保留在参数副本；范围单位来自 GameData 配置。
static func display_radius(effect: Dictionary, key: String = "radius") -> float:
	if effect.has("%s_r" % key):
		return resolve_pixels(effect.get("%s_r" % key))
	if key == "radius" and effect.has("radius_r"):
		return resolve_pixels(effect.get("radius_r"))
	return float(effect.get(key, 0.0))


## 作用：仅在源范围单位字段存在且目标像素字段缺失时补入换算值。
## 使用：params 为动作或状态参数；source_key 为来源冷却身份。
static func _resolve_unit_field(params: Dictionary, source_key: String, target_key: String) -> void:
	if not params.has(source_key):
		return
	if params.has(target_key):
		return
	params[target_key] = resolve_pixels(params[source_key])
