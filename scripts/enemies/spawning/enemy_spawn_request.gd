extends RefCounted
class_name EnemySpawnRequest


static func create(enemy_id: Variant, params: Dictionary = {}) -> Dictionary:
	var request: Dictionary = params.duplicate(true)
	request["enemy_id"] = StringName(String(enemy_id))
	if not request.has("source_type"):
		request["source_type"] = "unknown"
	if not request.has("multipliers"):
		request["multipliers"] = {}
	return request


static func wave(enemy_id: Variant, multipliers: Dictionary = {}, enemy_type_override: Variant = &"") -> Dictionary:
	return create(enemy_id, {
		"source_type": "wave",
		"multipliers": multipliers,
		"enemy_type_override": String(enemy_type_override)
	})


static func map_event(enemy_id: Variant, multipliers: Dictionary = {}) -> Dictionary:
	return create(enemy_id, {
		"source_type": "map_event",
		"multipliers": multipliers,
		"enemy_type_override": "normal"
	})


static func summon(enemy_id: Variant, position: Vector2, multipliers: Dictionary = {}, source_id: Variant = "") -> Dictionary:
	return create(enemy_id, {
		"source_type": "summon",
		"source_id": String(source_id),
		"position": position,
		"multipliers": multipliers,
		"reward_policy": {
			"award_soul": false
		}
	})


static func boss_core(enemy_id: Variant, position: Vector2, hp: int, armor: int, resistances: Dictionary = {}) -> Dictionary:
	return create(enemy_id, {
		"source_type": "boss_core",
		"position": position,
		"spawn_clearance": 0.0,
		"multipliers": {"hp": 1.0, "damage": 0.01, "exp": 0.0},
		"enemy_type_override": "boss_core",
		"enemy_rank_override": "boss_core",
		"groups": [&"boss_cores"],
		"reward_policy": {
			"award_soul": false,
			"drop_experience": false
		},
		"post_ready_properties": {
			"max_health": hp,
			"current_health": hp,
			"armor": armor,
			"resistances": resistances.duplicate(true),
			"move_speed": 0.0,
			"dropped_experience": 0,
			"soul_drop": 0
		}
	})
