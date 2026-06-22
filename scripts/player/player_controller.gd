extends CharacterBody2D


const SKILL_LEVEL_UP_OPTION_PREFIX: String = "skill_level_up:"
const SKILL_BRANCH_PREFIX: String = "branch_choice:"
const LEVEL_UP_UPGRADE_PREFIX: String = "level_up_upgrade:"
const PlayerDebugOverlayScript: Script = preload("res://scripts/debug/player_debug_overlay.gd")
const CharacterRuntimeScript: Script = preload("res://scripts/characters/character_runtime.gd")
const CharacterTraitSystemScript: Script = preload("res://scripts/characters/character_trait_system.gd")
const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")
const CharacterRunInitializerScript: Script = preload("res://scripts/characters/character_run_initializer.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")
const ModifierStoreScript: Script = preload("res://scripts/modifiers/modifier_store.gd")
const WeaponEquipSystemScript: Script = preload("res://scripts/weapons/weapon_equip_system.gd")
const WeaponSkillBindingScript: Script = preload("res://scripts/weapons/weapon_skill_binding.gd")
const WeaponBranchSystemScript: Script = preload("res://scripts/weapons/weapon_branch_system.gd")
const WeaponVisualScript: Script = preload("res://scripts/weapons/weapon_visual.gd")
const PlayerVisualControllerScript: Script = preload("res://scripts/player/player_visual_controller.gd")
const PlayerModifierApplierScript: Script = preload("res://scripts/player/player_modifier_applier.gd")
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

const RECENT_ENEMY_DAMAGE_PRIORITY_WINDOW_SECONDS: float = 0.75

signal health_changed(current_health: int, max_health: int)
signal died
signal experience_changed(current_experience: int, experience_to_next_level: int, level: int)
signal leveled_up(level: int)
signal upgrade_applied(upgrade_id: StringName)


@export var selected_character_id: StringName = &"mage"
@export var selected_weapon_id: StringName = &"fire_staff"
@export var load_config_from_data: bool = true
@export_range(0.0, 1000.0, 10.0, "or_greater") var move_speed: float = 220.0
@export_range(1, 1000, 1, "or_greater") var max_health: int = 100
@export_range(1, 100, 1, "or_greater") var starting_level: int = 1
@export_range(1, 10000, 1, "or_greater") var base_experience_to_next_level: int = 100
@export_range(1.0, 10.0, 0.05, "or_greater") var experience_growth_per_level: float = 1.25

var current_health: int
var level: int
var current_experience: int
var experience_to_next_level: int
var pickup_radius: float = 80.0
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


func _ready() -> void:
	add_to_group(&"player")
	_visual_controller.call("setup", self)
	_status_display_controller.call("setup", self)
	_ensure_status_manager()
	_ensure_debug_overlay()
	_ensure_character_systems()
	var default_loadout: RefCounted = CharacterLoadoutServiceScript.build_loadout(selected_character_id, selected_weapon_id)
	if default_loadout != null:
		reset_for_loadout(default_loadout)
	else:
		push_error("[Player] Could not build initial RunLoadout for %s + %s." % [String(selected_character_id), String(selected_weapon_id)])


func _ensure_debug_overlay() -> void:
	if get_node_or_null("PlayerDebugOverlay") != null:
		return

	var overlay: PlayerDebugOverlay = PlayerDebugOverlayScript.new()
	overlay.name = "PlayerDebugOverlay"
	add_child(overlay)


func reset_for_loadout(loadout: RefCounted) -> void:
	if loadout == null or not bool(loadout.call("is_valid")):
		push_error("[Player] reset_for_loadout requires a valid RunLoadout.")
		return
	_run_loadout = loadout
	selected_character_id = StringName(String(loadout.get("character_id")))
	selected_weapon_id = StringName(String(loadout.get("weapon_id")))
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
	_refresh_weapon_visual()
	_character_run_initializer.call("configure_starting_skills", self)
	_refresh_synergies()
	global_position = Vector2(768, 512)
	_has_movement_bounds = false
	_refresh_movement_bounds()
	health_changed.emit(current_health, max_health)
	experience_changed.emit(current_experience, experience_to_next_level, level)


