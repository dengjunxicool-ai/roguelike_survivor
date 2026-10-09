## 文件用途：构建带敌方来源、伤害类型和来源实例信息的 DamagePacket。
## 使用方式：敌方攻击执行前静态调用 build；目标受击只接收严格伤害包。

extends RefCounted
class_name EnemyDamagePacketBuilder


const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")


## 作用：构建含敌人 ID、来源类别、技能、实例和可选目标 ID 的严格 DamagePacket。
## 使用：owner 为攻击敌人，amount 为实际伤害，source_type/source_skill_id 标识动作来源；params 可覆盖来源、伤害类型与元素；交给受击入口使用；返回 DamagePacket 对象/值。
static func build(owner: Node, amount: int, source_type: String, source_skill_id: Variant, params: Dictionary = {}) -> DamagePacket:
	var enemy_id: StringName = StringName(String(owner.get("enemy_id"))) if owner != null else &"enemy"
	var source_id_value: String = String(params.get("source_id", source_id_for(owner, source_type)))
	var skill_id: StringName = StringName(String(source_skill_id))
	var target: Node = params.get("target") as Node
	return DamagePacketBuilderScript.from_enemy_action_object({
		"owner": owner,
		"amount": amount,
		"source_type": source_type,
		"source_id": source_id_value,
		"source_origin_id": enemy_id,
		"source_skill_id": skill_id,
		"source_instance_id": _source_instance_id(owner, source_type, skill_id),
		"target_id": str(target.get_instance_id()) if target != null else "",
		"damage_origin": String(params.get("damage_origin", _default_damage_origin(source_type))),
		"damage_type": StringName(String(params.get("damage_type", _default_damage_type(source_type)))),
		"element": StringName(String(params.get("element", "physical")))
	})


## 作用：根据敌人等阶返回 boss 或 enemy 来源标识。
## 使用：owner 为空时返回 fallback；只把 enemy_rank 为 boss 的节点标为 boss。
static func source_id_for(owner: Node, fallback: String = "enemy") -> String:
	if owner == null:
		return fallback
	var rank: String = String(owner.get_meta("enemy_rank", "normal"))
	return "boss" if rank == "boss" else "enemy"


## 作用：把区域动作默认归为 field，其余默认归为 primary_attack。
## 使用：source_type 为动作来源类别，供 build 缺少显式来源时使用；返回 String 文本/标识。
static func _default_damage_origin(source_type: String) -> String:
	return "field" if source_type == "area" else "primary_attack"


## 作用：把区域动作默认归为 area_direct，其余默认归为 direct_physical。
## 使用：source_type 为动作来源类别，供 build 缺少显式类型时使用；返回 String 文本/标识。
static func _default_damage_type(source_type: String) -> String:
	return "area_direct" if source_type == "area" else "direct_physical"


## 作用：拼接敌人实例 ID、动作类别与技能 ID，形成稳定来源标识。
## 使用：owner 为空时以 enemy 为前缀；返回用于同源归因的字符串。
static func _source_instance_id(owner: Node, source_type: String, source_skill_id: StringName) -> String:
	if owner == null:
		return "enemy:%s:%s" % [source_type, String(source_skill_id)]
	return "%s:%s:%s" % [str(owner.get_instance_id()), source_type, String(source_skill_id)]

