## 文件用途：聚合玩家移动、突进、状态、经验成长、升级、属性来源与受击入口。
## 使用方式：挂载玩家场景；开局 reset_for_loadout 注入合法角色配置；伤害经 take_damage，技能成长与状态通过公开接口。

extends CharacterBody2D


const SKILL_LEVEL_UP_OPTION_PREFIX: String = "skill_level_up:"
const LEVEL_UP_UPGRADE_PREFIX: String = "level_up_upgrade:"
const SkillLearnDefinitionRepositoryScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const PlayerDebugOverlayScript: Script = preload("res://scripts/runtime/player_debug_overlay.gd")
const CharacterRuntimeScript: Script = preload("res://scripts/characters/character_runtime.gd")
const CharacterTraitSystemScript: Script = preload("res://scripts/characters/character_trait_system.gd")
const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")
const CharacterRunInitializerScript: Script = preload("res://scripts/characters/character_run_initializer.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")
const ModifierStoreScript: Script = preload("res://scripts/modifiers/modifier_store.gd")
const PlayerVisualControllerScript: Script = preload("res://scripts/player/player_visual_controller.gd")
const PlayerModifierApplierScript: Script = preload("res://scripts/player/player_modifier_applier.gd")
const PlayerSkillEventContextScript: Script = preload("res://scripts/player/player_skill_event_context.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const DamageNumberPopupScript: Script = preload("res://scripts/combat/damage_number_popup.gd")
const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")
const SkillSpecialRuleExecutorScript: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")
const FireSkillRuntimeScript: Script = preload("res://scripts/skills/fire_skill_runtime.gd")
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")
const PlayerStatusDisplayControllerScript: Script = preload("res://scripts/player/player_status_display_controller.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

const RECENT_ENEMY_DAMAGE_PRIORITY_WINDOW_SECONDS: float = 0.75

signal health_changed(current_health: int, max_health: int)
signal died
signal experience_changed(current_experience: int, experience_to_next_level: int, level: int)
signal leveled_up(level: int)
signal upgrade_applied(upgrade_id: StringName)


@export var selected_character_id: StringName = &"mage"
@export var load_config_from_data: bool = true
@export_range(0.0, 1000.0, 10.0, "or_greater") var move_speed: float = 220.0
@export_range(0.0, 2000.0, 10.0, "or_greater") var dash_speed: float = 780.0
@export_range(0.0, 2.0, 0.01, "or_greater") var dash_duration: float = 0.16
@export_range(0.0, 5.0, 0.01, "or_greater") var dash_cooldown: float = 2.6
@export_range(0.01, 1.0, 0.01, "or_greater") var dash_afterimage_interval: float = 0.035
@export_range(0.01, 2.0, 0.01, "or_greater") var dash_afterimage_fade_duration: float = 0.22
@export_range(1, 1000, 1, "or_greater") var max_health: int = 100
@export_range(1, 100, 1, "or_greater") var starting_level: int = 1
@export_range(1, 10000, 1, "or_greater") var base_experience_to_next_level: int = 100
@export_range(1.0, 10.0, 0.05, "or_greater") var experience_growth_per_level: float = 1.25

var current_health: int
var level: int
var current_experience: int
var experience_to_next_level: int
var pickup_radius: float = 80.0
var attack_power: float = 24.0
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var armor: int = 0
var soul_gain_multiplier: float = 1.0
var experience_gain_multiplier: float = 1.0
var coin_gain_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0
var skill_area_multiplier: float = 1.0
var rare_weight_add: float = 0.0
var epic_weight_add: float = 0.0
var legendary_weight_add: float = 0.0
var level_up_rerolls: int = 0

var enemy_spawn_count_multiplier_add: float = 0.0
var boss_hp_multiplier_add: float = 0.0
var fire_damage_multiplier_add: float = 0.0
var poison_damage_multiplier_add: float = 0.0
var on_hit_slow_chance_add: float = 0.0
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var aura_slow_enabled: bool = false
var aura_radius: float = 0.0
var revive_count_add: int = 0
var revive_hp_percent: float = 0.0
var thorns_damage: int = 0
var thorns_area_radius: float = 0.0
var status_duration_multiplier: float = 1.0

var _experience_formula_type: String = "exponential"
var _experience_formula_base: int = 100
var _experience_formula_per_level: int = 0
var _experience_table: Array[int] = []
var _movement_bounds: Rect2 = Rect2()
var _has_movement_bounds: bool = false
var _last_move_direction: Vector2 = Vector2.DOWN
var _dash_direction: Vector2 = Vector2.DOWN
var _dash_time_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_afterimage_timer: float = 0.0
var _dash_collision_exceptions: Array[PhysicsBody2D] = []
var _last_boss_skill_hit_time: float = -10.0
var _last_contact_damage_time: float = -10.0
var _last_area_damage_times: Dictionary = {}
var _recent_enemy_damage_sources: Dictionary = {}
var _damage_popup_offset_index: int = 0
var _visual_controller: RefCounted = PlayerVisualControllerScript.new()
var _modifier_applier: RefCounted = PlayerModifierApplierScript.new()
var _character_run_initializer: RefCounted = CharacterRunInitializerScript.new()
var _skill_special_rule_executor: RefCounted = SkillSpecialRuleExecutorScript.new()
var _status_manager: Node
var _status_display_controller: RefCounted = PlayerStatusDisplayControllerScript.new()
var _run_loadout: RefCounted


## 作用：在节点入树后完成组件初始化与信号登记。
## 使用：由 Godot 自动调用；场景中的配置与依赖应在入树前设置。
func _ready() -> void:
	add_to_group(&"player")
	_visual_controller.call("setup", self)
	_status_display_controller.call("setup", self)
	_ensure_status_manager()
	_ensure_debug_overlay()
	_ensure_character_systems()
	var default_loadout: RefCounted = CharacterLoadoutServiceScript.build_loadout(selected_character_id)
	if default_loadout != null:
		reset_for_loadout(default_loadout)
	else:
		push_error("[Player] Could not build initial RunLoadout for %s." % String(selected_character_id))


## 作用：确保调试叠层。
## 使用：本文件由 _ready 调用。
func _ensure_debug_overlay() -> void:
	if get_node_or_null("PlayerDebugOverlay") != null:
		return

	var overlay: PlayerDebugOverlay = PlayerDebugOverlayScript.new()
	overlay.name = "PlayerDebugOverlay"
	add_child(overlay)


## 作用：验证并保存 loadout，重置运行状态，再应用角色、永久成长和起始技能。
## 使用：开局或重开调用；必须传合法 RunLoadout，最后复位位置、边界并发出血量/经验信号。
func reset_for_loadout(loadout: RefCounted) -> void:
	if loadout == null or not bool(loadout.call("is_valid")):
		push_error("[Player] reset_for_loadout requires a valid RunLoadout.")
		return
	_run_loadout = loadout
	selected_character_id = StringName(String(loadout.get("character_id")))
	_reset_runtime_stats()
	_ensure_character_systems()
	_initialize_character_runtime()
	if load_config_from_data:
		_character_run_initializer.call("apply_character_setup", self)

	current_health = max_health
	level = starting_level
	current_experience = 0
	experience_to_next_level = _get_experience_required_for_level(level)
	_apply_permanent_upgrade_modifiers()
	_character_run_initializer.call("configure_starting_skills", self)
	_refresh_synergies()
	global_position = Vector2(768, 512)
	_has_movement_bounds = false
	_refresh_movement_bounds()
	health_changed.emit(current_health, max_health)
	experience_changed.emit(current_experience, experience_to_next_level, level)


## 作用：确保角色系统组。
## 使用：本文件由 _ready、reset_for_loadout 调用。
func _ensure_character_systems() -> void:
	if get_node_or_null("CharacterRuntime") == null:
		var runtime: CharacterRuntime = CharacterRuntimeScript.new()
		runtime.name = "CharacterRuntime"
		add_child(runtime)
	if get_node_or_null("CharacterTraitSystem") == null:
		var trait_system: Node = CharacterTraitSystemScript.new()
		trait_system.name = "CharacterTraitSystem"
		add_child(trait_system)
	if get_node_or_null("ModifierStore") == null:
		var modifier_store: Node = ModifierStoreScript.new()
		modifier_store.name = "ModifierStore"
		add_child(modifier_store)


## 作用：确保状态效果管理服务。
## 使用：本文件由 _ready、_update_status_label、_is_movement_frozen 调用；返回 Node 对象/值。
func _ensure_status_manager() -> Node:
	if _status_manager != null and is_instance_valid(_status_manager):
		return _status_manager

	_status_manager = get_node_or_null("StatusEffectManager")
	if _status_manager != null:
		return _status_manager

	_status_manager = StatusEffectManagerScript.new()
	_status_manager.name = "StatusEffectManager"
	add_child(_status_manager)
	return _status_manager


## 作用：更新状态效果效果列表。
## 使用：本文件由 _update_player_runtime_tick 调用；输入 delta（delta）。
func _update_status_effects(delta: float) -> void:
	var manager: Node = _status_manager if _status_manager != null and is_instance_valid(_status_manager) else null
	if manager == null:
		return
	if manager.has_method("has_active_statuses") and not bool(manager.call("has_active_statuses")):
		return
	if manager.has_method("should_update_status_effects") and not bool(manager.call("should_update_status_effects", delta)):
		return
	if manager.has_method("consume_pending_status_update_delta"):
		delta = float(manager.call("consume_pending_status_update_delta"))
	if manager.has_method("update_status_effects"):
		manager.call("update_status_effects", delta)


## 作用：更新状态效果标签。
## 使用：本文件由 apply_status、consume_status_stack、clear_statuses 调用。
func _update_status_label() -> void:
	var manager: Node = _ensure_status_manager()
	if manager != null and manager.has_method("consume_status_display_dirty") and not bool(manager.call("consume_status_display_dirty")):
		return
	_status_display_controller.call("update", get_status_snapshot())


## 作用：判断移动冻结，返回布尔判断结果；具体处理委托给 manager.is_movement_frozen。
## 使用：本文件由 _update_player_runtime_tick 调用。
func _is_movement_frozen() -> bool:
	var manager: Node = _ensure_status_manager()
	return manager != null and manager.has_method("is_movement_frozen") and bool(manager.call("is_movement_frozen"))


## 作用：获取生效移动速度，供当前模块后续逻辑使用；具体处理委托给 manager.get_move_speed_multiplier。
## 使用：本文件由 _apply_dash_or_walk_velocity 调用；返回计算或读取的数值。
func _get_effective_move_speed() -> float:
	var manager: Node = _ensure_status_manager()
	var multiplier: float = 1.0
	if manager != null and manager.has_method("get_move_speed_multiplier"):
		multiplier = float(manager.call("get_move_speed_multiplier"))
	return move_speed * _get_modifier_move_speed_multiplier() * multiplier


## 作用：获取属性修正移动速度倍率，供当前模块后续逻辑使用。
## 使用：本文件由 _get_effective_move_speed 调用；返回计算或读取的数值。
func _get_modifier_move_speed_multiplier() -> float:
	var modifiers: Dictionary = ModifierAggregatorScript.collect(ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_MOVEMENT))
	var multiplier: float = float(modifiers.get("move_speed_multiplier", 1.0))
	multiplier *= maxf(1.0 + float(modifiers.get("move_speed_multiplier_add", 0.0)), 0.05)
	return maxf(multiplier, 0.05)


## 作用：获取生效拾取半径，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回计算或读取的数值。
func get_effective_pickup_radius() -> float:
	var modifiers: Dictionary = ModifierAggregatorScript.collect(ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_PICKUP))
	var radius: float = pickup_radius
	radius *= maxf(1.0 + float(modifiers.get("pickup_radius_multiplier_add", 0.0)), 0.05)
	radius += float(modifiers.get("pickup_radius_add", 0.0))
	return maxf(radius, 1.0)


