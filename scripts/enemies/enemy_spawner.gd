## 文件用途：编排普通波次、时间线事件、Boss、奖励事件与生成服务。
## 使用方式：挂载主运行场景；reset_for_run 重开一局，物理更新驱动各 director，UI 监听波次和时间信号。

extends Node2D
class_name EnemySpawner


const EnemySpawnRequestScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_request.gd")
const EnemySpawnServiceScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
const EnemyTimelineControllerScript: Script = preload("res://scripts/enemies/timeline/enemy_timeline_controller.gd")
const WaveDirectorScript: Script = preload("res://scripts/enemies/timeline/wave_director.gd")
const BossEncounterControllerScript: Script = preload("res://scripts/enemies/timeline/boss_encounter_controller.gd")
const SpawnGroupPickerScript: Script = preload("res://scripts/enemies/timeline/spawn_group_picker.gd")
const EnemyCleanupServiceScript: Script = preload("res://scripts/enemies/timeline/enemy_cleanup_service.gd")
const RewardEventDirectorScript: Script = preload("res://scripts/enemies/timeline/reward_event_director.gd")

signal wave_changed(wave_id: String)
signal timeline_event_started(event_id: String, announcement: String)
signal run_time_changed(elapsed_time: float, duration: float)
signal wave_timer_changed(wave_index: int, wave_id: String, remaining_time: float, duration: float, spawned_count: int, total_count: int)
signal wave_cleared(wave_id: String, cleared_early: bool)
signal boss_defeated(elapsed_time: float)


@export var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/boss.tscn")
@export_range(0.1, 60.0, 0.1, "or_greater") var spawn_interval: float = 2.0
@export_range(0.0, 3000.0, 10.0, "or_greater") var spawn_radius: float = 650.0
@export var target_group: StringName = &"player"

var _normal_spawn_cooldown: float = 0.0
var _boss_minion_spawn_cooldown: float = 0.0
var _elapsed_time: float = 0.0
var _run_duration: float = 300.0
var _normal_phase_duration: float = 240.0
var _boss_spawn_time: float = 240.0
var _hard_time_limit: float = 300.0
var _despawn_radius: float = 1100.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_radius_min: float = 520.0
var _spawn_radius_max: float = 760.0
var _spawn_batch_interval: float = 3.0
var _max_spawn_batch_size: int = 15
var _spawn_warning_duration: float = 1.5
var _visible_spawn_margin: float = 64.0
var _spawn_player_safe_radius: float = 120.0
var _spawn_count_multiplier_bonus: float = 0.0
var _boss_health_multiplier_bonus: float = 0.0
var _current_wave_id: String = ""
var _current_wave_index: int = -1
var _wave_elapsed_time: float = 0.0
var _wave_duration: float = 55.0
var _wave_spawned_count: int = 0
var _wave_total_count: int = 0
var _wave_transition_timer: float = 0.0
var _wave_transition_notice_seconds: float = 2.0
var _normal_phase_complete: bool = false
var _triggered_wave_events: Dictionary = {}
var _triggered_reward_events: Dictionary = {}
var _triggered_boss_event: bool = false
var _boss_active: bool = false
var _spawn_service: RefCounted = EnemySpawnServiceScript.new()
var _timeline_controller: RefCounted = EnemyTimelineControllerScript.new()
var _wave_director: RefCounted = WaveDirectorScript.new()
var _boss_encounter_controller: RefCounted = BossEncounterControllerScript.new()
var _spawn_group_picker: RefCounted = SpawnGroupPickerScript.new()
var _cleanup_service: RefCounted = EnemyCleanupServiceScript.new()
var _reward_event_director: RefCounted = RewardEventDirectorScript.new()


## 作用：在节点入树后完成组件初始化与信号登记。
## 使用：由 Godot 自动调用；场景中的配置与依赖应在入树前设置。
func _ready() -> void:
	add_to_group(&"enemy_spawner")
	_rng.randomize()
	_sync_spawn_service()
	_sync_timeline_services()
	_apply_timeline_config()


