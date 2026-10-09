## 文件用途：保存一次伤害公式计算的包、目标防御快照、modifier、阶段追踪与结果。
## 使用方式：DamageSystem 准备包后创建；计算阶段共享对象并在结束时保存 DamageResult。
extends RefCounted
class_name DamageCalculationContext


const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const DamageTraceScript: Script = preload("res://scripts/combat/damage_trace.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")

var packet: DamagePacket
var packet_dictionary: Dictionary = {}
var target: Node = null
var target_profile: RefCounted
var attacker: Node = null
var damage_modifiers: Dictionary = {}
var stages: Dictionary = {}
var trace: RefCounted
var raw_amount: float = 0.0
var value: float = 0.0
var critical: bool = false
var final_amount: int = 0
var result: Dictionary = {}
var result_object: DamageResult


## 作用：绑定包、目标与攻击者，解析防御快照和追踪并初始化非负原始值。
## 使用：packet_object 应已校验；目标可空，返回可计算上下文。
static func create(packet_object: DamagePacket, target_node: Node, attacker_node: Node = null) -> RefCounted:
	var context: RefCounted = new()
	context.packet = packet_object
	context.target = target_node
	context.attacker = attacker_node
	context.target_profile = TargetDamageProfileResolverScript.resolve(target_node)
	context.trace = DamageTraceScript.create()
	context.sync_packet_dictionary()
	context.raw_amount = maxf(float(context.packet_dictionary.get("raw_amount", 0.0)), 0.0)
	context.value = context.raw_amount
	return context


## 作用：从当前包重新生成并保存显式字典视图。
## 使用：包修改后需要刷新视图时调用；返回当前快照。
func sync_packet_dictionary() -> Dictionary:
	packet_dictionary = packet.to_dictionary()
	return packet_dictionary

## 作用：返回已缓存的伤害字典视图。
## 使用：不重新序列化，调用者应避免修改共享快照。
func packet_dict() -> Dictionary:
	return packet_dictionary


## 作用：通过 DamagePacket 读取字段。
## 使用：key 与 fallback 语义同包接口，避免计算阶段重新构建字典。
func packet_value(key: Variant, fallback: Variant = null) -> Variant:
	return packet.get_value(key, fallback)

## 作用：通过包接口检查字段是否存在。
## 使用：核心字段一直存在，扩展字段按实际内容判断。
func packet_has(key: Variant) -> bool:
	return packet.has_value(key)

## 作用：同步写入计算阶段字典与 DamageTrace。
## 使用：key 为追踪项名称，stage_value 为中间计算结果。
func set_stage(key: Variant, stage_value: Variant) -> void:
	stages[key] = stage_value
	if trace != null:
		trace.call("set_stage", key, stage_value)


## 作用：复制并保存阶段执行顺序到上下文和 trace。
## 使用：order 用于验证公式顺序，不执行阶段。
func set_stage_order(order: Array) -> void:
	stages["stage_order"] = order.duplicate()
	if trace != null:
		trace.call("set_stage_order", order)


## 作用：保存终值、暴击标记、浮点结果与结果字典。
## 使用：供不同伤害管线结束时统一收尾，返回 output 本身。
func finish(final_damage: int, is_critical: bool, final_value: float, output: Dictionary) -> Dictionary:
	final_amount = final_damage
	critical = is_critical
	value = final_value
	result = output
	return result


## 作用：保存 typed 结果并按其字典字段调用统一收尾。
## 使用：output_object 可空，空时以零值和空字典收尾。
func finish_with_result(output_object: DamageResult) -> Dictionary:
	result_object = output_object
	var output: Dictionary = output_object.to_dictionary() if output_object != null else {}
	return finish(int(output.get("amount", 0)), bool(output.get("is_critical", false)), float(output.get("amount", 0)), output)