func _ensure_character_systems() -> void:
	if get_node_or_null("CharacterRuntime") == null:
		var runtime: CharacterRuntime = CharacterRuntimeScript.new()
		runtime.name = "CharacterRuntime"
		add_child(runtime)
	if get_node_or_null("WeaponEquipSystem") == null:
		var equip_system: WeaponEquipSystem = WeaponEquipSystemScript.new()
		equip_system.name = "WeaponEquipSystem"
		add_child(equip_system)
	if get_node_or_null("WeaponSkillBinding") == null:
		var binding: WeaponSkillBinding = WeaponSkillBindingScript.new()
		binding.name = "WeaponSkillBinding"
		add_child(binding)
	if get_node_or_null("WeaponVisual") == null:
		var weapon_visual: Node2D = WeaponVisualScript.new()
		weapon_visual.name = "WeaponVisual"
		add_child(weapon_visual)
	if get_node_or_null("CharacterTraitSystem") == null:
		var trait_system: Node = CharacterTraitSystemScript.new()
		trait_system.name = "CharacterTraitSystem"
		add_child(trait_system)
	if get_node_or_null("ModifierStore") == null:
		var modifier_store: Node = ModifierStoreScript.new()
		modifier_store.name = "ModifierStore"
		add_child(modifier_store)
	if get_node_or_null("WeaponBranchSystem") == null:
		var branch_system: Node = WeaponBranchSystemScript.new()
		branch_system.name = "WeaponBranchSystem"
		add_child(branch_system)


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


func _update_status_effects(delta: float) -> void:
	var manager: Node = _ensure_status_manager()
	if manager != null and manager.has_method("update_status_effects"):
		manager.call("update_status_effects", delta)


func _update_status_label() -> void:
	_status_display_controller.call("update", get_status_snapshot())


func _is_movement_frozen() -> bool:
	var manager: Node = _ensure_status_manager()
	return manager != null and manager.has_method("is_movement_frozen") and bool(manager.call("is_movement_frozen"))


func _get_effective_move_speed() -> float:
	var manager: Node = _ensure_status_manager()
	var multiplier: float = 1.0
	if manager != null and manager.has_method("get_move_speed_multiplier"):
		multiplier = float(manager.call("get_move_speed_multiplier"))
	return move_speed * _get_modifier_move_speed_multiplier() * multiplier


func _get_modifier_move_speed_multiplier() -> float:
	var modifiers: Dictionary = ModifierAggregatorScript.collect(ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_MOVEMENT))
	var multiplier: float = float(modifiers.get("move_speed_multiplier", 1.0))
	multiplier *= maxf(1.0 + float(modifiers.get("move_speed_multiplier_add", 0.0)), 0.05)
	return maxf(multiplier, 0.05)


func get_effective_pickup_radius() -> float:
	var modifiers: Dictionary = ModifierAggregatorScript.collect(ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_PICKUP))
	var radius: float = pickup_radius
	radius *= maxf(1.0 + float(modifiers.get("pickup_radius_multiplier_add", 0.0)), 0.05)
	radius += float(modifiers.get("pickup_radius_add", 0.0))
	return maxf(radius, 1.0)


func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
	var manager: Node = _ensure_status_manager()
	if manager == null or not manager.has_method("apply_status"):
		return false
	var applied: bool = bool(manager.call("apply_status", status_id, params))
	_update_status_label()
	return applied


func has_status(status_id: Variant) -> bool:
	var manager: Node = _ensure_status_manager()
	return manager != null and manager.has_method("has_status") and bool(manager.call("has_status", status_id))


func get_status_stack(status_id: Variant) -> int:
	var manager: Node = _ensure_status_manager()
	if manager == null or not manager.has_method("get_status_stack"):
		return 0
	return int(manager.call("get_status_stack", status_id))


func consume_shock_stack() -> bool:
	return consume_status_stack(&"shock", 1)


func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
	var manager: Node = _ensure_status_manager()
	if manager == null or not manager.has_method("consume_status_stack"):
		return false
	var consumed: bool = bool(manager.call("consume_status_stack", status_id, stack_count))
	_update_status_label()
	return consumed


