extends RefCounted
class_name DamagePacketBuilder


const DamageSourceIdentityScript: Script = preload("res://scripts/combat/damage_source_identity.gd")
const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

const TYPE_TRUE_DAMAGE: String = "true_damage"
const TYPE_TRUE_PERCENT_DAMAGE: String = "true_percent_damage"
const TYPE_STATUS_DOT: String = "status_dot"
const TYPE_REACTION_DAMAGE: String = "reaction_damage"
const TYPE_TRAP_DAMAGE: String = "trap_damage"
const TYPE_SUMMON_DAMAGE: String = "summon_damage"


static func from_skill_action(args: Dictionary) -> Dictionary:
	var params: Dictionary = _get_dictionary(args.get("params", {}))
	var context: Dictionary = _get_dictionary(args.get("context", {}))
	var amount: int = maxi(int(args.get("amount", 0)), 0)
	var source_type: String = String(args.get("source_type", "skill"))
	var damage_origin: String = String(args.get("damage_origin", "primary_attack"))
	var damage_type: StringName = StringName(String(args.get("damage_type", &"direct_physical")))
	var element: StringName = StringName(String(args.get("element", &"physical")))
	var caster: Node = context.get("caster") as Node
	var target: Node = context.get("target") as Node
	var skill_id: StringName = StringName(String(context.get("skill_id", params.get("source_id", ""))))
	var source_instance_id: StringName = _resolve_skill_source_instance_id(params, context, skill_id)
	var uses_skill_level: bool = bool(params.get("uses_skill_level_coefficient", damage_origin == "primary_attack"))

	var packet: Dictionary = {
		"raw_amount": amount,
		"amount": amount,
		"damage_origin": damage_origin,
		"damage_type": damage_type,
		"element": element,
		"source_type": source_type,
		"source_origin_id": StringName(String(context.get("source_origin_id", ""))),
		"source_skill_id": skill_id,
		"source_instance_id": source_instance_id,
		"attacker": caster,
		"attacker_id": str(caster.get_instance_id()) if caster != null else "",
		"target_id": str(target.get_instance_id()) if target != null else "",
		"source_id": skill_id,
		"can_crit": bool(params.get("can_crit", _default_can_crit(damage_origin, String(damage_type)))),
		"can_trigger_reaction": bool(params.get("can_trigger_reaction", damage_origin != "reaction")),
		"reaction_depth": int(params.get("reaction_depth", 0)),
		"uses_character_damage_multiplier": bool(params.get("uses_character_damage_multiplier", _default_uses_character_damage(damage_origin, String(damage_type)))),
		"uses_skill_level_coefficient": uses_skill_level,
		"skill_level_coefficient": float(args.get("skill_level_coefficient", 1.0)) if uses_skill_level else 1.0,
		"ignore_defense": bool(params.get("ignore_defense", false)),
		"ignore_resistance": bool(params.get("ignore_resistance", false)),
		"ignore_vulnerability": bool(params.get("ignore_vulnerability", false)),
		"ignore_min_damage": bool(params.get("ignore_min_damage", false)),
		"special_rule_tags": _get_array(params.get("special_rule_tags", []))
	}

	_copy_optional(params, packet, "field_damage_model")
	_copy_optional_float(params, packet, "special_final_modifier")
	_copy_optional_string(params, packet, "special_final_modifier_source")
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return _finalize_packet(packet)


static func from_skill_action_object(args: Dictionary) -> RefCounted:
	return DamagePacketScript.from_dictionary(from_skill_action(args))