## 作用：重置对应单局。
## 使用：供本模块调用者使用。
func reset_for_run() -> void:
	_normal_spawn_cooldown = 0.0
	_boss_minion_spawn_cooldown = 0.0
	_elapsed_time = 0.0
	_current_wave_id = ""
	_current_wave_index = -1
	_wave_elapsed_time = 0.0
	_wave_spawned_count = 0
	_wave_total_count = 0
	_wave_transition_timer = 0.0
	_normal_phase_complete = false
	_triggered_wave_events.clear()
	_triggered_reward_events.clear()
	_triggered_boss_event = false
	_boss_active = false
	_spawn_count_multiplier_bonus = 0.0
	_boss_health_multiplier_bonus = 0.0
	_sync_spawn_service()
	_sync_timeline_services()
	_apply_timeline_config()


## 作用：应用单局属性修正。
## 使用：供本模块调用者使用；输入 modifiers（属性修正）。
func apply_run_modifiers(modifiers: Dictionary) -> void:
	_spawn_count_multiplier_bonus = float(modifiers.get("enemy_spawn_count_multiplier_add", _spawn_count_multiplier_bonus))
	var previous_boss_bonus: float = _boss_health_multiplier_bonus
	_boss_health_multiplier_bonus = float(modifiers.get("boss_hp_multiplier_add", _boss_health_multiplier_bonus))
	if not is_equal_approx(previous_boss_bonus, _boss_health_multiplier_bonus):
		_apply_boss_health_bonus_to_alive_bosses(previous_boss_bonus, _boss_health_multiplier_bonus)


## 作用：设置生成半径范围。
## 使用：供本模块调用者使用；输入 min_radius（下限半径）、max_radius（上限半径）。
func set_spawn_radius_range(min_radius: float, max_radius: float) -> void:
	_spawn_radius_min = maxf(min_radius, 1.0)
	_spawn_radius_max = maxf(max_radius, _spawn_radius_min)
	_sync_spawn_service()


## 作用：同步生成服务。
## 使用：本文件由 _ready、reset_for_run、set_spawn_radius_range 调用。
func _sync_spawn_service() -> void:
	if _spawn_service == null:
		_spawn_service = EnemySpawnServiceScript.new()
	_spawn_service.call("setup", self, enemy_scene, boss_scene, target_group, _rng)
	_spawn_service.call("set_spawn_radius_range", _spawn_radius_min, _spawn_radius_max)
	_spawn_service.call("set_visible_spawn_rules", true, _visible_spawn_margin, _spawn_player_safe_radius, _spawn_warning_duration)


## 作用：同步时间线服务组。
## 使用：本文件由 _ready、reset_for_run 调用。
func _sync_timeline_services() -> void:
	if _timeline_controller == null:
		_timeline_controller = EnemyTimelineControllerScript.new()
	if _wave_director == null:
		_wave_director = WaveDirectorScript.new()
	if _boss_encounter_controller == null:
		_boss_encounter_controller = BossEncounterControllerScript.new()
	if _spawn_group_picker == null:
		_spawn_group_picker = SpawnGroupPickerScript.new()
	if _cleanup_service == null:
		_cleanup_service = EnemyCleanupServiceScript.new()
	if _reward_event_director == null:
		_reward_event_director = RewardEventDirectorScript.new()
	_timeline_controller.call("setup", self)
	_wave_director.call("setup", self)
	_boss_encounter_controller.call("setup", self)
	_spawn_group_picker.call("setup", _rng)
	_cleanup_service.call("setup", self, target_group)
	_reward_event_director.call("setup", self)


## 作用：生成地图敌人。
## 使用：供本模块调用者使用；输入 enemy_id（敌人ID）、count（数量）、multipliers（倍率组）；返回计算或读取的数值。
func spawn_map_enemy(enemy_id: Variant, count: int = 1, multipliers: Dictionary = {}) -> int:
	var spawned_count: int = 0
	var spawn_count: int = maxi(count, 0)
	for _index in range(spawn_count):
		var request: Dictionary = EnemySpawnRequestScript.map_event(enemy_id, multipliers)
		if _spawn_service.call("spawn", request) != null:
			spawned_count += 1
	return spawned_count