func get_status_snapshot() -> Array[Dictionary]:
	var manager: Node = _ensure_status_manager()
	if manager == null or not manager.has_method("get_status_snapshot"):
		return []
	return manager.call("get_status_snapshot")


func clear_statuses() -> void:
	var manager: Node = _ensure_status_manager()
	if manager != null and manager.has_method("clear_statuses"):
		manager.call("clear_statuses")
	_update_status_label()


func _initialize_character_runtime() -> bool:
	if _run_loadout != null:
		return bool(_character_run_initializer.call("initialize_loadout", self, _run_loadout))
	push_error("[Player] Missing RunLoadout during character runtime initialization.")
	return false


func _refresh_weapon_visual() -> void:
	var weapon_visual: Node = get_node_or_null("WeaponVisual")
	if weapon_visual != null and weapon_visual.has_method("refresh_from_player"):
		weapon_visual.call("refresh_from_player", self)


func _reset_runtime_stats() -> void:
	move_speed = 220.0
	max_health = 100
	starting_level = 1
	base_experience_to_next_level = 100
	experience_growth_per_level = 1.25
	pickup_radius = 80.0
	damage_multiplier = 1.0
	attack_speed_multiplier = 1.0
	crit_chance = 0.0
	crit_damage = 1.5
	armor = 0
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
	_last_boss_skill_hit_time = -10.0
	_last_contact_damage_time = -10.0
	_last_area_damage_times.clear()
	_recent_enemy_damage_sources.clear()
	set_meta("level_up_upgrade_levels", {})
	_experience_formula_type = "exponential"
	_experience_formula_base = 100
	_experience_formula_per_level = 0
	_experience_table = []
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


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	_update_status_effects(delta)
	_update_player_tick_special_rules(delta)
	_update_status_label()
	if _is_movement_frozen():
		input_direction = Vector2.ZERO

	velocity = input_direction * _get_effective_move_speed()
	_limit_actor_motion(delta)
	move_and_slide()
	_clamp_to_movement_bounds()
	_update_trait_movement(input_direction, delta)
	_update_visual_state(input_direction, delta)


func _limit_actor_motion(delta: float) -> void:
	if velocity.length_squared() <= 0.01 or delta <= 0.0:
		return

	var motion: Vector2 = velocity * delta
	var scale: float = 1.0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		scale = minf(scale, _get_actor_motion_scale(motion, enemy))
	if scale < 1.0:
		velocity *= maxf(scale, 0.0)


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


func _clamp_to_movement_bounds() -> void:
	if not _has_movement_bounds:
		_refresh_movement_bounds()
	if not _has_movement_bounds:
		return

	global_position = Vector2(
		clampf(global_position.x, _movement_bounds.position.x, _movement_bounds.position.x + _movement_bounds.size.x),
		clampf(global_position.y, _movement_bounds.position.y, _movement_bounds.position.y + _movement_bounds.size.y)
	)


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


func refresh_movement_bounds() -> void:
	_has_movement_bounds = false
	_refresh_movement_bounds()


func _apply_camera_limits(background_bounds: Rect2) -> void:
	var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	camera.limit_left = floori(background_bounds.position.x)
	camera.limit_top = floori(background_bounds.position.y)
	camera.limit_right = ceili(background_bounds.position.x + background_bounds.size.x)
	camera.limit_bottom = ceili(background_bounds.position.y + background_bounds.size.y)
	camera.limit_smoothed = true


func take_damage(amount_or_packet: Variant, _damage_type: Variant = &"") -> void:
	DamageApplicationServiceScript.apply_player_damage(self, amount_or_packet, _damage_type)


func _record_damage_taken(amount: int, damage_result: Dictionary, source_packet: Variant) -> void:
	var tracker: Node = RunStatsTrackerScript.get_active(get_tree())
	if tracker != null and tracker.has_method("record_damage_taken"):
		tracker.call("record_damage_taken", amount, damage_result, source_packet)
	_record_recent_enemy_damage_source(amount, source_packet, damage_result)
	if amount > 0:
		_trigger_damage_taken_special_rules(source_packet, damage_result, amount)


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


func _record_recent_enemy_damage_source(amount: int, source_packet: Variant, damage_result: Dictionary = {}) -> void:
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


