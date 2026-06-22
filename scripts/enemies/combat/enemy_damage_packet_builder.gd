extends RefCounted
class_name EnemyDamagePacketBuilder


const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")


static func build(owner: Node, amount: int, source_type: String, source_skill_id: Variant, params: Dictionary = {}) -> Dictionary:
	var enemy_id: StringName = StringName(String(owner.get("enemy_id"))) if owner != null else &"enemy"
	var source_id_value: String = String(params.get("source_id", source_id_for(owner, source_type)))
	var skill_id: StringName = StringName(String(source_skill_id))
	var target: Node = params.get("target") as Node
	return DamagePacketBuilderScript.from_enemy_action({
		"owner": owner,
		"amount": amount,
		"source_type": source_type,
		"source_id": source_id_value,
		"source_weapon_id": enemy_id,
		"source_skill_id": skill_id,
		"source_instance_id": _source_instance_id(owner, source_type, skill_id),
		"target_id": str(target.get_instance_id()) if target != null else "",
		"damage_origin": String(params.get("damage_origin", _default_damage_origin(source_type))),
		"damage_type": StringName(String(params.get("damage_type", _default_damage_type(source_type)))),
		"element": StringName(String(params.get("element", "physical")))
	})


static func source_id_for(owner: Node, fallback: String = "enemy") -> String:
	if owner == null:
		return fallback
	var rank: String = String(owner.get_meta("enemy_rank", owner.get_meta("enemy_type", "normal")))
	return "boss" if rank == "boss" else "enemy"


static func _default_damage_origin(source_type: String) -> String:
	return "field" if source_type == "area" else "primary_attack"


static func _default_damage_type(source_type: String) -> String:
	return "area_direct" if source_type == "area" else "direct_physical"


static func _source_instance_id(owner: Node, source_type: String, source_skill_id: StringName) -> String:
	if owner == null:
		return "enemy:%s:%s" % [source_type, String(source_skill_id)]
	return "%s:%s:%s" % [str(owner.get_instance_id()), source_type, String(source_skill_id)]