## 作用：推进本节点的物理帧更新流程。
## 使用：由 Godot 自动调用；delta 为自上一帧经过的秒数。
func _physics_process(delta: float) -> void:
	if _is_debug_manual_spawn_only():
		return
	_timeline_controller.call("process", delta)


## 作用：更新离散波次；具体处理委托给 _wave_director.process_discrete_wave。
## 使用：内部辅助入口；输入 delta（delta）。
func _process_discrete_wave(delta: float) -> void:
	_wave_director.call("process_discrete_wave", delta)


## 作用：判断调试控件模式，返回布尔判断结果。
## 使用：内部辅助入口。
func _is_debug_control_mode() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_control_mode", false))


## 作用：判断调试手动生成仅，返回布尔判断结果。
## 使用：本文件由 _physics_process 调用。
func _is_debug_manual_spawn_only() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_manual_spawn_only", false))


## 作用：更新波次生成；具体处理委托给 _wave_director.process_wave_spawn。
## 使用：内部辅助入口；输入 delta（delta）、wave（波次）。
func _process_wave_spawn(delta: float, wave: Dictionary) -> void:
	_wave_director.call("process_wave_spawn", delta, wave)


## 作用：更新波次事件组。
## 使用：内部辅助入口；输入 wave（波次）。
func _process_wave_events(wave: Dictionary) -> void:
	if _wave_spawned_count >= _wave_total_count:
		return

	var events: Array = _get_array(wave.get("events", []))
	for event_index in range(events.size()):
		var event_variant: Variant = events[event_index]
		if not (event_variant is Dictionary):
			continue

		var event: Dictionary = event_variant
		var event_key: String = "%s:%d" % [String(wave.get("id", _current_wave_index)), event_index]
		if _triggered_wave_events.has(event_key):
			continue

		var event_time: float = float(event.get("wave_time", event.get("time", 0.0)))
		if not event.has("wave_time") and event_time > _wave_duration:
			event_time = clampf(event_time - float(wave.get("start_time", 0.0)), 0.0, _wave_duration)
		if _wave_elapsed_time < event_time:
			continue

		_triggered_wave_events[event_key] = true
		_start_wave_event(event_key, event)


## 作用：启动波次事件。
## 使用：本文件由 _process_wave_events 调用；输入 event_key（事件键）、event（事件）。
func _start_wave_event(event_key: String, event: Dictionary) -> void:
	var event_type: String = String(event.get("type", ""))
	match event_type:
		"spawn_elite":
			if _wave_spawned_count >= _wave_total_count:
				return
			var enemy_id: StringName = StringName(String(event.get("enemy_id", "")))
			if enemy_id != &"":
				var enemy: Node2D = spawn_enemy(EnemySpawnRequestScript.create(enemy_id, {
					"multipliers": _get_event_enemy_multipliers(event), "enemy_rank": "elite", "source_type": "elite_event"
				}))
				if enemy != null:
					_wave_spawned_count += 1
			timeline_event_started.emit(
				"elite:%s" % String(enemy_id),
				String(event.get("announcement", ""))
			)
		"final_blessing":
			timeline_event_started.emit(
				"final_blessing:%s" % event_key,
				String(event.get("announcement", ""))
			)
		_:
			timeline_event_started.emit(
				"event:%s" % event_key,
				String(event.get("announcement", ""))
			)


## 作用：更新奖励事件组；具体处理委托给 _reward_event_director.process_reward_events。
## 使用：内部辅助入口。
func _process_reward_events() -> void:
	_reward_event_director.call("process_reward_events")


