## 文件用途：从包创建来源对象并用显式攻击者补缺失身份。
## 使用方式：DamagePacket.sync_from_dictionary 调用；显式攻击者不会覆盖包已有引用或ID。
extends RefCounted
class_name DamageSourceContextFactory


const DamageSourceContextScript: Script = preload("res://scripts/combat/damage_source_context.gd")


## 作用：解析来源后仅补空的 attacker 与 attacker_id。
## 使用：attacker 可空；已有来源信息保持优先，返回来源对象。
static func from_packet(packet: Dictionary, attacker: Node = null) -> RefCounted:
	var source_context: RefCounted = DamageSourceContextScript.from_dictionary(packet)
	if attacker != null and source_context.get("attacker") == null:
		source_context.set("attacker", attacker)
	if attacker != null and String(source_context.get("attacker_id")) == "":
		source_context.set("attacker_id", str(attacker.get_instance_id()))
	return source_context
