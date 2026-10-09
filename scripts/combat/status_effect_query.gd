## 文件用途：对状态运行字典提供存在、层数、快照、移动和易伤的纯查询。
## 使用方式：StatusEffectManager委托查询；packet参数区分能触发下一次承伤/满层爆炸易伤的伤害。
extends RefCounted
class_name StatusEffectQuery

const StatusEffectTickHelperScript: Script = preload("res://scripts/combat/status_effect_tick_helper.gd")


## 作用：将状态ID规范为StringName并检查状态字典中存在。
## 使用：只查键，不判断剩余时间；过期移除由管理器处理。
static func has_status(statuses: Dictionary, status_id: Variant) -> bool:
	return statuses.has(StringName(str(status_id)))


## 作用：读取已存在状态的stacks，缺失返回0。
## 使用：statuses为运行状态表。
static func get_status_stack(statuses: Dictionary, status_id: Variant) -> int:
	var id: StringName = StringName(str(status_id))
	if not statuses.has(id):
		return 0
	var status: Dictionary = _get_dictionary(statuses[id])
	return int(status.get("stacks", 0))


## 作用：导出各状态ID、层数、时长、tick和元素信息。
## 使用：返回新数组与简化字典，tick_damage_total包含叠层及Power效果。
static func get_status_snapshot(statuses: Dictionary) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for status_variant: Variant in statuses.values():
		if not (status_variant is Dictionary):
			continue
		var status: Dictionary = status_variant
		snapshot.append({
			"id": StringName(str(status.get("id", ""))),
			"stacks": int(status.get("stacks", 0)),
			"duration_remaining": float(status.get("duration_remaining", 0.0)),
			"tick_interval": float(status.get("tick_interval", 0.0)),
			"tick_damage": float(status.get("tick_damage", 0.0)),
			"tick_damage_total": StatusEffectTickHelperScript.tick_damage_total(status),
			"damage_type": StringName(str(status.get("damage_type", ""))),
			"element": StringName(str(status.get("element", "")))
		})
	return snapshot


## 作用：合并状态固定减速和每层减速，非指定锁定状态可直接令速度为0。
## 使用：Boss/精英减速上限35%，普通60%，正常倍率最少0.05。
static func movement_speed_multiplier(statuses: Dictionary, movement_lock_status_ids: Array[StringName], is_boss: bool, is_elite: bool) -> float:
	var slow_percent: float = 0.0
	for id_variant: Variant in statuses.keys():
		var status: Dictionary = _get_dictionary(statuses[id_variant])
		var definition: Dictionary = _get_dictionary(status.get("definition", {}))
		var stacks: int = maxi(int(status.get("stacks", 1)), 1)
		if _get_effect_bool(definition, "locks_movement", false) and not movement_lock_status_ids.has(StringName(str(id_variant))):
			return 0.0
		slow_percent += float(status.get("slow_percent", 0.0))
		slow_percent += _get_effect_value(definition, "move_slow_per_stack", 0.0) * float(stacks)

	var max_slow: float = 0.60
	if is_boss:
		max_slow = 0.30
	elif is_elite:
		max_slow = 0.35

	return maxf(1.0 - clampf(slow_percent, 0.0, max_slow), 0.05)


