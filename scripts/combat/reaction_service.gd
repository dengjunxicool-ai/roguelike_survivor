## 文件用途：提供元素反应准备、限制检查、登记与产出伤害包的统一门面。
## 使用方式：try_trigger检查通过后先登记，再返回单个反应包数组；失败返回空数组。
extends RefCounted
class_name ReactionService


const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const ReactionDamageBuilderScript: Script = preload("res://scripts/combat/reaction_damage_builder.gd")


## 作用：复制包并规范非负反应深度，缺失触发开关时按来源与深度补充。
## 使用：返回新字典，已有开关不会覆盖。 本入口委托ReactionLimiterScript.prepare_damage_packet执行。
static func prepare_damage_packet(packet: Dictionary) -> Dictionary:
	return ReactionLimiterScript.prepare_damage_packet(packet)


## 作用：检查触发开关、递归深度、来源冷却及次数/目标数量限制。
## 使用：支持字典/包/上下文，返回布尔值；可能清理过期计数但不登记触发。
static func can_trigger(packet: Dictionary, reaction_type: String, target: Node = null) -> bool:
	return ReactionLimiterScript.can_trigger(packet, reaction_type, target)


## 作用：检查触发开关、递归深度、来源冷却及次数/目标数量限制。
## 使用：支持字典/包/上下文，返回布尔值；可能清理过期计数但不登记触发。
static func can_trigger_any(packet_source: Variant, reaction_type: String, target: Node = null) -> bool:
	return ReactionLimiterScript.can_trigger_any(packet_source, reaction_type, target)


## 作用：检查触发开关、递归深度、来源冷却及次数/目标数量限制。
## 使用：支持字典/包/上下文，返回布尔值；可能清理过期计数但不登记触发。
static func can_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node = null) -> bool:
	return ReactionLimiterScript.can_trigger_for_context(calculation_context, reaction_type, target)


## 作用：检查触发开关、递归深度、来源冷却及次数/目标数量限制。
## 使用：支持字典/包/上下文，返回布尔值；可能清理过期计数但不登记触发。
static func can_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node = null) -> bool:
	return ReactionLimiterScript.can_trigger_for_packet_object(packet_object, reaction_type, target)


## 作用：按来源作用域记录触发时间、次数与目标集合。
## 使用：仅在反应确认触发后调用；不会重新检查限制。
static func record_trigger(packet: Dictionary, reaction_type: String, target: Node = null) -> void:
	ReactionLimiterScript.record_trigger(packet, reaction_type, target)


## 作用：按来源作用域记录触发时间、次数与目标集合。
## 使用：仅在反应确认触发后调用；不会重新检查限制。
static func record_trigger_any(packet_source: Variant, reaction_type: String, target: Node = null) -> void:
	ReactionLimiterScript.record_trigger_any(packet_source, reaction_type, target)


## 作用：按来源作用域记录触发时间、次数与目标集合。
## 使用：仅在反应确认触发后调用；不会重新检查限制。
static func record_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node = null) -> void:
	ReactionLimiterScript.record_trigger_for_context(calculation_context, reaction_type, target)


## 作用：按来源作用域记录触发时间、次数与目标集合。
## 使用：仅在反应确认触发后调用；不会重新检查限制。
static func record_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node = null) -> void:
	ReactionLimiterScript.record_trigger_for_packet_object(packet_object, reaction_type, target)


## 作用：从基础字典和反应配置tier生成反应包。
## 使用：不直接应用伤害，amount为反应原始值。
static func make_reaction_packet(base_packet: Dictionary, reaction_type: String, amount: float, element: Variant = &"neutral") -> Dictionary:
	return ReactionDamageBuilderScript.build(base_packet, reaction_type, amount, element, ReactionLimiterScript.reaction_tier(reaction_type))


## 作用：从字典、typed包或上下文生成反应包并读取配置tier。
## 使用：返回规范字典供动作层继续应用。
static func make_reaction_packet_any(packet_source: Variant, reaction_type: String, amount: float, element: Variant = &"neutral") -> Dictionary:
	return ReactionDamageBuilderScript.build_any(packet_source, reaction_type, amount, element, ReactionLimiterScript.reaction_tier(reaction_type))


## 作用：检查限制，成功时登记触发并返回新反应包数组。
## 使用：packet为基础字典，target用于限制计数；失败没有触发登记。
static func try_trigger(packet: Dictionary, reaction_type: String, target: Node, amount: float, element: Variant = &"neutral") -> Array[Dictionary]:
	if not can_trigger(packet, reaction_type, target):
		return []
	record_trigger(packet, reaction_type, target)
	return [make_reaction_packet(packet, reaction_type, amount, element)]


## 作用：对统一来源接口执行限制检查、登记和构包。
## 使用：支持字典/包/上下文，返回空或单项字典数组。
static func try_trigger_any(packet_source: Variant, reaction_type: String, target: Node, amount: float, element: Variant = &"neutral") -> Array[Dictionary]:
	if not can_trigger_any(packet_source, reaction_type, target):
		return []
	record_trigger_any(packet_source, reaction_type, target)
	return [make_reaction_packet_any(packet_source, reaction_type, amount, element)]


## 作用：对统一来源接口执行限制检查、登记和构包。
## 使用：支持字典/包/上下文，返回空或单项字典数组。
static func try_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node, amount: float, element: Variant = &"neutral") -> Array[Dictionary]:
	return try_trigger_any(calculation_context, reaction_type, target, amount, element)


## 作用：对统一来源接口执行限制检查、登记和构包。
## 使用：支持字典/包/上下文，返回空或单项字典数组。
static func try_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node, amount: float, element: Variant = &"neutral") -> Array[Dictionary]:
	return try_trigger_any(packet_object, reaction_type, target, amount, element)
