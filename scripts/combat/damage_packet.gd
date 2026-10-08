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
var source_context: DamageSourceContext
var flags: DamageFlags
var scaling: DamageScaling
var special_rule_tags: Array = []
var extras: Dictionary = {}
var _input_errors: Array[String] = []


func _init() -> void:
	_ensure_parts()


func clone() -> DamagePacket:
	var copy: DamagePacket = from_dictionary(to_dictionary())
	copy._input_errors = _input_errors.duplicate()
	return copy




static func from_dictionary(packet: Dictionary, attacker: Node = null, target: Node = null) -> DamagePacket:
	var result: DamagePacket = new()
	result.call("sync_from_dictionary", packet, attacker, target)
	return result


func sync_from_dictionary(packet: Dictionary, attacker: Node = null, target: Node = null) -> DamagePacket:
	_input_errors = _validate_input_fields(packet)
	extras = {}
	for key: Variant in packet:
		if not _is_known_field(String(key)):
			extras[String(key)] = packet[key]
	raw_amount = float(packet.get("raw_amount", 0.0))
	amount = float(packet.get("amount", raw_amount))
	damage_origin = StringName(String(packet.get("damage_origin", damage_origin)))
	damage_type = StringName(String(packet.get("damage_type", damage_type)))
	element = StringName(String(packet.get("element", element)))
	target_id = str(target.get_instance_id()) if target != null else String(packet.get("target_id", ""))
	reaction_depth = int(packet.get("reaction_depth", 0))
	source_context = DamageSourceContextFactoryScript.from_packet(packet, attacker)
	var defaults: Dictionary = packet.duplicate(true)
	var origin: String = String(damage_origin)
	var kind: String = String(damage_type)
	for key: String in ["can_crit", "ignore_defense", "ignore_resistance", "ignore_vulnerability"]:
		if not defaults.has(key):
			defaults[key] = DamageRuleRegistry.default_can_crit(origin, kind) if key == "can_crit" else _default_ignore(key, kind)
	if not defaults.has("can_trigger_reaction"):
		defaults["can_trigger_reaction"] = origin != "reaction" and reaction_depth == 0
	if not defaults.has("uses_character_damage_multiplier"):
		defaults["uses_character_damage_multiplier"] = DamageRuleRegistry.default_uses_character_damage(origin, kind)
	if not defaults.has("uses_skill_level_coefficient"):
		defaults["uses_skill_level_coefficient"] = DamageRuleRegistry.default_uses_skill_level(origin)
	flags = DamageFlagsScript.from_dictionary(defaults)
	scaling = DamageScalingScript.from_dictionary(defaults)
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
			raw_amount = float(value)
		"amount":
			amount = float(value)
		"damage_origin":
			damage_origin = StringName(String(value))
		"damage_type":
			damage_type = StringName(String(value))
		"element":
			element = StringName(String(value))
		"target_id":
			target_id = String(value)
		"reaction_depth":
			reaction_depth = int(value)
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
			scaling.skill_level_coefficient = float(value)
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
	var errors: Array[String] = _input_errors.duplicate()
	errors.append_array(DamagePacketExtensionRegistry.validate(extras))
	if not is_finite(raw_amount) or raw_amount < 0.0:
		errors.append("raw_amount must be finite and non-negative")
	if not is_finite(amount) or amount < 0.0:
		errors.append("amount must be finite and non-negative")
	if not is_finite(scaling.skill_level_coefficient) or scaling.skill_level_coefficient < 0.0:
		errors.append("skill_level_coefficient must be finite and non-negative")
	if reaction_depth < 0:
		errors.append("reaction_depth must be non-negative")
	if not DamageRuleRegistry.ALLOWED_ORIGINS.has(String(damage_origin)):
		errors.append("damage_origin must be registered")
	if not DamageRuleRegistry.ALLOWED_DAMAGE_TYPES.has(String(damage_type)):
		errors.append("damage_type must be registered")
	if not DamageRuleRegistry.is_element(String(element)):
		errors.append("element must be registered")
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



static func _default_ignore(key: String, kind: String) -> bool:
	match key:
		"ignore_defense": return DamageRuleRegistry.default_ignore_defense(kind)
		"ignore_resistance": return DamageRuleRegistry.default_ignore_resistance(kind)
		"ignore_vulnerability": return DamageRuleRegistry.default_ignore_vulnerability(kind)
	return false


static func _validate_input_fields(packet: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not packet.has("raw_amount"):
		errors.append("raw_amount is required")
	for key: Variant in packet:
		var field: String = String(key)
		var value: Variant = packet[key]
		if field in ["raw_amount", "amount", "skill_level_coefficient"]:
			if not (value is int or value is float) or not is_finite(float(value)):
				errors.append("%s must be a finite number" % field)
		elif field in ["reaction_depth"]:
			if not value is int or int(value) < 0:
				errors.append("reaction_depth must be a non-negative int")
		elif field in ["can_crit", "can_trigger_reaction", "ignore_defense", "ignore_resistance", "ignore_vulnerability", "ignore_min_damage", "uses_character_damage_multiplier", "uses_skill_level_coefficient"]:
			if not value is bool:
				errors.append("%s must be bool" % field)
		elif field in ["special_rule_tags", "source_tags"]:
			if not value is Array:
				errors.append("%s must be an Array" % field)
	return errors
