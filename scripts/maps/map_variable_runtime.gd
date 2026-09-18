extends Node
class_name MapVariableRuntime


const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")

var _map_id: StringName = &""
var _variable_type: String = "open"
var _target_group: StringName = &"player"
var _hazard_timer: float = 0.0
var _map_enemy_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func setup(map_data: Dictionary, target_group: StringName = &"player") -> void:
	_map_id = StringName(String(map_data.get("id", "")))
	var variable: Dictionary = _get_dictionary(map_data.get("map_variable", {}))
	_variable_type = String(variable.get("type", "open"))
	_target_group = target_group
	_hazard_timer = _get_interval()
	_map_enemy_timer = 6.0
	_apply_spawn_pressure()


func reset() -> void:
	_map_id = &""
	_variable_type = "open"
	_hazard_timer = 0.0
	_map_enemy_timer = 0.0


func _physics_process(delta: float) -> void:
	if _variable_type == "open" or get_tree() == null or get_tree().paused:
		return

	match _variable_type:
		"toxic_fog", "lava_fissure":
			_hazard_timer = maxf(_hazard_timer - delta, 0.0)
			if _hazard_timer <= 0.0:
				_spawn_hazard()
				_hazard_timer = _get_interval()
			if _variable_type == "toxic_fog":
				_map_enemy_timer = maxf(_map_enemy_timer - delta, 0.0)
				if _map_enemy_timer <= 0.0:
					_spawn_map_pressure_enemy(&"toxic_bug", 2)
					_map_enemy_timer = 10.0


func _spawn_hazard() -> void:
	var player: Node2D = get_tree().get_first_node_in_group(_target_group) as Node2D
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if player == null or parent == null:
		return

	var offset: Vector2 = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(90.0, 260.0)
	var position: Vector2 = player.global_position + offset
	var is_lava: bool = _variable_type == "lava_fissure"
	var hazard: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": StringName("map_%s" % _variable_type),
		"position": position,
		"damage": 18 if is_lava else 10,
		"damage_type": &"status_dot",
		"element": &"fire" if is_lava else &"poison",
		"source_id": StringName("map_lava" if is_lava else "map_toxic_fog"),
		"damage_packet": {
			"damage_origin": "field",
			"source_id": "map_lava" if is_lava else "map_toxic_fog",
			"source_skill_id": "map_lava" if is_lava else "map_toxic_fog",
			"source_type": "map_hazard",
			"element": &"fire" if is_lava else &"poison",
			"damage_type": &"status_dot",
			"can_crit": false,
			"can_trigger_reaction": false,
			"uses_character_damage_multiplier": false,
			"uses_skill_level_coefficient": false
		},
		"duration": 2.2 if is_lava else 3.0,
		"tick_interval": 1.0,
		"radius": 96.0 if is_lava else 130.0,
		"target_group": _target_group,
		"visual_color": Color(1.0, 0.22, 0.05, 0.28) if is_lava else Color(0.35, 0.9, 0.2, 0.24),
		"statuses_on_hit": [&"burning"] if is_lava else [&"poison"],
		"status_params": {
			"duration": 2.5,
			"damage": 6,
			"tick_interval": 1.0
		}
	})
	if hazard != null:
		hazard.add_to_group(&"map_hazard")
	var tracker: Node = get_tree().get_first_node_in_group(&"run_stats_tracker")
	if tracker != null and tracker.has_method("record_map_event"):
		tracker.call("record_map_event", _variable_type)


func _apply_spawn_pressure() -> void:
	if _variable_type != "narrow_corridor":
		return

	var spawner: Node = get_tree().get_first_node_in_group(&"enemy_spawner") if get_tree() != null else null
	if spawner == null:
		return
	spawner.set("spawn_radius", 520.0)
	if spawner.has_method("set_spawn_radius_range"):
		spawner.call("set_spawn_radius_range", 360.0, 560.0)
	if spawner.has_method("apply_run_modifiers"):
		spawner.call("apply_run_modifiers", {"enemy_spawn_count_multiplier_add": 0.12})


func _spawn_map_pressure_enemy(enemy_id: StringName, count: int) -> void:
	var spawner: Node = get_tree().get_first_node_in_group(&"enemy_spawner") if get_tree() != null else null
	if spawner != null and spawner.has_method("spawn_map_enemy"):
		spawner.call("spawn_map_enemy", enemy_id, count, {"hp": 1.05, "damage": 1.0, "exp": 0.8})


func _get_interval() -> float:
	match _variable_type:
		"toxic_fog":
			return 7.0
		"lava_fissure":
			return 5.5
		_:
			return 9999.0


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
