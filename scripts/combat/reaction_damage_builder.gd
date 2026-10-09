## 文件用途：把基础包转换为保留来源追踪、禁止递归的新反应包。
## 使用方式：build用于字典基础包，build_any接受typed包或计算上下文。
extends RefCounted
class_name ReactionDamageBuilder


const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")


## 作用：把基础包、反应名、伤害量、元素和tier交给统一反应构建器。
## 使用：返回字典，保留来源但派生新实例ID并增加深度。
static func build(base_packet: Dictionary, reaction_type: String, amount: float, element: Variant = &"neutral", reaction_tier: String = "normal") -> Dictionary:
	return DamagePacketBuilderScript.from_reaction({
		"base_packet": base_packet,
		"reaction_type": reaction_type,
		"amount": amount,
		"element": element,
		"reaction_tier": reaction_tier
	})


## 作用：先取得支持来源的字典视图再构建反应包。
## 使用：支持Dictionary、DamagePacket、DamageCalculationContext。
static func build_any(packet_source: Variant, reaction_type: String, amount: float, element: Variant = &"neutral", reaction_tier: String = "normal") -> Dictionary:
	return build(_packet_dictionary(packet_source), reaction_type, amount, element, reaction_tier)


## 作用：将支持的伤害来源转换为字典视图。
## 使用：接受字典、DamagePacket 或 DamageCalculationContext；不支持类型返回空字典。
static func _packet_dictionary(packet_source: Variant) -> Dictionary:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).duplicate(true)
	if packet_source is DamageCalculationContext:
		return packet_source.packet_dict()
	if packet_source is DamagePacket:
		return packet_source.to_dictionary()
	return {}
