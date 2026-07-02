extends CharacterBody2D
class_name EnemyBase


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const EnemyAttackTelegraphScript: Script = preload("res://scripts/enemies/enemy_attack_telegraph.gd")
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
const RuntimePoolRegistryScript: Script = preload("res://scripts/runtime/runtime_pool_registry.gd")
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
const VISUAL_UPDATE_FAR_DISTANCE_SQUARED: float = 900.0 * 900.0

signal health_changed(current_health: int, max_health: int)
signal died


@export_range(0.0, 1000.0, 10.0, "or_greater") var move_speed: float = 120.0
@export_range(1, 1000, 1, "or_greater") var max_health: int = 30
@export_range(0, 1000, 1, "or_greater") var contact_damage: int = 10
@export_range(1.0, 2000.0, 1.0, "or_greater") var attack_range: float = 32.0
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
var _state_controller: RefCounted = EnemyStateControllerScript.new()
var _visual_update_timer: float = 0.0
static var _nearby_enemy_index_frame: int = -1
static var _nearby_enemy_index_tree_id: int = 0
static var _nearby_enemy_grid: Dictionary = {}
static var _nearby_enemy_total_count: int = 0
static var _enemy_profile_sections: Dictionary = {}


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"enemies")
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
	_visual_update_timer = float(int(get_instance_id()) % 7) * 0.01

	current_health = max_health
	health_changed.emit(current_health, max_health)
	target = _get_target_from_path()
	if target == null:
		target = _find_target_in_group()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	var profile_start: int = _profile_start()
	_update_enemy_runtime_tick(delta)
	_profile_add("runtime_tick", profile_start)
	profile_start = _profile_start()
	_state_controller.call("update", delta)
	var debug_forced_state: String = _get_debug_enemy_forced_state()
	if debug_forced_state != "":
		_state_controller.call("set_forced_state", debug_forced_state)
		_apply_debug_forced_state(delta, debug_forced_state)
		_profile_add("debug_forced_state", profile_start)
		return
	_state_controller.call("clear_forced_state")
	if _is_debug_control_mode():
		_stop_motion_and_update_visual(delta)
		_profile_add("debug_control", profile_start)
		return

	if _is_movement_frozen():
		_stop_motion_and_update_visual(delta)
		_profile_add("movement_frozen", profile_start)
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
		_stop_motion()
		_profile_add("resolve_target_missing", profile_start)
		return
	_profile_add("resolve_target", profile_start)

	if _should_skip_crowded_runtime_frame():
		move_and_slide()
		return

	profile_start = _profile_start()
	_update_behavior(delta)
	_profile_add("behavior", profile_start)
	profile_start = _profile_start()
	if _should_limit_actor_motion():
		_limit_actor_motion(delta, true)
	_profile_add("motion_limit", profile_start)
	profile_start = _profile_start()
	move_and_slide()
	_profile_add("move_and_slide", profile_start)
	profile_start = _profile_start()
	if _should_update_enemy_visual_state(delta):
		_update_enemy_visual_state(delta)
	_profile_add("visual", profile_start)

	profile_start = _profile_start()
	_apply_contact_damage()
	_profile_add("contact_damage", profile_start)


func _update_enemy_runtime_tick(delta: float) -> void:
	_update_status_effects(delta)
	_update_status_label()


func _update_enemy_action_cooldowns(delta: float) -> void:
	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_shoot_cooldown = maxf(_shoot_cooldown - delta, 0.0)
	_summon_cooldown = maxf(_summon_cooldown - delta, 0.0)
	_cast_cooldown = maxf(_cast_cooldown - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)


func _resolve_current_target() -> bool:
	if not is_instance_valid(target):
		target = _find_target_in_group()
	return target != null


func _stop_motion() -> void:
	_cancel_ranged_attack_warning()
	velocity = Vector2.ZERO
	move_and_slide()


func _stop_motion_and_update_visual(delta: float) -> void:
	_stop_motion()
	_update_enemy_visual_state(delta)


func _update_behavior(delta: float) -> void:
	_behavior_controller.call("tick", delta)


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

	_limit_actor_motion(delta, true)
	move_and_slide()
	_update_enemy_visual_state(delta)


func _apply_debug_chase_movement() -> void:
	if target == null:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = global_position.direction_to(target.global_position)
	velocity = direction * _get_effective_move_speed()


