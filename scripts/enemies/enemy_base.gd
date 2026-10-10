## 文件用途：聚合敌人配置、状态、AI、移动、受击、死亡与奖励子系统。
## 使用方式：挂载敌人场景；生成时先设置 ID/倍率，入树初始化；伤害经 take_damage，死亡经统一流水线。

extends CharacterBody2D
class_name EnemyBase


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const EnemyAttackTelegraphScript: Script = preload("res://scripts/enemies/enemy_attack_telegraph.gd")
const EnemyAreaTelegraphScript: Script = preload("res://scripts/enemies/combat/enemy_attack_telegraph.gd")
const EnemyVisualControllerScript: Script = preload("res://scripts/enemies/enemy_visual_controller.gd")
const EnemyDebugDisplayControllerScript: Script = preload("res://scripts/enemies/enemy_debug_display_controller.gd")
const EnemyStatusDisplayControllerScript: Script = preload("res://scripts/enemies/enemy_status_display_controller.gd")
const EnemyActionExecutorScript: Script = preload("res://scripts/enemies/enemy_action_executor.gd")
const EnemyRewardControllerScript: Script = preload("res://scripts/enemies/enemy_reward_controller.gd")
const EnemyStatusFacadeScript: Script = preload("res://scripts/enemies/enemy_status_facade.gd")
const EnemyDeathContextScript: Script = preload("res://scripts/enemies/death/enemy_death_context.gd")
const EnemyDeathPipelineScript: Script = preload("res://scripts/enemies/death/enemy_death_pipeline.gd")
const EnemyBehaviorControllerScript: Script = preload("res://scripts/enemies/behaviors/enemy_behavior_controller.gd")
const EnemySkillControllerScript: Script = preload("res://scripts/enemies/skills/enemy_skill_controller.gd")
const EnemyDamagePacketBuilderScript: Script = preload("res://scripts/enemies/combat/enemy_damage_packet_builder.gd")
const EnemyStateControllerScript: Script = preload("res://scripts/enemies/enemy_state_controller.gd")
const EnemyConfigHelperScript: Script = preload("res://scripts/enemies/enemy_config_helper.gd")
const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")
const RuntimePoolRegistryScript: Script = preload("res://scripts/runtime/runtime_pool_registry.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")
const EnemyMapBoundaryScript: Script = preload("res://scripts/enemies/enemy_map_boundary.gd")
const NEARBY_ENEMY_CELL_SIZE: float = 128.0
const MOTION_LIMIT_EXTRA_RADIUS: float = 96.0
const CROWDED_ENEMY_LOD_THRESHOLD: int = 60
const HEAVY_CROWD_ENEMY_LOD_THRESHOLD: int = 90
const HEAVY_CROWD_RUNTIME_SKIP_THRESHOLD: int = 70
const MOTION_LIMIT_ALWAYS_DISTANCE_SQUARED: float = 220.0 * 220.0
const CROWDED_RUNTIME_SKIP_DISTANCE_SQUARED: float = 420.0 * 420.0
const VISUAL_UPDATE_CROWDED_INTERVAL: float = 0.05
const VISUAL_UPDATE_HEAVY_CROWD_INTERVAL: float = 0.10
const VISUAL_UPDATE_FAR_INTERVAL: float = 0.20
const VISUAL_UPDATE_OFFSCREEN_INTERVAL: float = 0.35
const VISUAL_UPDATE_FAR_DISTANCE_SQUARED: float = 900.0 * 900.0
const VISUAL_UPDATE_OFFSCREEN_MARGIN: float = 160.0
const ENEMY_NEIGHBOR_CHECK_INTERVAL: float = 0.1
const MAX_ENEMY_NEIGHBOR_CHECKS_PER_FRAME: int = 12
const MAX_NEARBY_ENEMY_CANDIDATES: int = 8

signal health_changed(current_health: int, max_health: int)
signal died


@export_range(0.0, 1000.0, 10.0, "or_greater") var move_speed: float = 120.0
@export_range(1, 1000, 1, "or_greater") var max_health: int = 30
@export_range(0, 1000, 1, "or_greater") var contact_damage: int = 10
@export_range(0.0, 2000.0, 1.0, "or_greater") var attack_range: float = 32.0
@export_range(0.05, 10.0, 0.05, "or_greater") var damage_interval: float = 0.5
@export_range(0, 10000, 1, "or_greater") var dropped_experience: int = 25
@export_range(0, 10000, 1, "or_greater") var soul_drop: int = 0
@export_range(0, 1000, 1, "or_greater") var armor: int = 0
@export var resistances: Dictionary = {}
@export var enemy_id: StringName = &"small_slime"
@export var load_config_from_data: bool = true
@export_range(0.01, 100.0, 0.01, "or_greater") var health_multiplier: float = 1.0
@export_range(0.01, 100.0, 0.01, "or_greater") var damage_multiplier: float = 1.0
@export_range(0.01, 100.0, 0.01, "or_greater") var move_speed_multiplier: float = 1.0
@export_range(0.01, 100.0, 0.01, "or_greater") var experience_multiplier: float = 1.0
@export var experience_crystal_scene: PackedScene = preload("res://scenes/drops/experience_crystal.tscn")
@export var enemy_projectile_scene: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")
@export var damage_area_scene: PackedScene = preload("res://scenes/combat/damage_area.tscn")
@export var target_group: StringName = &"player"
@export var target_path: NodePath

var target: Node2D
var current_health: int
var _damage_cooldown: float = 0.0
var _is_dead: bool = false
var _behavior: Dictionary = {}
var _enemy_skill_refs: Array[Dictionary] = []
var _death_effect: Dictionary = {}
var _death_policy: Dictionary = {}
var _shoot_cooldown: float = 0.0
var _ranged_warning_timer: float = 0.0
var _ranged_warning_direction: Vector2 = Vector2.RIGHT
var _fuse_timer: float = 0.0
var _is_fusing: bool = false
var _behavior_time: float = 0.0
var _summon_cooldown: float = 0.0
var _cast_cooldown: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_warning_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _special_attack_contact_blocked := false
var _special_attack_passes_target := false
var _dash_hit_targets: Dictionary = {}
var _attack_generation := 0
var _boss_skill_cooldowns: Dictionary = {}
var _visual_controller: RefCounted = EnemyVisualControllerScript.new()
var _debug_display_controller: RefCounted = EnemyDebugDisplayControllerScript.new()
var _status_display_controller: RefCounted = EnemyStatusDisplayControllerScript.new()
var _action_executor: RefCounted = EnemyActionExecutorScript.new()
var _reward_controller: RefCounted = EnemyRewardControllerScript.new()
var _attack_telegraph: RefCounted = EnemyAttackTelegraphScript.new()
var _status_facade: RefCounted = EnemyStatusFacadeScript.new()
var _death_pipeline: RefCounted = EnemyDeathPipelineScript.new()
var _behavior_controller: RefCounted = EnemyBehaviorControllerScript.new()
var _skill_controller: RefCounted = EnemySkillControllerScript.new()
var _support_buff_controller: RefCounted = preload("res://scripts/enemies/enemy_support_buff_controller.gd").new()
var _boss_mechanic_scheduler: RefCounted = preload("res://scripts/enemies/skills/boss_mechanic_scheduler.gd").new()
var _boss_ring_rng := RandomNumberGenerator.new()
var _state_controller: RefCounted = EnemyStateControllerScript.new()
var _visual_update_timer: float = 0.0
var _neighbor_check_timer: float = 0.0
static var _nearby_enemy_index_frame: int = -1
static var _nearby_enemy_index_tree_id: int = 0
static var _nearby_enemy_grid: Dictionary = {}
static var _nearby_enemy_total_count: int = 0
static var _enemy_profile_sections: Dictionary = {}
static var _neighbor_check_budget_frame: int = -1
static var _neighbor_checks_this_frame: int = 0