## 作用：应用状态效果；具体处理委托给 manager.apply_status。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）、params（参数）；返回是否满足条件或执行成功。
func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
	var manager: Node = _ensure_status_manager()
	if manager == null or not manager.has_method("apply_status"):
		return false
	var applied: bool = bool(manager.call("apply_status", status_id, params))
	_update_status_label()
	return applied


## 作用：是否包含状态效果，返回布尔判断结果；具体处理委托给 manager.has_status。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）。
func has_status(status_id: Variant) -> bool:
	var manager: Node = _ensure_status_manager()
	return manager != null and manager.has_method("has_status") and bool(manager.call("has_status", status_id))


## 作用：获取状态效果叠层，供当前模块后续逻辑使用；具体处理委托给 manager.get_status_stack。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）；返回计算或读取的数值。
func get_status_stack(status_id: Variant) -> int:
	var manager: Node = _ensure_status_manager()
	if manager == null or not manager.has_method("get_status_stack"):
		return 0
	return int(manager.call("get_status_stack", status_id))


## 作用：消耗感电叠层。
## 使用：供本模块调用者使用；返回是否满足条件或执行成功。
func consume_shock_stack() -> bool:
	return consume_status_stack(&"shock", 1)


## 作用：消耗状态效果叠层；具体处理委托给 manager.consume_status_stack。
## 使用：本文件由 consume_shock_stack 调用；输入 status_id（状态效果ID）、stack_count（叠层数量）；返回是否满足条件或执行成功。
func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
	var manager: Node = _ensure_status_manager()
	if manager == null or not manager.has_method("consume_status_stack"):
		return false
	var consumed: bool = bool(manager.call("consume_status_stack", status_id, stack_count))
	_update_status_label()
	return consumed


## 作用：获取状态效果快照，供当前模块后续逻辑使用；具体处理委托给 manager.get_status_snapshot。
## 使用：本文件由 _update_status_label 调用；返回 Array[Dictionary] 列表。
func get_status_snapshot() -> Array[Dictionary]:
	var manager: Node = _ensure_status_manager()
	if manager == null or not manager.has_method("get_status_snapshot"):
		return []
	return manager.call("get_status_snapshot")


## 作用：清除状态效果组；具体处理委托给 manager.clear_statuses。
## 使用：本文件由 _reset_runtime_subsystems 调用。
func clear_statuses() -> void:
	var manager: Node = _ensure_status_manager()
	if manager != null and manager.has_method("clear_statuses"):
		manager.call("clear_statuses")
	_update_status_label()


## 作用：初始化角色运行时；具体处理委托给 _character_run_initializer.initialize_loadout。
## 使用：本文件由 reset_for_loadout 调用；返回是否满足条件或执行成功。
func _initialize_character_runtime() -> bool:
	if _run_loadout != null:
		return bool(_character_run_initializer.call("initialize_loadout", self, _run_loadout))
	push_error("[Player] Missing RunLoadout during character runtime initialization.")
	return false


## 作用：重置运行时属性统计。
## 使用：本文件由 reset_for_loadout 调用。
func _reset_runtime_stats() -> void:
	_reset_core_runtime_stats()
	_reset_reward_and_spawn_modifiers()
	_reset_damage_reaction_state()
	_reset_dash_runtime_state()
	_reset_experience_runtime_state()
	_reset_runtime_subsystems()


## 作用：重置核心运行时属性统计。
## 使用：本文件由 _reset_runtime_stats 调用。
func _reset_core_runtime_stats() -> void:
	move_speed = 220.0
	max_health = 100
	starting_level = 1
	base_experience_to_next_level = 100
	experience_growth_per_level = 1.25
	pickup_radius = 80.0
	attack_power = 24.0
	damage_multiplier = 1.0
	attack_speed_multiplier = 1.0
	crit_chance = 0.0
	crit_damage = 1.5
	armor = 0


## 作用：重置奖励与生成属性修正。
## 使用：本文件由 _reset_runtime_stats 调用。
func _reset_reward_and_spawn_modifiers() -> void:
	soul_gain_multiplier = 1.0
	experience_gain_multiplier = 1.0
	coin_gain_multiplier = 1.0
	damage_taken_multiplier = 1.0
	skill_area_multiplier = 1.0
	rare_weight_add = 0.0
	epic_weight_add = 0.0
	legendary_weight_add = 0.0
	level_up_rerolls = 0
	enemy_spawn_count_multiplier_add = 0.0
	boss_hp_multiplier_add = 0.0
	fire_damage_multiplier_add = 0.0
	poison_damage_multiplier_add = 0.0
	on_hit_slow_chance_add = 0.0
	slow_percent = 0.0
	slow_duration = 0.0
	aura_slow_enabled = false
	aura_radius = 0.0
	revive_count_add = 0
	revive_hp_percent = 0.0
	thorns_damage = 0
	thorns_area_radius = 0.0
	status_duration_multiplier = 1.0


