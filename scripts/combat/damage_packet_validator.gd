extends RefCounted
class_name DamagePacketValidator


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")

const MODE_DISABLED: String = "disabled"
const MODE_WARNING: String = "warning"
const MODE_ERROR: String = "error"
static var validation_mode: String = MODE_WARNING

const REQUIRED_PACKET_FIELDS: Array[String] = [
	"raw_amount",
	"damage_origin",
	"damage_type",
	"element",
	"source_weapon_id",
	"source_skill_id",
	"source_instance_id",
	"attacker_id",
	"target_id",
	"can_crit",
	"can_trigger_reaction",
	"reaction_depth",
	"uses_character_damage_multiplier",
	"uses_skill_level_coefficient",
	"ignore_defense",
	"ignore_resistance",
	"ignore_vulnerability",
	"ignore_min_damage",
	"special_rule_tags"
]


static func validate(packet: Dictionary, target: Node = null) -> void:
	if validation_mode == MODE_DISABLED:
		return
	for key: String in REQUIRED_PACKET_FIELDS:
		if not packet.has(key):
			_report("DamagePacket missing required field: %s." % key)

	_warn_unstable_fractional_source(packet)
	_warn_reaction_recursion_risk(packet)
	_warn_enemy_packet_scaling(packet)
	_warn_missing_source_identity(packet, target)


static func validate_any(value: Variant, target: Node = null) -> void:
	if validation_mode == MODE_DISABLED:
		return
	if value is RefCounted and value.has_method("packet_value"):
		validate_for_context(value, target)
		return
	if value is RefCounted and value.has_method("get_value"):
		_validate_packet_object(value, target)
		return
	if value is Dictionary:
		validate(value, target)
		return
	_report("DamagePacket validator received unsupported value.")


static func validate_for_context(calculation_context: RefCounted, target: Node = null) -> void:
	if validation_mode == MODE_DISABLED:
		return
	for key: String in REQUIRED_PACKET_FIELDS:
		if not bool(calculation_context.call("packet_has", key)):
			_report("DamagePacket missing required field: %s." % key)

	_warn_unstable_fractional_source_for_context(calculation_context)
	_warn_reaction_recursion_risk_for_context(calculation_context)
	_warn_enemy_packet_scaling_for_context(calculation_context)
	_warn_missing_source_identity_for_context(calculation_context, target)


static func _validate_packet_object(packet_object: RefCounted, target: Node = null) -> void:
	for key: String in REQUIRED_PACKET_FIELDS:
		if not bool(packet_object.call("has_value", key)):
			_report("DamagePacket missing required field: %s." % key)

	_warn_unstable_fractional_source_for_packet_object(packet_object)
	_warn_reaction_recursion_risk_for_packet_object(packet_object)
	_warn_enemy_packet_scaling_for_packet_object(packet_object)
	_warn_missing_source_identity_for_packet_object(packet_object, target)


static func _warn_unstable_fractional_source(packet: Dictionary) -> void:
	if not DamageRuleRegistryScript.uses_fractional_buffer(packet):
		return

	var source_instance_id: String = String(packet.get("source_instance_id", ""))
	if source_instance_id == "":
		_report("Fractional damage requires a stable source_instance_id.")


static func _warn_unstable_fractional_source_for_context(calculation_context: RefCounted) -> void:
	if not DamageRuleRegistryScript.uses_fractional_buffer_for_context(calculation_context):
		return

	var source_instance_id: String = String(calculation_context.call("packet_value", "source_instance_id", ""))
	if source_instance_id == "":
		_report("Fractional damage requires a stable source_instance_id.")


static func _warn_unstable_fractional_source_for_packet_object(packet_object: RefCounted) -> void:
	if not DamageRuleRegistryScript.uses_fractional_buffer_for_packet_object(packet_object):
		return

	var source_instance_id: String = String(packet_object.call("get_value", "source_instance_id", ""))
	if source_instance_id == "":
		_report("Fractional damage requires a stable source_instance_id.")


static func _warn_reaction_recursion_risk(packet: Dictionary) -> void:
	var origin: String = String(packet.get("damage_origin", ""))
	var reaction_depth: int = int(packet.get("reaction_depth", 0))
	if origin == "reaction" and bool(packet.get("can_trigger_reaction", false)):
		_report("Reaction damage should set can_trigger_reaction=false.")
	if reaction_depth > 0 and bool(packet.get("can_trigger_reaction", false)):
		_report("Nested reaction packet should not trigger another reaction.")