## 作用：注册目标并初始化视觉、奖励、状态、行为和技能组件，再载入敌人配置。
## 使用：生成服务须在 add_child 前设置 enemy_id 与倍率；Godot 入树回调最后初始化生命值并寻找玩家。
func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"enemies")
	_register_combat_target()
	_visual_controller.call("setup", self)
	_debug_display_controller.call("setup", self)
	_status_display_controller.call("setup", self)
	_action_executor.call("setup", self)
	_reward_controller.call("setup", self)
	_attack_telegraph.call("setup", self)
	_status_facade.call("setup", self)
	_state_controller.call("setup", self)
	if load_config_from_data:
		_apply_enemy_config()
	_behavior_controller.call("setup", self, _behavior)
	_skill_controller.call("setup", self, _enemy_skill_refs, _behavior)
	_support_buff_controller.call("setup", self)
	_boss_mechanic_scheduler.call("setup", self)
	if String(_behavior.get("type", "")) == "boss_dungeon_heart":
		_boss_ring_rng.seed = randi()
	_visual_update_timer = float(int(get_instance_id()) % 7) * 0.01
	_neighbor_check_timer = _neighbor_check_initial_offset()

	current_health = max_health
	health_changed.emit(current_health, max_health)
	target = _get_target_from_path()
	if target == null:
		target = _find_target_in_group()


## 作用：在节点离树时清理其注册关系。
## 使用：由 Godot 自动调用，避免服务继续持有已移除节点。
func _exit_tree() -> void:
	if not _is_dead:
		var tracker := RunStatsTracker.get_active(get_tree())
		if tracker!=null:
			tracker.record_monster_lifecycle(self,&"natural_escape" if String(get_meta("spawn_recycle_reason",""))=="natural_escape" else &"recycle",get_meta("spawn_request",{}))
	_boss_mechanic_scheduler.call("reset")
	_unregister_combat_target()


## 作用：推进本节点的物理帧更新流程。
## 使用：由 Godot 自动调用；delta 为自上一帧经过的秒数。
func _physics_process(delta: float) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_physics_process_profiled(delta)
	HotPathProfilerScript.end(self, &"enemy_update", hot_path_start)


## 作用：推进本节点的物理帧更新流程。
## 使用：由 _physics_process 调用；delta 为自上一帧经过的秒数。
func _physics_process_profiled(delta: float) -> void:
	if _is_dead:
		return
	if has_meta("treasure_lifetime") and not bool(get_meta("spawn_reveal_pending",false)):
		var remaining := float(get_meta("treasure_lifetime"))-delta
		set_meta("treasure_lifetime",remaining)
		if remaining<=0.00001:
			set_meta("spawn_recycle_reason",&"natural_escape")
			queue_free()
			return

	var profile_start: int = _profile_start()
	_update_enemy_runtime_tick(delta)
	_profile_add("runtime_tick", profile_start)
	var ai_hot_path_start: int = HotPathProfilerScript.begin(self)
	profile_start = _profile_start()
	_state_controller.call("update", delta)
	var debug_forced_state: String = _get_debug_enemy_forced_state()
	if debug_forced_state != "":
		_state_controller.call("set_forced_state", debug_forced_state)
		_apply_debug_forced_state(delta, debug_forced_state)
		_profile_add("debug_forced_state", profile_start)
		HotPathProfilerScript.end(self, &"enemy_ai_update", ai_hot_path_start)
		return
	_state_controller.call("clear_forced_state")
	if _is_debug_control_mode():
		_stop_motion_and_update_visual(delta)
		_profile_add("debug_control", profile_start)
		HotPathProfilerScript.end(self, &"enemy_ai_update", ai_hot_path_start)
		return

	if _is_movement_frozen():
		_stop_motion_and_update_visual(delta)
		_profile_add("movement_frozen", profile_start)
		HotPathProfilerScript.end(self, &"enemy_ai_update", ai_hot_path_start)
		return
	_profile_add("state_update", profile_start)

	profile_start = _profile_start()
	_behavior_time += delta
	_update_enemy_action_cooldowns(delta)
	_profile_add("cooldowns", profile_start)
	profile_start = _profile_start()
	_skill_controller.call("tick", delta)
	_profile_add("enemy_skill_tick", profile_start)

	profile_start = _profile_start()
	if not _resolve_current_target():
		_behavior_controller.call("cancel_pending_attack")
		if _is_fusing and String(_behavior.get("type", "")) == "explode_near_player":
			_update_behavior(delta)
		else:
			_stop_motion()
		_profile_add("resolve_target_missing", profile_start)
		HotPathProfilerScript.end(self, &"enemy_ai_update", ai_hot_path_start)
		return
	_profile_add("resolve_target", profile_start)

	if _should_skip_crowded_runtime_frame():
		HotPathProfilerScript.end(self, &"enemy_ai_update", ai_hot_path_start)
		var skipped_movement_start: int = HotPathProfilerScript.begin(self)
		velocity=EnemyMapBoundaryScript.limit_velocity(self,velocity,delta,_get_collision_radius(self,24.0))
		move_and_slide()
		HotPathProfilerScript.end(self, &"enemy_movement", skipped_movement_start)
		return

	profile_start = _profile_start()
	_update_behavior(delta)
	_profile_add("behavior", profile_start)
	HotPathProfilerScript.end(self, &"enemy_ai_update", ai_hot_path_start)

	profile_start = _profile_start()
	var should_limit_motion: bool = _should_limit_actor_motion()
	if should_limit_motion:
		_limit_actor_motion(delta, true, _should_run_neighbor_check(delta))
	_profile_add("motion_limit", profile_start)
	velocity=EnemyMapBoundaryScript.limit_velocity(self,velocity,delta,_get_collision_radius(self,24.0))
	var movement_hot_path_start: int = HotPathProfilerScript.begin(self)
	profile_start = _profile_start()
	move_and_slide()
	_profile_add("move_and_slide", profile_start)
	HotPathProfilerScript.end(self, &"enemy_movement", movement_hot_path_start)
	var animation_hot_path_start: int = HotPathProfilerScript.begin(self)
	profile_start = _profile_start()
	if _should_update_enemy_visual_state(delta):
		_update_enemy_visual_state(delta)
	_profile_add("visual", profile_start)
	HotPathProfilerScript.end(self, &"enemy_animation_update", animation_hot_path_start)

	var attack_hot_path_start: int = HotPathProfilerScript.begin(self)
	profile_start = _profile_start()
	_apply_contact_damage()
	_profile_add("contact_damage", profile_start)
	HotPathProfilerScript.end(self, &"enemy_attack_update", attack_hot_path_start)


## 作用：更新敌人运行时周期。
## 使用：本文件由 _physics_process_profiled 调用；输入 delta（delta）。
func _update_enemy_runtime_tick(delta: float) -> void:
	_support_buff_controller.call("tick", delta)
	_update_status_effects(delta)
	var status_visual_hot_path_start: int = HotPathProfilerScript.begin(self)
	_update_status_label()
	HotPathProfilerScript.end(self, &"enemy_status_visual_update", status_visual_hot_path_start)


## 作用：更新敌人动作冷却计时。
## 使用：本文件由 _physics_process_profiled 调用；输入 delta（delta）。
func _update_enemy_action_cooldowns(delta: float) -> void:
	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_shoot_cooldown = maxf(_shoot_cooldown - delta, 0.0)
	_summon_cooldown = maxf(_summon_cooldown - delta, 0.0)
	_cast_cooldown = maxf(_cast_cooldown - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)


## 作用：解析当前目标，供当前模块后续逻辑使用。
## 使用：本文件由 _physics_process_profiled 调用；返回是否满足条件或执行成功。
func _resolve_current_target() -> bool:
	if not is_instance_valid(target):
		target = _find_target_in_group()
	return target != null


## 作用：登记战斗目标；具体处理委托给 registry.register_enemy。
## 使用：本文件由 _ready 调用。
func _register_combat_target() -> void:
	var registry: Node = CombatTargetRegistryScript.get_or_create(self)
	if registry != null and registry.has_method("register_enemy"):
		registry.call("register_enemy", self)


## 作用：注销战斗目标；具体处理委托给 registry.unregister_enemy。
## 使用：本文件由 _exit_tree、_finish_death 调用。
func _unregister_combat_target() -> void:
	var registry: Node = CombatTargetRegistryScript.get_or_create(self)
	if registry != null and registry.has_method("unregister_enemy"):
		registry.call("unregister_enemy", self)