static func from_status_dot(args: Dictionary) -> Dictionary:
	var target: Node = args.get("target") as Node
	var status: Dictionary = _get_dictionary(args.get("status", {}))
	var status_id: StringName = StringName(String(args.get("status_id", status.get("id", "status_dot"))))
	var amount: float = maxf(float(args.get("amount", 0.0)), 0.0)
	var element: StringName = StringName(String(args.get("element", args.get("damage_type", status_id))))
	var source_instance_id: String = String(args.get("source_instance_id", ""))
	if source_instance_id == "":
		source_instance_id = DamageSourceIdentityScript.for_status_dot(target, status_id, args.get("applier_source_instance_id", args.get("attacker_id", "")))

	var packet: Dictionary = {
		"raw_amount": amount,
		"amount": amount,
		"damage_origin": "status_dot",
		"damage_type": StringName(String(args.get("damage_type", &"status_dot"))),
		"element": element,
		"source_type": "status",
		"source_id": status_id,
		"source_origin_id": StringName(String(args.get("source_origin_id", ""))),
		"source_skill_id": status_id,
		"source_instance_id": source_instance_id,
		"attacker": args.get("attacker") as Node,
		"attacker_id": String(args.get("attacker_id", "")),
		"target_id": str(target.get_instance_id()) if target != null else String(args.get("target_id", "")),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": bool(args.get("uses_character_damage_multiplier", true)),
		"uses_skill_level_coefficient": false,
		"skill_level_coefficient": 1.0,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"ignore_min_damage": false,
		"ignore_target_class_origin_modifier": bool(args.get("ignore_target_class_origin_modifier", false)),
		"special_rule_tags": _get_array(args.get("special_rule_tags", []))
	}
	packet = DamageTraceContextScript.apply_to_packet(packet, args)
	return _finalize_packet(packet)


static func from_status_dot_object(args: Dictionary) -> RefCounted:
	return DamagePacketScript.from_dictionary(from_status_dot(args))


static func from_reaction(args: Dictionary) -> Dictionary:
	var base_packet: Dictionary = _get_dictionary(args.get("base_packet", {})).duplicate(true)
	var reaction_type: String = String(args.get("reaction_type", "reaction"))
	var amount: float = maxf(float(args.get("amount", 0.0)), 0.0)
	base_packet["raw_amount"] = amount
	base_packet["amount"] = amount
	base_packet["damage_origin"] = "reaction"
	base_packet["damage_type"] = &"reaction_damage"
	base_packet["element"] = StringName(String(args.get("element", &"neutral")))
	base_packet["reaction_type"] = reaction_type
	base_packet["reaction_depth"] = int(args.get("reaction_depth", int(base_packet.get("reaction_depth", 0)) + 1))
	if not base_packet.has("source_origin_id"):
		base_packet["source_origin_id"] = StringName("")
	if not base_packet.has("source_skill_id"):
		base_packet["source_skill_id"] = StringName(String(base_packet.get("source_id", reaction_type)))
	base_packet["source_instance_id"] = DamageSourceIdentityScript.for_reaction(
		base_packet.get("source_instance_id", base_packet.get("source_skill_id", reaction_type)),
		reaction_type,
		int(base_packet.get("reaction_depth", 1))
	)
	base_packet["can_crit"] = false
	base_packet["can_trigger_reaction"] = false
	base_packet["uses_skill_level_coefficient"] = false
	base_packet["skill_level_coefficient"] = 1.0
	base_packet["reaction_tier"] = String(args.get("reaction_tier", "normal"))
	base_packet["special_rule_tags"] = _merge_tags(base_packet.get("special_rule_tags", []), ["system_reaction"])
	if not base_packet.has("ignore_min_damage"):
		base_packet["ignore_min_damage"] = false
	base_packet = DamageTraceContextScript.apply_to_packet(base_packet, args)
	return _finalize_packet(base_packet)


static func from_reaction_object(args: Dictionary) -> RefCounted:
	return DamagePacketScript.from_dictionary(from_reaction(args))


static func from_enemy_action(args: Dictionary) -> Dictionary:
	var owner: Node = args.get("owner") as Node
	var amount: int = maxi(int(args.get("amount", 0)), 0)
	var source_type: String = String(args.get("source_type", "area"))
	var source_skill_id: String = String(args.get("source_skill_id", "enemy_area"))
	var source_id: String = String(args.get("source_id", _get_enemy_source_id(owner)))
	var source_instance_id: String = String(args.get("source_instance_id", ""))
	if source_instance_id == "" and owner != null:
		source_instance_id = "%s:%s" % [str(owner.get_instance_id()), source_type]
	if source_instance_id == "":
		source_instance_id = "enemy:%s" % source_type

	return _finalize_packet({
		"raw_amount": amount,
		"amount": amount,
		"damage_origin": String(args.get("damage_origin", "field")),
		"damage_type": StringName(String(args.get("damage_type", &"area_direct"))),
		"element": StringName(String(args.get("element", &"physical"))),
		"source_type": source_type,
		"source_id": source_id,
		"source_origin_id": StringName(String(args.get("source_origin_id", owner.get("enemy_id") if owner != null else "enemy"))),
		"source_skill_id": source_skill_id,
		"source_instance_id": source_instance_id,
		"attacker": owner,
		"attacker_id": str(owner.get_instance_id()) if owner != null else "",
		"target_id": String(args.get("target_id", "")),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"skill_level_coefficient": 1.0,
		"ignore_defense": bool(args.get("ignore_defense", false)),
		"ignore_resistance": bool(args.get("ignore_resistance", false)),
		"ignore_vulnerability": bool(args.get("ignore_vulnerability", false)),
		"ignore_min_damage": bool(args.get("ignore_min_damage", false)),
		"special_rule_tags": _get_array(args.get("special_rule_tags", []))
	})