## 作用：重置伤害反应状态。
## 使用：本文件由 _reset_runtime_stats 调用。
func _reset_damage_reaction_state() -> void:
	_last_boss_skill_hit_time = -10.0
	_last_contact_damage_time = -10.0
	_last_area_damage_times.clear()
	_recent_enemy_damage_sources.clear()


## 作用：重置突进运行时状态。
## 使用：本文件由 _reset_runtime_stats 调用。
func _reset_dash_runtime_state() -> void:
	_last_move_direction = Vector2.DOWN
	_dash_direction = Vector2.DOWN
	_dash_time_remaining = 0.0
	_dash_cooldown_remaining = 0.0
	_dash_afterimage_timer = 0.0
	_clear_dash_collision_exceptions()


## 作用：重置经验运行时状态。
## 使用：本文件由 _reset_runtime_stats 调用。
func _reset_experience_runtime_state() -> void:
	set_meta("level_up_upgrade_levels", {})
	_experience_formula_type = "exponential"
	_experience_formula_base = 100
	_experience_formula_per_level = 0
	_experience_table = []


## 作用：重置运行时子系统。
## 使用：本文件由 _reset_runtime_stats 调用。
func _reset_runtime_subsystems() -> void:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager != null and skill_manager.has_method("clear_skills"):
		skill_manager.call("clear_skills")
	var relic_manager: Node = get_node_or_null("RelicManager")
	if relic_manager != null and relic_manager.has_method("reset_run_effect_state"):
		relic_manager.call("reset_run_effect_state")
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store != null and modifier_store.has_method("clear_all"):
		modifier_store.call("clear_all")
	clear_statuses()


## 作用：推进本节点的物理帧更新流程。
## 使用：由 Godot 自动调用；delta 为自上一帧经过的秒数。
func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = _get_movement_input_direction()
	var movement_frozen: bool = _update_player_runtime_tick(delta)
	if movement_frozen:
		input_direction = Vector2.ZERO

	_update_dash_cooldown(delta)
	_update_last_move_direction(input_direction)
	if Input.is_action_just_pressed("dash") and not movement_frozen:
		start_dash(input_direction)
	var was_dash_active: bool = is_dash_active()
	_apply_dash_or_walk_velocity(input_direction, delta, was_dash_active)
	move_and_slide()
	if was_dash_active and not is_dash_active():
		_clear_dash_collision_exceptions()
		_emit_dash_skill_event(&"dash_end")
	_clamp_to_movement_bounds()
	_update_trait_movement(input_direction, delta)
	_update_visual_state(_dash_direction if is_dash_active() else input_direction, delta)


## 作用：获取移动输入方向，供当前模块后续逻辑使用。
## 使用：本文件由 _physics_process 调用；返回 Vector2 对象/值。
func _get_movement_input_direction() -> Vector2:
	return Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)


## 作用：更新玩家运行时周期。
## 使用：本文件由 _physics_process 调用；输入 delta（delta）；返回是否满足条件或执行成功。
func _update_player_runtime_tick(delta: float) -> bool:
	_update_status_effects(delta)
	_update_player_tick_special_rules(delta)
	_update_status_label()
	return _is_movement_frozen()


## 作用：更新上次移动方向。
## 使用：本文件由 _physics_process 调用；输入 input_direction（输入方向）。
func _update_last_move_direction(input_direction: Vector2) -> void:
	if input_direction.length_squared() > 0.001:
		_last_move_direction = input_direction.normalized()


## 作用：应用突进或行走速度。
## 使用：本文件由 _physics_process 调用；输入 input_direction（输入方向）、delta（delta）、was_dash_active（was突进活跃）。
func _apply_dash_or_walk_velocity(input_direction: Vector2, delta: float, was_dash_active: bool) -> void:
	if was_dash_active:
		_apply_dash_collision_exceptions()
		velocity = _dash_direction * dash_speed
		_update_dash_afterimage(delta)
		_dash_time_remaining = maxf(_dash_time_remaining - delta, 0.0)
	else:
		velocity = input_direction * _get_effective_move_speed()


## 作用：检查速度、时长、冷却及当前突进状态后启动突进。
## 使用：direction 为零时沿最后移动方向；成功加入碰撞例外、生成残影并发送 dash_start，返回成功标志。
func start_dash(direction: Vector2 = Vector2.ZERO) -> bool:
	if dash_speed <= 0.0 or dash_duration <= 0.0 or _dash_cooldown_remaining > 0.0 or is_dash_active():
		return false
	var resolved_direction: Vector2 = direction
	if resolved_direction.length_squared() <= 0.001:
		resolved_direction = _last_move_direction
	if resolved_direction.length_squared() <= 0.001:
		resolved_direction = Vector2.DOWN
	_dash_direction = resolved_direction.normalized()
	_dash_time_remaining = dash_duration
	_dash_cooldown_remaining = dash_cooldown
	_dash_afterimage_timer = 0.0
	_apply_dash_collision_exceptions()
	_spawn_dash_afterimage()
	_emit_dash_skill_event(&"dash_start")
	return true


## 作用：发出突进技能事件并衔接对应的事件处理流程。
## 使用：本文件由 _physics_process、start_dash、_update_dash_afterimage 调用；输入 event_name（事件名称）。
func _emit_dash_skill_event(event_name: StringName) -> void:
	var event_bus: Node = get_node_or_null("SkillEventBus")
	if event_bus == null or not event_bus.has_method("emit_skill_event"):
		return
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null:
		return
	event_bus.call("emit_skill_event", event_name, PlayerSkillEventContextScript.build_dash_context(self, _dash_direction, skill_manager, get_node_or_null("RelicManager"), event_bus))


## 作用：判断突进活跃，返回布尔判断结果。
## 使用：本文件由 _physics_process、start_dash 调用。
func is_dash_active() -> bool:
	return _dash_time_remaining > 0.0


## 作用：更新突进冷却。
## 使用：本文件由 _physics_process 调用；输入 delta（delta）。
func _update_dash_cooldown(delta: float) -> void:
	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)


## 作用：只忽略剩余突进路径附近的有效敌人物理碰撞。
## 使用：突进开始及每帧调用；记录 body 列表供结束后恢复，不忽略路径外敌人。
func _apply_dash_collision_exceptions() -> void:
	var registry: Node = CombatTargetRegistryScript.get_or_create(self)
	var targets: Array = _get_dash_collision_candidates(registry)
	for node: Node in targets:
		var body: PhysicsBody2D = node as PhysicsBody2D
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		if not _is_body_near_dash_path(body):
			continue
		if _dash_collision_exceptions.has(body):
			continue
		add_collision_exception_with(body)
		_dash_collision_exceptions.append(body)


## 作用：获取突进碰撞候选项，供当前模块后续逻辑使用。
## 使用：本文件由 _apply_dash_collision_exceptions 调用；输入 registry（registry）；返回 Array 列表。
func _get_dash_collision_candidates(registry: Node) -> Array:
	if registry == null:
		return []
	var remaining_distance: float = _dash_remaining_distance()
	var player_radius: float = _get_collision_radius(self, 24.0)
	var path_center: Vector2 = global_position + _dash_direction * remaining_distance * 0.5
	var query_radius: float = remaining_distance * 0.5 + player_radius + 96.0
	if registry.has_method("get_targets_in_radius"):
		return registry.call("get_targets_in_radius", path_center, query_radius, &"enemies")
	if registry.has_method("get_targets"):
		return registry.call("get_targets", &"enemies")
	return []


## 作用：判断主体附近突进路径，返回布尔判断结果。
## 使用：本文件由 _apply_dash_collision_exceptions 调用；输入 body（主体）。
func _is_body_near_dash_path(body: PhysicsBody2D) -> bool:
	var target: Node2D = body as Node2D
	if target == null:
		return false
	var remaining_distance: float = _dash_remaining_distance()
	if remaining_distance <= 0.0:
		return false
	var start: Vector2 = global_position
	var end: Vector2 = start + _dash_direction * remaining_distance
	var path: Vector2 = end - start
	var path_length_squared: float = path.length_squared()
	if path_length_squared <= 0.001:
		return false
	var target_offset: Vector2 = target.global_position - start
	var along_path: float = clampf(target_offset.dot(path) / path_length_squared, 0.0, 1.0)
	var closest_point: Vector2 = start + path * along_path
	var clearance: float = _get_collision_radius(self, 24.0) + _get_collision_radius(target, 24.0) + 8.0
	return closest_point.distance_squared_to(target.global_position) <= clearance * clearance