## 作用：停止移动。
## 使用：本文件由 _physics_process_profiled、_stop_motion_and_update_visual 调用。
func _stop_motion() -> void:
	_cancel_ranged_attack_warning()
	velocity = Vector2.ZERO
	move_and_slide()


## 作用：停止移动与更新视觉。
## 使用：本文件由 _physics_process_profiled 调用；输入 delta（delta）。
func _stop_motion_and_update_visual(delta: float) -> void:
	_stop_motion()
	_update_enemy_visual_state(delta)


## 作用：更新行为；具体处理委托给 _behavior_controller.tick。
## 使用：本文件由 _physics_process_profiled 调用；输入 delta（delta）。
func _update_behavior(delta: float) -> void:
	_behavior_controller.call("tick", delta)


## 作用：应用调试强制状态。
## 使用：本文件由 _physics_process_profiled 调用；输入 delta（delta）、forced_state（强制状态）。
func _apply_debug_forced_state(delta: float, forced_state: String) -> void:
	_cancel_ranged_attack_warning()
	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	if not is_instance_valid(target):
		target = _find_target_in_group()

	match forced_state:
		"idle":
			velocity = Vector2.ZERO
		"chase":
			_apply_debug_chase_movement()
		"attack":
			velocity = Vector2.ZERO
			_apply_range_attack_damage()
		"hurt", "dead":
			velocity = Vector2.ZERO
		_:
			velocity = Vector2.ZERO

	_limit_actor_motion(delta, true, true)
	move_and_slide()
	_update_enemy_visual_state(delta)


## 作用：应用调试追逐移动。
## 使用：本文件由 _apply_debug_forced_state 调用。
func _apply_debug_chase_movement() -> void:
	if target == null:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = global_position.direction_to(target.global_position)
	velocity = direction * _get_effective_move_speed()


## 作用：启动远程攻击预警；具体处理委托给 _attack_telegraph.show。
## 使用：内部辅助入口；输入 direction（方向）。
func _start_ranged_attack_warning(direction: Vector2) -> void:
	_record_attack_metric(&"ranged_warning",&"warning")
	_ranged_warning_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_ranged_warning_timer = maxf(float(_behavior.get("projectile_warning_time", 0.0)), 0.0)
	if _ranged_warning_timer > 0.0:
		_attack_telegraph.call("show", _ranged_warning_direction, _behavior, attack_range)


## 作用：取消远程攻击预警。
## 使用：本文件由 _stop_motion、_apply_debug_forced_state 调用。
func _cancel_ranged_attack_warning() -> void:
	if _ranged_warning_timer <= 0.0:
		_attack_telegraph.call("hide")
		return

	_ranged_warning_timer = 0.0
	_attack_telegraph.call("hide")


## 作用：显示远程攻击预警；具体处理委托给 _attack_telegraph.show。
## 使用：内部辅助入口。
func _show_ranged_attack_warning() -> void:
	_attack_telegraph.call("show", _ranged_warning_direction, _behavior, attack_range)


## 作用：显示突进攻击预警；具体处理委托给 _attack_telegraph.show。
## 使用：内部辅助入口。
func _show_dash_attack_warning() -> void:
	var warning_config := _behavior.duplicate(true)
	warning_config["projectile_warning_range"] = float(_behavior.get("dash_speed", 360.0)) * float(_behavior.get("dash_duration", 0.4))
	warning_config["projectile_warning_width"] = _get_collision_radius(self, 24.0) * 2.0
	_attack_telegraph.call("show", _dash_direction, warning_config, attack_range)


## 作用：隐藏攻击攻击预警；具体处理委托给 _attack_telegraph.hide。
## 使用：内部辅助入口。
func _hide_attack_telegraph() -> void:
	_attack_telegraph.call("hide")


## 作用：判断目标处于攻击范围内，返回布尔判断结果。
## 使用：内部辅助入口；输入 distance（距离）。
func _is_target_in_attack_range(distance: float = -1.0) -> bool:
	if target == null:
		return false

	var current_distance: float = distance
	if current_distance < 0.0:
		current_distance = global_position.distance_to(target.global_position)

	return current_distance <= attack_range


## 作用：判断目标处于行为攻击范围内，返回布尔判断结果。
## 使用：内部辅助入口；输入 distance（距离）。
func _is_target_in_behavior_attack_range(distance: float = -1.0) -> bool:
	if target == null:
		return false

	var current_distance: float = distance
	if current_distance < 0.0:
		current_distance = global_position.distance_to(target.global_position)

	return current_distance <= _get_behavior_attack_range()


## 作用：获取目标来源路径，供当前模块后续逻辑使用。
## 使用：本文件由 _ready 调用；返回 Node2D 对象/值。
func _get_target_from_path() -> Node2D:
	if target_path.is_empty():
		return null

	return get_node_or_null(target_path) as Node2D


## 作用：查找目标范围内分组，供当前模块后续逻辑使用。
## 使用：本文件由 _ready、_resolve_current_target、_apply_debug_forced_state 调用；返回 Node2D 对象/值。
func _find_target_in_group() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


## 作用：更新状态效果效果列表；具体处理委托给 _status_facade.update_status_effects。
## 使用：本文件由 _update_enemy_runtime_tick 调用；输入 delta（delta）。
func _update_status_effects(delta: float) -> void:
	_status_facade.call("update_status_effects", delta)


## 作用：更新状态效果标签。
## 使用：本文件由 _update_enemy_runtime_tick 调用。
func _update_status_label() -> void:
	if not bool(_status_facade.call("consume_status_display_dirty")):
		return
	_status_display_controller.call("update", get_status_snapshot())


## 作用：判断移动冻结，返回布尔判断结果；具体处理委托给 _status_facade.is_movement_frozen。
## 使用：本文件由 _physics_process_profiled 调用。
func _is_movement_frozen() -> bool:
	return bool(_status_facade.call("is_movement_frozen"))


## 作用：获取生效移动速度，供当前模块后续逻辑使用；具体处理委托给 _status_facade.get_effective_move_speed。
## 使用：本文件由 _apply_debug_chase_movement 调用；返回计算或读取的数值。
func _get_effective_move_speed() -> float:
	return float(_status_facade.call("get_effective_move_speed", move_speed)) * float(_support_buff_controller.call("get_move_speed_multiplier"))


## 作用：接触半径内按冷却伤害目标，并执行接触状态动作。
## 使用：在敌人物理更新末调用；突进期间可使用 dash_damage，成功发起攻击后重置接触冷却。
func _apply_contact_damage() -> void:
	if String(_behavior.get("type",""))=="flee_player": return
	if _is_dead or _special_attack_contact_blocked or _damage_cooldown > 0.0 or (_is_fusing and String(_behavior.get("type", "")) == "explode_near_player"):
		return

	var contact_target: Object = null
	if _is_target_touching_contact_radius():
		contact_target = target
	if contact_target == null or not contact_target.has_method("take_damage"):
		return
	if _dash_timer > 0.0:
		var target_id: int = contact_target.get_instance_id()
		if _dash_hit_targets.has(target_id):
			return
		_dash_hit_targets[target_id] = _attack_generation

	var applied_damage: int = int(_behavior.get("dash_damage", contact_damage)) if _dash_timer > 0.0 else contact_damage
	var attack_kind := "charge" if _dash_timer>0.0 else "contact"
	_record_attack_metric(StringName(attack_kind),&"attempt")
	contact_target.call(&"take_damage", _get_enemy_damage_packet(applied_damage, attack_kind))
	_execute_enemy_skill_action("contact_status", {"target": contact_target})
	_mark_runtime_state("attack", 0.2)
	_damage_cooldown = damage_interval


## 作用：判断目标接触接触半径，返回布尔判断结果。
## 使用：本文件由 _apply_contact_damage 调用。
func _is_target_touching_contact_radius() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var contact_radius: float = _get_contact_radius()
	return global_position.distance_squared_to(target.global_position) <= contact_radius * contact_radius