## 作用：启动奖励事件；具体处理委托给 _reward_event_director.start_reward_event。
## 使用：内部辅助入口；输入 event_index（事件索引）、event（事件）。
func _start_reward_event(event_index: int, event: Dictionary) -> void:
	_reward_event_director.call("start_reward_event", event_index, event)


## 作用：更新Boss事件；具体处理委托给 _boss_encounter_controller.process_boss_event。
## 使用：内部辅助入口。
func _process_boss_event() -> void:
	_boss_encounter_controller.call("process_boss_event")


## 作用：更新Boss随从生成；具体处理委托给 _boss_encounter_controller.process_boss_minion_spawn。
## 使用：内部辅助入口；输入 delta（delta）。
func _process_boss_minion_spawn(delta: float) -> void:
	_boss_encounter_controller.call("process_boss_minion_spawn", delta)


## 作用：生成来源分组配置。
## 使用：本文件由 _spawn_batch_from_source 调用；输入 group_config（分组配置）、multipliers（倍率组）、source_type（来源类型）、limit（限制）；返回计算或读取的数值。
func _spawn_from_group_config(group_config: Dictionary, multipliers: Dictionary = {}, source_type: StringName = &"wave", limit: int = -1) -> int:
	var count_min: int = int(group_config.get("count_min", 1))
	var count_max: int = int(group_config.get("count_max", count_min))
	var spawn_count: int = _rng.randi_range(count_min, maxi(count_max, count_min))
	spawn_count = _scale_spawn_count(spawn_count)
	if limit >= 0:
		spawn_count = mini(spawn_count, limit)
	if spawn_count <= 0:
		return 0

	var enemy_id: StringName = _pick_enemy_id_from_group(group_config)
	var spawned_count: int = 0
	for _spawn_index in range(spawn_count):
		var request: Dictionary = EnemySpawnRequestScript.create(enemy_id, {"multipliers": multipliers, "source_type": String(source_type)})
		if spawn_enemy(request) != null:
			spawned_count += 1
	return spawned_count


## 作用：生成批次来源来源。
## 使用：内部辅助入口；输入 source（来源）、multipliers（倍率组）、source_type（来源类型）、limit（限制）；返回计算或读取的数值。
func _spawn_batch_from_source(source: Dictionary, multipliers: Dictionary = {}, source_type: StringName = &"wave", limit: int = -1) -> int:
	var remaining: int = maxi(limit, 0)
	var spawned_count: int = 0
	while remaining > 0:
		var group_config: Dictionary = _pick_enemy_group(source)
		if group_config.is_empty():
			break
		var spawned: int = _spawn_from_group_config(group_config, multipliers, source_type, remaining)
		if spawned <= 0:
			break
		spawned_count += spawned
		remaining -= spawned
	return spawned_count


## 作用：生成敌人；具体处理委托给 _spawn_service.spawn。
## 使用：本文件由 _start_wave_event、_spawn_from_group_config 调用；输入 request（请求）；返回 Node2D 对象/值。
func spawn_enemy(request: Dictionary) -> Node2D:
	var source_type: String = String(request.get("source_type", "unknown"))
	if source_type == "wave" or source_type == "boss_minion":
		request["visible_spawn_warning"] = true
		request["spawn_warning_duration"] = _spawn_warning_duration
	return _spawn_service.call("spawn", request) as Node2D


## 作用：响应Boss死亡并衔接对应的事件处理流程。
## 使用：内部辅助入口。
func _on_boss_died() -> void:
	if not _boss_active:
		return

	_boss_active = false
	boss_defeated.emit(_elapsed_time)