## 作用：突进剩余距离。
## 使用：本文件由 _get_dash_collision_candidates、_is_body_near_dash_path 调用；返回计算或读取的数值。
func _dash_remaining_distance() -> float:
	return maxf(dash_speed * _dash_time_remaining, 0.0)


## 作用：移除本轮突进登记的全部有效碰撞例外。
## 使用：突进结束或重开时调用；清空列表，避免永久穿过敌人。
func _clear_dash_collision_exceptions() -> void:
	for body: PhysicsBody2D in _dash_collision_exceptions:
		if body != null and is_instance_valid(body):
			remove_collision_exception_with(body)
	_dash_collision_exceptions.clear()


## 作用：更新突进残影。
## 使用：本文件由 _apply_dash_or_walk_velocity 调用；输入 delta（delta）。
func _update_dash_afterimage(delta: float) -> void:
	_dash_afterimage_timer -= delta
	if _dash_afterimage_timer > 0.0:
		return
	_spawn_dash_afterimage()
	_emit_dash_skill_event(&"dash_tick")
	_dash_afterimage_timer = dash_afterimage_interval


## 作用：生成突进残影。
## 使用：本文件由 start_dash、_update_dash_afterimage 调用。
func _spawn_dash_afterimage() -> void:
	var source: Node2D = _get_dash_visual_source()
	if source == null:
		return
	var afterimage: Sprite2D = Sprite2D.new()
	afterimage.name = "DashAfterimage"
	afterimage.texture = _get_dash_visual_texture(source)
	if afterimage.texture == null:
		return
	if source is Sprite2D:
		var source_sprite: Sprite2D = source as Sprite2D
		afterimage.centered = source_sprite.centered
		afterimage.offset = source_sprite.offset
		afterimage.flip_h = source_sprite.flip_h
		afterimage.flip_v = source_sprite.flip_v
		afterimage.region_enabled = source_sprite.region_enabled
		afterimage.region_rect = source_sprite.region_rect
		afterimage.hframes = source_sprite.hframes
		afterimage.vframes = source_sprite.vframes
		afterimage.frame = source_sprite.frame
	afterimage.modulate = Color(0.48, 0.86, 1.0, 0.42)
	afterimage.z_index = z_index - 1
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = self
	parent_node.add_child(afterimage)
	afterimage.global_position = source.global_position
	afterimage.global_rotation = source.global_rotation
	afterimage.global_scale = source.global_scale
	var tween: Tween = afterimage.create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, dash_afterimage_fade_duration)
	tween.tween_callback(afterimage.queue_free)


## 作用：获取突进视觉来源，供当前模块后续逻辑使用。
## 使用：本文件由 _spawn_dash_afterimage 调用；返回 Node2D 对象/值。
func _get_dash_visual_source() -> Node2D:
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null and animated_sprite.visible and animated_sprite.sprite_frames != null:
		return animated_sprite
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.visible and sprite.texture != null:
		return sprite
	return null


## 作用：获取突进视觉纹理，供当前模块后续逻辑使用。
## 使用：本文件由 _spawn_dash_afterimage 调用；输入 source（来源）；返回 Texture2D 对象/值。
func _get_dash_visual_texture(source: Node2D) -> Texture2D:
	if source is Sprite2D:
		return (source as Sprite2D).texture
	if source is AnimatedSprite2D:
		var animated_sprite: AnimatedSprite2D = source as AnimatedSprite2D
		if animated_sprite.sprite_frames == null:
			return null
		return animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	return null


## 作用：保留玩家移动限制接口，当前直接返回不做限制。
## 使用：delta 未用于运算；现有行走依赖 move_and_slide 与地图边界，不要误以为调用会改变速度。
func _limit_actor_motion(delta: float) -> void:
	return


## 作用：获取实体移动缩放，供当前模块后续逻辑使用。
## 使用：内部辅助入口；输入 motion（移动）、blocker（blocker）；返回计算或读取的数值。
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
## 使用：本文件由 _get_dash_collision_candidates、_is_body_near_dash_path、_get_actor_motion_scale 调用；输入 node（节点）、fallback（回退）；返回计算或读取的数值。
func _get_collision_radius(node: Node2D, fallback: float) -> float:
	var collision_shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return maxf((collision_shape.shape as CircleShape2D).radius, 0.0)
	return fallback


## 作用：限制转换移动边界。
## 使用：本文件由 _physics_process 调用。
func _clamp_to_movement_bounds() -> void:
	if not _has_movement_bounds:
		_refresh_movement_bounds()
	if not _has_movement_bounds:
		return

	global_position = Vector2(
		clampf(global_position.x, _movement_bounds.position.x, _movement_bounds.position.x + _movement_bounds.size.x),
		clampf(global_position.y, _movement_bounds.position.y, _movement_bounds.position.y + _movement_bounds.size.y)
	)


## 作用：刷新移动边界。
## 使用：本文件由 reset_for_loadout、_clamp_to_movement_bounds、refresh_movement_bounds 调用。
func _refresh_movement_bounds() -> void:
	var background: Sprite2D = get_tree().root.find_child("DungeonBackground", true, false) as Sprite2D
	if background == null or background.texture == null:
		_has_movement_bounds = false
		return

	var texture_size: Vector2 = background.texture.get_size()
	var scaled_size: Vector2 = texture_size * background.global_scale.abs()
	var top_left: Vector2 = background.global_position
	if background.centered:
		top_left -= scaled_size * 0.5

	var margin: float = 24.0
	_movement_bounds = Rect2(
		top_left + Vector2.ONE * margin,
		Vector2(maxf(scaled_size.x - margin * 2.0, 1.0), maxf(scaled_size.y - margin * 2.0, 1.0))
	)
	_has_movement_bounds = true
	_apply_camera_limits(Rect2(top_left, scaled_size))


## 作用：刷新移动边界。
## 使用：供本模块调用者使用。
func refresh_movement_bounds() -> void:
	_has_movement_bounds = false
	_refresh_movement_bounds()


## 作用：应用相机边界。
## 使用：本文件由 _refresh_movement_bounds 调用；输入 background_bounds（背景边界）。
func _apply_camera_limits(background_bounds: Rect2) -> void:
	var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	camera.limit_left = floori(background_bounds.position.x)
	camera.limit_top = floori(background_bounds.position.y)
	camera.limit_right = ceili(background_bounds.position.x + background_bounds.size.x)
	camera.limit_bottom = ceili(background_bounds.position.y + background_bounds.size.y)
	camera.limit_smoothed = true


## 作用：把严格 DamagePacket 交给统一玩家伤害应用服务。
## 使用：外部受击入口；包校验、命中保护、吸收与扣血遵循统一管线顺序。
func take_damage(packet: DamagePacket) -> void:
	DamageApplicationServiceScript.apply_player_damage(self, packet)


## 作用：记录承伤；具体处理委托给 tracker.record_damage_taken。
## 使用：内部辅助入口；输入 amount（数量）、damage_result（伤害结果）、source_packet（来源伤害包）。
func _record_damage_taken(amount: int, damage_result: Dictionary, source_packet: DamagePacket) -> void:
	var tracker: Node = RunStatsTrackerScript.get_active(get_tree())
	if tracker != null and tracker.has_method("record_damage_taken"):
		tracker.call("record_damage_taken", amount, damage_result, source_packet)
	_record_recent_enemy_damage_source(amount, source_packet, damage_result)
	if amount > 0:
		_trigger_damage_taken_special_rules(source_packet, damage_result, amount)


