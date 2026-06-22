extends RefCounted
class_name DamageFlags


var can_crit: bool = true
var can_trigger_reaction: bool = true
var ignore_defense: bool = false
var ignore_resistance: bool = false
var ignore_vulnerability: bool = false
var ignore_min_damage: bool = false


static func from_dictionary(packet: Dictionary) -> RefCounted:
	var flags: RefCounted = new()
	flags.can_crit = bool(packet.get("can_crit", flags.can_crit))
	flags.can_trigger_reaction = bool(packet.get("can_trigger_reaction", flags.can_trigger_reaction))
	flags.ignore_defense = bool(packet.get("ignore_defense", flags.ignore_defense))
	flags.ignore_resistance = bool(packet.get("ignore_resistance", flags.ignore_resistance))
	flags.ignore_vulnerability = bool(packet.get("ignore_vulnerability", flags.ignore_vulnerability))
	flags.ignore_min_damage = bool(packet.get("ignore_min_damage", flags.ignore_min_damage))
	return flags


func apply_to_dictionary(packet: Dictionary) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	result["can_crit"] = can_crit
	result["can_trigger_reaction"] = can_trigger_reaction
	result["ignore_defense"] = ignore_defense
	result["ignore_resistance"] = ignore_resistance
	result["ignore_vulnerability"] = ignore_vulnerability
	result["ignore_min_damage"] = ignore_min_damage
	return result
