extends RefCounted
class_name SkillSlotPolicy


static func category(definition: Dictionary) -> String:
	return String(definition.get("slot_category", ""))


static func is_starting_attack(definition: Dictionary) -> bool:
	return bool(definition.get("is_starting_skill", false))


static func is_attack(definition: Dictionary) -> bool:
	return is_starting_attack(definition) or String(definition.get("skill_type", "")) == "attack"


static func is_dash(definition: Dictionary) -> bool:
	return String(definition.get("skill_type", "")) == "dash"


static func counts_active_capacity(definition: Dictionary) -> bool:
	return not is_attack(definition) and not is_dash(definition)