## 作用：接触只按双方碰撞半径计算，不使用攻击或施法距离。
func _get_contact_radius() -> float:
	return _get_collision_radius(self, 24.0) + _get_collision_radius(target, 24.0) + 2.0


## 作用：应用范围攻击伤害；具体处理委托给 target.take_damage。
## 使用：本文件由 _apply_debug_forced_state 调用。
func _apply_range_attack_damage() -> void:
	if _damage_cooldown > 0.0 or target == null:
		return

	if target.has_method("take_damage"):
		target.call(&"take_damage", _get_enemy_damage_packet(contact_damage, "ranged"))
		_mark_runtime_state("attack", 0.2)
		_damage_cooldown = damage_interval


## 作用：把严格 DamagePacket 交给统一敌人伤害应用服务。
## 使用：外部命中入口；不要传裸数字或直接修改 current_health。
func take_damage(packet: DamagePacket) -> void:
	DamageApplicationServiceScript.apply_enemy_damage(self, packet)


## 作用：应用状态效果；具体处理委托给 _status_facade.apply_status。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）、params（参数）；返回是否满足条件或执行成功。
func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
	return bool(_status_facade.call("apply_status", status_id, params))

## 作用：是否包含状态效果，返回布尔判断结果；具体处理委托给 _status_facade.has_status。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）。
func has_status(status_id: Variant) -> bool:
	return bool(_status_facade.call("has_status", status_id))

## 作用：获取状态效果叠层，供当前模块后续逻辑使用；具体处理委托给 _status_facade.get_status_stack。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）；返回计算或读取的数值。
func get_status_stack(status_id: Variant) -> int:
	return int(_status_facade.call("get_status_stack", status_id))

## 作用：消耗感电叠层；具体处理委托给 _status_facade.consume_shock_stack。
## 使用：供本模块调用者使用；返回是否满足条件或执行成功。
func consume_shock_stack() -> bool:
	return bool(_status_facade.call("consume_shock_stack"))

## 作用：消耗状态效果叠层；具体处理委托给 _status_facade.consume_status_stack。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）、stack_count（叠层数量）；返回是否满足条件或执行成功。
func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
	return bool(_status_facade.call("consume_status_stack", status_id, stack_count))

## 作用：判断死亡，返回布尔判断结果。
## 使用：供本模块调用者使用。
func is_dead() -> bool:
	return _is_dead

## 作用：获取状态效果快照，供当前模块后续逻辑使用；具体处理委托给 _status_facade.get_status_snapshot。
## 使用：本文件由 _update_status_label 调用；返回 Array[Dictionary] 列表。
func get_status_snapshot() -> Array[Dictionary]:
	return _status_facade.call("get_status_snapshot")

## 作用：清除状态效果组；具体处理委托给 _status_facade.clear_statuses。
## 使用：供本模块调用者使用。
func clear_statuses() -> void:
	_status_facade.call("clear_statuses")


## 作用：死亡。
## 使用：内部辅助入口。
func _die() -> void:
	_finish_death("damage")


## 作用：记录输出伤害；具体处理委托给 _reward_controller.record_damage_done。
## 使用：内部辅助入口；输入 amount（数量）、damage_result（伤害结果）、source_packet（来源伤害包）。
func _record_damage_done(amount: int, damage_result: Dictionary, source_packet: DamagePacket) -> void:
	_reward_controller.call("record_damage_done", amount, damage_result, source_packet)


## 作用：获取伤害来源键，供当前模块后续逻辑使用。
## 使用：内部辅助入口；输入 source_packet（来源伤害包）、damage_result（伤害结果）；返回 String 文本/标识。
func _get_damage_source_key(source_packet: DamagePacket, damage_result: Dictionary) -> String:
	for key: String in ["source_instance_id", "source_id", "source_skill_id", "attacker_id"]:
		var packet_value: String = String(source_packet.get_value(key, ""))
		if packet_value != "":
			return packet_value
	for key: String in ["source_instance_id", "source_id", "source_skill_id", "attacker_id"]:
		var result_value: String = String(damage_result.get(key, ""))
		if result_value != "":
			return result_value
	return "unknown"


## 作用：获取敌人伤害包，供当前模块后续逻辑使用。
## 使用：本文件由 _apply_contact_damage、_apply_range_attack_damage 调用；输入 amount（数量）、source_kind（来源类型）；返回 DamagePacket 对象/值。
func _get_enemy_damage_packet(amount: int, source_kind: String) -> DamagePacket:
	return EnemyDamagePacketBuilderScript.build(self, amount, source_kind, StringName(source_kind), {
		"target": target,
		"source_id": source_kind,
		"damage_origin": "primary_attack",
		"damage_type": "direct_physical",
		"element": "physical"
	})


## 作用：先执行爆炸，再以 self_explosion 原因结束生命。
## 使用：爆炸失败或已经死亡返回 false；成功后按自爆奖励策略进入死亡流水线。
func _run_self_explosion_action() -> bool:
	if _is_dead:
		return false
	var explosion := _behavior.duplicate(true)
	explosion["source_skill_id"]=_skill_controller.call("get_skill_id_for_action","self_explode",&"bug_explosion")
	if not bool(_action_executor.call("explode", explosion)):
		return false
	_finish_death("self_explosion")
	return true


## 作用：注销战斗目标并按原因构建死亡上下文，交给死亡流水线。
## 使用：已死亡时直接返回；cause 为 damage 或 self_explosion 等原因。
func _finish_death(cause: String = "damage") -> void:
	_support_buff_controller.call("clear")
	_behavior_controller.call("cancel_pending_attack")
	_boss_mechanic_scheduler.call("reset")
	if _is_dead:
		return

	_unregister_combat_target()
	var tracker := RunStatsTracker.get_active(get_tree())
	if tracker!=null:
		tracker.record_monster_lifecycle(self,&"death",get_meta("spawn_request",{}))
		tracker.record_enemy_attack_event(enemy_id,StringName(cause),&"death_cause",false)
	var context: Dictionary = EnemyDeathContextScript.create(cause, _get_death_policy(cause), {
		"enemy_id": String(enemy_id),
		"spawn_source_type": String(get_meta("spawn_source_type", "unknown")),
		"enemy_rank": String(get_meta("enemy_rank", "normal")),
		"source_key": String(get_meta("last_damage_source_key", "unknown"))
	})
	_death_pipeline.call("execute", self, context)


## 作用：获取死亡策略，供当前模块后续逻辑使用。
## 使用：本文件由 _finish_death 调用；输入 cause（原因）；返回结果字典。
func _get_death_policy(cause: String) -> Dictionary:
	var policy: Dictionary = _get_default_death_policy(cause)
	_merge_death_policy(policy, _get_dictionary(_death_policy.get("default", {})))
	_merge_death_policy(policy, _get_dictionary(_death_policy.get(cause, {})))
	return policy

func _record_attack_metric(skill_id: StringName,phase: StringName) -> void:
	var tracker := RunStatsTracker.get_active(get_tree())
	if tracker!=null: tracker.record_enemy_attack_event(enemy_id,skill_id,phase,false)


## 作用：获取默认死亡策略，供当前模块后续逻辑使用。
## 使用：本文件由 _get_death_policy 调用；输入 cause（原因）；返回字典包含 play_death_visual/record_boss_core/award_soul/notify_kill_events/emit_died_signal/run_death_effect/drop_experience。
func _get_default_death_policy(cause: String) -> Dictionary:
	if cause == "self_explosion":
		return {
			"play_death_visual": false,
			"record_boss_core": false,
			"award_soul": false,
			"notify_kill_events": true,
			"emit_died_signal": true,
			"run_death_effect": false,
			"drop_experience": false
		}
	return {
		"play_death_visual": true,
		"record_boss_core": true,
		"award_soul": true,
		"notify_kill_events": true,
		"emit_died_signal": true,
		"run_death_effect": true,
		"drop_experience": true
	}