## 作用：应用时间线配置。
## 使用：本文件由 _ready、reset_for_run 调用。
func _apply_timeline_config() -> void:
	var wave_config: Dictionary = GameData.get_wave_config()

	var run_data: Dictionary = _get_dictionary(wave_config.get("run", {}))
	_run_duration = float(run_data.get("duration_seconds", _run_duration))
	_normal_phase_duration = float(run_data.get("normal_phase_duration_seconds", run_data.get("boss_spawn_time", _normal_phase_duration)))
	_boss_spawn_time = float(run_data.get("boss_spawn_time_seconds", run_data.get("boss_spawn_time", _boss_spawn_time)))
	_hard_time_limit = float(run_data.get("hard_time_limit_seconds", _run_duration))

	var rules: Dictionary = _get_dictionary(wave_config.get("spawn_rules", {}))
	_spawn_radius_min = float(rules.get("spawn_radius_min", _spawn_radius_min))
	_spawn_radius_max = float(rules.get("spawn_radius_max", _spawn_radius_max))
	_spawn_batch_interval = maxf(float(rules.get("spawn_batch_interval_seconds", 3.0)), 0.05)
	_max_spawn_batch_size = maxi(int(rules.get("max_spawn_batch_size", 15)), 1)
	_spawn_warning_duration = maxf(float(rules.get("spawn_warning_duration_seconds", 1.5)), 0.0)
	_visible_spawn_margin = maxf(float(rules.get("visible_spawn_margin", 64.0)), 0.0)
	_spawn_player_safe_radius = maxf(float(rules.get("spawn_player_safe_radius", 120.0)), 0.0)
	_despawn_radius = float(rules.get("despawn_radius", _despawn_radius))
	_wave_duration = float(rules.get("wave_duration_seconds", 55.0))
	_wave_transition_notice_seconds = float(rules.get("wave_transition_notice_seconds", _wave_transition_notice_seconds))
	for wave_variant: Variant in _get_config_array("waves"):
		if wave_variant is Dictionary:
			var wave: Dictionary = wave_variant
			_normal_phase_duration = maxf(_normal_phase_duration, float(wave.get("end_time", 0.0)))
	_boss_spawn_time = minf(_boss_spawn_time, _normal_phase_duration)
	_run_duration = maxf(_run_duration, _normal_phase_duration)
	spawn_radius = _spawn_radius_max
	_sync_spawn_service()


## 作用：获取当前波次，供当前模块后续逻辑使用。
## 使用：本文件由 _get_event_enemy_multipliers 调用；返回结果字典。
func _get_current_wave() -> Dictionary:
	if _current_wave_index >= 0:
		return _get_wave_at_index(_current_wave_index)

	var waves: Array = _get_config_array("waves")
	for wave_variant: Variant in waves:
		if not (wave_variant is Dictionary):
			continue

		var wave: Dictionary = wave_variant
		var start_time: float = float(wave.get("start_time", 0.0))
		var end_time: float = float(wave.get("end_time", INF))
		if _elapsed_time >= start_time and _elapsed_time < end_time:
			return wave

	return {}


## 作用：获取波次指定位置索引，供当前模块后续逻辑使用。
## 使用：本文件由 _get_current_wave 调用；输入 wave_index（波次索引）；返回结果字典。
func _get_wave_at_index(wave_index: int) -> Dictionary:
	var waves: Array = _get_config_array("waves")
	if wave_index < 0 or wave_index >= waves.size():
		return {}
	if waves[wave_index] is Dictionary:
		var wave: Dictionary = waves[wave_index]
		return wave
	return {}


## 作用：启动波次；具体处理委托给 _wave_director.start_wave。
## 使用：内部辅助入口；输入 wave_index（波次索引）。
func _start_wave(wave_index: int) -> void:
	_wave_director.call("start_wave", wave_index)


## 作用：完成波次；具体处理委托给 _wave_director.finish_wave。
## 使用：内部辅助入口；输入 cleared_early（通关early）。
func _finish_wave(cleared_early: bool) -> void:
	_wave_director.call("finish_wave", cleared_early)


## 作用：完成普通阶段。
## 使用：内部辅助入口。
func _finish_normal_phase() -> void:
	if _normal_phase_complete:
		return
	_normal_phase_complete = true
	_current_wave_id = ""
	_wave_transition_timer = 0.0
	_collect_all_experience_crystals()
	timeline_event_started.emit("normal_phase_complete", "普通阶段完成，Boss 即将登场")


