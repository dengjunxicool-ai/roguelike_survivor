extends RefCounted
class_name EnemyConfigHelper


static func duplicate_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


static func duplicate_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			result.append(item.duplicate(true))
	return result


static func apply_classification_metadata(enemy: Node, enemy_config: Dictionary) -> void:
	if enemy == null:
		return
	var enemy_type: String = String(enemy.get_meta("enemy_type_override", enemy_config.get("type", "normal")))
	var enemy_rank: String = String(enemy.get_meta("enemy_rank_override", enemy.get_meta("enemy_rank", enemy_config.get("rank", enemy_type))))
	if enemy_rank == "":
		enemy_rank = enemy_type
	enemy.set_meta("enemy_type", enemy_type)
	enemy.set_meta("enemy_rank", enemy_rank)
	enemy.set_meta("is_boss", enemy_rank == "boss")
	enemy.set_meta("is_elite", enemy_rank == "elite")
	if enemy_rank == "boss":
		enemy.add_to_group(&"bosses")
	elif enemy_rank == "elite":
		enemy.add_to_group(&"elites")


static func behavior_attack_range_fallback(behavior: Dictionary, attack_range: float) -> float:
	match String(behavior.get("type", "")):
		"keep_distance_and_shoot":
			return float(behavior.get("preferred_distance", attack_range))
		"explode_near_player":
			return float(behavior.get("trigger_radius", attack_range))
		"summon_and_chase":
			return float(behavior.get("summon_range", behavior.get("attack_range", attack_range)))
		"chase_and_cast_pool":
			return float(behavior.get("cast_range", behavior.get("attack_range", attack_range)))
		"dash_attack":
			return float(behavior.get("dash_trigger_range", behavior.get("attack_range", attack_range)))
		"boss_dungeon_heart":
			return float(behavior.get("skill_range", behavior.get("attack_range", attack_range)))
		_:
			return attack_range


static func behavior_attack_range(behavior: Dictionary, attack_range: float) -> float:
	match String(behavior.get("type", "")):
		"summon_and_chase":
			return float(behavior.get("summon_range", behavior.get("attack_range", attack_range)))
		"chase_and_cast_pool":
			return float(behavior.get("cast_range", behavior.get("attack_range", attack_range)))
		"dash_attack":
			return float(behavior.get("dash_trigger_range", behavior.get("attack_range", attack_range)))
		"boss_dungeon_heart":
			return float(behavior.get("skill_range", behavior.get("attack_range", attack_range)))
		_:
			return attack_range