## 作用：合并死亡策略。
## 使用：本文件由 _get_death_policy 调用；输入 target_policy（目标策略）、override_policy（override策略）。
func _merge_death_policy(target_policy: Dictionary, override_policy: Dictionary) -> void:
	for key: Variant in override_policy.keys():
		target_policy[String(key)] = override_policy[key]


## 作用：应用死亡效果；具体处理委托给 _action_executor.apply_death_effect。
## 使用：内部辅助入口。
func _apply_death_effect() -> void:
	_action_executor.call("apply_death_effect", _death_effect)


## 作用：生成敌人组周围；具体处理委托给 _action_executor.spawn_enemies_around。
## 使用：内部辅助入口；输入 spawn_enemy_id（生成敌人ID）、count（数量）、center（中心）、radius（半径）。
func _spawn_enemies_around(spawn_enemy_id: StringName, count: int, center: Vector2, radius: float = 48.0) -> int:
	return int(_action_executor.call("spawn_enemies_around", spawn_enemy_id, count, center, radius))

func _get_owned_summon_count() -> int:
	var count := int(_action_executor.call("get_pending_summon_count"))
	for child: Node in get_tree().get_nodes_in_group(&"enemies"):
		if child.get_meta("summoner_instance_id", 0) == get_instance_id() and not child.is_queued_for_deletion() and child.get("_is_dead") != true:
			count += 1
	return count


## 作用：生成腐化核心列表；具体处理委托给 _action_executor.spawn_corrupted_cores。
## 使用：内部辅助入口；输入 count（数量）、hp（生命值）；返回是否满足条件或执行成功。
func _spawn_corrupted_cores(count: int, hp: int) -> bool:
	return bool(_action_executor.call("spawn_corrupted_cores", count, hp))


## 作用：更新Boss技能冷却计时。
## 使用：内部辅助入口；输入 delta（delta）。
func _update_boss_skill_cooldowns(delta: float) -> void:
	_boss_mechanic_scheduler.call("tick", delta)
	for key: Variant in _boss_skill_cooldowns.keys():
		_boss_skill_cooldowns[key] = maxf(float(_boss_skill_cooldowns[key]) - delta, 0.0)


## 作用：按当前血量阶段的并发上限与独立冷却请求 Boss 技能。
## 使用：只对本阶段冷却已结束的技能尝试执行；成功后记录冷却，不吞失败重试机会。
func _process_boss_phase_skills() -> void:
	var phase: Dictionary = _get_active_boss_phase()
	var skills: Array = _get_array(phase.get("skills", []))
	var active_cap: int = maxi(int(phase.get("max_concurrent_skills", 1)), 1)
	for skill_index in range(skills.size()):
		var skill_variant: Variant = skills[skill_index]
		if not (skill_variant is Dictionary):
			continue

		var skill: Dictionary = skill_variant
		var cooldown_key: String = String(skill.get("skill_id", ""))
		if float(_boss_skill_cooldowns.get(cooldown_key, 0.0)) > 0.0:
			continue

		var group: StringName = &"area_denial" if String(skill.get("type", "")) in ["delayed_area_blast", "corruption_gaze", "shockwave", "damage_area"] else &"projectiles"
		var token: int = _boss_mechanic_scheduler.call("try_reserve", StringName(cooldown_key), group, active_cap)
		if token < 0:
			continue
		if _execute_boss_skill(skill, token):
			_boss_mechanic_scheduler.call("commit", token)
			_boss_skill_cooldowns[cooldown_key] = maxf(float(skill.get("cooldown", 5.0)), 0.1)
		else:
			_boss_mechanic_scheduler.call("cancel", token)


## 作用：按当前生命值比例选取首个包含该比例的阶段。
## 使用：返回附带 _phase_index 的配置深拷贝；无阶段匹配返回空字典。
func _get_active_boss_phase() -> Dictionary:
	var phases: Array = _get_array(_behavior.get("phases", []))
	if phases.is_empty():
		return {}

	var hp_percent: float = float(current_health) / maxf(float(max_health), 1.0)
	for phase_index in range(phases.size()):
		var phase_variant: Variant = phases[phase_index]
		if not (phase_variant is Dictionary):
			continue

		var phase: Dictionary = phase_variant
		var min_hp: float = float(phase.get("hp_percent_min", 0.0))
		var max_hp: float = float(phase.get("hp_percent_max", 1.0))
		if hp_percent >= min_hp and hp_percent <= max_hp:
			var active_phase: Dictionary = phase.duplicate(true)
			active_phase["_phase_index"] = phase_index
			return active_phase

	return {}


## 作用：执行Boss技能。
## 使用：本文件由 _process_boss_phase_skills 调用；输入 skill（技能）；返回是否满足条件或执行成功。
func _execute_boss_skill(skill: Dictionary, mechanic_token: int = -1) -> bool:
	var skill_id: StringName = StringName(String(skill.get("skill_id", "")))
	if skill_id == &"":
		push_warning("[EnemyBase] Boss phase skill is missing skill_id for enemy '%s'" % String(enemy_id))
		return false
	var runtime_params: Dictionary = {
		"boss_skill": skill,
		"position": _get_boss_skill_target_position(skill),
		"mechanic_scheduler": _boss_mechanic_scheduler,
		"mechanic_token": mechanic_token
	}
	var executed: bool = bool(_skill_controller.call("execute_skill_id", skill_id, runtime_params))
	if executed:
		_mark_runtime_state("attack", 0.2)
	return executed


## 作用：获取Boss技能目标位置，供当前模块后续逻辑使用。
## 使用：本文件由 _execute_boss_skill 调用；输入 skill（技能）；返回 Vector2 对象/值。
func _get_boss_skill_target_position(skill: Dictionary) -> Vector2:
	match String(skill.get("type", "")):
		"shockwave", "corrupted_cores", "ring_projectiles", "summon", "shield_orbs":
			return global_position
		_:
			return target.global_position if target != null else global_position


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 _process_boss_phase_skills、_get_active_boss_phase 调用；输入 value（值）。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value

	return []


## 作用：更新引信视觉。
## 使用：内部辅助入口。
func _update_fuse_visual() -> void:
	var sprite: CanvasItem = get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sprite == null or not sprite.visible:
		sprite = get_node_or_null("Sprite2D") as CanvasItem
	if sprite == null:
		return

	var pulse: float = 0.65 + absf(sin(_fuse_timer * 18.0)) * 0.45
	sprite.modulate = Color(1.0, pulse, 0.18, 1.0)
	var warning: Node2D = get_node_or_null("FuseTelegraph") as Node2D
	if warning == null:
		warning = EnemyAreaTelegraphScript.new()
		warning.name = "FuseTelegraph"
		add_child(warning)
		warning.call("configure", &"circle", {"radius": float(_behavior.get("explosion_radius", 76.0))})
	warning.call("set_progress", _fuse_timer / maxf(float(_behavior.get("fuse_time", 0.8)), 0.05))


## 作用：掉落经验晶体。
## 使用：内部辅助入口。
func _drop_experience_crystal() -> void:
	var parent: Node = get_parent()
	if dropped_experience <= 0 or experience_crystal_scene == null or parent == null:
		return

	var crystal: Node2D = _spawn_experience_crystal(parent)
	if crystal == null:
		return

	crystal.global_position = global_position

	if crystal.has_method("prepare_for_pool_spawn"):
		crystal.call(&"prepare_for_pool_spawn", dropped_experience)
	elif crystal.has_method("set_experience_amount"):
		crystal.call(&"set_experience_amount", dropped_experience)


## 作用：生成经验晶体。
## 使用：本文件由 _drop_experience_crystal 调用；输入 parent（父节点）；返回 Node2D 对象/值。
func _spawn_experience_crystal(parent: Node) -> Node2D:
	var pool: Node = RuntimePoolRegistryScript.get_or_create(parent)
	if pool != null and pool.has_method("spawn"):
		return pool.call("spawn", _experience_crystal_pool_key(), Callable(self, "_instantiate_experience_crystal"), parent) as Node2D
	var crystal: Node2D = _instantiate_experience_crystal() as Node2D
	if crystal != null:
		if Engine.is_in_physics_frame():
			parent.call_deferred("add_child", crystal)
		else:
			parent.add_child(crystal)
	return crystal