## 作用：收集全部经验晶体组；具体处理委托给 _cleanup_service.collect_all_experience_crystals。
## 使用：本文件由 _finish_normal_phase 调用。
func _collect_all_experience_crystals() -> void:
	_cleanup_service.call("collect_all_experience_crystals")


## 作用：获取波次总量数量，供当前模块后续逻辑使用。
## 使用：内部辅助入口；输入 wave（波次）；返回计算或读取的数值。
func _get_wave_total_count(wave: Dictionary) -> int:
	return _scale_spawn_count(int(wave.get("total_count", 0)))


## 作用：获取加权平均分组数量，供当前模块后续逻辑使用；具体处理委托给 _spawn_group_picker.weighted_average_group_count。
## 使用：内部辅助入口；输入 source（来源）；返回计算或读取的数值。
func _get_weighted_average_group_count(source: Dictionary) -> float:
	return float(_spawn_group_picker.call("weighted_average_group_count", source))


## 作用：发出波次变化按条件按需并衔接对应的事件处理流程。
## 使用：内部辅助入口；输入 wave（波次）。
func _emit_wave_changed_if_needed(wave: Dictionary) -> void:
	var wave_id: String = String(wave.get("id", ""))
	if wave_id == _current_wave_id:
		return

	_current_wave_id = wave_id
	wave_changed.emit(wave_id)
	timeline_event_started.emit(
		"wave:%s" % wave_id,
		String(wave.get("announcement", ""))
	)


## 作用：选择敌人分组，供当前模块后续逻辑使用；具体处理委托给 _spawn_group_picker.pick_enemy_group。
## 使用：本文件由 _spawn_batch_from_source 调用；输入 source（来源）；返回结果字典。
func _pick_enemy_group(source: Dictionary) -> Dictionary:
	return _spawn_group_picker.call("pick_enemy_group", source)


## 作用：选择敌人ID来源分组，供当前模块后续逻辑使用；具体处理委托给 _spawn_group_picker.pick_enemy_id_from_group。
## 使用：本文件由 _spawn_from_group_config 调用；输入 group_config（分组配置）；返回 StringName 文本/标识。
func _pick_enemy_id_from_group(group_config: Dictionary) -> StringName:
	return StringName(_spawn_group_picker.call("pick_enemy_id_from_group", group_config))


## 作用：获取配置数组，供当前模块后续逻辑使用。
## 使用：本文件由 _apply_timeline_config、_get_current_wave、_get_wave_at_index 调用；输入 key（键）；返回 Array 列表。
func _get_config_array(key: String) -> Array:
	var wave_config: Dictionary = GameData.get_wave_config()
	return _get_array(wave_config.get(key, []))


## 作用：获取配置字典，供当前模块后续逻辑使用。
## 使用：内部辅助入口；输入 key（键）；返回结果字典。
func _get_config_dictionary(key: String) -> Dictionary:
	var wave_config: Dictionary = GameData.get_wave_config()
	return _get_dictionary(wave_config.get(key, {}))


## 作用：获取波次敌人倍率组，供当前模块后续逻辑使用。
## 使用：本文件由 _get_event_enemy_multipliers 调用；输入 wave（波次）；返回结果字典。
func _get_wave_enemy_multipliers(wave: Dictionary) -> Dictionary:
	return _get_dictionary(wave.get("enemy_multipliers", {}))


## 作用：获取事件敌人倍率组，供当前模块后续逻辑使用。
## 使用：本文件由 _start_wave_event 调用；输入 event（事件）；返回结果字典。
func _get_event_enemy_multipliers(event: Dictionary) -> Dictionary:
	return _get_dictionary(event.get("enemy_multipliers", _get_wave_enemy_multipliers(_get_current_wave())))


## 作用：获取Boss敌人倍率组，供当前模块后续逻辑使用。
## 使用：内部辅助入口；输入 boss_event（Boss事件）；返回结果字典。
func _get_boss_enemy_multipliers(boss_event: Dictionary) -> Dictionary:
	var multipliers: Dictionary = _get_dictionary(boss_event.get("boss_multipliers", {}))
	multipliers["hp"] = _get_multiplier(multipliers, "hp", 1.0) * maxf(1.0 + _boss_health_multiplier_bonus, 0.01)
	return multipliers