static func _warn_reaction_recursion_risk_for_context(calculation_context: RefCounted) -> void:
	var origin: String = String(calculation_context.call("packet_value", "damage_origin", ""))
	var reaction_depth: int = int(calculation_context.call("packet_value", "reaction_depth", 0))
	var can_trigger_reaction: bool = bool(calculation_context.call("packet_value", "can_trigger_reaction", false))
	if origin == "reaction" and can_trigger_reaction:
		_report("Reaction damage should set can_trigger_reaction=false.")
	if reaction_depth > 0 and can_trigger_reaction:
		_report("Nested reaction packet should not trigger another reaction.")


static func _warn_reaction_recursion_risk_for_packet_object(packet_object: RefCounted) -> void:
	var origin: String = String(packet_object.call("get_value", "damage_origin", ""))
	var reaction_depth: int = int(packet_object.call("get_value", "reaction_depth", 0))
	var can_trigger_reaction: bool = bool(packet_object.call("get_value", "can_trigger_reaction", false))
	if origin == "reaction" and can_trigger_reaction:
		_report("Reaction damage should set can_trigger_reaction=false.")
	if reaction_depth > 0 and can_trigger_reaction:
		_report("Nested reaction packet should not trigger another reaction.")


static func _warn_enemy_packet_scaling(packet: Dictionary) -> void:
	var attacker: Node = packet.get("attacker") as Node
	if attacker == null:
		return
	if not attacker.is_in_group(&"enemies") and not attacker.is_in_group(&"enemy"):
		return
	if bool(packet.get("uses_character_damage_multiplier", false)):
		_report("Enemy damage packet should not use player character damage multiplier.")


static func _warn_enemy_packet_scaling_for_context(calculation_context: RefCounted) -> void:
	var attacker: Node = calculation_context.call("packet_value", "attacker", null) as Node
	if attacker == null:
		return
	if not attacker.is_in_group(&"enemies") and not attacker.is_in_group(&"enemy"):
		return
	if bool(calculation_context.call("packet_value", "uses_character_damage_multiplier", false)):
		_report("Enemy damage packet should not use player character damage multiplier.")


static func _warn_enemy_packet_scaling_for_packet_object(packet_object: RefCounted) -> void:
	var attacker: Node = packet_object.call("get_value", "attacker", null) as Node
	if attacker == null:
		return
	if not attacker.is_in_group(&"enemies") and not attacker.is_in_group(&"enemy"):
		return
	if bool(packet_object.call("get_value", "uses_character_damage_multiplier", false)):
		_report("Enemy damage packet should not use player character damage multiplier.")


static func _warn_missing_source_identity(packet: Dictionary, target: Node) -> void:
	var source_skill_id: String = String(packet.get("source_skill_id", ""))
	var source_weapon_id: String = String(packet.get("source_weapon_id", ""))
	if source_skill_id == "" and source_weapon_id == "":
		var target_id: String = str(target.get_instance_id()) if target != null else String(packet.get("target_id", ""))
		_report("DamagePacket has no source_skill_id or source_weapon_id. target=%s" % target_id)


static func _warn_missing_source_identity_for_context(calculation_context: RefCounted, target: Node) -> void:
	var source_skill_id: String = String(calculation_context.call("packet_value", "source_skill_id", ""))
	var source_weapon_id: String = String(calculation_context.call("packet_value", "source_weapon_id", ""))
	if source_skill_id == "" and source_weapon_id == "":
		var target_id: String = str(target.get_instance_id()) if target != null else String(calculation_context.call("packet_value", "target_id", ""))
		_report("DamagePacket has no source_skill_id or source_weapon_id. target=%s" % target_id)


static func _warn_missing_source_identity_for_packet_object(packet_object: RefCounted, target: Node) -> void:
	var source_skill_id: String = String(packet_object.call("get_value", "source_skill_id", ""))
	var source_weapon_id: String = String(packet_object.call("get_value", "source_weapon_id", ""))
	if source_skill_id == "" and source_weapon_id == "":
		var target_id: String = str(target.get_instance_id()) if target != null else String(packet_object.call("get_value", "target_id", ""))
		_report("DamagePacket has no source_skill_id or source_weapon_id. target=%s" % target_id)


static func _report(message: String) -> void:
	if validation_mode == MODE_ERROR:
		push_error("[DamagePacketValidator] %s" % message)
	else:
		push_warning("[DamagePacketValidator] %s" % message)