static func from_enemy_action_object(args: Dictionary) -> RefCounted:
	return DamagePacketScript.from_dictionary(from_enemy_action(args))


static func from_special_rule(args: Dictionary) -> Dictionary:
	var source_id: String = String(args.get("source_id", "special_rule"))
	var amount: int = maxi(int(args.get("amount", 0)), 0)
	var origin: String = String(args.get("damage_origin", "special"))
	var packet: Dictionary = {
		"raw_amount": amount,
		"amount": amount,
		"damage_origin": origin,
		"damage_type": StringName(String(args.get("damage_type", &"area_direct" if origin != "special" else &"true_damage"))),
		"element": StringName(String(args.get("element", &"fire"))),
		"source_id": source_id,
		"source_origin_id": StringName(String(args.get("source_origin_id", ""))),
		"source_skill_id": StringName(String(args.get("source_skill_id", source_id))),
		"source_instance_id": String(args.get("source_instance_id", "%s:%d" % [source_id, Time.get_ticks_msec()])),
		"attacker": args.get("attacker") as Node,
		"attacker_id": String(args.get("attacker_id", "")),
		"target_id": String(args.get("target_id", "")),
		"can_crit": bool(args.get("can_crit", false)),
		"can_trigger_reaction": false,
		"reaction_depth": int(args.get("reaction_depth", 0)),
		"uses_character_damage_multiplier": bool(args.get("uses_character_damage_multiplier", origin == "primary_attack")),
		"uses_skill_level_coefficient": false,
		"skill_level_coefficient": 1.0,
		"ignore_defense": bool(args.get("ignore_defense", origin == "special")),
		"ignore_resistance": bool(args.get("ignore_resistance", origin == "special")),
		"ignore_vulnerability": bool(args.get("ignore_vulnerability", origin == "special")),
		"ignore_min_damage": bool(args.get("ignore_min_damage", false)),
		"special_rule_tags": _get_array(args.get("special_rule_tags", ["fireball_special_rule"]))
	}
	packet = DamageTraceContextScript.apply_to_packet(packet, args)
	return _finalize_packet(packet)


static func from_special_rule_object(args: Dictionary) -> RefCounted:
	return DamagePacketScript.from_dictionary(from_special_rule(args))


