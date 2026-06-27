extends RefCounted
class_name DamagePacketNormalizer


const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const ReactionServiceScript: Script = preload("res://scripts/combat/reaction_service.gd")
const DamagePacketValidatorScript: Script = preload("res://scripts/combat/damage_packet_validator.gd")


static func normalize_to_dictionary(amount_or_packet: Variant, legacy_damage_type: Variant, attacker: Node, target: Node = null) -> Dictionary:
	return normalize_to_packet(amount_or_packet, legacy_damage_type, attacker, target).call("to_dictionary")


static func normalize_to_packet(amount_or_packet: Variant, _legacy_damage_type: Variant, attacker: Node, target: Node = null) -> RefCounted:
	var packet: Dictionary = {}
	if amount_or_packet is RefCounted and amount_or_packet.has_method("to_dictionary"):
		packet = amount_or_packet.call("to_dictionary")
	elif amount_or_packet is Dictionary:
		packet = (amount_or_packet as Dictionary).duplicate(true)
	else:
		push_warning("[DamageSystem] Numeric damage input is deprecated. Pass a complete DamagePacket instead.")
		packet["raw_amount"] = int(amount_or_packet)
		packet["amount"] = int(amount_or_packet)

	if attacker != null and not packet.has("attacker"):
		packet["attacker"] = attacker
	if target != null and not packet.has("target_id"):
		packet["target_id"] = str(target.get_instance_id())
	if packet.has("amount") and not packet.has("raw_amount"):
		packet["raw_amount"] = packet["amount"]
	elif packet.has("damage") and not packet.has("raw_amount"):
		packet["raw_amount"] = packet["damage"]

	var origin: String = normalize_origin(String(packet.get("damage_origin", "")), packet)
	packet["damage_origin"] = origin

	var element: String = normalize_element(String(packet.get("element", "")), packet)
	packet["element"] = StringName(element)

	var original_type: String = String(packet.get("damage_type", ""))
	var damage_type: String = normalize_damage_type(original_type, origin)
	packet["damage_type"] = StringName(damage_type)

	if not packet.has("uses_character_damage_multiplier"):
		packet["uses_character_damage_multiplier"] = DamageRuleRegistryScript.default_uses_character_damage(origin, damage_type)
	if not packet.has("uses_skill_level_coefficient"):
		packet["uses_skill_level_coefficient"] = DamageRuleRegistryScript.default_uses_skill_level(origin)
	if not packet.has("ignore_defense"):
		packet["ignore_defense"] = DamageRuleRegistryScript.default_ignore_defense(damage_type)
	if not packet.has("ignore_resistance"):
		packet["ignore_resistance"] = DamageRuleRegistryScript.default_ignore_resistance(damage_type)
	if not packet.has("ignore_vulnerability"):
		packet["ignore_vulnerability"] = DamageRuleRegistryScript.default_ignore_vulnerability(damage_type)
	if not packet.has("can_crit"):
		packet["can_crit"] = DamageRuleRegistryScript.default_can_crit(origin, damage_type)
	if not packet.has("ignore_min_damage"):
		packet["ignore_min_damage"] = false
	if not packet.has("special_rule_tags"):
		packet["special_rule_tags"] = []
	if not packet.has("source_origin_id"):
		packet["source_origin_id"] = StringName("")
	if not packet.has("source_skill_id"):
		packet["source_skill_id"] = StringName(String(packet.get("source_id", "")))
	if not packet.has("source_instance_id"):
		packet["source_instance_id"] = String(packet.get("source_id", packet.get("source_skill_id", "")))
	if not packet.has("attacker_id"):
		packet["attacker_id"] = str(attacker.get_instance_id()) if attacker != null else ""

	var packet_object: RefCounted = DamagePacketScript.from_dictionary(packet, attacker, target)
	packet = packet_object.call("to_dictionary")
	packet = ReactionServiceScript.prepare_damage_packet(packet)
	packet_object.call("sync_from_dictionary", packet, attacker, target)
	packet = packet_object.call("to_dictionary")
	DamagePacketValidatorScript.validate_any(packet_object, target)
	warn_invalid_origin_type(packet)
	return packet_object


static func normalize_element(value: String, _packet: Dictionary) -> String:
	if DamageRuleRegistryScript.is_element(value):
		return value
	if value != "":
		push_warning("[DamageSystem] Invalid DamagePacket element '%s'; defaulting to physical." % value)
	return DamageRuleRegistryScript.normalize_element(value)


static func normalize_damage_type(value: String, origin: String) -> String:
	if DamageRuleRegistryScript.ALLOWED_DAMAGE_TYPES.has(value):
		return value
	if value != "":
		push_warning("[DamageSystem] Invalid DamagePacket damage_type '%s'; using default for origin '%s'." % [value, origin])
	return DamageRuleRegistryScript.normalize_damage_type(value, origin)


static func normalize_origin(value: String, _packet: Dictionary) -> String:
	if DamageRuleRegistryScript.ALLOWED_ORIGINS.has(value):
		return value
	if value != "":
		push_warning("[DamageSystem] Invalid DamagePacket damage_origin '%s'; defaulting to primary_attack." % value)
	return DamageRuleRegistryScript.normalize_origin(value)


static func warn_invalid_origin_type(packet: Dictionary) -> void:
	var origin: String = String(packet.get("damage_origin", ""))
	var damage_type: String = String(packet.get("damage_type", ""))
	if is_legal_origin_type(origin, damage_type):
		return
	var tags: Array = packet.get("special_rule_tags", [])
	if tags.has("allow_unlisted_damage_combo"):
		return
	push_warning("[DamageSystem] Unlisted damage_origin + damage_type combo: %s + %s." % [origin, damage_type])


static func is_legal_origin_type(origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.is_legal_origin_type(origin, damage_type)