func _start_ranged_attack_warning(direction: Vector2) -> void:
	_ranged_warning_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_ranged_warning_timer = maxf(float(_behavior.get("projectile_warning_time", 0.0)), 0.0)
	if _ranged_warning_timer > 0.0:
		_attack_telegraph.call("show", _ranged_warning_direction, _behavior, attack_range)


func _cancel_ranged_attack_warning() -> void:
	if _ranged_warning_timer <= 0.0:
		_attack_telegraph.call("hide")
		return

	_ranged_warning_timer = 0.0
	_attack_telegraph.call("hide")


func _show_ranged_attack_warning() -> void:
	_attack_telegraph.call("show", _ranged_warning_direction, _behavior, attack_range)


func _show_dash_attack_warning() -> void:
	_attack_telegraph.call("show", _dash_direction, _behavior, attack_range)


func _hide_attack_telegraph() -> void:
	_attack_telegraph.call("hide")


func _is_target_in_attack_range(distance: float = -1.0) -> bool:
	if target == null:
		return false

	var current_distance: float = distance
	if current_distance < 0.0:
		current_distance = global_position.distance_to(target.global_position)

	return current_distance <= attack_range


func _is_target_in_behavior_attack_range(distance: float = -1.0) -> bool:
	if target == null:
		return false

	var current_distance: float = distance
	if current_distance < 0.0:
		current_distance = global_position.distance_to(target.global_position)

	return current_distance <= _get_behavior_attack_range()


func _get_target_from_path() -> Node2D:
	if target_path.is_empty():
		return null

	return get_node_or_null(target_path) as Node2D


func _find_target_in_group() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


func _update_status_effects(delta: float) -> void:
	_status_facade.call("update_status_effects", delta)


func _update_status_label() -> void:
	_status_display_controller.call("update", get_status_snapshot())


func _is_movement_frozen() -> bool:
	return bool(_status_facade.call("is_movement_frozen"))


func _get_effective_move_speed() -> float:
	return float(_status_facade.call("get_effective_move_speed", move_speed))


func _apply_contact_damage() -> void:
	if _damage_cooldown > 0.0:
		return

	var contact_target: Object = null
	if _is_target_touching_contact_radius():
		contact_target = target
	if contact_target == null or not contact_target.has_method("take_damage"):
		return

	var applied_damage: int = int(_behavior.get("dash_damage", contact_damage)) if _dash_timer > 0.0 else contact_damage
	contact_target.call(&"take_damage", _get_enemy_damage_packet(applied_damage, "contact"))
	_execute_enemy_skill_action("contact_status", {"target": contact_target})
	_mark_runtime_state("attack", 0.2)
	_damage_cooldown = damage_interval


func _is_target_touching_contact_radius() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var contact_radius: float = maxf(
		attack_range,
		_get_collision_radius(self, 24.0) + _get_collision_radius(target, 24.0) + 2.0
	)
	return global_position.distance_squared_to(target.global_position) <= contact_radius * contact_radius


func _apply_range_attack_damage() -> void:
	if _damage_cooldown > 0.0 or target == null:
		return

	if target.has_method("take_damage"):
		target.call(&"take_damage", _get_enemy_damage_packet(contact_damage, "ranged"))
		_mark_runtime_state("attack", 0.2)
		_damage_cooldown = damage_interval


func take_damage(amount_or_packet: Variant, damage_type: Variant = &"") -> void:
	DamageApplicationServiceScript.apply_enemy_damage(self, amount_or_packet, damage_type)


func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
	return bool(_status_facade.call("apply_status", status_id, params))

func has_status(status_id: Variant) -> bool:
	return bool(_status_facade.call("has_status", status_id))

func get_status_stack(status_id: Variant) -> int:
	return int(_status_facade.call("get_status_stack", status_id))

func consume_shock_stack() -> bool:
	return bool(_status_facade.call("consume_shock_stack"))

func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
	return bool(_status_facade.call("consume_status_stack", status_id, stack_count))

func is_dead() -> bool:
	return _is_dead

func get_status_snapshot() -> Array[Dictionary]:
	return _status_facade.call("get_status_snapshot")

func clear_statuses() -> void:
	_status_facade.call("clear_statuses")


func _die() -> void:
	_finish_death("damage")


func _record_damage_done(amount: int, damage_result: Dictionary, source_packet: Variant) -> void:
	_reward_controller.call("record_damage_done", amount, damage_result, source_packet)