static func from_combat_object_hit(args: Dictionary) -> Dictionary:
	var template: Dictionary = _get_dictionary(args.get("template", {})).duplicate(true)
	var target: Node = args.get("target") as Node
	var owner: Node = args.get("owner") as Node
	var amount: int = maxi(int(args.get("amount", 0)), 0)
	var source_type: String = String(args.get("source_type", "combat_object"))
	var source_id: String = String(args.get("source_id", ""))
	var default_origin: String = String(args.get("default_damage_origin", _default_combat_object_origin(source_type)))
	var default_type: StringName = _normalize_combat_object_damage_type(args.get("default_damage_type", &""))

	if not template.has("raw_amount"):
		template["raw_amount"] = amount
	if bool(args.get("overwrite_amount", true)) or not template.has("amount"):
		template["amount"] = amount
	if not template.has("damage_origin"):
		template["damage_origin"] = default_origin
	if not template.has("damage_type"):
		template["damage_type"] = default_type
	if not template.has("element"):
		template["element"] = StringName(String(args.get("default_element", &"physical")))
	if not template.has("source_type"):
		template["source_type"] = source_type
	if not template.has("source_id") and source_id != "":
		template["source_id"] = source_id
	if not template.has("source_origin_id"):
		template["source_origin_id"] = StringName(String(args.get("source_origin_id", "")))
	if not template.has("source_skill_id"):
		template["source_skill_id"] = StringName(String(args.get("source_skill_id", source_id)))
	if not template.has("source_instance_id"):
		template["source_instance_id"] = String(args.get("source_instance_id", ""))
	if String(template.get("source_instance_id", "")) == "":
		template["source_instance_id"] = str(args.get("instance_id", "combat_object"))
	if target != null:
		template["target_id"] = str(target.get_instance_id())
	elif not template.has("target_id"):
		template["target_id"] = ""
	if owner != null and not template.has("attacker"):
		template["attacker"] = owner
	if not template.has("attacker_id"):
		template["attacker_id"] = str(owner.get_instance_id()) if owner != null else ""
	if not template.has("can_crit"):
		template["can_crit"] = bool(args.get("can_crit", _default_can_crit(String(template.get("damage_origin", default_origin)), String(template.get("damage_type", default_type)))))
	if not template.has("can_trigger_reaction"):
		template["can_trigger_reaction"] = bool(args.get("can_trigger_reaction", String(template.get("damage_origin", default_origin)) != "reaction"))
	if not template.has("reaction_depth"):
		template["reaction_depth"] = int(args.get("reaction_depth", 0))
	if not template.has("uses_character_damage_multiplier"):
		template["uses_character_damage_multiplier"] = bool(args.get("uses_character_damage_multiplier", _default_uses_character_damage(String(template.get("damage_origin", default_origin)), String(template.get("damage_type", default_type)))))
	if not template.has("uses_skill_level_coefficient"):
		template["uses_skill_level_coefficient"] = bool(args.get("uses_skill_level_coefficient", String(template.get("damage_origin", default_origin)) == "primary_attack"))
	if not template.has("skill_level_coefficient"):
		template["skill_level_coefficient"] = float(args.get("skill_level_coefficient", 1.0))
	if not template.has("ignore_defense"):
		template["ignore_defense"] = bool(args.get("ignore_defense", false))
	if not template.has("ignore_resistance"):
		template["ignore_resistance"] = bool(args.get("ignore_resistance", false))
	if not template.has("ignore_vulnerability"):
		template["ignore_vulnerability"] = bool(args.get("ignore_vulnerability", false))
	if not template.has("ignore_min_damage"):
		template["ignore_min_damage"] = bool(args.get("ignore_min_damage", false))
	if not template.has("special_rule_tags"):
		template["special_rule_tags"] = []
	template = DamageTraceContextScript.apply_to_packet(template, args)
	return _finalize_packet(template)


static func from_combat_object_hit_object(args: Dictionary) -> RefCounted:
	return DamagePacketScript.from_dictionary(from_combat_object_hit(args))


static func _finalize_packet(packet: Dictionary) -> Dictionary:
	return _build_packet(packet).call("to_dictionary")


static func _build_packet(packet: Dictionary) -> RefCounted:
	return DamagePacketScript.from_dictionary(packet)


static func _resolve_skill_source_instance_id(params: Dictionary, context: Dictionary, skill_id: StringName) -> StringName:
	return StringName(String(params.get("source_instance_id", context.get("source_instance_id", params.get("projectile_id", params.get("area_id", params.get("object_id", skill_id)))))))


static func _default_can_crit(damage_origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_can_crit(damage_origin, damage_type)


static func _default_uses_character_damage(damage_origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_uses_character_damage(damage_origin, damage_type)


static func _copy_optional(source: Dictionary, target: Dictionary, key: String) -> void:
	if source.has(key):
		target[key] = source[key]


static func _copy_optional_float(source: Dictionary, target: Dictionary, key: String) -> void:
	if source.has(key):
		target[key] = float(source[key])


static func _copy_optional_string(source: Dictionary, target: Dictionary, key: String) -> void:
	if source.has(key):
		target[key] = String(source[key])


static func _merge_tags(value: Variant, extra_tags: Array[String]) -> Array:
	var tags: Array = []
	if value is Array:
		tags = (value as Array).duplicate()
	for tag: String in extra_tags:
		if not tags.has(tag) and not tags.has(StringName(tag)):
			tags.append(tag)
	return tags


static func _get_enemy_source_id(owner: Node) -> String:
	if owner == null:
		return "enemy"
	var rank: String = String(owner.get_meta("enemy_rank", owner.get_meta("enemy_type", "normal")))
	return "boss" if rank == "boss" else "enemy"


static func _default_combat_object_origin(source_type: String) -> String:
	return DamageRuleRegistryScript.default_combat_object_origin(source_type)


static func _normalize_combat_object_damage_type(value: Variant) -> StringName:
	return DamageRuleRegistryScript.normalize_combat_object_damage_type(value)


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