## 作用：返回敌人在最近时间窗口内造成的伤害权重。
## 使用：enemy 为候选目标，window_seconds 为秒；过期或未知来源返回 0，并移除过期记录。
func get_recent_enemy_damage_priority(enemy: Node, window_seconds: float = RECENT_ENEMY_DAMAGE_PRIORITY_WINDOW_SECONDS) -> float:
	if enemy == null:
		return 0.0

	var key: String = str(enemy.get_instance_id())
	var record_variant: Variant = _recent_enemy_damage_sources.get(key, {})
	if not (record_variant is Dictionary):
		return 0.0

	var record: Dictionary = record_variant
	var now_seconds: float = _now_seconds()
	var record_time: float = float(record.get("time", -INF))
	if now_seconds - record_time > maxf(window_seconds, 0.0):
		_recent_enemy_damage_sources.erase(key)
		return 0.0

	return maxf(float(record.get("amount", 0.0)), 0.0)


## 作用：记录近期敌人伤害来源。
## 使用：本文件由 _record_damage_taken 调用；输入 amount（数量）、source_packet（来源伤害包）、damage_result（伤害结果）。
func _record_recent_enemy_damage_source(amount: int, source_packet: DamagePacket, damage_result: Dictionary = {}) -> void:
	if amount <= 0:
		return

	var source_instance_id: String = String(_damage_source_value(source_packet, "source_instance_id", damage_result.get("source_instance_id", "")))
	var attacker_id: String = String(_damage_source_value(source_packet, "attacker_id", damage_result.get("attacker_id", "")))
	var enemy_instance_id: String = _extract_enemy_instance_id(source_instance_id, attacker_id)
	if enemy_instance_id == "":
		return

	var now_seconds: float = _now_seconds()
	_recent_enemy_damage_sources[enemy_instance_id] = {
		"amount": amount,
		"time": now_seconds
	}
	_prune_recent_enemy_damage_sources(now_seconds)


## 作用：按真实正承伤依次触发被动运行时、事件总线和各技能受击规则。
## 使用：传入原伤害包与结果；上下文标记跳过重复火系被动执行。
func _trigger_damage_taken_special_rules(source_packet: DamagePacket, damage_result: Dictionary = {}, amount: int = 0) -> void:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return
	var event_bus: Node = get_node_or_null("SkillEventBus")
	var damage_context: Dictionary = PlayerSkillEventContextScript.build_damage_taken_context(self, source_packet.to_dictionary(), damage_result, amount, skill_manager, get_node_or_null("RelicManager"), event_bus)
	FireSkillRuntimeScript.execute_passive_event(&"on_player_damaged", damage_context, skill_manager)
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		var skill_rule_context: Dictionary = damage_context.duplicate(true)
		skill_rule_context["skip_fire_passive_runtime"] = true
		event_bus.call("emit_skill_event", &"on_player_damaged", skill_rule_context)
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill_instance: RefCounted = skill_variant as RefCounted
		if skill_instance == null:
			continue
		_skill_special_rule_executor.call("execute_player_damaged", PlayerSkillEventContextScript.build_skill_instance_damage_context(self, source_packet.to_dictionary(), damage_result, amount, skill_instance, skill_manager, get_node_or_null("RelicManager")))
		var rules_variant: Variant = skill_instance.get("runtime_special_rules")
		if not (rules_variant is Dictionary):
			continue
		var rules: Dictionary = rules_variant
		if not rules.has("protective_lava_ring_on_player_damaged"):
			if rules.has("frost_ring_on_player_damaged"):
				SpecialDamageRuleHandlerScript.execute_frost_ring_on_player_damaged(rules, PlayerSkillEventContextScript.build_damage_rule_context(self, source_packet.to_dictionary(), damage_result, skill_instance))
			continue
		SpecialDamageRuleHandlerScript.execute_protective_lava_ring_on_player_damaged(rules, PlayerSkillEventContextScript.build_damage_rule_context(self, source_packet.to_dictionary(), damage_result, skill_instance))
		if rules.has("frost_ring_on_player_damaged"):
			SpecialDamageRuleHandlerScript.execute_frost_ring_on_player_damaged(rules, PlayerSkillEventContextScript.build_damage_rule_context(self, source_packet.to_dictionary(), damage_result, skill_instance))


## 作用：更新玩家周期特殊规则。
## 使用：本文件由 _update_player_runtime_tick 调用；输入 _delta（delta）。
func _update_player_tick_special_rules(_delta: float) -> void:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill_instance: RefCounted = skill_variant as RefCounted
		if skill_instance == null:
			continue
		_skill_special_rule_executor.call("execute_player_tick", {
			"caster": self,
			"owner": self,
			"player": self,
			"parent": get_tree().current_scene if get_tree() != null else get_parent(),
			"skill_instance": skill_instance,
			"skill_manager": skill_manager,
			"relic_manager": get_node_or_null("RelicManager"),
			"target_group": &"enemies"
		})


## 作用：提取敌人实例ID。
## 使用：本文件由 _record_recent_enemy_damage_source 调用；输入 source_instance_id（来源实例ID）、attacker_id（攻击者ID）；返回 String 文本/标识。
func _extract_enemy_instance_id(source_instance_id: String, attacker_id: String) -> String:
	if source_instance_id != "":
		var source_parts: PackedStringArray = source_instance_id.split(":", false, 1)
		if not source_parts.is_empty() and _is_positive_int_string(source_parts[0]):
			return source_parts[0]
	if _is_positive_int_string(attacker_id):
		return attacker_id
	return ""


## 作用：判断正数整数字符串，返回布尔判断结果。
## 使用：本文件由 _extract_enemy_instance_id 调用；输入 value（值）。
func _is_positive_int_string(value: String) -> bool:
	return value.is_valid_int() and int(value) > 0


## 作用：清理近期敌人伤害来源组。
## 使用：本文件由 _record_recent_enemy_damage_source 调用；输入 now_seconds（当前秒）。
func _prune_recent_enemy_damage_sources(now_seconds: float) -> void:
	var max_age: float = RECENT_ENEMY_DAMAGE_PRIORITY_WINDOW_SECONDS * 2.0
	for key: Variant in _recent_enemy_damage_sources.keys():
		var record_variant: Variant = _recent_enemy_damage_sources.get(key)
		if not (record_variant is Dictionary):
			_recent_enemy_damage_sources.erase(key)
			continue
		var record: Dictionary = record_variant
		if now_seconds - float(record.get("time", -INF)) > max_age:
			_recent_enemy_damage_sources.erase(key)


## 作用：当前秒。
## 使用：本文件由 get_recent_enemy_damage_priority、_record_recent_enemy_damage_source 调用；返回计算或读取的数值。
func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## 作用：显示伤害数值。
## 使用：内部辅助入口；输入 amount（数量）、damage_result（伤害结果）。
func _show_damage_number(amount: int, damage_result: Dictionary) -> void:
	DamageNumberPopupScript.show(self, amount, damage_result, {
		"name": "PlayerDamageNumber",
		"offset_index": _damage_popup_offset_index,
		"prefix": "-",
		"y": -84.0,
		"font_size": 18,
		"incoming": true,
		"rise": 34.0,
		"drift_x": float((_damage_popup_offset_index % 3) - 1) * 6.0
	})
	_damage_popup_offset_index += 1


## 作用：降低短时间内重复 Boss 来源伤害并更新命中时间。
## 使用：source_id 为 boss 且距离上次 <=0.3 秒时伤害减半、至少 1；其他来源保持原值；返回计算或读取的数值。
func _apply_boss_overlap_protection(amount: int, source_packet: DamagePacket) -> int:
	if amount <= 0:
		return amount
	if String(_damage_source_value(source_packet, "source_id", "")) != "boss":
		return amount
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var adjusted_amount: int = amount
	if now_seconds - _last_boss_skill_hit_time <= 0.3:
		adjusted_amount = maxi(roundi(float(amount) * 0.5), 1)
	_last_boss_skill_hit_time = now_seconds
	return adjusted_amount


## 作用：判断接触/同一伤害区是否落在保护间隔内，并登记此次允许命中的时间。
## 使用：严格伤害包验证后调用；接触间隔 0.45 秒，同来源区域间隔 0.5 秒；返回是否满足条件或执行成功。
func _is_damage_blocked_by_hit_protection(source_packet: DamagePacket) -> bool:
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var source_type: String = String(_damage_source_value(source_packet, "source_type", ""))
	if source_type == "contact":
		if now_seconds - _last_contact_damage_time < 0.45:
			return true
		_last_contact_damage_time = now_seconds
		return false

	if source_type == "area" or String(_damage_source_value(source_packet, "damage_origin", "")) == "field":
		var area_key: String = String(_damage_source_value(source_packet, "source_instance_id", _damage_source_value(source_packet, "source_id", "area")))
		if area_key != "":
			var last_time: float = float(_last_area_damage_times.get(area_key, -10.0))
			if now_seconds - last_time < 0.5:
				return true
			_last_area_damage_times[area_key] = now_seconds

	return false