## 作用：实例化经验晶体。
## 使用：本文件由 _spawn_experience_crystal 调用；返回 Node 对象/值。
func _instantiate_experience_crystal() -> Node:
	return experience_crystal_scene.instantiate() if experience_crystal_scene != null else null


## 作用：经验晶体池键。
## 使用：本文件由 _spawn_experience_crystal 调用；返回 StringName 文本/标识。
func _experience_crystal_pool_key() -> StringName:
	var scene_path: String = experience_crystal_scene.resource_path if experience_crystal_scene != null else "anonymous"
	if scene_path == "":
		scene_path = "anonymous"
	return StringName("pickup_scene:%s" % scene_path)


## 作用：应用敌人配置。
## 使用：本文件由 _ready 调用。
func _apply_enemy_config() -> void:
	var enemy_config: Dictionary = GameData.get_enemy(enemy_id)
	if enemy_config.is_empty():
		return

	var base_stats: Variant = enemy_config.get("base_stats", {})
	if not (base_stats is Dictionary):
		return

	_behavior = _get_dictionary(enemy_config.get("behavior", {}))
	_enemy_skill_refs = _get_dictionary_array(enemy_config.get("skills", []))
	_death_effect = _get_dictionary(enemy_config.get("death_effect", {}))
	_death_policy = _get_dictionary(enemy_config.get("death_policy", {}))
	var stats: Dictionary = base_stats
	max_health = int(stats.get("max_hp", max_health))
	move_speed = float(stats.get("move_speed", move_speed))
	contact_damage = int(stats.get("contact_damage", contact_damage))
	damage_interval = maxf(float(stats["contact_interval"]), 0.05)
	armor = int(stats.get("armor", armor))
	armor += int(get_meta("defense_add", 0))
	resistances = _get_dictionary(stats.get("resistances", resistances))
	attack_range = float(stats.get("attack_range", _get_behavior_attack_range_fallback()))
	dropped_experience = int(stats.get("exp_drop", dropped_experience))
	soul_drop = int(stats.get("soul_drop", soul_drop))
	max_health = maxi(roundi(float(max_health) * health_multiplier), 1)
	contact_damage = maxi(roundi(float(contact_damage) * damage_multiplier), 0)
	move_speed = maxf(move_speed * move_speed_multiplier, 1.0)
	dropped_experience = maxi(roundi(float(dropped_experience) * experience_multiplier), 0)
	set_meta("enemy_id", enemy_id)
	_apply_classification_metadata(enemy_config)
	if _behavior.has("projectile_damage"):
		_behavior["projectile_damage"] = maxi(roundi(float(_behavior["projectile_damage"]) * damage_multiplier), 0)
	if _behavior.has("explosion_damage"):
		_behavior["explosion_damage"] = maxi(roundi(float(_behavior["explosion_damage"]) * damage_multiplier), 0)
	if _death_effect.has("damage"):
		_death_effect["damage"] = maxi(roundi(float(_death_effect["damage"]) * damage_multiplier), 0)
	_apply_visual_config(enemy_config)

	var collision_radius: float = float(stats.get("collision_radius", 0.0))
	if collision_radius > 0.0:
		_apply_collision_radius(collision_radius)


## 作用：取得敌人配置字典的独立深拷贝。
## 使用：转发 EnemyConfigHelper.duplicate_dictionary；类型非法返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	return EnemyConfigHelperScript.duplicate_dictionary(value)


## 作用：获取字典数组，供当前模块后续逻辑使用。
## 使用：本文件由 _apply_enemy_config 调用；输入 value（值）；返回 Array[Dictionary] 列表。
func _get_dictionary_array(value: Variant) -> Array[Dictionary]:
	return EnemyConfigHelperScript.duplicate_dictionary_array(value)


## 作用：执行敌方技能动作；具体处理委托给 _skill_controller.execute_action_type。
## 使用：本文件由 _apply_contact_damage 调用；输入 action_type（动作类型）、runtime_params（运行时参数）；返回是否满足条件或执行成功。
func _execute_enemy_skill_action(action_type: String, runtime_params: Dictionary = {}) -> bool:
	var executed: bool = bool(_skill_controller.call("execute_action_type", action_type, runtime_params))
	if executed and not _is_dead and action_type != "contact_status":
		_mark_runtime_state("attack", 0.2)
	return executed


## 作用：标记运行时状态；具体处理委托给 _state_controller.mark。
## 使用：本文件由 _apply_contact_damage、_apply_range_attack_damage、_execute_boss_skill 调用；输入 state（状态）、duration（持续时间）。
func _mark_runtime_state(state: String, duration: float) -> void:
	_state_controller.call("mark", state, duration)


## 作用：显示受击视觉。
## 使用：内部辅助入口。
func _show_hurt_visual() -> void:
	_mark_runtime_state("hurt", 0.12)


## 作用：获取运行时状态，供当前模块后续逻辑使用；具体处理委托给 _state_controller.get_snapshot。
## 使用：供本模块调用者使用；返回 String 文本/标识。
func get_runtime_state() -> String:
	return String(_state_controller.call("get_snapshot").get("state", "idle"))


## 作用：获取运行时状态快照，供当前模块后续逻辑使用；具体处理委托给 _state_controller.get_snapshot。
## 使用：供本模块调用者使用；返回结果字典。
func get_runtime_state_snapshot() -> Dictionary:
	return _state_controller.call("get_snapshot")


## 作用：获取行为类型，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 String 文本/标识。
func get_behavior_type() -> String:
	return String(_behavior.get("type", ""))


## 作用：获取敌方技能冷却，供当前模块后续逻辑使用；具体处理委托给 _skill_controller.get_cooldown_for_action。
## 使用：内部辅助入口；输入 action_type（动作类型）、fallback（回退）；返回计算或读取的数值。
func _get_enemy_skill_cooldown(action_type: String, fallback: float) -> float:
	return float(_skill_controller.call("get_cooldown_for_action", action_type, fallback))


## 作用：应用分类元数据。
## 使用：本文件由 _apply_enemy_config 调用；输入 enemy_config（敌人配置）。
func _apply_classification_metadata(enemy_config: Dictionary) -> void:
	EnemyConfigHelperScript.apply_classification_metadata(self, enemy_config)


## 作用：获取行为攻击范围回退，供当前模块后续逻辑使用。
## 使用：本文件由 _apply_enemy_config 调用；返回计算或读取的数值。
func _get_behavior_attack_range_fallback() -> float:
	return EnemyConfigHelperScript.behavior_attack_range_fallback(_behavior, attack_range)


## 作用：获取行为攻击范围，供当前模块后续逻辑使用。
## 使用：本文件由 _is_target_in_behavior_attack_range 调用；返回计算或读取的数值。
func _get_behavior_attack_range() -> float:
	return EnemyConfigHelperScript.behavior_attack_range(_behavior, attack_range)


## 作用：应用碰撞半径。
## 使用：本文件由 _apply_enemy_config 调用；输入 radius（半径）。
func _apply_collision_radius(radius: float) -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return

	if collision_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		circle_shape.radius = radius


## 作用：限制实体移动。
## 使用：本文件由 _physics_process_profiled、_apply_debug_forced_state 调用；输入 delta（delta）、include_player（include玩家）、include_enemy_neighbors（include敌人neighbors）。
func _limit_actor_motion(delta: float, include_player: bool = false, include_enemy_neighbors: bool = true) -> void:
	if velocity.length_squared() <= 0.01 or delta <= 0.0:
		return

	var motion: Vector2 = velocity * delta
	var scale: float = 1.0
	if include_player and not _special_attack_passes_target and target != null and is_instance_valid(target):
		scale = minf(scale, _get_actor_motion_scale(motion, target))
	if not include_enemy_neighbors or _should_skip_enemy_neighbor_motion_limit():
		if scale < 1.0:
			velocity *= maxf(scale, 0.0)
		return
	var query_radius: float = maxf(
		motion.length() + _get_collision_radius(self, 24.0) + MOTION_LIMIT_EXTRA_RADIUS,
		NEARBY_ENEMY_CELL_SIZE
	)
	for enemy: Node2D in _nearby_enemies(global_position, query_radius, MAX_NEARBY_ENEMY_CANDIDATES):
		scale = minf(scale, _get_actor_motion_scale(motion, enemy))
	if scale < 1.0:
		velocity *= maxf(scale, 0.0)