func _trigger_damage_taken_special_rules(source_packet: Variant, damage_result: Dictionary = {}, amount: int = 0) -> void:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return
	var parent_node: Node = get_tree().current_scene if get_tree() != null else get_parent()
	FireSkillRuntimeScript.execute_passive_event(&"on_player_damaged", {
		"player": self,
		"caster": self,
		"owner": self,
		"parent": parent_node,
		"source_packet": source_packet,
		"damage_result": damage_result,
		"amount": amount,
		"skill_manager": skill_manager,
		"relic_manager": get_node_or_null("RelicManager"),
		"event_bus": get_node_or_null("SkillEventBus"),
		"target_group": &"enemies"
	}, skill_manager)
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill_instance: RefCounted = skill_variant as RefCounted
		if skill_instance == null:
			continue
		_skill_special_rule_executor.call("execute_player_damaged", {
			"player": self,
			"caster": self,
			"parent": parent_node,
			"source_packet": source_packet,
			"damage_result": damage_result,
			"amount": amount,
			"skill_instance": skill_instance,
			"skill_manager": skill_manager,
			"relic_manager": get_node_or_null("RelicManager"),
			"target_group": &"enemies"
		})
		var rules_variant: Variant = skill_instance.get("runtime_special_rules")
		if not (rules_variant is Dictionary):
			continue
		var rules: Dictionary = rules_variant
		if not rules.has("protective_lava_ring_on_player_damaged"):
			if rules.has("frost_ring_on_player_damaged"):
				SpecialDamageRuleHandlerScript.execute_frost_ring_on_player_damaged(rules, {
					"player": self,
					"caster": self,
					"parent": parent_node,
					"source_packet": source_packet,
					"damage_result": damage_result,
					"skill_instance": skill_instance,
					"target_group": &"enemies"
				})
			continue
		SpecialDamageRuleHandlerScript.execute_protective_lava_ring_on_player_damaged(rules, {
			"player": self,
			"caster": self,
			"parent": parent_node,
			"source_packet": source_packet,
			"damage_result": damage_result,
			"skill_instance": skill_instance,
			"target_group": &"enemies"
		})
		if rules.has("frost_ring_on_player_damaged"):
			SpecialDamageRuleHandlerScript.execute_frost_ring_on_player_damaged(rules, {
				"player": self,
				"caster": self,
				"parent": parent_node,
				"source_packet": source_packet,
				"damage_result": damage_result,
				"skill_instance": skill_instance,
				"target_group": &"enemies"
			})


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


func _extract_enemy_instance_id(source_instance_id: String, attacker_id: String) -> String:
	if source_instance_id != "":
		var source_parts: PackedStringArray = source_instance_id.split(":", false, 1)
		if not source_parts.is_empty() and _is_positive_int_string(source_parts[0]):
			return source_parts[0]
	if _is_positive_int_string(attacker_id):
		return attacker_id
	return ""


func _is_positive_int_string(value: String) -> bool:
	return value.is_valid_int() and int(value) > 0


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


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


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


func _apply_boss_overlap_protection(amount: int, source_packet: Variant) -> int:
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


func _is_damage_blocked_by_hit_protection(source_packet: Variant) -> bool:
	if not (source_packet is Dictionary) and not (source_packet is RefCounted and source_packet.has_method("get_value")):
		return false

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


