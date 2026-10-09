## 文件用途：从严格伤害包与目标档案构建伤害属性查询。
## 使用方式：make 接收 DamagePacket，可在包未声明 target_type 时用 TargetDamageProfile 补齐；to_modifier_query 返回内部查询。
extends RefCounted
class_name DamageModifierQuery


const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")

var query: ModifierQuery


## 作用：从伤害包创建查询，包未声明目标类型时用目标档案补充。
## 使用：packet 为待修饰伤害包视图。
static func make(packet: DamagePacket, attacker: Node = null, target_profile: TargetDamageProfile = null) -> DamageModifierQuery:
	var result: DamageModifierQuery = new()
	result.query = ModifierQueryScript.for_damage(packet, attacker)
	if result.query.target_type == &"" and target_profile != null:
		result.query.target_type = target_profile.target_type
	return result


## 作用：返回封装的 ModifierQuery 对象给聚合器使用。
## 使用：make 接收 DamagePacket，可在包未声明 target_type 时用 TargetDamageProfile 补齐；to_modifier_query 返回内部查询。
func to_modifier_query() -> ModifierQuery:
	return query


## 作用：读取伤害查询属性，内部查询为空时使用调用方默认值。
## 使用：fallback 为缺值备用结果。
func get_query_value(key: String, fallback: Variant = null) -> Variant:
	if query == null:
		return fallback
	return query.get(key)
