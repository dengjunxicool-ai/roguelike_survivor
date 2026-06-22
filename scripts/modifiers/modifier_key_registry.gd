extends RefCounted
class_name ModifierKeyRegistry


static func element_bonus_key(element: Variant) -> String:
	var text: String = String(element)
	return "%s_damage_multiplier_add" % text if text != "" else ""


static func origin_bonus_keys(origin: Variant) -> Array[String]:
	match String(origin):
		"primary_attack":
			return ["primary_attack_damage_multiplier_add", "direct_damage_multiplier_add", "equipped_weapon_damage_add"]
		"status_dot":
			return ["dot_damage_multiplier_add"]
		"reaction":
			return ["reaction_damage_multiplier_add"]
		"field":
			return ["field_damage_multiplier_add", "area_damage_multiplier_add"]
		"trap":
			return ["trap_damage_multiplier_add"]
	return []


static func enemy_type_bonus_key(target_class: Variant) -> String:
	if String(target_class) == "boss":
		return "boss_damage_multiplier_add"
	if String(target_class) == "elite":
		return "elite_damage_multiplier_add"
	return ""
