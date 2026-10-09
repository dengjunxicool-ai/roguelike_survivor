## 文件用途：依据地图变量配置周期生成危险区域并调整生成压力。
## 使用方式：入树后 setup(map_data,target_group) 设置地图并应用压力；reset 清空地图状态，物理更新推进危险区域计时。

extends Node
class_name MapVariableRuntime


const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")

var _map_id: StringName = &""
var _variable_type: String = "open"
var _target_group: StringName = &"player"
var _hazard_timer: float = 0.0
var _map_enemy_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## 作用：在节点入树后完成组件初始化与信号登记。
## 使用：由 Godot 自动调用；场景中的配置与依赖应在入树前设置。
func _ready() -> void:
	_rng.randomize()


## 作用：解析地图变量类型、设置计时器并应用地图生成压力。
## 使用：map_data 来自 GameData，target_group 默认 player；节点应已入树以便找到生成器。
func setup(map_data: Dictionary, target_group: StringName = &"player") -> void:
	_map_id = StringName(String(map_data.get("id", "")))
	var variable: Dictionary = _get_dictionary(map_data.get("map_variable", {}))
	_variable_type = String(variable.get("type", "open"))
	_target_group = target_group
	_hazard_timer = _get_interval()
	_map_enemy_timer = 6.0
	_apply_spawn_pressure()


## 作用：重置地图 ID、变量类型和计时器为开放地图空状态。
## 使用：生命周期重置时调用；已有危害节点由场景编排清理。
func reset() -> void:
	_map_id = &""
	_variable_type = "open"
	_hazard_timer = 0.0
	_map_enemy_timer = 0.0


## 作用：推进本节点的物理帧更新流程。
## 使用：由 Godot 自动调用；delta 为自上一帧经过的秒数。
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


## 作用：在玩家周围生成毒雾或岩浆区域并记录地图事件。
## 使用：由危害计时器触发；区域与状态通过 CombatObjectFactory 统一创建，不直接扣血。
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


## 作用：为窄走廊地图调整生成半径并增加波次数量倍率。
## 使用：仅 narrow_corridor 生效；通过 spawner 公开接口应用，不直接创建敌人。
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


## 作用：生成地图压力敌人；具体处理委托给 spawner.spawn_map_enemy。
## 使用：本文件由 _physics_process 调用；输入 enemy_id（敌人ID）、count（数量）。
func _spawn_map_pressure_enemy(enemy_id: StringName, count: int) -> void:
	var spawner: Node = get_tree().get_first_node_in_group(&"enemy_spawner") if get_tree() != null else null
	if spawner != null and spawner.has_method("spawn_map_enemy"):
		spawner.call("spawn_map_enemy", enemy_id, count, {"hp": 1.05, "damage": 1.0, "exp": 0.8})


## 作用：获取间隔，供当前模块后续逻辑使用。
## 使用：本文件由 setup、_physics_process 调用；返回计算或读取的数值。
func _get_interval() -> float:
	match _variable_type:
		"toxic_fog":
			return 7.0
		"lava_fissure":
			return 5.5
		_:
			return 9999.0


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 setup 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
