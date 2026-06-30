extends RefCounted
class_name SkillGrowthScaling


const RARITY_MULTIPLIERS: Dictionary = {
	"normal": 1.0,
	"rare": 1.25,
	"epic": 1.55,
	"legendary": 1.95
}

const TYPE_GROWTH: Dictionary = {
	"attack": {"damage": 0.08, "radius": 0.03, "duration": 0.05, "cooldown": 0.0},
	"dash": {"damage": 0.10, "radius": 0.04, "duration": 0.05, "cooldown": 0.0},
	"cast": {"damage": 0.12, "radius": 0.05, "duration": 0.06, "cooldown": 0.04},
	"summon": {"damage": 0.10, "radius": 0.0, "duration": 0.06, "attack_interval": 0.03},
	"passive": {"passive": 0.20},
	"power": {"damage": 0.12, "radius": 0.05, "duration": 0.05, "cooldown": 0.03},
	"fusion": {"damage": 0.15, "radius": 0.05, "duration": 0.05, "cooldown": 0.03},
	"core": {}
}


static func stat_multiplier(skill_instance: RefCounted, stat_kind: String) -> float:
	if skill_instance == null:
		return 1.0
	if _skill_type(skill_instance) == "core":
		return 1.0
	if stat_kind == "tick_damage" or stat_kind == "tick_interval":
		return 1.0

	var growth: Dictionary = _growth_for(skill_instance)
	var level: int = maxi(int(skill_instance.get("current_level")), 1)
	var per_level: float = float(growth.get(_growth_key(stat_kind), 0.0))
	var rarity: float = rarity_multiplier(_string_or(skill_instance.get("current_rarity"), _definition_rarity(skill_instance)))
	if _is_reduction_stat(stat_kind):
		return maxf(1.0 - per_level * float(level - 1), 0.05) / rarity
	return maxf(1.0 + per_level * float(level - 1), 0.0) * rarity


static func apply_to_number(value: float, skill_instance: RefCounted, stat_kind: String) -> float:
	return value * stat_multiplier(skill_instance, stat_kind)


static func rarity_multiplier(rarity: String) -> float:
	return float(RARITY_MULTIPLIERS.get(rarity, 1.0))


static func rarity_weight_map_for_max_level(max_level: int) -> Dictionary:
	if max_level <= 1:
		return {"legendary": 1.0}
	if max_level == 2:
		return {"epic": 1.0, "legendary": 1.0}
	return {"normal": 1.0, "rare": 2.0, "epic": 1.0, "legendary": 1.0}


static func pick_rarity_for_max_level(max_level: int, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = rarity_weight_map_for_max_level(max_level)
	var total: float = 0.0
	for weight_variant: Variant in weights.values():
		total += maxf(float(weight_variant), 0.0)
	if total <= 0.0:
		return "normal"
	var roll: float = rng.randf_range(0.0, total)
	var accumulated: float = 0.0
	for rarity_variant: Variant in weights.keys():
		var rarity: String = String(rarity_variant)
		accumulated += maxf(float(weights[rarity_variant]), 0.0)
		if roll <= accumulated:
			return rarity
	return String(weights.keys()[weights.size() - 1])


static func _growth_for(skill_instance: RefCounted) -> Dictionary:
	return TYPE_GROWTH.get(_skill_type(skill_instance), {})


static func _growth_key(stat_kind: String) -> String:
	match stat_kind:
		"area_radius", "radius", "projectile_radius", "explosion_radius", "orbit_radius":
			return "radius"
		"status_duration":
			return "duration"
		"attack_cooldown", "attack_interval", "hit_interval":
			return "attack_interval"
		"modifier":
			return "passive"
		_:
			return stat_kind


static func _is_reduction_stat(stat_kind: String) -> bool:
	return stat_kind == "cooldown" or stat_kind == "attack_cooldown" or stat_kind == "attack_interval" or stat_kind == "hit_interval"


static func _skill_type(skill_instance: RefCounted) -> String:
	var direct: String = _string_or(skill_instance.get("skill_type"), "")
	if direct != "":
		return direct
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition != null:
		return _string_or(definition.get("skill_type"), "")
	return ""


static func _definition_rarity(skill_instance: RefCounted) -> String:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition != null:
		return _string_or(definition.get("rarity"), "normal")
	return "normal"


static func _string_or(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	var text: String = String(value)
	if text == "" or text == "<null>":
		return fallback
	return text
