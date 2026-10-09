## 文件用途：实现玩家专用的波次倍率、临时防护、固定护甲、比例减伤和最终取整。
## 使用方式：玩家伤害计算按 incoming、defense、reduction、damage_taken、rounding 顺序调用。
extends RefCounted
class_name DamagePlayerIncomingResolver


const DamageTargetRuntimeModifiersScript: Script = preload("res://scripts/combat/damage_target_runtime_modifiers.gd")

const PLAYER_DEFENSE_REDUCTION_CAP: float = 0.40


## 作用：将波次/阶段倍率、熔岩/圣盾/遗物防护与敌人减攻状态乘到原始入伤。
## 使用：读取双方临时元数据，记录生效系数和 incoming_damage。
static func apply_player_incoming_modifier_stage(calculation_context: RefCounted) -> float:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	var incoming: float = raw_amount
	incoming *= maxf(float(calculation_context.call("packet_value", "wave_damage_multiplier", 1.0)), 0.0)
	incoming *= maxf(float(calculation_context.call("packet_value", "boss_phase_modifier", 1.0)), 0.0)
	var protective_lava_multiplier: float = DamageTargetRuntimeModifiersScript.protective_lava_player_multiplier(calculation_context)
	incoming *= protective_lava_multiplier
	if protective_lava_multiplier != 1.0:
		stages["protective_lava_damage_taken_multiplier"] = protective_lava_multiplier
	var holy_shield_multiplier: float = DamageTargetRuntimeModifiersScript.holy_shield_player_multiplier(calculation_context)
	incoming *= holy_shield_multiplier
	if holy_shield_multiplier != 1.0:
		stages["holy_shield_player_multiplier"] = holy_shield_multiplier
	var cross_relic_multiplier: float = DamageTargetRuntimeModifiersScript.cross_relic_field_player_multiplier(calculation_context)
	incoming *= cross_relic_multiplier
	if cross_relic_multiplier != 1.0:
		stages["cross_relic_field_player_multiplier"] = cross_relic_multiplier
	var toxic_vial_enemy_multiplier: float = DamageTargetRuntimeModifiersScript.toxic_vial_enemy_damage_multiplier(calculation_context)
	incoming *= toxic_vial_enemy_multiplier
	if toxic_vial_enemy_multiplier != 1.0:
		stages["toxic_vial_enemy_damage_multiplier"] = toxic_vial_enemy_multiplier
	var fire_oil_smoke_enemy_multiplier: float = DamageTargetRuntimeModifiersScript.fire_oil_smoke_enemy_damage_multiplier(calculation_context)
	incoming *= fire_oil_smoke_enemy_multiplier
	if fire_oil_smoke_enemy_multiplier != 1.0:
		stages["fire_oil_smoke_enemy_damage_multiplier"] = fire_oil_smoke_enemy_multiplier
	stages["incoming_damage"] = incoming
	return incoming


## 作用：用玩家护甲抵扣入伤，并将抵扣上限限制为入伤40%。
## 使用：incoming 为已应用入伤倍率的值；记录护甲与实际抵扣。
static func apply_player_defense_stage(calculation_context: RefCounted, incoming: float) -> float:
	var target: Node = calculation_context.get("target") as Node
	var stages: Dictionary = calculation_context.get("stages")
	var player_defense: float = maxf(_get_float_property(target, "armor", _get_float_property(target, "defense", 0.0)), 0.0)
	var actual_defense: float = minf(player_defense, incoming * PLAYER_DEFENSE_REDUCTION_CAP)
	var after_defense: float = maxf(incoming - actual_defense, 0.0)
	stages["player_armor"] = player_defense
	stages["actual_defense"] = actual_defense
	stages["after_defense"] = after_defense
	return after_defense


## 作用：按包内玩家比例减伤抵扣防御后值，减伤限制在0至95%。
## 使用：返回浮点结果并写入 after_reduction。
static func apply_player_reduction_stage(calculation_context: RefCounted, after_defense: float) -> float:
	var stages: Dictionary = calculation_context.get("stages")
	var reduction_total: float = clampf(float(calculation_context.call("packet_value", "player_damage_reduction_total", 0.0)), 0.0, 0.95)
	var after_reduction: float = after_defense * (1.0 - reduction_total)
	stages["player_damage_reduction_total"] = reduction_total
	stages["after_reduction"] = after_reduction
	return after_reduction


## 作用：将玩家 damage_taken_multiplier 乘到比例减伤结果。
## 使用：倍率限制为非负，覆盖追踪中的 after_reduction。
static func apply_player_damage_taken_stage(calculation_context: RefCounted, after_reduction: float) -> float:
	var target: Node = calculation_context.get("target") as Node
	var stages: Dictionary = calculation_context.get("stages")
	var damage_taken_multiplier: float = _get_float_property(target, "damage_taken_multiplier", 1.0)
	after_reduction *= maxf(damage_taken_multiplier, 0.0)
	stages["damage_taken_multiplier"] = damage_taken_multiplier
	stages["after_reduction"] = after_reduction
	return after_reduction


## 作用：将正数玩家入伤四舍五入并至少保留1点，非正数返回0。
## 使用：写入 rounded_amount，作为玩家计算最终阶段。
static func apply_player_rounding_stage(calculation_context: RefCounted, after_reduction: float) -> int:
	var stages: Dictionary = calculation_context.get("stages")
	var final_amount: int = 0 if after_reduction <= 0.0 else maxi(roundi(after_reduction), 1)
	stages["rounded_amount"] = final_amount
	return final_amount


## 作用：读取对象属性并转为浮点值，缺失对象或属性时使用默认值。
## 使用：object/property/fallback 指定对象、属性名和缺失值，供伤害或配置计算使用。
static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	var value: Variant = _get_property(object, property, fallback)
	if value == null:
		return fallback
	return float(value)


## 作用：查找对象属性列表中匹配的属性，找不到时返回默认值。
## 使用：用于可选属性访问，避免对没有该属性的对象直接读取。
static func _get_property(object: Object, property: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return object.get(property)
	return fallback