## 作用：伤害来源值。
## 使用：本文件由 _record_recent_enemy_damage_source、_apply_boss_overlap_protection、_is_damage_blocked_by_hit_protection 调用；输入 source_packet（来源伤害包）、key（键）、fallback（回退）；返回 Variant 对象/值。
func _damage_source_value(source_packet: DamagePacket, key: Variant, fallback: Variant = null) -> Variant:
	return source_packet.get_value(key, fallback)


## 作用：更新视觉状态；具体处理委托给 _visual_controller.update。
## 使用：本文件由 _physics_process 调用；输入 input_direction（输入方向）、delta（delta）。
func _update_visual_state(input_direction: Vector2, delta: float) -> void:
	_visual_controller.call("update", input_direction, current_health, delta)


## 作用：更新特质移动；具体处理委托给 trait_system.handle_movement。
## 使用：本文件由 _physics_process 调用；输入 input_direction（输入方向）、delta（delta）。
func _update_trait_movement(input_direction: Vector2, delta: float) -> void:
	var trait_system: Node = get_node_or_null("CharacterTraitSystem")
	if trait_system == null or not trait_system.has_method("handle_movement"):
		return
	trait_system.call("handle_movement", input_direction.length_squared() > 0.001, delta)


## 作用：添加经验。
## 使用：供本模块调用者使用；输入 amount（数量）。
func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	_apply_experience_total(_calculate_experience_gain(amount))


## 作用：分别计算每份经验倍率与取整后累计为一次成长输入。
## 使用：amounts 来自 PickupManager 队列；逐条取整保持单晶体收益语义，仍逐级发升级信号。
func add_experience_batch(amounts: Array) -> void:
	var final_amount: int = 0
	for amount_variant: Variant in amounts:
		final_amount += _calculate_experience_gain(int(amount_variant))
	_apply_experience_total(final_amount)


## 作用：计算经验收益。
## 使用：本文件由 add_experience、add_experience_batch 调用；输入 amount（数量）；返回计算或读取的数值。
func _calculate_experience_gain(amount: int) -> int:
	if amount <= 0:
		return 0
	return maxi(roundi(float(amount) * experience_gain_multiplier), 1)


## 作用：累计最终经验并循环处理跨越的所有等级。
## 使用：final_amount 须为正；每升一级发 leveled_up，最后发一次 experience_changed。
func _apply_experience_total(final_amount: int) -> void:
	if final_amount <= 0:
		return

	current_experience += final_amount

	while current_experience >= experience_to_next_level:
		current_experience -= experience_to_next_level
		level += 1
		experience_to_next_level = _get_experience_required_for_level(level)
		leveled_up.emit(level)

	experience_changed.emit(current_experience, experience_to_next_level, level)


## 作用：根据选项 ID 前缀分派技能升级、局内升级或通用升级。
## 使用：接收 skill_level_up:/level_up_upgrade: 或配置 ID；成功后发送 upgrade_applied 并刷新对应状态。
func apply_upgrade(upgrade_id: StringName) -> void:
	var upgrade_id_text: String = String(upgrade_id)
	var dev_enabled: bool = _is_dev_run()
	if upgrade_id_text.begins_with(SKILL_LEVEL_UP_OPTION_PREFIX):
		if _apply_skill_level_up_upgrade(upgrade_id_text, dev_enabled):
			upgrade_applied.emit(upgrade_id)
		return

	if upgrade_id_text.begins_with(LEVEL_UP_UPGRADE_PREFIX):
		var upgrade_parts: PackedStringArray = upgrade_id_text.split(":")
		var level_up_upgrade_id: StringName = StringName(upgrade_parts[1] if upgrade_parts.size() > 1 else "")
		var rarity: String = String(upgrade_parts[2] if upgrade_parts.size() > 2 else "")
		if _apply_level_up_upgrade(level_up_upgrade_id, rarity):
			upgrade_applied.emit(upgrade_id)
			_refresh_skill_configs()
			_refresh_synergies()
		return

	var upgrade: Dictionary = GameData.get_upgrade(upgrade_id)
	if not upgrade.is_empty():
		_apply_upgrade_data(upgrade_id, upgrade_id, upgrade)


## 作用：应用升级数据。
## 使用：本文件由 apply_upgrade 调用；输入 _definition_upgrade_id（定义升级ID）、emitted_upgrade_id（emitted升级ID）、upgrade（升级）。
func _apply_upgrade_data(_definition_upgrade_id: StringName, emitted_upgrade_id: StringName, upgrade: Dictionary) -> void:
	if upgrade.is_empty():
		return

	var modifiers: Variant = upgrade.get("modifiers", [])
	if not _is_empty_modifier_value(modifiers):
		set_run_modifier_source("upgrade:%s:modifiers" % String(emitted_upgrade_id), modifiers)

	var effect: Variant = upgrade.get("effect", [])
	if not _is_empty_modifier_value(effect):
		set_run_modifier_source("upgrade:%s:effect" % String(emitted_upgrade_id), effect)

	upgrade_applied.emit(emitted_upgrade_id)
	_refresh_skill_configs()
	_refresh_synergies()


## 作用：解析动态学习定义，检查等级上限并学习技能或施加逐级修正。
## 使用：upgrade_id 为定义 ID；只有实际应用成功才增加该选项已选等级；返回是否满足条件或执行成功。
func _apply_level_up_upgrade(upgrade_id: StringName, rarity: String = "") -> bool:
	var upgrade: Dictionary = SkillLearnDefinitionRepositoryScript.resolve_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false

	var upgrade_level: int = _get_level_up_upgrade_level(upgrade_id)
	var max_level: int = maxi(int(upgrade.get("max_level", 1)), 1)
	if upgrade_level >= max_level:
		return false

	if upgrade.has("learn_skill_id"):
		var learned_skill_id: StringName = StringName(String(upgrade.get("learn_skill_id", "")))
		var skill_rarity: String = rarity if rarity != "" else String(upgrade.get("rarity", "normal"))
		if not _learn_active_skill(learned_skill_id, skill_rarity):
			return false
		_set_level_up_upgrade_level(upgrade_id, upgrade_level + 1)
		return true

	var level_modifiers: Array = _get_array(upgrade.get("level_modifiers", []))
	var modifiers: Variant = []
	if upgrade_level < level_modifiers.size():
		modifiers = level_modifiers[upgrade_level]
	else:
		modifiers = upgrade.get("modifiers", [])
	if not _is_empty_modifier_value(modifiers):
		set_run_modifier_source("level_upgrade:%s:%d" % [String(upgrade_id), upgrade_level + 1], modifiers)

	var skill_modifiers: Variant = _get_level_modifier_value(upgrade.get("skill_modifiers", []), upgrade_level)
	if not _is_empty_modifier_value(skill_modifiers):
		var skill_manager: Node = _get_skill_manager()
		if skill_manager != null and skill_manager.has_method("add_passive_modifier"):
			skill_manager.call("add_passive_modifier", skill_modifiers)

	_set_level_up_upgrade_level(upgrade_id, upgrade_level + 1)
	return true


## 作用：学习活跃技能；具体处理委托给 skill_manager.add_skill。
## 使用：本文件由 _apply_level_up_upgrade 调用；输入 skill_id（技能ID）、rarity（稀有度）；返回是否满足条件或执行成功。
func _learn_active_skill(skill_id: StringName, rarity: String = "") -> bool:
	if skill_id == &"":
		return false
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("add_skill"):
		return false
	return bool(skill_manager.call("add_skill", skill_id, rarity))