## 作用：合并通用、元素、类型、破甲、下一击和满层爆炸易伤并按阶级裁剪。
## 使用：只查询加成；不会实际消费下一击状态。
static func vulnerability_total(statuses: Dictionary, damage_type: Variant = &"", category: Variant = &"", packet: Variant = {}, is_boss: bool = false, is_elite: bool = false) -> float:
	var type_name: String = str(damage_type)
	var category_name: String = str(category)
	var multiplier_add: float = 0.0
	for status_variant: Variant in statuses.values():
		var status: Dictionary = _get_dictionary(status_variant)
		var definition: Dictionary = _get_dictionary(status.get("definition", {}))
		var stacks: float = float(maxi(int(status.get("stacks", 1)), 1))
		var effect: Dictionary = _get_dictionary(definition.get("effect", {}))

		multiplier_add += float(effect.get("all_damage_taken_multiplier_add_per_stack", 0.0)) * stacks
		multiplier_add += float(effect.get("%s_damage_taken_multiplier_add_per_stack" % type_name, 0.0)) * stacks
		multiplier_add += float(status.get("all_damage_taken_multiplier_add_per_stack", 0.0)) * stacks
		multiplier_add += float(status.get("%s_damage_taken_multiplier_add_per_stack" % type_name, 0.0)) * stacks
		if category_name != "":
			multiplier_add += float(effect.get("%s_damage_taken_multiplier_add_per_stack" % category_name, 0.0)) * stacks
			multiplier_add += float(status.get("%s_damage_taken_multiplier_add_per_stack" % category_name, 0.0)) * stacks
		if type_name == "physical" or category_name == "direct_physical":
			multiplier_add += float(status.get("armor_break_multiplier_add", 0.0)) * stacks
		if effect.has("next_damage_taken_multiplier_add") and can_consume_next_damage_taken(packet):
			multiplier_add += float(effect.get("next_damage_taken_multiplier_add", 0.0))
		if is_full_stack_explosion_vulnerability_active(status, packet):
			multiplier_add += float(status.get("full_stack_explosion_damage_taken_multiplier_add", 0.0))

	var cap_add: float = 0.30
	var floor_value: float = -0.60
	if is_boss:
		cap_add = 0.15
		floor_value = -0.50
	elif is_elite:
		cap_add = 0.20
	return clampf(multiplier_add, floor_value, cap_add)


## 作用：判断伤害是否可使用下一击承伤加成，排除DOT、场地与minor反应。
## 使用：空字典视为允许，支持typed包和上下文。
static func can_consume_next_damage_taken(packet: Variant) -> bool:
	if packet is Dictionary and (packet as Dictionary).is_empty():
		return true
	var damage_type: String = str(damage_packet_value(packet, "damage_type", ""))
	var damage_origin: String = str(damage_packet_value(packet, "damage_origin", ""))
	if damage_type == "status_dot" or damage_origin == "field":
		return false
	if damage_origin == "reaction" and str(damage_packet_value(packet, "reaction_tier", "minor")) == "minor":
		return false
	return true


## 作用：检查满层阈值与反应/爆炸来源是否同时符合。
## 使用：status含required_stacks与加成，返回布尔值。
static func is_full_stack_explosion_vulnerability_active(status: Dictionary, packet: Variant) -> bool:
	if not status.has("full_stack_explosion_damage_taken_multiplier_add"):
		return false
	var required_stacks: int = maxi(int(status.get("full_stack_required_stacks", status.get("stacks", 1))), 1)
	if int(status.get("stacks", 0)) < required_stacks:
		return false
	var damage_origin: String = str(damage_packet_value(packet, "damage_origin", ""))
	var damage_type: String = str(damage_packet_value(packet, "damage_type", ""))
	var source_type: String = str(damage_packet_value(packet, "source_type", ""))
	return damage_origin == "reaction" or damage_type == "reaction_damage" or source_type == "explosion"


## 作用：读取字典、包或上下文的伤害字段。
## 使用：不支持类型返回fallback。
static func damage_packet_value(packet: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet is Dictionary:
		return (packet as Dictionary).get(key, fallback)
	if packet is DamageCalculationContext:
		return packet.packet_value(key, fallback)
	if packet is DamagePacket:
		return packet.get_value(key, fallback)
	return fallback


## 作用：读取状态定义 effect 下的浮点参数。
## 使用：key 为效果字段，字段缺失或 effect 非字典时返回 fallback。
static func _get_effect_value(definition: Dictionary, key: String, fallback: float) -> float:
	var effect: Dictionary = _get_dictionary(definition.get("effect", {}))
	return float(effect.get(key, fallback))


## 作用：读取状态定义 effect 下的布尔参数。
## 使用：key 为效果开关，字段缺失时使用 fallback。
static func _get_effect_bool(definition: Dictionary, key: String, fallback: bool) -> bool:
	var effect: Dictionary = _get_dictionary(definition.get("effect", {}))
	return bool(effect.get(key, fallback))


## 作用：读取字典配置，非字典输入返回空字典。
## 使用：value为待检查配置；返回输入字典本身，调用方写入会影响原值。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