## 作用：是否需要限制实体移动，返回布尔判断结果。
## 使用：本文件由 _physics_process_profiled 调用。
func _should_limit_actor_motion() -> bool:
	if velocity.length_squared() <= 0.01:
		return false
	if _is_strong_enemy():
		return true
	if target != null and is_instance_valid(target):
		if global_position.distance_squared_to(target.global_position) <= MOTION_LIMIT_ALWAYS_DISTANCE_SQUARED:
			return true
	return true


## 作用：是否需要跳过敌人邻居移动限制，返回布尔判断结果。
## 使用：本文件由 _limit_actor_motion 调用。
func _should_skip_enemy_neighbor_motion_limit() -> bool:
	return not _is_strong_enemy() and _is_crowded_enemy_lod_active()


## 作用：是否需要跳过近战邻居逻辑，返回布尔判断结果。
## 使用：内部辅助入口。
func _should_skip_melee_neighbor_logic() -> bool:
	return not _is_strong_enemy() and not _should_run_neighbor_check(0.0)


## 作用：是否需要跳过拥挤运行时帧，返回布尔判断结果。
## 使用：本文件由 _physics_process_profiled 调用。
func _should_skip_crowded_runtime_frame() -> bool:
	if _is_strong_enemy() or target == null or not is_instance_valid(target):
		return false
	if velocity.length_squared() <= 0.01:
		return false
	_ensure_nearby_enemy_index()
	if _nearby_enemy_total_count < HEAVY_CROWD_RUNTIME_SKIP_THRESHOLD:
		return false
	if global_position.distance_squared_to(target.global_position) <= CROWDED_RUNTIME_SKIP_DISTANCE_SQUARED:
		return false

	var throttle_frames: int = 2 if _nearby_enemy_total_count < HEAVY_CROWD_ENEMY_LOD_THRESHOLD else 3
	var frame: int = int(Engine.get_physics_frames())
	return frame % throttle_frames != int(get_instance_id()) % throttle_frames


## 作用：判断拥挤敌人更新降频活跃，返回布尔判断结果。
## 使用：本文件由 _should_skip_enemy_neighbor_motion_limit 调用。
func _is_crowded_enemy_lod_active() -> bool:
	_ensure_nearby_enemy_index()
	return _nearby_enemy_total_count >= CROWDED_ENEMY_LOD_THRESHOLD


## 作用：附近敌人组。
## 使用：本文件由 _limit_actor_motion 调用；输入 center（中心）、radius（半径）、max_results（上限results）；返回 Array[Node2D] 列表。
func _nearby_enemies(center: Vector2, radius: float, max_results: int = 0) -> Array[Node2D]:
	var neighbor_hot_path_start: int = HotPathProfilerScript.begin(self)
	_ensure_nearby_enemy_index()
	var result: Array[Node2D] = []
	var query_radius: float = maxf(radius, 0.0)
	var radius_squared: float = query_radius * query_radius
	var center_cell: Vector2i = _enemy_spatial_cell(center)
	var cell_radius: int = maxi(ceili(query_radius / NEARBY_ENEMY_CELL_SIZE), 1)
	for cell_x: int in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for cell_y: int in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			var bucket: Array = _nearby_enemy_grid.get(cell, [])
			for item: Variant in bucket:
				var enemy: Node2D = item as Node2D
				if enemy == null or enemy == self or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
					continue
				if enemy.global_position.distance_squared_to(center) <= radius_squared:
					result.append(enemy)
					if max_results > 0 and result.size() >= max_results:
						HotPathProfilerScript.end(self, &"enemy_neighbor_check", neighbor_hot_path_start)
						return result
	HotPathProfilerScript.end(self, &"enemy_neighbor_check", neighbor_hot_path_start)
	return result


## 作用：是否需要单局邻居检查，返回布尔判断结果。
## 使用：本文件由 _physics_process_profiled、_should_skip_melee_neighbor_logic 调用；输入 delta（delta）。
func _should_run_neighbor_check(delta: float) -> bool:
	if _is_strong_enemy():
		return true
	_neighbor_check_timer = maxf(_neighbor_check_timer - maxf(delta, 0.0), 0.0)
	if _neighbor_check_timer > 0.0:
		return false
	if not _try_consume_neighbor_check_budget():
		return false
	_reset_neighbor_check_timer()
	return true


## 作用：重置邻居检查计时器。
## 使用：本文件由 _should_run_neighbor_check 调用。
func _reset_neighbor_check_timer() -> void:
	_neighbor_check_timer = ENEMY_NEIGHBOR_CHECK_INTERVAL + _neighbor_check_initial_offset() * 0.25


## 作用：邻居检查初始偏移。
## 使用：本文件由 _ready、_reset_neighbor_check_timer 调用；返回计算或读取的数值。
func _neighbor_check_initial_offset() -> float:
	return float(int(get_instance_id()) % 100) / 100.0 * ENEMY_NEIGHBOR_CHECK_INTERVAL


## 作用：尝试消耗邻居检查预算。
## 使用：本文件由 _should_run_neighbor_check 调用；返回是否满足条件或执行成功。
func _try_consume_neighbor_check_budget() -> bool:
	var frame: int = int(Engine.get_physics_frames())
	if _neighbor_check_budget_frame != frame:
		_neighbor_check_budget_frame = frame
		_neighbor_checks_this_frame = 0
	if _neighbor_checks_this_frame >= MAX_ENEMY_NEIGHBOR_CHECKS_PER_FRAME:
		return false
	_neighbor_checks_this_frame += 1
	return true


## 作用：确保附近敌人索引。
## 使用：本文件由 _should_skip_crowded_runtime_frame、_is_crowded_enemy_lod_active、_nearby_enemies 调用。
func _ensure_nearby_enemy_index() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		_nearby_enemy_grid.clear()
		_nearby_enemy_index_frame = -1
		_nearby_enemy_index_tree_id = 0
		return
	var frame: int = int(Engine.get_physics_frames())
	var tree_id: int = int(tree.get_instance_id())
	if Engine.is_in_physics_frame() and _nearby_enemy_index_frame == frame and _nearby_enemy_index_tree_id == tree_id:
		return
	_nearby_enemy_grid.clear()
	_nearby_enemy_total_count = 0
	_nearby_enemy_index_frame = frame
	_nearby_enemy_index_tree_id = tree_id
	var registry: Node = CombatTargetRegistryScript.get_or_create(self)
	var targets: Array = registry.call("get_targets", &"enemies") if registry != null and registry.has_method("get_targets") else []
	for target_variant: Variant in targets:
		var enemy: Node2D = target_variant as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		var cell: Vector2i = _enemy_spatial_cell(enemy.global_position)
		var bucket: Array = _nearby_enemy_grid.get(cell, [])
		bucket.append(enemy)
		_nearby_enemy_grid[cell] = bucket
		_nearby_enemy_total_count += 1


## 作用：敌人空间网格。
## 使用：本文件由 _nearby_enemies、_ensure_nearby_enemy_index 调用；输入 position（位置）；返回 Vector2i 对象/值。
static func _enemy_spatial_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / NEARBY_ENEMY_CELL_SIZE),
		floori(position.y / NEARBY_ENEMY_CELL_SIZE)
	)


## 作用：获取敌人性能采样快照，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 reset（重置）；返回结果字典。
func get_enemy_profile_snapshot(reset: bool = true) -> Dictionary:
	var snapshot: Dictionary = _enemy_profile_sections.duplicate(true)
	if reset:
		_enemy_profile_sections.clear()
	return snapshot


## 作用：性能采样启动。
## 使用：本文件由 _physics_process_profiled 调用；返回计算或读取的数值。
func _profile_start() -> int:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null or not bool(tree.root.get_meta("profile_enemy_physics", false)):
		return 0
	return Time.get_ticks_usec()