## 作用：按线性、查表或指数公式计算该等级所需经验。
## 使用：character_level 为当前等级；所有分支结果至少为 1，查表索引限制在有效范围；返回计算或读取的数值。
func _get_experience_required_for_level(character_level: int) -> int:
	if _experience_formula_type == "linear":
		return maxi(_experience_formula_base + _experience_formula_per_level * maxi(character_level, 0), 1)
	if _experience_formula_type == "table" and not _experience_table.is_empty():
		var table_index: int = clampi(character_level - 1, 0, _experience_table.size() - 1)
		return maxi(_experience_table[table_index], 1)

	var level_offset: int = maxi(character_level - 1, 0)
	return maxi(roundi(base_experience_to_next_level * pow(experience_growth_per_level, level_offset)), 1)


## 作用：应用单局配置。
## 使用：内部辅助入口。
func _apply_run_config() -> void:
	var run_config: Dictionary = GameData.get_run_config()
	if run_config.is_empty():
		return

	starting_level = int(run_config.get("starting_level", starting_level))

	var formula: Variant = run_config.get("experience_formula", {})
	if formula is Dictionary:
		var formula_data: Dictionary = formula
		_experience_formula_type = String(formula_data.get("type", _experience_formula_type))
		_experience_formula_base = int(formula_data.get("base", base_experience_to_next_level))
		_experience_formula_per_level = int(formula_data.get("per_level", _experience_formula_per_level))
		_experience_table = _parse_int_array(formula_data.get("values", []))


## 作用：应用基础属性统计。
## 使用：内部辅助入口；输入 base_stats（基础属性统计）。
func _apply_base_stats(base_stats: Dictionary) -> void:
	max_health = int(base_stats.get("max_hp", max_health))
	move_speed = float(base_stats.get("move_speed", move_speed))
	pickup_radius = float(base_stats.get("pickup_radius", pickup_radius))
	attack_power = float(base_stats.get("attack_power", attack_power))
	damage_multiplier = float(base_stats.get("damage_multiplier", damage_multiplier))
	attack_speed_multiplier = float(base_stats.get("attack_speed_multiplier", attack_speed_multiplier))
	crit_chance = float(base_stats.get("crit_chance", crit_chance))
	crit_damage = float(base_stats.get("crit_damage", crit_damage))
	armor = int(base_stats.get("armor", armor))
	soul_gain_multiplier = float(base_stats.get("soul_gain_multiplier", soul_gain_multiplier))


## 作用：应用视觉配置；具体处理委托给 _visual_controller.apply_character_config。
## 使用：内部辅助入口；输入 character（角色）。
func _apply_visual_config(character: Dictionary) -> void:
	_visual_controller.call("apply_character_config", character)


## 作用：应用永久升级属性修正。
## 使用：本文件由 reset_for_loadout 调用。
func _apply_permanent_upgrade_modifiers() -> void:
	var modifiers: Dictionary = SaveManager.get_permanent_upgrade_total_modifiers()
	if modifiers.is_empty():
		return

	set_run_modifier_source(&"permanent_upgrades", modifiers)


## 作用：获取技能管理服务，供当前模块后续逻辑使用。
## 使用：本文件由 _reset_runtime_subsystems、_emit_dash_skill_event、_trigger_damage_taken_special_rules 调用；返回 Node 对象/值。
func _get_skill_manager() -> Node:
	return get_node_or_null("SkillManager")


## 作用：获取升级升级等级，供当前模块后续逻辑使用。
## 使用：本文件由 _apply_level_up_upgrade 调用；输入 upgrade_id（升级ID）；返回计算或读取的数值。
func _get_level_up_upgrade_level(upgrade_id: StringName) -> int:
	var levels_variant: Variant = get_meta("level_up_upgrade_levels", {})
	if levels_variant is Dictionary:
		var levels: Dictionary = levels_variant
		return int(levels.get(String(upgrade_id), 0))
	return 0


## 作用：设置升级升级等级。
## 使用：本文件由 _apply_level_up_upgrade 调用；输入 upgrade_id（升级ID）、level_value（等级值）。
func _set_level_up_upgrade_level(upgrade_id: StringName, level_value: int) -> void:
	var levels: Dictionary = {}
	var levels_variant: Variant = get_meta("level_up_upgrade_levels", {})
	if levels_variant is Dictionary:
		levels = (levels_variant as Dictionary).duplicate(true)
	levels[String(upgrade_id)] = level_value
	set_meta("level_up_upgrade_levels", levels)


## 作用：获取技能实例，供当前模块后续逻辑使用；具体处理委托给 skill_manager.get_skill。
## 使用：本文件由 _apply_skill_level_up_upgrade 调用；输入 skill_id（技能ID）；返回 RefCounted 对象/值。
func _get_skill_instance(skill_id: StringName) -> RefCounted:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("get_skill"):
		return null

	return skill_manager.call("get_skill", skill_id) as RefCounted


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：传入待解析 Variant；返回独立深拷贝；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 _apply_level_up_upgrade 调用；输入 value（值）。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：解析整数数组。
## 使用：本文件由 _apply_run_config 调用；输入 value（值）；返回 Array[int] 列表。
func _parse_int_array(value: Variant) -> Array[int]:
	var parsed: Array[int] = []
	if not (value is Array):
		return parsed
	for item: Variant in value:
		parsed.append(int(item))
	return parsed


## 作用：获取等级字典，供当前模块后续逻辑使用。
## 使用：内部辅助入口；输入 value（值）、level_index（等级索引）；返回结果字典。
func _get_level_dictionary(value: Variant, level_index: int) -> Dictionary:
	if value is Array:
		var items: Array = value
		if level_index >= 0 and level_index < items.size() and items[level_index] is Dictionary:
			return (items[level_index] as Dictionary).duplicate(true)
	elif value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：获取等级属性修正值，供当前模块后续逻辑使用。
## 使用：本文件由 _apply_level_up_upgrade 调用；输入 value（值）、level_index（等级索引）；返回 Variant 对象/值。
func _get_level_modifier_value(value: Variant, level_index: int) -> Variant:
	if value is Array:
		var items: Array = value
		if level_index >= 0 and level_index < items.size():
			var level_value: Variant = items[level_index]
			if level_value is Array:
				return (level_value as Array).duplicate(true)
			if level_value is Dictionary:
				return (level_value as Dictionary).duplicate(true)
	elif value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return []


## 作用：判断空值属性修正值，返回布尔判断结果。
## 使用：本文件由 _apply_upgrade_data、_apply_level_up_upgrade 调用；输入 value（值）。
func _is_empty_modifier_value(value: Variant) -> bool:
	if value is Array:
		return (value as Array).is_empty()
	if value is Dictionary:
		return (value as Dictionary).is_empty()
	return true


## 作用：刷新技能配置组。
## 使用：本文件由 apply_upgrade、_apply_upgrade_data 调用。
func _refresh_skill_configs() -> void:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager != null and skill_manager.has_signal("skill_changed"):
		skill_manager.emit_signal("skill_changed")


## 作用：应用属性修正；具体处理委托给 _modifier_applier.apply。
## 使用：本文件由 set_run_modifier_source、merge_run_modifier_source、refresh_run_modifier_snapshot 调用；输入 modifiers（属性修正）。
func _apply_modifiers(modifiers: Variant) -> void:
	_modifier_applier.call("apply", self, ModifierSourceScript.flatten(modifiers, ModifierSourceScript.SOURCE_UNKNOWN, ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_PLAYER)))


## 作用：获取快照属性修正，供当前模块后续逻辑使用。
## 使用：本文件由 set_run_modifier_source、merge_run_modifier_source、refresh_run_modifier_snapshot 调用；输入 modifiers（属性修正）；返回结果字典。
func _get_snapshot_modifiers(modifiers: Variant) -> Dictionary:
	var flat_modifiers: Dictionary = ModifierSourceScript.flatten(modifiers, ModifierSourceScript.SOURCE_UNKNOWN, ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_PLAYER))
	var snapshot_modifiers: Dictionary = {}
	for key_variant: Variant in flat_modifiers.keys():
		var key: String = String(key_variant)
		if _is_dynamic_scope_modifier_key(key):
			continue
		snapshot_modifiers[key_variant] = flat_modifiers[key_variant]
	return snapshot_modifiers


## 作用：判断动态作用域属性修正键，返回布尔判断结果。
## 使用：本文件由 _get_snapshot_modifiers 调用；输入 key（键）。
func _is_dynamic_scope_modifier_key(key: String) -> bool:
	return _is_damage_scope_modifier_key(key) or _is_movement_scope_modifier_key(key) or _is_pickup_scope_modifier_key(key)


