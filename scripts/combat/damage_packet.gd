extends RefCounted
class_name DamagePacket


const DamageSourceContextScript: Script = preload("res://scripts/combat/damage_source_context.gd")
const DamageSourceContextFactoryScript: Script = preload("res://scripts/combat/damage_source_context_factory.gd")
const DamageFlagsScript: Script = preload("res://scripts/combat/damage_flags.gd")
const DamageScalingScript: Script = preload("res://scripts/combat/damage_scaling.gd")

var raw_amount: float = 0.0
var amount: float = 0.0
var damage_origin: StringName = &"primary_attack"
var damage_type: StringName = &"direct_physical"
var element: StringName = &"physical"
var target_id: String = ""
var reaction_depth: int = 0
var source_context: RefCounted
var flags: RefCounted
var scaling: RefCounted
var special_rule_tags: Array = []
var extras: Dictionary = {}


func _init() -> void:
	_ensure_parts()


static func from_any(value: Variant, legacy_damage_type: Variant = &"", attacker: Node = null, target: Node = null) -> RefCounted:
	if value is RefCounted and value.has_method("to_dictionary"):
		return value
	if value is Dictionary:
		return from_dictionary(value, attacker, target)
	var packet: Dictionary = {
		"raw_amount": float(value),
		"amount": float(value),
		"damage_type": legacy_damage_type
	}
	return from_dictionary(packet, attacker, target)


static func from_dictionary(packet: Dictionary, attacker: Node = null, target: Node = null) -> RefCounted:
	var result: RefCounted = new()
	result.call("sync_from_dictionary", packet, attacker, target)
	return result


func sync_from_dictionary(packet: Dictionary, attacker: Node = null, target: Node = null) -> RefCounted:
	extras = packet.duplicate(true)
	raw_amount = maxf(float(packet.get("raw_amount", packet.get("amount", packet.get("damage", 0.0)))), 0.0)
	amount = maxf(float(packet.get("amount", raw_amount)), 0.0)
	damage_origin = StringName(String(packet.get("damage_origin", damage_origin)))
	damage_type = StringName(String(packet.get("damage_type", damage_type)))
	element = StringName(String(packet.get("element", element)))
	target_id = str(target.get_instance_id()) if target != null else String(packet.get("target_id", ""))
	reaction_depth = maxi(int(packet.get("reaction_depth", 0)), 0)
	source_context = DamageSourceContextFactoryScript.from_packet(packet, attacker)
	flags = DamageFlagsScript.from_dictionary(packet)
	scaling = DamageScalingScript.from_dictionary(packet)
	special_rule_tags = _get_array(packet.get("special_rule_tags", []))
	return self


func has_value(key: Variant) -> bool:
	var field: String = String(key)
	return _is_known_field(field) or extras.has(key) or extras.has(field) or extras.has(StringName(field))


func get_value(key: Variant, fallback: Variant = null) -> Variant:
	_ensure_parts()
	var field: String = String(key)
	match field:
		"raw_amount":
			return raw_amount
		"amount":
			return amount
		"damage_origin":
			return damage_origin
		"damage_type":
			return damage_type
		"element":
			return element
		"target_id":
			return target_id
		"reaction_depth":
			return reaction_depth
		"special_rule_tags":
			return special_rule_tags.duplicate()
		"source_tags":
			return source_context.get("tags").duplicate()
		"source_type", "attacker", "attacker_id", "source_origin_id", "source_skill_id", "source_instance_id", "source_action_id", "source_slot_id", "owner_character_id":
			return source_context.get(field)
		"can_crit", "can_trigger_reaction", "ignore_defense", "ignore_resistance", "ignore_vulnerability", "ignore_min_damage":
			return flags.get(field)
		"uses_character_damage_multiplier", "uses_skill_level_coefficient", "skill_level_coefficient":
			return scaling.get(field)
	if extras.has(key):
		return extras.get(key, fallback)
	if extras.has(field):
		return extras.get(field, fallback)
	var string_name_key: StringName = StringName(field)
	if extras.has(string_name_key):
		return extras.get(string_name_key, fallback)
	return fallback


func set_value(key: Variant, value: Variant) -> void:
	_ensure_parts()
	var field: String = String(key)
	match field:
		"raw_amount":
			raw_amount = maxf(float(value), 0.0)
		"amount":
			amount = maxf(float(value), 0.0)
		"damage_origin":
			damage_origin = StringName(String(value))
		"damage_type":
			damage_type = StringName(String(value))
		"element":
			element = StringName(String(value))
		"target_id":
			target_id = String(value)
		"reaction_depth":
			reaction_depth = maxi(int(value), 0)
		"special_rule_tags":
			special_rule_tags = _get_array(value)
		"source_tags":
			source_context.set("tags", _string_name_array(value))
		"source_type", "source_origin_id", "source_skill_id", "source_action_id", "source_slot_id", "owner_character_id":
			source_context.set(field, StringName(String(value)))
		"attacker":
			source_context.set("attacker", value as Node)
		"attacker_id", "source_instance_id":
			source_context.set(field, String(value))
		"can_crit", "can_trigger_reaction", "ignore_defense", "ignore_resistance", "ignore_vulnerability", "ignore_min_damage":
			flags.set(field, bool(value))
		"uses_character_damage_multiplier", "uses_skill_level_coefficient":
			scaling.set(field, bool(value))
		"skill_level_coefficient":
			scaling.set("skill_level_coefficient", maxf(float(value), 0.0))
		_:
			extras[field] = value


func to_dictionary() -> Dictionary:
	_ensure_parts()
	var result: Dictionary = extras.duplicate(true)
	result["raw_amount"] = raw_amount
	result["amount"] = amount
	result["damage_origin"] = damage_origin
	result["damage_type"] = damage_type
	result["element"] = element
	result["target_id"] = target_id
	result["reaction_depth"] = reaction_depth
	result["special_rule_tags"] = special_rule_tags.duplicate()
	result = source_context.apply_to_dictionary(result)
	result = flags.apply_to_dictionary(result)
	result = scaling.apply_to_dictionary(result)
	return result


func validate() -> Array[String]:
	_ensure_parts()
	var errors: Array[String] = []
	if raw_amount < 0.0:
		errors.append("raw_amount must be non-negative")
	if String(damage_origin) == "":
		errors.append("damage_origin is required")
	if String(damage_type) == "":
		errors.append("damage_type is required")
	if source_context == null or source_context.source_instance_id == "":
		errors.append("source_instance_id is required")
	return errors


func _ensure_parts() -> void:
	if source_context == null:
		source_context = DamageSourceContextScript.from_dictionary({})
	if flags == null:
		flags = DamageFlagsScript.from_dictionary({})
	if scaling == null:
		scaling = DamageScalingScript.from_dictionary({})


static func _is_known_field(field: String) -> bool:
	return [
		"raw_amount",
		"amount",
		"damage_origin",
		"damage_type",
		"element",
		"target_id",
		"reaction_depth",
		"special_rule_tags",
		"source_tags",
		"source_type",
		"attacker",
		"attacker_id",
		"source_origin_id",
		"source_skill_id",
		"source_instance_id",
		"source_action_id",
		"source_slot_id",
		"owner_character_id",
		"can_crit",
		"can_trigger_reaction",
		"ignore_defense",
		"ignore_resistance",
		"ignore_vulnerability",
		"ignore_min_damage",
		"uses_character_damage_multiplier",
		"uses_skill_level_coefficient",
		"skill_level_coefficient"
	].has(field)


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate()
	return []


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			var name: StringName = StringName(String(item))
			if name != &"" and not result.has(name):
				result.append(name)
	return result