func _get_damage_source_key(source_packet: Variant, damage_result: Dictionary) -> String:
	for key: String in ["source_instance_id", "source_id", "source_skill_id", "attacker_id"]:
		var packet_value: String = String(_damage_source_value(source_packet, key, ""))
		if packet_value != "":
			return packet_value
	for key: String in ["source_instance_id", "source_id", "source_skill_id", "attacker_id"]:
		var result_value: String = String(damage_result.get(key, ""))
		if result_value != "":
			return result_value
	return "unknown"


func _damage_source_value(source_packet: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if source_packet is Dictionary:
		return (source_packet as Dictionary).get(key, fallback)
	if source_packet is RefCounted and source_packet.has_method("get_value"):
		return source_packet.call("get_value", key, fallback)
	return fallback


func _get_enemy_damage_packet(amount: int, source_kind: String) -> Dictionary:
	return EnemyDamagePacketBuilderScript.build(self, amount, source_kind, StringName(source_kind), {
		"target": target,
		"source_id": source_kind,
		"damage_origin": "primary_attack",
		"damage_type": "direct_physical",
		"element": "physical"
	})


func _run_self_explosion_action() -> bool:
	if _is_dead:
		return false
	if not bool(_action_executor.call("explode", _behavior)):
		return false
	_finish_death("self_explosion")
	return true


func _finish_death(cause: String = "damage") -> void:
	if _is_dead:
		return

	var context: Dictionary = EnemyDeathContextScript.create(cause, _get_death_policy(cause), {
		"enemy_id": String(enemy_id),
		"enemy_type": String(get_meta("enemy_type", "normal")),
		"enemy_rank": String(get_meta("enemy_rank", get_meta("enemy_type", "normal"))),
		"source_key": String(get_meta("last_damage_source_key", "unknown"))
	})
	_death_pipeline.call("execute", self, context)


func _get_death_policy(cause: String) -> Dictionary:
	var policy: Dictionary = _get_default_death_policy(cause)
	_merge_death_policy(policy, _get_dictionary(_death_policy.get("default", {})))
	_merge_death_policy(policy, _get_dictionary(_death_policy.get(cause, {})))
	return policy


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


func _merge_death_policy(target_policy: Dictionary, override_policy: Dictionary) -> void:
	for key: Variant in override_policy.keys():
		target_policy[String(key)] = override_policy[key]


func _apply_death_effect() -> void:
	_action_executor.call("apply_death_effect", _death_effect)


func _spawn_enemies_around(spawn_enemy_id: StringName, count: int, center: Vector2, radius: float = 48.0) -> void:
	_action_executor.call("spawn_enemies_around", spawn_enemy_id, count, center, radius)


func _spawn_corrupted_cores(count: int, hp: int) -> bool:
	return bool(_action_executor.call("spawn_corrupted_cores", count, hp))


func _update_boss_skill_cooldowns(delta: float) -> void:
	for key: Variant in _boss_skill_cooldowns.keys():
		_boss_skill_cooldowns[key] = maxf(float(_boss_skill_cooldowns[key]) - delta, 0.0)


func _process_boss_phase_skills() -> void:
	var phase: Dictionary = _get_active_boss_phase()
	var skills: Array = _get_array(phase.get("skills", []))
	var active_count: int = 0
	var active_cap: int = maxi(int(phase.get("max_concurrent_skills", 1)), 1)
	for skill_index in range(skills.size()):
		if active_count >= active_cap:
			return
		var skill_variant: Variant = skills[skill_index]
		if not (skill_variant is Dictionary):
			continue

		var skill: Dictionary = skill_variant
		var cooldown_key: String = "%s:%d" % [str(phase.get("_phase_index", 0)), skill_index]
		if float(_boss_skill_cooldowns.get(cooldown_key, 0.0)) > 0.0:
			continue

		if _execute_boss_skill(skill):
			_boss_skill_cooldowns[cooldown_key] = maxf(float(skill.get("cooldown", 5.0)), 0.1)
			active_count += 1


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


func _execute_boss_skill(skill: Dictionary) -> bool:
	var skill_id: StringName = StringName(String(skill.get("skill_id", "")))
	if skill_id == &"":
		push_warning("[EnemyBase] Boss phase skill is missing skill_id for enemy '%s'" % String(enemy_id))
		return false
	var runtime_params: Dictionary = {
		"boss_skill": skill,
		"position": _get_boss_skill_target_position(skill)
	}
	var executed: bool = bool(_skill_controller.call("execute_skill_id", skill_id, runtime_params))
	if executed:
		_mark_runtime_state("attack", 0.2)
	return executed


func _get_boss_skill_target_position(skill: Dictionary) -> Vector2:
	match String(skill.get("type", "")):
		"shockwave", "corrupted_cores", "ring_projectiles", "summon", "shield_orbs":
			return global_position
		_:
			return target.global_position if target != null else global_position


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value

	return []


func _update_fuse_visual() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var pulse: float = 0.65 + absf(sin(_fuse_timer * 18.0)) * 0.45
	sprite.modulate = Color(1.0, pulse, 0.18, 1.0)


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


func _instantiate_experience_crystal() -> Node:
	return experience_crystal_scene.instantiate() if experience_crystal_scene != null else null


func _experience_crystal_pool_key() -> StringName:
	var scene_path: String = experience_crystal_scene.resource_path if experience_crystal_scene != null else "anonymous"
	if scene_path == "":
		scene_path = "anonymous"
	return StringName("pickup_scene:%s" % scene_path)


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
	var configured_damage_interval: Variant = stats.get(
		"contact_interval",
		enemy_config.get("contact_interval", stats.get("damage_interval", enemy_config.get("damage_interval", damage_interval)))
	)
	damage_interval = maxf(float(configured_damage_interval), 0.05)
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


func _get_dictionary(value: Variant) -> Dictionary:
	return EnemyConfigHelperScript.duplicate_dictionary(value)


func _get_dictionary_array(value: Variant) -> Array[Dictionary]:
	return EnemyConfigHelperScript.duplicate_dictionary_array(value)


func _execute_enemy_skill_action(action_type: String, runtime_params: Dictionary = {}) -> bool:
	var executed: bool = bool(_skill_controller.call("execute_action_type", action_type, runtime_params))
	if executed and not _is_dead and action_type != "contact_status":
		_mark_runtime_state("attack", 0.2)
	return executed


func _mark_runtime_state(state: String, duration: float) -> void:
	_state_controller.call("mark", state, duration)


func _show_hurt_visual() -> void:
	_mark_runtime_state("hurt", 0.12)


func get_runtime_state() -> String:
	return String(_state_controller.call("get_snapshot").get("state", "idle"))


func get_runtime_state_snapshot() -> Dictionary:
	return _state_controller.call("get_snapshot")


func get_behavior_type() -> String:
	return String(_behavior.get("type", ""))


func _get_enemy_skill_cooldown(action_type: String, fallback: float) -> float:
	return float(_skill_controller.call("get_cooldown_for_action", action_type, fallback))


func _apply_classification_metadata(enemy_config: Dictionary) -> void:
	EnemyConfigHelperScript.apply_classification_metadata(self, enemy_config)


func _get_behavior_attack_range_fallback() -> float:
	return EnemyConfigHelperScript.behavior_attack_range_fallback(_behavior, attack_range)


func _get_behavior_attack_range() -> float:
	return EnemyConfigHelperScript.behavior_attack_range(_behavior, attack_range)


func _apply_collision_radius(radius: float) -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return

	if collision_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		circle_shape.radius = radius


func _limit_actor_motion(delta: float, include_player: bool = false) -> void:
	if velocity.length_squared() <= 0.01 or delta <= 0.0:
		return

	var motion: Vector2 = velocity * delta
	var scale: float = 1.0
	if include_player and target != null and is_instance_valid(target):
		scale = minf(scale, _get_actor_motion_scale(motion, target))
	if _should_skip_enemy_neighbor_motion_limit():
		if scale < 1.0:
			velocity *= maxf(scale, 0.0)
		return
	var query_radius: float = maxf(
		motion.length() + _get_collision_radius(self, 24.0) + MOTION_LIMIT_EXTRA_RADIUS,
		NEARBY_ENEMY_CELL_SIZE
	)
	for enemy: Node2D in _nearby_enemies(global_position, query_radius):
		scale = minf(scale, _get_actor_motion_scale(motion, enemy))
	if scale < 1.0:
		velocity *= maxf(scale, 0.0)


func _should_limit_actor_motion() -> bool:
	if _is_strong_enemy():
		return true
	if target != null and is_instance_valid(target):
		if global_position.distance_squared_to(target.global_position) <= MOTION_LIMIT_ALWAYS_DISTANCE_SQUARED:
			return true

	_ensure_nearby_enemy_index()
	var enemy_count: int = _nearby_enemy_total_count
	if enemy_count < CROWDED_ENEMY_LOD_THRESHOLD:
		return true

	var throttle_frames: int = 2 if enemy_count < HEAVY_CROWD_ENEMY_LOD_THRESHOLD else 3
	var frame: int = int(Engine.get_physics_frames())
	return frame % throttle_frames == int(get_instance_id()) % throttle_frames


func _should_skip_enemy_neighbor_motion_limit() -> bool:
	return not _is_strong_enemy() and _is_crowded_enemy_lod_active()


func _should_skip_melee_neighbor_logic() -> bool:
	return not _is_strong_enemy() and _is_crowded_enemy_lod_active()


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


func _is_crowded_enemy_lod_active() -> bool:
	_ensure_nearby_enemy_index()
	return _nearby_enemy_total_count >= CROWDED_ENEMY_LOD_THRESHOLD


func _nearby_enemies(center: Vector2, radius: float) -> Array[Node2D]:
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
	return result


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
	for node: Node in tree.get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		var cell: Vector2i = _enemy_spatial_cell(enemy.global_position)
		var bucket: Array = _nearby_enemy_grid.get(cell, [])
		bucket.append(enemy)
		_nearby_enemy_grid[cell] = bucket
		_nearby_enemy_total_count += 1


static func _enemy_spatial_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / NEARBY_ENEMY_CELL_SIZE),
		floori(position.y / NEARBY_ENEMY_CELL_SIZE)
	)