## 作用：获取倍率，供当前模块后续逻辑使用。
## 使用：本文件由 _get_boss_enemy_multipliers 调用；输入 multipliers（倍率组）、key（键）、fallback（回退）；返回计算或读取的数值。
func _get_multiplier(multipliers: Dictionary, key: String, fallback: float) -> float:
	return maxf(float(multipliers.get(key, fallback)), 0.01)


## 作用：缩放生成数量。
## 使用：本文件由 _spawn_from_group_config、_get_wave_total_count 调用；输入 base_count（基础数量）；返回计算或读取的数值。
func _scale_spawn_count(base_count: int) -> int:
	var multiplier: float = maxf(1.0 + _spawn_count_multiplier_bonus, 0.01)
	return maxi(roundi(float(base_count) * multiplier), 1)


## 作用：获取存活普通敌人数量，供当前模块后续逻辑使用；具体处理委托给 _cleanup_service.get_alive_normal_enemy_count。
## 使用：内部辅助入口；返回计算或读取的数值。
func _get_alive_normal_enemy_count() -> int:
	return int(_cleanup_service.call("get_alive_normal_enemy_count"))


## 作用：获取存活敌人数量，供当前模块后续逻辑使用；具体处理委托给 _cleanup_service.get_alive_enemy_count。
## 使用：内部辅助入口；返回计算或读取的数值。
func _get_alive_enemy_count() -> int:
	return int(_cleanup_service.call("get_alive_enemy_count"))


## 作用：获取存活Boss随从数量，供当前模块后续逻辑使用；具体处理委托给 _cleanup_service.get_alive_boss_minion_count。
## 使用：内部辅助入口；返回计算或读取的数值。
func _get_alive_boss_minion_count() -> int:
	return int(_cleanup_service.call("get_alive_boss_minion_count"))


## 作用：回收远处敌人组；具体处理委托给 _cleanup_service.despawn_far_enemies。
## 使用：内部辅助入口。
func _despawn_far_enemies() -> void:
	_cleanup_service.call("despawn_far_enemies", _despawn_radius)


## 作用：清除普通敌人组；具体处理委托给 _cleanup_service.clear_normal_enemies。
## 使用：内部辅助入口。
func _clear_normal_enemies() -> void:
	_cleanup_service.call("clear_normal_enemies")


## 作用：应用Boss生命值加成转换存活Boss列表。
## 使用：本文件由 apply_run_modifiers 调用；输入 previous_bonus（previous加成）、new_bonus（新值加成）。
func _apply_boss_health_bonus_to_alive_bosses(previous_bonus: float, new_bonus: float) -> void:
	var previous_multiplier: float = maxf(1.0 + previous_bonus, 0.01)
	var new_multiplier: float = maxf(1.0 + new_bonus, 0.01)
	if is_equal_approx(previous_multiplier, new_multiplier):
		return

	var ratio: float = new_multiplier / previous_multiplier
	for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
		if String(enemy.get_meta("enemy_rank", "normal")) != "boss":
			continue

		var current_max_health: int = int(enemy.get("max_health"))
		var current_health: int = int(enemy.get("current_health"))
		var new_max_health: int = maxi(roundi(float(current_max_health) * ratio), 1)
		var added_health: int = maxi(new_max_health - current_max_health, 0)
		enemy.set("max_health", new_max_health)
		enemy.set("current_health", mini(current_health + added_health, new_max_health))
		if enemy.has_signal(&"health_changed"):
			enemy.emit_signal(&"health_changed", int(enemy.get("current_health")), new_max_health)


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _apply_timeline_config、_get_config_dictionary、_get_wave_enemy_multipliers 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 _process_wave_events、_get_config_array 调用；输入 value（值）。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
