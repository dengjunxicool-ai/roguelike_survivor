## 文件用途：封装计算后的整数伤害、原始值、倍率、暴击、类型和完整阶段追踪。
## 使用方式：DamageSystem.calculate 返回此对象；应用阶段通过 to_dictionary 获取显式事件视图。
extends RefCounted
class_name DamageResult


const DamageTraceScript: Script = preload("res://scripts/combat/damage_trace.gd")

var amount: int = 0
var raw_amount: float = 0.0
var multiplier: float = 1.0
var is_critical: bool = false
var damage_origin: StringName = &""
var damage_type: StringName = &""
var element: StringName = &""
var trace: RefCounted = DamageTraceScript.create()


## 作用：从伤害来源与公式终值建立结果并深复制追踪。
## 使用：packet_source 支持字典、包或上下文；final_amount 是已取整结果。
static func make(packet_source: Variant, final_amount: int, critical: bool, raw_damage: float, damage_multiplier: float, stage_values: Dictionary) -> RefCounted:
	var result: RefCounted = new()
	result.amount = final_amount
	result.raw_amount = raw_damage
	result.multiplier = damage_multiplier
	result.is_critical = critical
	result.damage_origin = StringName(String(_packet_value(packet_source, "damage_origin", "")))
	result.damage_type = StringName(String(_packet_value(packet_source, "damage_type", "")))
	result.element = StringName(String(_packet_value(packet_source, "element", "")))
	result.trace = DamageTraceScript.create(stage_values)
	return result


## 作用：用计算上下文作为字段来源创建结果。
## 使用：参数为计算终值与阶段字典，不应用目标生命变化。
static func make_for_context(calculation_context: RefCounted, final_amount: int, critical: bool, raw_damage: float, damage_multiplier: float, stage_values: Dictionary) -> RefCounted:
	return make(calculation_context, final_amount, critical, raw_damage, damage_multiplier, stage_values)


## 作用：从结果字典恢复伤害量、类型和追踪对象。
## 使用：trace 字段优先，缺失时使用 stages。
static func from_dictionary(value: Dictionary) -> RefCounted:
	var result: RefCounted = new()
	result.amount = int(value.get("amount", 0))
	result.raw_amount = float(value.get("raw_amount", 0.0))
	result.multiplier = float(value.get("multiplier", 1.0))
	result.is_critical = bool(value.get("is_critical", false))
	result.damage_origin = StringName(String(value.get("damage_origin", "")))
	result.damage_type = StringName(String(value.get("damage_type", "")))
	result.element = StringName(String(value.get("element", "")))
	result.trace = DamageTraceScript.create(value.get("trace", value.get("stages", {})))
	return result


## 作用：导出伤害量、倍率、类型及彼此独立的 stages/trace 字典。
## 使用：应用、统计和展示使用该显式视图，不修改结果对象。
func to_dictionary() -> Dictionary:
	var trace_dictionary: Dictionary = trace.call("to_dictionary") if trace != null else {}
	return {
		"amount": amount,
		"raw_amount": raw_amount,
		"multiplier": multiplier,
		"is_critical": is_critical,
		"damage_origin": damage_origin,
		"damage_type": damage_type,
		"element": element,
		"stages": trace_dictionary.duplicate(true),
		"trace": trace_dictionary
	}


## 作用：读取字典、DamagePacket 或计算上下文中的伤害字段。
## 使用：key 指定字段；不支持的输入类型返回 fallback。
static func _packet_value(packet_source: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).get(key, fallback)
	if packet_source is DamageCalculationContext:
		return packet_source.packet_value(key, fallback)
	if packet_source is DamagePacket:
		return packet_source.get_value(key, fallback)
	return fallback