func get_enemy_profile_snapshot(reset: bool = true) -> Dictionary:
	var snapshot: Dictionary = _enemy_profile_sections.duplicate(true)
	if reset:
		_enemy_profile_sections.clear()
	return snapshot


func _profile_start() -> int:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null or not bool(tree.root.get_meta("profile_enemy_physics", false)):
		return 0
	return Time.get_ticks_usec()


func _profile_add(section: String, start_usec: int) -> void:
	if start_usec <= 0:
		return
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var record: Dictionary = _enemy_profile_sections.get(section, {"usec": 0, "count": 0})
	record["usec"] = int(record.get("usec", 0)) + elapsed_usec
	record["count"] = int(record.get("count", 0)) + 1
	_enemy_profile_sections[section] = record


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


func _get_collision_radius(node: Node2D, fallback: float) -> float:
	var collision_shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return maxf((collision_shape.shape as CircleShape2D).radius, 0.0)
	return fallback


func _apply_visual_config(enemy_config: Dictionary) -> void:
	_visual_controller.call("apply_enemy_config", enemy_config)


func _update_enemy_visual_state(delta: float) -> void:
	var state: Dictionary = _state_controller.call("get_snapshot")
	state["status_state"] = _get_priority_status_visual_state()
	_visual_controller.call("update", state, delta)


