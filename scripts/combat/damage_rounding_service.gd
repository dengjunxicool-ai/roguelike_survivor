## 文件用途：统一整数伤害取整并以目标/来源/类型/元素隔离DOT小数累计池。
## 使用方式：伤害管线最后调用；目标离场须 clear_target 清理累计余数。
extends RefCounted
class_name DamageRoundingService


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")

static var _fractional_buffers: Dictionary = {}


## 作用：为字典伤害决定普通四舍五入或持续伤害小数累计。
## 使用：非正值返回0；普通正伤害默认至少1点，ignore_min_damage 可取消。
static func resolve(float_damage: float, packet: Dictionary, target: Node) -> int:
	if float_damage <= 0.0:
		return 0

	if _uses_fractional_buffer(packet):
		return _resolve_fractional(float_damage, packet, target)

	var final_damage: int = roundi(float_damage)
	if bool(packet.get("ignore_min_damage", false)):
		return maxi(final_damage, 0)
	return maxi(final_damage, 1)


## 作用：按上下文规则执行普通取整或稳定来源的小数累积。
## 使用：可能更新静态余数池，返回本次真正释放的整数伤害。
static func resolve_for_context(float_damage: float, calculation_context: RefCounted) -> int:
	if float_damage <= 0.0:
		return 0

	if _uses_fractional_buffer_for_context(calculation_context):
		return _resolve_fractional_for_context(float_damage, calculation_context)

	var final_damage: int = roundi(float_damage)
	if bool(calculation_context.call("packet_value", "ignore_min_damage", false)):
		return maxi(final_damage, 0)
	return maxi(final_damage, 1)


## 作用：移除以目标实例ID开头的所有小数余数。
## 使用：目标死亡或释放时调用，空目标无操作。
static func clear_target(target: Node) -> void:
	if target == null:
		return

	var prefix: String = "%s:" % str(target.get_instance_id())
	for key: Variant in _fractional_buffers.keys():
		if String(key).begins_with(prefix):
			_fractional_buffers.erase(key)


## 作用：把本次小数加入隔离余数池，向下取整并保存剩余小数。
## 使用：pool key 由目标、来源、来源类别、类型、元素决定。
static func _resolve_fractional(float_damage: float, packet: Dictionary, target: Node) -> int:
	var key: String = _buffer_key(packet, target)
	var buffered: float = float(_fractional_buffers.get(key, 0.0)) + float_damage
	var final_damage: int = floori(buffered)
	_fractional_buffers[key] = buffered - float(final_damage)
	return final_damage


## 作用：按上下文构造来源键并累计小数后释放整数部分。
## 使用：连续tick必须复用稳定来源ID，否则余数不会合并。
static func _resolve_fractional_for_context(float_damage: float, calculation_context: RefCounted) -> int:
	var key: String = _buffer_key_for_context(calculation_context)
	var buffered: float = float(_fractional_buffers.get(key, 0.0)) + float_damage
	var final_damage: int = floori(buffered)
	_fractional_buffers[key] = buffered - float(final_damage)
	return final_damage


## 作用：查询字典包是否应使用DOT/场地持续tick小数池。
## 使用：ignore_fractional_buffer 优先关闭。
static func _uses_fractional_buffer(packet: Dictionary) -> bool:
	return DamageRuleRegistryScript.uses_fractional_buffer(packet)


## 作用：按忽略开关、状态DOT类型、dot_tick模型或显式开关选择小数池。
## 使用：只决定策略，不更新池。
static func _uses_fractional_buffer_for_context(calculation_context: RefCounted) -> bool:
	if bool(calculation_context.call("packet_value", "ignore_fractional_buffer", false)):
		return false
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", ""))
	var field_damage_model: String = String(calculation_context.call("packet_value", "field_damage_model", ""))
	return damage_type == DamageRuleRegistryScript.TYPE_STATUS_DOT or field_damage_model == "dot_tick" or bool(calculation_context.call("packet_value", "uses_fractional_buffer", false))


## 作用：组合目标、稳定来源、来源类别、伤害类型和元素为余数键。
## 使用：target 为空时使用 no_target；缺失来源逐级回退。
static func _buffer_key(packet: Dictionary, target: Node) -> String:
	var target_key: String = str(target.get_instance_id()) if target != null else "no_target"
	var source_instance_id: String = String(packet.get("source_instance_id", packet.get("source_id", packet.get("source_skill_id", "unknown"))))
	var damage_origin: String = String(packet.get("damage_origin", "unknown"))
	var damage_type: String = String(packet.get("damage_type", "unknown"))
	var element: String = String(packet.get("element", "neutral"))
	return "%s:%s:%s:%s:%s" % [target_key, source_instance_id, damage_origin, damage_type, element]


## 作用：从计算上下文组成隔离的余数键。
## 使用：同一目标不同来源/元素独立累计，返回字符串。
static func _buffer_key_for_context(calculation_context: RefCounted) -> String:
	var target: Node = calculation_context.get("target") as Node
	var target_key: String = str(target.get_instance_id()) if target != null else "no_target"
	var source_fallback: Variant = calculation_context.call("packet_value", "source_id", calculation_context.call("packet_value", "source_skill_id", "unknown"))
	var source_instance_id: String = String(calculation_context.call("packet_value", "source_instance_id", source_fallback))
	var damage_origin: String = String(calculation_context.call("packet_value", "damage_origin", "unknown"))
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", "unknown"))
	var element: String = String(calculation_context.call("packet_value", "element", "neutral"))
	return "%s:%s:%s:%s:%s" % [target_key, source_instance_id, damage_origin, damage_type, element]