## 作用：性能采样添加。
## 使用：本文件由 _physics_process_profiled 调用；输入 section（段）、start_usec（启动usec）。
func _profile_add(section: String, start_usec: int) -> void:
	if start_usec <= 0:
		return
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var record: Dictionary = _enemy_profile_sections.get(section, {"usec": 0, "count": 0})
	record["usec"] = int(record.get("usec", 0)) + elapsed_usec
	record["count"] = int(record.get("count", 0)) + 1
	_enemy_profile_sections[section] = record


## 作用：获取实体移动缩放，供当前模块后续逻辑使用。
## 使用：本文件由 _limit_actor_motion 调用；输入 motion（移动）、blocker（blocker）；返回计算或读取的数值。
func _get_actor_motion_scale(motion: Vector2, blocker: Node2D) -> float:
	var radius: float = _get_collision_radius(self, 24.0) + _get_collision_radius(blocker, 24.0) + 2.0
	var offset: Vector2 = global_position - blocker.global_position
	var a: float = motion.length_squared()
	if a <= 0.01:
		return 1.0
	var c: float = offset.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0 if offset.dot(motion) < 0.0 else 1.0
	var b: float = 2.0 * offset.dot(motion)
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return 1.0
	var t: float = (-b - sqrt(discriminant)) / (2.0 * a)
	return clampf(t, 0.0, 1.0) if t >= 0.0 and t <= 1.0 else 1.0


## 作用：获取碰撞半径，供当前模块后续逻辑使用。
## 使用：本文件由 _is_target_touching_contact_radius、_limit_actor_motion、_get_actor_motion_scale 调用；输入 node（节点）、fallback（回退）；返回计算或读取的数值。
func _get_collision_radius(node: Node2D, fallback: float) -> float:
	var collision_shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return maxf((collision_shape.shape as CircleShape2D).radius, 0.0)
	return fallback


## 作用：应用视觉配置；具体处理委托给 _visual_controller.apply_enemy_config。
## 使用：本文件由 _apply_enemy_config 调用；输入 enemy_config（敌人配置）。
func _apply_visual_config(enemy_config: Dictionary) -> void:
	_visual_controller.call("apply_enemy_config", enemy_config)


## 作用：更新敌人视觉状态。
## 使用：本文件由 _physics_process_profiled、_stop_motion_and_update_visual、_apply_debug_forced_state 调用；输入 delta（delta）。
func _update_enemy_visual_state(delta: float) -> void:
	var state: Dictionary = _state_controller.call("get_snapshot")
	state["status_state"] = _get_priority_status_visual_state()
	_visual_controller.call("update", state, delta)


## 作用：是否需要更新敌人视觉状态，返回布尔判断结果。
## 使用：本文件由 _physics_process_profiled 调用；输入 delta（delta）。
func _should_update_enemy_visual_state(delta: float) -> bool:
	var interval: float = _get_enemy_visual_update_interval()
	if interval <= 0.0:
		return true

	_visual_update_timer -= delta
	if _visual_update_timer > 0.0:
		return false

	_visual_update_timer = interval + float(int(get_instance_id()) % 5) * 0.003
	return true


## 作用：获取敌人视觉更新间隔，供当前模块后续逻辑使用。
## 使用：本文件由 _should_update_enemy_visual_state 调用；返回计算或读取的数值。
func _get_enemy_visual_update_interval() -> float:
	if not _is_normal_enemy():
		return 0.0
	if _is_offscreen_for_visual_update():
		return VISUAL_UPDATE_OFFSCREEN_INTERVAL
	_ensure_nearby_enemy_index()
	if target != null and is_instance_valid(target):
		var distance_squared: float = global_position.distance_squared_to(target.global_position)
		if distance_squared > VISUAL_UPDATE_FAR_DISTANCE_SQUARED:
			return VISUAL_UPDATE_FAR_INTERVAL
	if _nearby_enemy_total_count >= HEAVY_CROWD_ENEMY_LOD_THRESHOLD:
		return VISUAL_UPDATE_HEAVY_CROWD_INTERVAL
	if _nearby_enemy_total_count >= CROWDED_ENEMY_LOD_THRESHOLD:
		return VISUAL_UPDATE_CROWDED_INTERVAL
	return 0.0


## 作用：判断屏幕外对应视觉更新，返回布尔判断结果。
## 使用：本文件由 _get_enemy_visual_update_interval 调用。
func _is_offscreen_for_visual_update() -> bool:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var visible_rect: Rect2 = viewport.get_visible_rect().grow(VISUAL_UPDATE_OFFSCREEN_MARGIN)
	var screen_position: Vector2 = viewport.get_canvas_transform() * global_position
	return not visible_rect.has_point(screen_position)


## 作用：获取优先级状态效果视觉状态，供当前模块后续逻辑使用。
## 使用：本文件由 _update_enemy_visual_state 调用；返回 String 文本/标识。
func _get_priority_status_visual_state() -> String:
	return ""


## 作用：更新调试生命值展示；具体处理委托给 _debug_display_controller.update_health。
## 使用：内部辅助入口。
func _update_debug_health_display() -> void:
	_debug_display_controller.call("update_health", current_health, max_health)


## 作用：显示调试伤害数值；具体处理委托给 _debug_display_controller.show_damage_number。
## 使用：内部辅助入口；输入 amount（数量）、damage_result（伤害结果）。
func _show_debug_damage_number(amount: int, damage_result: Dictionary = {}) -> void:
	_debug_display_controller.call("show_damage_number", amount, damage_result)


## 作用：发放灵魂石；具体处理委托给 _reward_controller.award_soul_stones。
## 使用：内部辅助入口。
func _award_soul_stones() -> void:
	_reward_controller.call("award_soul_stones")


## 作用：应用伤害协同；具体处理委托给 _reward_controller.apply_damage_synergies。
## 使用：内部辅助入口；输入 amount（数量）、damage_type（伤害类型）；返回计算或读取的数值。
func _apply_damage_synergies(amount: int, damage_type: Variant) -> int:
	return int(_reward_controller.call("apply_damage_synergies", amount, damage_type))


## 作用：通知敌人击杀协同；具体处理委托给 _reward_controller.notify_enemy_killed_synergies。
## 使用：内部辅助入口。
func _notify_enemy_killed_synergies() -> void:
	_reward_controller.call("notify_enemy_killed_synergies")


## 作用：判断调试控件模式，返回布尔判断结果。
## 使用：本文件由 _physics_process_profiled 调用。
func _is_debug_control_mode() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_control_mode", false))


## 作用：获取调试敌人强制状态，供当前模块后续逻辑使用。
## 使用：本文件由 _physics_process_profiled 调用；返回 String 文本/标识。
func _get_debug_enemy_forced_state() -> String:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return ""
	var state: String = String(tree.root.get_meta("debug_enemy_forced_state", ""))
	match state:
		"idle", "chase", "attack":
			return state
		"hurt":
			return state if _can_debug_force_elite_visual_state() else ""
		"dead", "death":
			return "dead" if _can_debug_force_elite_visual_state() else ""
		_:
			return ""


## 作用：可否调试强制精英视觉状态，返回布尔判断结果。
## 使用：本文件由 _get_debug_enemy_forced_state 调用。
func _can_debug_force_elite_visual_state() -> bool:
	var rank: String = String(get_meta("enemy_rank", "normal"))
	return rank == "elite" or rank == "boss"


## 作用：判断普通敌人，返回布尔判断结果。
## 使用：本文件由 _get_enemy_visual_update_interval 调用。
func _is_normal_enemy() -> bool:
	return String(get_meta("enemy_rank", "normal")) == "normal" and String(get_meta("spawn_source_type", "")) != "boss_minion"


## 作用：判断强化敌人，返回布尔判断结果。
## 使用：本文件由 _should_limit_actor_motion、_should_skip_enemy_neighbor_motion_limit、_should_skip_melee_neighbor_logic 调用。
func _is_strong_enemy() -> bool:
	var rank: String = String(get_meta("enemy_rank", "normal"))
	return rank == "elite" or rank == "boss"