func _should_update_enemy_visual_state(delta: float) -> bool:
	var interval: float = _get_enemy_visual_update_interval()
	if interval <= 0.0:
		return true

	_visual_update_timer -= delta
	if _visual_update_timer > 0.0:
		return false

	_visual_update_timer = interval + float(int(get_instance_id()) % 5) * 0.003
	return true


func _get_enemy_visual_update_interval() -> float:
	if not _is_normal_enemy():
		return 0.0
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


func _get_priority_status_visual_state() -> String:
	return ""


func _update_debug_health_display() -> void:
	_debug_display_controller.call("update_health", current_health, max_health)


func _show_debug_damage_number(amount: int, damage_result: Dictionary = {}) -> void:
	_debug_display_controller.call("show_damage_number", amount, damage_result)


func _award_soul_stones() -> void:
	_reward_controller.call("award_soul_stones")


func _apply_damage_synergies(amount: int, damage_type: Variant) -> int:
	return int(_reward_controller.call("apply_damage_synergies", amount, damage_type))


func _notify_enemy_killed_synergies() -> void:
	_reward_controller.call("notify_enemy_killed_synergies")


func _is_debug_control_mode() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_control_mode", false))


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


func _can_debug_force_elite_visual_state() -> bool:
	var rank: String = String(get_meta("enemy_rank", get_meta("enemy_type", "normal")))
	return rank == "elite" or rank == "boss"


func _is_normal_enemy() -> bool:
	return String(get_meta("enemy_rank", get_meta("enemy_type", "normal"))) == "normal"


func _is_strong_enemy() -> bool:
	var rank: String = String(get_meta("enemy_rank", get_meta("enemy_type", "normal")))
	return rank == "elite" or rank == "boss"