## 作用：判断伤害作用域属性修正键，返回布尔判断结果。
## 使用：本文件由 _is_dynamic_scope_modifier_key、_get_run_modifier_scopes 调用；输入 key（键）。
func _is_damage_scope_modifier_key(key: String) -> bool:
	match key:
		"damage_multiplier", "damage_multiplier_add", "crit_chance_add", "crit_damage_add", "starting_skill_damage_add":
			return true
	if key.ends_with("_damage_multiplier_add"):
		return key != "damage_taken_multiplier_add"
	return false


## 作用：判断移动作用域属性修正键，返回布尔判断结果。
## 使用：本文件由 _is_dynamic_scope_modifier_key、_get_run_modifier_scopes 调用；输入 key（键）。
func _is_movement_scope_modifier_key(key: String) -> bool:
	return key == "move_speed_multiplier" or key == "move_speed_multiplier_add"


## 作用：判断拾取物作用域属性修正键，返回布尔判断结果。
## 使用：本文件由 _is_dynamic_scope_modifier_key、_get_run_modifier_scopes 调用；输入 key（键）。
func _is_pickup_scope_modifier_key(key: String) -> bool:
	return key == "pickup_radius_multiplier_add" or key == "pickup_radius_add"


## 作用：获取单局属性修正作用域，供当前模块后续逻辑使用。
## 使用：本文件由 set_run_modifier_source、merge_run_modifier_source 调用；输入 modifiers（属性修正）；返回 Array[StringName] 列表。
func _get_run_modifier_scopes(modifiers: Variant) -> Array[StringName]:
	var scopes: Array[StringName] = [ModifierQueryScript.SCOPE_PLAYER]
	var flat_modifiers: Dictionary = ModifierSourceScript.flatten(modifiers)
	for key_variant: Variant in flat_modifiers.keys():
		var key: String = String(key_variant)
		if _is_damage_scope_modifier_key(key) and not scopes.has(ModifierQueryScript.SCOPE_DAMAGE):
			scopes.append(ModifierQueryScript.SCOPE_DAMAGE)
		if _is_movement_scope_modifier_key(key) and not scopes.has(ModifierQueryScript.SCOPE_MOVEMENT):
			scopes.append(ModifierQueryScript.SCOPE_MOVEMENT)
		if _is_pickup_scope_modifier_key(key) and not scopes.has(ModifierQueryScript.SCOPE_PICKUP):
			scopes.append(ModifierQueryScript.SCOPE_PICKUP)
	return scopes


## 作用：更新 ModifierStore 来源及作用域，并把非动态属性快照应用到玩家。
## 使用：source_id 标识来源；伤害、移动与拾取动态字段由查询计算，避免重复写入基础字段。
func set_run_modifier_source(source_id: Variant, modifiers: Variant) -> void:
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store != null and modifier_store.has_method("set_source"):
		modifier_store.call("set_source", source_id, modifiers, _get_run_modifier_scopes(modifiers))
	_apply_modifiers(_get_snapshot_modifiers(modifiers))


## 作用：合并同一来源的属性效果并应用非动态字段。
## 使用：与 set_run_modifier_source 的覆盖行为不同，使用 ModifierStore.merge_source。
func merge_run_modifier_source(source_id: Variant, modifiers: Variant) -> void:
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store != null and modifier_store.has_method("merge_source"):
		modifier_store.call("merge_source", source_id, modifiers, _get_run_modifier_scopes(modifiers))
	_apply_modifiers(_get_snapshot_modifiers(modifiers))


## 作用：移除 ModifierStore 中指定来源。
## 使用：source_id 为来源键；本函数不逆向回滚已应用的基础字段快照。
func clear_run_modifier_source(source_id: Variant) -> void:
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store != null and modifier_store.has_method("clear_source"):
		modifier_store.call("clear_source", source_id)


## 作用：刷新单局属性修正快照；具体处理委托给 modifier_store.collect。
## 使用：供本模块调用者使用。
func refresh_run_modifier_snapshot() -> void:
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store == null or not modifier_store.has_method("collect"):
		return
	var modifiers_variant: Variant = modifier_store.call("collect", ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_PLAYER))
	if modifiers_variant is Dictionary:
		_apply_modifiers(_get_snapshot_modifiers(modifiers_variant))


## 作用：应用环境属性修正；具体处理委托给 spawner.apply_run_modifiers。
## 使用：内部辅助入口。
func _apply_environment_modifiers() -> void:
	var spawner: Node = get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null and spawner.has_method("apply_run_modifiers"):
		spawner.call(&"apply_run_modifiers", {
			"enemy_spawn_count_multiplier_add": enemy_spawn_count_multiplier_add,
			"boss_hp_multiplier_add": boss_hp_multiplier_add
		})


## 作用：升级技能。
## 使用：本文件由 _upgrade_all_owned_skills、_apply_skill_level_up_upgrade 调用；输入 skill_id（技能ID）、amount（数量）、rarity（稀有度）、_dev_level_hint（开发模式等级hint）、_dev_enabled（开发模式启用）；返回是否满足条件或执行成功。
func _upgrade_skill(skill_id: StringName, amount: int, rarity: String = "", _dev_level_hint: Variant = &"", _dev_enabled: bool = false) -> bool:
	if amount <= 0:
		return false

	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("upgrade_skill"):
		return false

	var upgraded: bool = false
	for _upgrade_index in range(amount):
		if not bool(skill_manager.call("upgrade_skill", skill_id, rarity)):
			break
		upgraded = true

	if upgraded:
		_refresh_synergies()
	return upgraded


## 作用：升级全部已拥有技能组。
## 使用：内部辅助入口；输入 amount（数量）。
func _upgrade_all_owned_skills(amount: int) -> void:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return

	for skill_instance_variant: Variant in skill_manager.call("get_all_skills"):
		var skill_instance: RefCounted = skill_instance_variant as RefCounted
		if skill_instance == null:
			continue

		var skill_id: StringName = StringName(skill_instance.get("skill_id"))
		_upgrade_skill(skill_id, amount)


## 作用：刷新协同；具体处理委托给 synergy_manager.refresh_active_synergies。
## 使用：本文件由 reset_for_loadout、apply_upgrade、_apply_upgrade_data 调用。
func _refresh_synergies() -> void:
	var synergy_manager: Node = get_node_or_null("SynergyManager")
	if synergy_manager != null and synergy_manager.has_method("refresh_active_synergies"):
		synergy_manager.call("refresh_active_synergies", self)


## 作用：应用技能升级升级。
## 使用：本文件由 apply_upgrade 调用；输入 upgrade_id_text（升级ID文本）、dev_enabled（开发模式启用）；返回是否满足条件或执行成功。
func _apply_skill_level_up_upgrade(upgrade_id_text: String, dev_enabled: bool = false) -> bool:
	var level_parts: PackedStringArray = upgrade_id_text.split(":")
	var skill_id_from_option: StringName = StringName(level_parts[1] if level_parts.size() > 1 else "")
	var rarity: String = String(level_parts[3] if level_parts.size() > 3 else "")
	if not dev_enabled:
		return _upgrade_skill(skill_id_from_option, 1, rarity)

	var target_level: int = int(level_parts[2] if level_parts.size() > 2 else "0")
	var skill_instance: RefCounted = _get_skill_instance(skill_id_from_option)
	if skill_instance == null:
		return false
	if target_level <= int(skill_instance.get("current_level")):
		return true
	return _upgrade_skill(skill_id_from_option, target_level - int(skill_instance.get("current_level")), rarity, target_level, true)


## 作用：判断开发模式单局，返回布尔判断结果。
## 使用：本文件由 apply_upgrade 调用。
func _is_dev_run() -> bool:
	var node: Node = self
	while node != null:
		if node.has_meta("debug"):
			return bool(node.get_meta("debug", false))
		node = node.get_parent()
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("developer_mode_enabled", false))

func complete_skill_replacement(upgrade_id: StringName) -> void:
	var parts: PackedStringArray = String(upgrade_id).split(":")
	if parts.size() < 2: return
	var id: StringName = StringName(parts[1])
	_set_level_up_upgrade_level(id, _get_level_up_upgrade_level(id) + 1)
	upgrade_applied.emit(upgrade_id)
	_refresh_skill_configs()
	_refresh_synergies()