func _damage_source_value(source_packet: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if source_packet is Dictionary:
		return (source_packet as Dictionary).get(key, fallback)
	if source_packet is RefCounted and source_packet.has_method("get_value"):
		return source_packet.call("get_value", key, fallback)
	return fallback


func _update_visual_state(input_direction: Vector2, delta: float) -> void:
	_visual_controller.call("update", input_direction, current_health, delta)


func _update_trait_movement(input_direction: Vector2, delta: float) -> void:
	var trait_system: Node = get_node_or_null("CharacterTraitSystem")
	if trait_system == null or not trait_system.has_method("handle_movement"):
		return
	trait_system.call("handle_movement", input_direction.length_squared() > 0.001, delta)


func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	var final_amount: int = maxi(roundi(float(amount) * experience_gain_multiplier), 1)
	current_experience += final_amount

	while current_experience >= experience_to_next_level:
		current_experience -= experience_to_next_level
		level += 1
		experience_to_next_level = _get_experience_required_for_level(level)
		leveled_up.emit(level)

	experience_changed.emit(current_experience, experience_to_next_level, level)


func apply_upgrade(upgrade_id: StringName) -> void:
	var upgrade_id_text: String = String(upgrade_id)
	var dev_enabled: bool = _is_dev_run()
	if upgrade_id_text.begins_with(SKILL_BRANCH_PREFIX):
		if _apply_branch_upgrade(upgrade_id_text, dev_enabled):
			upgrade_applied.emit(upgrade_id)
		return

	if upgrade_id_text.begins_with(SKILL_LEVEL_UP_OPTION_PREFIX):
		if _apply_skill_level_up_upgrade(upgrade_id_text, dev_enabled):
			upgrade_applied.emit(upgrade_id)
		return

	if upgrade_id_text.begins_with(LEVEL_UP_UPGRADE_PREFIX):
		var upgrade_parts: PackedStringArray = upgrade_id_text.split(":")
		var level_up_upgrade_id: StringName = StringName(upgrade_parts[1] if upgrade_parts.size() > 1 else "")
		if _apply_level_up_upgrade(level_up_upgrade_id):
			upgrade_applied.emit(upgrade_id)
			_refresh_skill_configs()
			_refresh_synergies()
		return

	var upgrade: Dictionary = GameData.get_upgrade(upgrade_id)
	if not upgrade.is_empty():
		_apply_upgrade_data(upgrade_id, upgrade_id, upgrade)


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


func _apply_level_up_upgrade(upgrade_id: StringName) -> bool:
	var upgrade: Dictionary = GameData.get_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false

	var upgrade_level: int = _get_level_up_upgrade_level(upgrade_id)
	var max_level: int = maxi(int(upgrade.get("max_level", 1)), 1)
	if upgrade_level >= max_level:
		return false

	if upgrade.has("learn_skill_id"):
		var learned_skill_id: StringName = StringName(String(upgrade.get("learn_skill_id", "")))
		if not _learn_active_skill(learned_skill_id):
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


func _learn_active_skill(skill_id: StringName) -> bool:
	if skill_id == &"":
		return false
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("add_skill"):
		return false
	return bool(skill_manager.call("add_skill", skill_id))


func _get_experience_required_for_level(character_level: int) -> int:
	if _experience_formula_type == "linear":
		return maxi(_experience_formula_base + _experience_formula_per_level * maxi(character_level, 0), 1)
	if _experience_formula_type == "table" and not _experience_table.is_empty():
		var table_index: int = clampi(character_level - 1, 0, _experience_table.size() - 1)
		return maxi(_experience_table[table_index], 1)

	var level_offset: int = maxi(character_level - 1, 0)
	return maxi(roundi(base_experience_to_next_level * pow(experience_growth_per_level, level_offset)), 1)


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


func _apply_base_stats(base_stats: Dictionary) -> void:
	max_health = int(base_stats.get("max_hp", max_health))
	move_speed = float(base_stats.get("move_speed", move_speed))
	pickup_radius = float(base_stats.get("pickup_radius", pickup_radius))
	damage_multiplier = float(base_stats.get("damage_multiplier", damage_multiplier))
	attack_speed_multiplier = float(base_stats.get("attack_speed_multiplier", attack_speed_multiplier))
	crit_chance = float(base_stats.get("crit_chance", crit_chance))
	crit_damage = float(base_stats.get("crit_damage", crit_damage))
	armor = int(base_stats.get("armor", armor))
	soul_gain_multiplier = float(base_stats.get("soul_gain_multiplier", soul_gain_multiplier))


func _apply_visual_config(character: Dictionary) -> void:
	_visual_controller.call("apply_character_config", character)


func _apply_permanent_upgrade_modifiers() -> void:
	var modifiers: Dictionary = SaveManager.get_permanent_upgrade_total_modifiers()
	if modifiers.is_empty():
		return

	set_run_modifier_source(&"permanent_upgrades", modifiers)


func _get_skill_manager() -> Node:
	return get_node_or_null("SkillManager")


func _get_level_up_upgrade_level(upgrade_id: StringName) -> int:
	var levels_variant: Variant = get_meta("level_up_upgrade_levels", {})
	if levels_variant is Dictionary:
		var levels: Dictionary = levels_variant
		return int(levels.get(String(upgrade_id), 0))
	return 0


func _set_level_up_upgrade_level(upgrade_id: StringName, level_value: int) -> void:
	var levels: Dictionary = {}
	var levels_variant: Variant = get_meta("level_up_upgrade_levels", {})
	if levels_variant is Dictionary:
		levels = (levels_variant as Dictionary).duplicate(true)
	levels[String(upgrade_id)] = level_value
	set_meta("level_up_upgrade_levels", levels)


func _get_skill_instance(skill_id: StringName) -> RefCounted:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("get_skill"):
		return null

	return skill_manager.call("get_skill", skill_id) as RefCounted


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _parse_int_array(value: Variant) -> Array[int]:
	var parsed: Array[int] = []
	if not (value is Array):
		return parsed
	for item: Variant in value:
		parsed.append(int(item))
	return parsed


func _get_level_dictionary(value: Variant, level_index: int) -> Dictionary:
	if value is Array:
		var items: Array = value
		if level_index >= 0 and level_index < items.size() and items[level_index] is Dictionary:
			return (items[level_index] as Dictionary).duplicate(true)
	elif value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


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


func _is_empty_modifier_value(value: Variant) -> bool:
	if value is Array:
		return (value as Array).is_empty()
	if value is Dictionary:
		return (value as Dictionary).is_empty()
	return true


func _refresh_skill_configs() -> void:
	var skill_manager: Node = _get_skill_manager()
	if skill_manager != null and skill_manager.has_signal("skill_changed"):
		skill_manager.emit_signal("skill_changed")


func _apply_modifiers(modifiers: Variant) -> void:
	_modifier_applier.call("apply", self, ModifierSourceScript.flatten(modifiers, ModifierSourceScript.SOURCE_UNKNOWN, ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_PLAYER)))


