extends RefCounted
class_name EnemySpawnMultipliers


static func normalize(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	return {
		"hp": maxf(float(source.get("hp", 1.0)), 0.01),
		"damage": maxf(float(source.get("damage", 1.0)), 0.01),
		"move_speed": maxf(float(source.get("move_speed", source.get("speed", 1.0))), 0.01),
		"exp": maxf(float(source.get("exp", 1.0)), 0.0),
		"defense_add": int(source.get("defense_add", 0))
	}
