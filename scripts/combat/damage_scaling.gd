extends RefCounted
class_name DamageScaling


var uses_character_damage_multiplier: bool = true
var uses_skill_level_coefficient: bool = true
var skill_level_coefficient: float = 1.0


static func from_dictionary(packet: Dictionary) -> RefCounted:
	var scaling: RefCounted = new()
	scaling.uses_character_damage_multiplier = bool(packet.get("uses_character_damage_multiplier", scaling.uses_character_damage_multiplier))
	scaling.uses_skill_level_coefficient = bool(packet.get("uses_skill_level_coefficient", scaling.uses_skill_level_coefficient))
	scaling.skill_level_coefficient = maxf(float(packet.get("skill_level_coefficient", scaling.skill_level_coefficient)), 0.0)
	return scaling


func apply_to_dictionary(packet: Dictionary) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	result["uses_character_damage_multiplier"] = uses_character_damage_multiplier
	result["uses_skill_level_coefficient"] = uses_skill_level_coefficient
	result["skill_level_coefficient"] = skill_level_coefficient
	return result