func _get_snapshot_modifiers(modifiers: Variant) -> Dictionary:
	var flat_modifiers: Dictionary = ModifierSourceScript.flatten(modifiers, ModifierSourceScript.SOURCE_UNKNOWN, ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_PLAYER))
	var snapshot_modifiers: Dictionary = {}
	for key_variant: Variant in flat_modifiers.keys():
		var key: String = String(key_variant)
		if _is_dynamic_scope_modifier_key(key):
			continue
		snapshot_modifiers[key_variant] = flat_modifiers[key_variant]
	return snapshot_modifiers


func _is_dynamic_scope_modifier_key(key: String) -> bool:
	return _is_damage_scope_modifier_key(key) or _is_movement_scope_modifier_key(key) or _is_pickup_scope_modifier_key(key)


func _is_damage_scope_modifier_key(key: String) -> bool:
	match key:
		"damage_multiplier", "damage_multiplier_add", "crit_chance_add", "crit_damage_add", "equipped_weapon_damage_add":
			return true
	if key.ends_with("_damage_multiplier_add"):
		return key != "damage_taken_multiplier_add"
	return false


func _is_movement_scope_modifier_key(key: String) -> bool:
	return key == "move_speed_multiplier" or key == "move_speed_multiplier_add"


func _is_pickup_scope_modifier_key(key: String) -> bool:
	return key == "pickup_radius_multiplier_add" or key == "pickup_radius_add"


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


func set_run_modifier_source(source_id: Variant, modifiers: Variant) -> void:
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store != null and modifier_store.has_method("set_source"):
		modifier_store.call("set_source", source_id, modifiers, _get_run_modifier_scopes(modifiers))
	_apply_modifiers(_get_snapshot_modifiers(modifiers))


func merge_run_modifier_source(source_id: Variant, modifiers: Variant) -> void:
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store != null and modifier_store.has_method("merge_source"):
		modifier_store.call("merge_source", source_id, modifiers, _get_run_modifier_scopes(modifiers))
	_apply_modifiers(_get_snapshot_modifiers(modifiers))


func clear_run_modifier_source(source_id: Variant) -> void:
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store != null and modifier_store.has_method("clear_source"):
		modifier_store.call("clear_source", source_id)


func refresh_run_modifier_snapshot() -> void:
	var modifier_store: Node = get_node_or_null("ModifierStore")
	if modifier_store == null or not modifier_store.has_method("collect"):
		return
	var modifiers_variant: Variant = modifier_store.call("collect", ModifierQueryScript.for_player(self, ModifierQueryScript.SCOPE_PLAYER))
	if modifiers_variant is Dictionary:
		_apply_modifiers(_get_snapshot_modifiers(modifiers_variant))


func _apply_environment_modifiers() -> void:
	var spawner: Node = get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null and spawner.has_method("apply_run_modifiers"):
		spawner.call(&"apply_run_modifiers", {
			"enemy_spawn_count_multiplier_add": enemy_spawn_count_multiplier_add,
			"boss_hp_multiplier_add": boss_hp_multiplier_add
		})


func _upgrade_skill(skill_id: StringName, amount: int, dev_branch_id: Variant = &"", dev_enabled: bool = false) -> bool:
	if amount <= 0:
		return false

	var skill_manager: Node = _get_skill_manager()
	if skill_manager == null or not skill_manager.has_method("upgrade_skill"):
		return false

	var upgraded: bool = false
	for _upgrade_index in range(amount):
		if not bool(skill_manager.call("upgrade_skill", skill_id)):
			break
		var skill_instance: RefCounted = _get_skill_instance(skill_id)
		var new_level: int = int(skill_instance.get("current_level")) if skill_instance != null else 0
		var branch_system: Node = get_node_or_null("WeaponBranchSystem")
		if branch_system != null and branch_system.has_method("apply_selected_branch_level"):
			branch_system.call("apply_selected_branch_level", self, new_level, dev_branch_id, dev_enabled)
		upgraded = true

	if upgraded:
		_refresh_synergies()
	return upgraded


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


func _refresh_synergies() -> void:
	var synergy_manager: Node = get_node_or_null("SynergyManager")
	if synergy_manager != null and synergy_manager.has_method("refresh_active_synergies"):
		synergy_manager.call("refresh_active_synergies", self)


func _apply_branch_upgrade(upgrade_id_text: String, _dev_enabled: bool = false) -> bool:
	var parts: PackedStringArray = upgrade_id_text.split(":")
	if parts.size() < 3:
		return false

	var skill_id: StringName = StringName(parts[1])
	var branch_id: StringName = StringName(parts[2])
	var skill_instance: RefCounted = _get_skill_instance(skill_id)
	if skill_instance == null:
		return false

	var branch_system: Node = get_node_or_null("WeaponBranchSystem")
	# Lv2 branch choice defines the run route, so dev Skill Cards must reuse the
	# same runtime lock as the normal upgrade flow.
	var applied: bool = branch_system != null and branch_system.has_method("apply_branch") and bool(branch_system.call("apply_branch", self, branch_id, false))
	if applied:
		_refresh_skill_configs()
		_refresh_synergies()
	return applied


func _apply_skill_level_up_upgrade(upgrade_id_text: String, dev_enabled: bool = false) -> bool:
	var level_parts: PackedStringArray = upgrade_id_text.split(":")
	var skill_id_from_option: StringName = StringName(level_parts[1] if level_parts.size() > 1 else "")
	if not dev_enabled:
		return _upgrade_skill(skill_id_from_option, 1)

	var target_level: int = int(level_parts[2] if level_parts.size() > 2 else "0")
	var branch_id: StringName = StringName(level_parts[3] if level_parts.size() > 3 else "")
	var skill_instance: RefCounted = _get_skill_instance(skill_id_from_option)
	if skill_instance == null:
		return false
	if target_level <= int(skill_instance.get("current_level")):
		var branch_system: Node = get_node_or_null("WeaponBranchSystem")
		return branch_system != null and branch_system.has_method("apply_selected_branch_level") and bool(branch_system.call("apply_selected_branch_level", self, target_level, branch_id, true))
	return _upgrade_skill(skill_id_from_option, target_level - int(skill_instance.get("current_level")), branch_id, true)


func _is_dev_run() -> bool:
	var node: Node = self
	while node != null:
		if node.has_meta("debug"):
			return bool(node.get_meta("debug", false))
		node = node.get_parent()
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("developer_mode_enabled", false))
