extends RefCounted
class_name SkillActionExecutor


const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const DamageSourceIdentityScript: Script = preload("res://scripts/combat/damage_source_identity.gd")
const ModifierResolverScript: Script = preload("res://scripts/skills/modifier_resolver.gd")
const SkillEffectAdapterScript: Script = preload("res://scripts/skills/skill_effect_adapter.gd")
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const SkillSpecialRuleExecutorScript: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")
const TargetingServiceScript: Script = preload("res://scripts/skills/targeting_service.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

const ELEMENT_ALIASES: Dictionary = {
	"frost": "ice",
	"thunder": "lightning"
}

var _special_rule_executor: RefCounted = SkillSpecialRuleExecutorScript.new()


func execute_actions(actions: Array, context: Dictionary) -> void:
	for action_variant: Variant in actions:
		if action_variant is Dictionary:
			execute_action(action_variant, context)


func execute_action(action: Dictionary, context: Dictionary) -> Variant:
	var action_type: String = String(action.get("type", ""))
	var params: Dictionary = _get_dictionary(action.get("params", {}))

	match action_type:
		"deal_damage":
			return _deal_damage(params, context)
		"apply_status":
			return _apply_status(params, context)
		"spawn_projectile":
			return _spawn_projectile(params, context)
		"spawn_projectiles_at_targets":
			return _spawn_projectiles_at_targets(params, context)
		"spawn_area":
			return _spawn_area(params, context, "area")
		"create_explosion":
			return _spawn_area(params, context, "explosion")
		"spawn_trap":
			return _spawn_trap(params, context)
		"spawn_orbit_object":
			return _spawn_orbit_object(params, context)
		"spawn_orbitals":
			return _spawn_orbitals(params, context)
		"spawn_particles":
			return _spawn_particles(params, context)
		"spawn_summon":
			return _spawn_summon(params, context)
		"chain_to_targets":
			return _chain_to_targets(params, context)
		"consume_status_stack":
			return _consume_status_stack(params, context)
		"damage_by_status_stack":
			return _damage_by_status_stack(params, context)
		"knockback":
			return _knockback(params, context)
		"heal_owner", "heal_caster":
			return _heal_owner(params, context)
		"destroy_enemy_projectile":
			return _destroy_enemy_projectile(params, context)
		"add_temporary_modifier":
			return _add_temporary_modifier(params, context)
		"grant_shield":
			return _grant_shield(params, context)
		"pull":
			return _pull(params, context)
		"repeat_skill":
			return _repeat_skill(params, context)
		"transform_area":
			return _transform_area(params, context)
		"transfer_status":
			return _transfer_status(params, context)
		"consume_status_duration":
			return _consume_status_duration(params, context)
		"trigger_overload":
			return _trigger_overload(params, context)
		"shatter_frozen":
			return _shatter_frozen(params, context)
		"spawn_projectile_burst":
			return _spawn_projectile_burst(params, context)
		"repeat_area_path":
			return _repeat_area_path(params, context)
		"spawn_area_from_existing_area":
			return _spawn_area_from_existing_area(params, context)
		_:
			push_warning("[SkillActionExecutor] Unsupported action type: %s" % action_type)
			return null


func _deal_damage(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("take_damage"):
		return false

	var base_amount: Variant = params.get("amount", ModifierResolverScript.get_stat(context, "damage", 0))
	var amount: int = maxi(roundi(_resolve_scaled_amount(base_amount, context, "damage")), 0)
	var damage_type: StringName = _get_damage_type(params, context, "skill", _get_damage_origin(params, context, "skill"))
	var packet: Dictionary = _build_damage_packet(params, context, amount, "skill")
	_inherit_projectile_runtime_damage_packet(packet, context, target)
	packet = _special_rule_executor.call("adjust_damage_packet", packet, context)
	target.call("take_damage", packet, damage_type)
	return true


func _inherit_projectile_runtime_damage_packet(packet: Dictionary, context: Dictionary, target: Node) -> void:
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return
	var runtime_packet: Dictionary = _get_dictionary(projectile.get("damage_packet"))
	if runtime_packet.is_empty():
		return
	for key_variant: Variant in runtime_packet.keys():
		var key: String = String(key_variant)
		if key == "raw_amount" or key == "amount" or key == "target_id":
			continue
		packet[key] = runtime_packet[key_variant]
	if target != null:
		packet["target_id"] = str(target.get_instance_id())


func _apply_status(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false

	var chance: float = clampf(float(params.get("chance", 1.0)), 0.0, 1.0)
	if randf() > chance:
		return false

	var status_id: StringName = StringName(String(params.get("status_id", "")))
	if status_id == &"":
		return false

	var status_params: Dictionary = {}
	if params.has("duration"):
		status_params["duration"] = float(ModifierResolverScript.resolve_value(context, "status_duration", params["duration"]))
	if params.has("damage"):
		status_params["damage"] = int(ModifierResolverScript.resolve_value(context, "status_damage", params["damage"]))
	if params.has("tick_interval"):
		status_params["tick_interval"] = float(ModifierResolverScript.resolve_value(context, "status_tick_interval", params["tick_interval"]))
	if params.has("stack"):
		status_params["stacks"] = int(params["stack"])
	if params.has("max_stacks"):
		status_params["max_stacks"] = int(params["max_stacks"])
	status_params = DamageTraceContextScript.apply_to_status_params(status_params, context)
	status_params = _special_rule_executor.call("get_status_params", status_id, status_params, context)

	if target.has_method("apply_status"):
		return bool(target.call("apply_status", status_id, status_params))
	if target.has_method("add_status_effect"):
		target.call("add_status_effect", status_id)
		return true

	return false


func _spawn_projectile(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node2D = context.get("caster") as Node2D
	var target: Node2D = context.get("target") as Node2D
	if caster == null or target == null:
		return false

	var count: int = maxi(int(ModifierResolverScript.resolve_value(context, "projectile_count", params.get("count", 1))), 1)
	var speed: float = maxf(float(ModifierResolverScript.resolve_value(context, "projectile_speed", params.get("speed", 420.0))), 1.0)
	var spread_angle: float = deg_to_rad(float(ModifierResolverScript.resolve_value(context, "spread_angle", params.get("spread_angle", 0.0))))
	var pierce: int = maxi(int(ModifierResolverScript.resolve_value(context, "pierce", params.get("pierce", 0))), 0)
	var radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "area_radius", params.get("collision_radius", params.get("radius", 10.0)))), 1.0)
	var lifetime: float = maxf(float(params.get("lifetime", 2.0)), 0.1)
	var damage: int = maxi(roundi(_resolve_scaled_amount(params.get("damage", ModifierResolverScript.get_stat(context, "damage", 0)), context, "damage")), 0)
	var source_id: StringName = StringName(String(params.get("projectile_id", params.get("source_id", ""))))
	var statuses_on_hit: Array[StringName] = _get_statuses_on_hit(params, context)
	var base_direction: Vector2 = caster.global_position.direction_to(target.global_position)
	if base_direction == Vector2.ZERO:
		return false

	var parent: Node = _get_parent_node(context)
	var cast_instance_id: String = _next_cast_instance_id(context)
	_mark_storm_hail_cast(context, cast_instance_id)
	var forbidden_page_pending: bool = _consume_forbidden_page_pending(context)
	var arcane_extra_projectiles: int = _consume_arcane_double_page_pending(context)
	count += arcane_extra_projectiles
	var hot_rapid_fire_pending: bool = _consume_hot_rapid_fire_pending(context)
	var hot_rapid_fire_crit_chance_add: float = _get_hot_rapid_fire_crit_chance_add(context)
	var start_angle: float = -spread_angle * float(count - 1) * 0.5
	for projectile_index in range(count):
		var projectile_params: Dictionary = params.duplicate(true)
		if not projectile_params.has("source_instance_id"):
			projectile_params["source_instance_id"] = DamageSourceIdentityScript.for_projectile(cast_instance_id, projectile_index, source_id)
		var use_hot_rapid_fire: bool = hot_rapid_fire_pending and projectile_index == 0
		var direction: Vector2 = base_direction.rotated(start_angle + spread_angle * float(projectile_index)).normalized()
		var projectile_position: Vector2 = caster.global_position + direction * float(params.get("spawn_offset", 24.0))
		var trajectory_mode: String = String(params.get("trajectory_mode", "linear"))
		CombatObjectFactoryScript.create_projectile({
			"parent": parent,
			"projectile_id": source_id,
			"position": projectile_position,
			"direction": direction,
			"damage": damage,
			"damage_type": _get_damage_type(projectile_params, context, "projectile", _get_damage_origin(projectile_params, context, "projectile")),
			"damage_packet": _build_damage_packet(projectile_params, context, damage, "projectile"),
			"speed": speed,
			"pierce": pierce,
			"radius": radius,
			"lifetime": lifetime,
			"status_on_hit": StringName(String(params.get("status_id", params.get("status_on_hit", "")))),
			"statuses_on_hit": statuses_on_hit,
			"status_params": _get_status_params(params, context),
			"target_group": context.get("target_group", &"enemies"),
			"event_bus": context.get("event_bus"),
			"skill_instance": context.get("skill_instance"),
			"caster": caster,
			"skill_manager": context.get("skill_manager"),
			"relic_manager": context.get("relic_manager"),
			"source_id": source_id,
			"event_on_hit": &"on_projectile_hit",
			"actions_on_hit": _get_array(projectile_params.get("actions_on_hit", [])),
			"cast_instance_id": cast_instance_id,
			"hot_rapid_fire_crit": use_hot_rapid_fire,
			"hot_rapid_fire_crit_chance_add": hot_rapid_fire_crit_chance_add if use_hot_rapid_fire else 0.0,
			"forbidden_page": forbidden_page_pending and projectile_index == 0,
			"trajectory_mode": trajectory_mode,
			"curve_start_position": projectile_position,
			"curve_target_position": target.global_position,
			"curve_height": float(params.get("curve_height", 64.0)),
			"homing_enabled": bool(params.get("homing_enabled", false)),
			"homing_turn_rate": float(params.get("homing_turn_rate", 8.0)),
			"homing_seek_range": float(params.get("homing_seek_range", params.get("range", 0.0)))
		})

	return true


func _spawn_projectiles_at_targets(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return false

	var count: int = maxi(int(ModifierResolverScript.resolve_value(context, "projectile_count", params.get("count", 1))), 1)
	var range: float = maxf(float(ModifierResolverScript.resolve_value(context, "range", params.get("range", ModifierResolverScript.get_stat(context, "range", INF)))), 1.0)
	var targets: Array = TargetingServiceScript.find_targets(caster, String(params.get("targeting_mode", "around_player")), {
		"origin": caster,
		"range": range,
		"radius": range,
		"count": count
	})
	if targets.is_empty():
		return false
	targets = _build_projectile_target_sequence(targets, count)

	var speed: float = maxf(float(ModifierResolverScript.resolve_value(context, "projectile_speed", params.get("speed", 420.0))), 1.0)
	var pierce: int = maxi(int(ModifierResolverScript.resolve_value(context, "pierce", params.get("pierce", 0))), 0)
	var radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "area_radius", params.get("collision_radius", params.get("radius", 10.0)))), 1.0)
	var lifetime: float = maxf(float(params.get("lifetime", 2.0)), 0.1)
	var damage: int = maxi(roundi(_resolve_scaled_amount(params.get("damage", ModifierResolverScript.get_stat(context, "damage", 0)), context, "damage")), 0)
	var source_id: StringName = StringName(String(params.get("projectile_id", params.get("source_id", ""))))
	var statuses_on_hit: Array[StringName] = _get_statuses_on_hit(params, context)
	var parent: Node = _get_parent_node(context)
	var cast_instance_id: String = _next_cast_instance_id(context)
	_mark_storm_hail_cast(context, cast_instance_id)

	var spawned: int = 0
	var target_hit_counts: Dictionary = {}
	for target_variant: Variant in targets:
		if spawned >= count:
			break
		var target: Node2D = target_variant as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		var target_key: String = str(target.get_instance_id())
		var same_target_hit_index: int = int(target_hit_counts.get(target_key, 0))
		target_hit_counts[target_key] = same_target_hit_index + 1
		var visual_start_position: Vector2 = _resolve_projectile_visual_start_position(caster.global_position, target.global_position, same_target_hit_index, params)
		var visual_target_position: Vector2 = _resolve_projectile_visual_target_position(target.global_position, same_target_hit_index, params)

		var direction: Vector2 = visual_start_position.direction_to(visual_target_position)
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var projectile_context: Dictionary = context.duplicate(true)
		projectile_context["target"] = target
		var projectile_params: Dictionary = params.duplicate(true)
		if not projectile_params.has("source_instance_id"):
			projectile_params["source_instance_id"] = DamageSourceIdentityScript.for_projectile(cast_instance_id, spawned, source_id)
		var damage_packet: Dictionary = _build_damage_packet(projectile_params, projectile_context, damage, "projectile")
		_apply_projectile_damage_sequence(damage_packet, projectile_params, same_target_hit_index, context)
		CombatObjectFactoryScript.create_projectile({
			"parent": parent,
			"projectile_id": source_id,
			"position": visual_start_position,
			"direction": direction.normalized(),
			"damage": damage,
			"damage_type": _get_damage_type(projectile_params, projectile_context, "projectile", _get_damage_origin(projectile_params, projectile_context, "projectile")),
			"damage_packet": damage_packet,
			"speed": speed,
			"pierce": pierce,
			"radius": radius,
			"lifetime": lifetime,
			"status_on_hit": StringName(String(params.get("status_id", params.get("status_on_hit", "")))),
			"statuses_on_hit": statuses_on_hit,
			"status_params": _get_status_params(params, projectile_context),
			"target_group": context.get("target_group", &"enemies"),
			"event_bus": context.get("event_bus"),
			"skill_instance": context.get("skill_instance"),
			"caster": caster,
			"skill_manager": context.get("skill_manager"),
			"relic_manager": context.get("relic_manager"),
			"source_id": source_id,
			"event_on_hit": &"on_projectile_hit",
			"cast_instance_id": cast_instance_id,
			"trajectory_mode": String(params.get("trajectory_mode", "curve")),
			"curve_start_position": visual_start_position,
			"curve_target_position": visual_target_position,
			"curve_height": float(params.get("curve_height", 64.0)),
			"homing_enabled": bool(params.get("homing_enabled", false)),
			"homing_turn_rate": float(params.get("homing_turn_rate", 8.0)),
			"homing_seek_range": float(params.get("homing_seek_range", params.get("range", 0.0)))
		})
		spawned += 1

	return spawned > 0


func _build_projectile_target_sequence(targets: Array, count: int) -> Array:
	var valid_targets: Array = []
	for target_variant: Variant in targets:
		var target: Node2D = target_variant as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		valid_targets.append(target)
	if valid_targets.is_empty():
		return []

	var result: Array = []
	for target: Node2D in valid_targets:
		if result.size() >= count:
			return result
		result.append(target)
	var repeat_index: int = 0
	while result.size() < count:
		result.append(valid_targets[repeat_index % valid_targets.size()])
		repeat_index += 1
	return result


func _resolve_projectile_visual_start_position(start_position: Vector2, target_position: Vector2, same_target_hit_index: int, params: Dictionary) -> Vector2:
	if same_target_hit_index <= 0:
		return start_position
	var spread_radius: float = maxf(float(params.get("same_target_curve_start_spread_radius", 12.0)), 0.0)
	if spread_radius <= 0.0:
		return start_position
	var forward: Vector2 = start_position.direction_to(target_position)
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var side: Vector2 = Vector2(-forward.y, forward.x).normalized()
	var side_sign: float = -1.0 if same_target_hit_index % 2 == 1 else 1.0
	var ring: float = float((same_target_hit_index + 1) / 2)
	return start_position + side * side_sign * spread_radius * ring


func _resolve_projectile_visual_target_position(target_position: Vector2, same_target_hit_index: int, params: Dictionary) -> Vector2:
	if same_target_hit_index <= 0:
		return target_position
	var spread_radius: float = maxf(float(params.get("same_target_curve_spread_radius", 18.0)), 0.0)
	if spread_radius <= 0.0:
		return target_position
	var angle: float = -PI * 0.5 + float(same_target_hit_index - 1) * TAU / 3.0
	return target_position + Vector2(cos(angle), sin(angle)) * spread_radius


func _apply_projectile_damage_sequence(packet: Dictionary, params: Dictionary, same_target_hit_index: int, context: Dictionary) -> void:
	var sequence: Array = _resolve_projectile_damage_sequence(params, context)
	if sequence.is_empty():
		return
	var sequence_index: int = clampi(same_target_hit_index, 0, sequence.size() - 1)
	var multiplier: float = maxf(float(sequence[sequence_index]), 0.0)
	packet["special_final_modifier"] = float(packet.get("special_final_modifier", 1.0)) * multiplier
	if String(packet.get("special_final_modifier_source", "")) == "":
		packet["special_final_modifier_source"] = "system_rule"


func _resolve_projectile_damage_sequence(params: Dictionary, context: Dictionary) -> Array:
	var sequence: Array = _get_array(params.get("damage_multiplier_sequence", [])).duplicate(true)
	var hail_decay_rule: Dictionary = _get_hail_same_target_decay_rule(context)
	if hail_decay_rule.is_empty():
		return sequence
	if sequence.is_empty():
		sequence = [1.0]
	while sequence.size() < 3:
		sequence.append(sequence[sequence.size() - 1])
	sequence[1] = maxf(float(hail_decay_rule.get("second_hit_multiplier", sequence[1])), 0.0)
	sequence[2] = maxf(float(hail_decay_rule.get("third_hit_multiplier", sequence[2])), 0.0)
	return sequence


func _get_hail_same_target_decay_rule(context: Dictionary) -> Dictionary:
	var special_rules: Dictionary = _get_runtime_special_rules(context)
	var rule_variant: Variant = special_rules.get("hail_same_target_decay", {})
	if rule_variant is Dictionary:
		return (rule_variant as Dictionary).duplicate(true)
	return {}


func _spawn_area(params: Dictionary, context: Dictionary, source_type: String = "area") -> bool:
	var parent: Node = _get_parent_node(context)
	var position: Vector2 = _resolve_position(params, context)
	var radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "area_radius", params.get("radius", params.get("collision_radius", 48.0)))), 1.0)
	var area_params: Dictionary = params.duplicate(true)
	var area_source_id: StringName = StringName(String(area_params.get("area_id", area_params.get("object_id", ""))))
	var special_rules: Dictionary = _get_runtime_special_rules(context)
	if source_type == "explosion":
		radius = maxf(float(ModifierResolverScript.resolve_value(context, "explosion_radius", radius)), 1.0)
	if source_type == "trap":
		if special_rules.has("trap_radius_upgrade"):
			var trap_radius_rule: Dictionary = _get_dictionary(special_rules.get("trap_radius_upgrade", {}))
			radius *= maxf(1.0 + float(trap_radius_rule.get("radius_multiplier_add", 0.0)), 0.05)
	var storm_rule: Dictionary = _get_storm_hail_rule_for_context(context)
	if not storm_rule.is_empty():
		radius *= maxf(1.0 + float(storm_rule.get("area_radius_multiplier_add", 0.0)), 0.05)
		area_params["max_targets"] = int(area_params.get("max_targets", 0)) + int(storm_rule.get("max_targets_add", 0))
		area_params["boss_damage_multiplier_add"] = float(area_params.get("boss_damage_multiplier_add", 0.0)) + float(storm_rule.get("boss_damage_multiplier", 0.8)) - 1.0
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_upgrade"):
		var fire_oil_upgrade: Dictionary = _get_dictionary(special_rules.get("fire_oil_merge_upgrade", {}))
		radius *= maxf(1.0 + float(fire_oil_upgrade.get("radius_multiplier_add", 0.0)), 0.05)
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_range_width"):
		var acid_range_rule: Dictionary = _get_dictionary(special_rules.get("acid_pressure_range_width", {}))
		radius += float(acid_range_rule.get("range_add", 0.0))
		area_params["cone_width_degrees"] = float(area_params.get("cone_width_degrees", 70.0)) + float(acid_range_rule.get("cone_width_degrees_add", 0.0))
	var holy_field_capacity: Dictionary = {}
	if area_source_id == &"holy_field_area" and special_rules.has("cross_relic_field_capacity"):
		holy_field_capacity = _get_dictionary(special_rules.get("cross_relic_field_capacity", {}))
	var damage_multiplier: float = float(params.get("damage_multiplier", 1.0))
	if not holy_field_capacity.is_empty():
		damage_multiplier *= maxf(1.0 + float(holy_field_capacity.get("field_damage_multiplier_add", 0.0)), 0.0)
	var damage: int = maxi(roundi(float(ModifierResolverScript.get_stat(context, "damage", 0)) * damage_multiplier), 0)
	if params.has("damage"):
		damage = maxi(roundi(_resolve_scaled_amount(params["damage"], context, "damage")), 0)
		if not holy_field_capacity.is_empty():
			damage = maxi(roundi(float(damage) * maxf(1.0 + float(holy_field_capacity.get("field_damage_multiplier_add", 0.0)), 0.0)), 0)
		if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_upgrade"):
			var fire_oil_damage_upgrade: Dictionary = _get_dictionary(special_rules.get("fire_oil_merge_upgrade", {}))
			damage = maxi(roundi(float(damage) * maxf(1.0 + float(fire_oil_damage_upgrade.get("tick_damage_multiplier_add", 0.0)), 0.0)), 0)
		if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_duration_damage"):
			var acid_damage_rule: Dictionary = _get_dictionary(special_rules.get("acid_pressure_duration_damage", {}))
			damage = maxi(roundi(float(damage) * maxf(1.0 + float(acid_damage_rule.get("tick_damage_multiplier_add", 0.0)), 0.0)), 0)
	if source_type == "explosion":
		damage = maxi(roundi(float(ModifierResolverScript.resolve_value(context, "explosion_damage", damage))), 0)

	var statuses_on_hit: Array[StringName] = _get_statuses_on_hit(params, context)
	var max_targets_stat: String = "%s_max_targets" % source_type
	var max_targets: int = maxi(int(ModifierResolverScript.resolve_value(context, max_targets_stat, area_params.get("max_targets", 0))), 0)
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if area_source_id == &"acid_spray_cone_area" and skill_instance != null and bool(skill_instance.get_meta("acid_pressure_next_cast", false)):
		max_targets = maxi(max_targets, int(_get_dictionary(special_rules.get("acid_pressure_every_n_casts", {})).get("max_targets", 8)))
		skill_instance.set_meta("acid_pressure_next_cast", false)
	var max_active: int = 0
	if source_type == "trap":
		max_active = maxi(int(ModifierResolverScript.resolve_value(context, "max_active_traps", area_params.get("max_active", 0))), 0)
	elif area_source_id == &"holy_field_area":
		max_active = maxi(int(ModifierResolverScript.resolve_value(context, "max_active_fields", area_params.get("max_active", 0))) + int(holy_field_capacity.get("max_active_add", 0)), 0)
	elif area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_zones"):
		max_active = maxi(int(_get_dictionary(special_rules.get("fire_oil_merge_zones", {})).get("max_active", area_params.get("max_active", 0))), 0)
	else:
		max_active = maxi(int(area_params.get("max_active", 0)), 0)
	var debug_trace_id: int = _get_debug_attack_trace_id(context)
	if not area_params.has("source_instance_id"):
		var cast_instance_id: String = _cast_instance_id_for_area(context)
		area_params["source_instance_id"] = DamageSourceIdentityScript.for_area(cast_instance_id, source_type, area_source_id)
	var damage_packet: Dictionary = _build_damage_packet(area_params, context, damage, source_type)
	if max_active > 0:
		_enforce_max_active_areas(parent, source_type, area_source_id, max_active)

	var duration: float = maxf(float(ModifierResolverScript.resolve_value(context, "duration", area_params.get("duration", 0.12))), 0.05)
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_duration_tuning"):
		duration += float(_get_dictionary(special_rules.get("fire_oil_duration_tuning", {})).get("duration_add", 0.0))
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_duration_damage"):
		duration += float(_get_dictionary(special_rules.get("acid_pressure_duration_damage", {})).get("duration_add", 0.0))
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_zones"):
		var fire_oil_merge: Dictionary = _get_dictionary(special_rules.get("fire_oil_merge_zones", {}))
		if bool(fire_oil_merge.get("enabled", false)) and _merge_existing_fire_oil_area(parent, position, radius, duration, damage, fire_oil_merge):
			return true

	var impact_target: Node = context.get("target") as Node
	var area_effect_params: Dictionary = {
		"parent": parent,
		"area_id": area_source_id,
		"position": position,
		"damage": damage,
		"damage_type": _get_damage_type(area_params, context, source_type, _get_damage_origin(area_params, context, source_type)),
		"damage_packet": damage_packet,
		"source_origin_id": StringName(String(damage_packet.get("source_origin_id", context.get("source_origin_id", "")))),
		"source_skill_id": StringName(String(damage_packet.get("source_skill_id", context.get("skill_id", "")))),
		"duration": duration,
		"tick_interval": _resolve_area_tick_interval(area_source_id, area_params, special_rules),
		"radius": radius,
		"cone_width_degrees": float(area_params.get("cone_width_degrees", 0.0)),
		"cone_direction": _resolve_cone_direction(area_params, context, position),
		"max_targets": max_targets,
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": area_params.get("visual_color", Color(1.0, 0.38, 0.05, 0.32)),
		"status_on_hit": StringName(String(area_params.get("status_id", area_params.get("status_on_hit", "")))),
		"statuses_on_hit": statuses_on_hit,
		"status_params": _get_status_params(area_params, context),
		"source_id": area_source_id,
		"event_on_hit": StringName(String(area_params.get("event_on_hit", ""))),
		"event_on_expire": StringName(String(area_params.get("event_on_expire", ""))),
		"actions_on_apply": _get_array(area_params.get("actions_on_apply", [])),
		"actions_on_tick": _get_array(area_params.get("actions_on_tick", [])),
		"actions_on_hit": _get_array(area_params.get("actions_on_hit", [])),
		"actions_on_expire": _get_array(area_params.get("actions_on_expire", [])),
		"actions_on_death": _get_array(area_params.get("actions_on_death", [])),
		"finish_after_damage": bool(area_params.get("finish_after_damage", false)),
		"impact_target": impact_target,
		"impact_target_id": str(impact_target.get_instance_id()) if impact_target != null else "",
		"impact_target_damage_multiplier": float(area_params.get("impact_target_damage_multiplier", 1.0)),
		"event_bus": context.get("event_bus"),
		"skill_instance": context.get("skill_instance"),
		"caster": context.get("caster"),
		"skill_manager": context.get("skill_manager"),
		"relic_manager": context.get("relic_manager")
	}
	if area_params.has("visual_style"):
		area_effect_params["visual_style"] = String(area_params.get("visual_style", ""))
	var area_effect: Node2D = CombatObjectFactoryScript.create_area_effect(area_effect_params)
	if area_effect != null:
		area_effect.set_meta("source_type", source_type)
		area_effect.set_meta("source_id", area_source_id)
		area_effect.set_meta("source_instance_id", String(area_params.get("source_instance_id", "")))
		area_effect.add_to_group(&"areas")
		area_effect.add_to_group(&"area_effects")
		if source_type == "trap":
			area_effect.add_to_group(&"traps")
		if area_source_id == &"holy_field_area":
			area_effect.set_meta("cross_relic_field", true)
		if area_source_id == &"poison_cloud_area":
			area_effect.set_meta("toxic_vial_poison_cloud", true)
			area_effect.set_meta("toxic_vial_poison_cloud_radius", radius)
		if area_source_id == &"fire_oil_area":
			area_effect.set_meta("fire_oil_area", true)
			area_effect.set_meta("fire_oil_radius", radius)
		if area_source_id == &"acid_spray_cone_area":
			area_effect.set_meta("acid_spray_cone_area", true)
			area_effect.set_meta("acid_spray_radius", radius)
		if area_source_id == &"smoke_cloud_area":
			area_effect.set_meta("fire_oil_smoke_cloud", true)
			area_effect.set_meta("fire_oil_smoke_radius", radius)
	if area_effect != null and source_type == "explosion":
		DebugCombatTraceScript.record_explosion(
			_get_root_node(),
			parent,
			position,
			radius,
			String(context.get("skill_id", area_params.get("source_id", ""))),
			String(area_params.get("source_instance_id", "")),
			debug_trace_id,
			damage_packet
		)
		if debug_trace_id > 0 and area_effect.has_method("apply_immediate_tick_once"):
			area_effect.call("apply_immediate_tick_once")
	return area_effect != null


func _spawn_trap(params: Dictionary, context: Dictionary) -> bool:
	var trap_params: Dictionary = params.duplicate(true)
	if not trap_params.has("damage_origin"):
		trap_params["damage_origin"] = "trap"
	if not trap_params.has("damage_type"):
		trap_params["damage_type"] = "trap_damage"
	if not trap_params.has("duration"):
		trap_params["duration"] = 4.0
	if not trap_params.has("tick_interval"):
		trap_params["tick_interval"] = 0.25
	if not trap_params.has("position_mode"):
		trap_params["position_mode"] = "target"
	return _spawn_area(trap_params, context, "trap")


func _enforce_max_active_areas(parent: Node, source_type: String, source_id: StringName, max_active: int) -> void:
	if parent == null or max_active <= 0:
		return
	var matches: Array[Node] = []
	for child: Node in parent.get_children():
		if child == null or not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if String(child.get_meta("source_type", "")) != source_type:
			continue
		if StringName(String(child.get_meta("source_id", ""))) != source_id:
			continue
		matches.append(child)
	while matches.size() >= max_active:
		var oldest: Node = matches.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()


func _merge_existing_fire_oil_area(parent: Node, position: Vector2, radius: float, duration: float, damage: int, rule: Dictionary) -> bool:
	if parent == null:
		return false
	var merge_radius: float = maxf(float(rule.get("merge_radius", 120.0)), 1.0)
	for child: Node in parent.get_children():
		var area: Node2D = child as Node2D
		if area == null or not bool(area.get_meta("fire_oil_area", false)) or area.is_queued_for_deletion():
			continue
		if area.global_position.distance_squared_to(position) > merge_radius * merge_radius:
			continue
		if area.has_method("extend_duration"):
			area.call("extend_duration", duration, duration + float(rule.get("duration_add", 1.0)))
		if area.has_method("set_effect_radius"):
			var merged_radius: float = maxf(float(area.get("radius")), radius)
			area.call("set_effect_radius", merged_radius)
			area.set_meta("fire_oil_radius", merged_radius)
		area.set_meta("fire_oil_merged_area", true)
		if int(area.get("damage")) < damage:
			area.set("damage", damage)
		return true
	return false


func _spawn_orbit_object(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return false

	var count: int = maxi(int(ModifierResolverScript.resolve_value(context, "orbit_object_count", params.get("count", 1))), 1)
	var orbit_radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "orbit_radius", params.get("orbit_radius", 72.0))), 1.0)
	var area_radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "area_radius", params.get("collision_radius", 18.0))), 1.0)
	var source_id: StringName = StringName(String(params.get("object_id", params.get("source_id", ""))))
	var parent: Node = _get_parent_node(context)
	var existing_objects: Array[Node2D] = _get_orbit_objects(parent, caster, StringName(String(context.get("skill_id", ""))), source_id)
	if existing_objects.size() != count:
		for existing_object: Node2D in existing_objects:
			if is_instance_valid(existing_object):
				existing_object.queue_free()
		existing_objects.clear()
	else:
		for existing_object: Node2D in existing_objects:
			if existing_object != null and existing_object.has_method("setup"):
				existing_object.call("setup", _build_orbit_params(params, context, caster, orbit_radius, area_radius, source_id, float(existing_object.get("angle"))))
		return true

	for object_index in range(count):
		var angle: float = TAU * float(object_index) / float(count)
		var orbit_params: Dictionary = _build_orbit_params(params, context, caster, orbit_radius, area_radius, source_id, angle)
		orbit_params["parent"] = parent
		orbit_params["position"] = caster.global_position + Vector2.RIGHT.rotated(angle) * orbit_radius
		var orbit_object: Node2D = CombatObjectFactoryScript.create_orbit_object(orbit_params)
		if orbit_object != null:
			orbit_object.set_meta("owner_instance_id", caster.get_instance_id())
			orbit_object.set_meta("skill_id", StringName(String(context.get("skill_id", ""))))
			orbit_object.set_meta("source_id", source_id)

	return true


func _spawn_orbitals(params: Dictionary, context: Dictionary) -> bool:
	var orbit_params: Dictionary = params.duplicate(true)
	if not orbit_params.has("object_id"):
		orbit_params["object_id"] = String(orbit_params.get("orbital_id", orbit_params.get("source_id", "")))
	if not orbit_params.has("orbit_radius"):
		orbit_params["orbit_radius"] = float(orbit_params.get("radius", 72.0))
	return _spawn_orbit_object(orbit_params, context)


func _spawn_particles(params: Dictionary, context: Dictionary) -> bool:
	var parent: Node = _get_parent_node(context)
	if parent == null:
		return false
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "SkillParticles_%s" % String(params.get("profile", "fire"))
	particles.global_position = _resolve_position(params, context)
	_configure_gpu_particles(particles, params, Color(1.0, 0.28, 0.04, 0.82))
	parent.add_child(particles)
	particles.restart()
	particles.emitting = true
	var lifetime: float = maxf(float(params.get("lifetime", 0.55)), 0.05)
	var tree: SceneTree = parent.get_tree()
	if tree != null:
		tree.create_timer(lifetime).timeout.connect(Callable(particles, "queue_free"))
	return true


func _spawn_summon(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node2D = context.get("caster") as Node2D
	var parent: Node = _get_parent_node(context)
	if caster == null or parent == null:
		return false

	var summon: Node2D = Node2D.new()
	summon.name = String(params.get("summon_id", "skill_summon"))
	summon.global_position = caster.global_position + Vector2(float(params.get("spawn_offset", 48.0)), 0.0).rotated(randf() * TAU)
	parent.add_child(summon)

	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "SummonParticles"
	_configure_gpu_particles(particles, {"profile": params.get("profile", "fire_summon"), "amount": 42, "lifetime": 0.75}, Color(1.0, 0.42, 0.08, 0.74))
	summon.add_child(particles)
	particles.restart()
	particles.emitting = true

	var attack_interval: float = maxf(float(params.get("attack_interval", 0.7)), 0.05)
	var duration: float = maxf(float(params.get("duration", 5.0)), attack_interval)
	var timer: Timer = Timer.new()
	timer.wait_time = attack_interval
	timer.one_shot = false
	timer.autostart = true
	summon.add_child(timer)
	timer.timeout.connect(func() -> void:
		_summon_tick(summon, params, context)
	)
	_summon_tick(summon, params, context)

	var tree: SceneTree = parent.get_tree()
	if tree != null:
		tree.create_timer(duration).timeout.connect(Callable(summon, "queue_free"))
	return true


func _summon_tick(summon: Node2D, params: Dictionary, context: Dictionary) -> void:
	if summon == null or not is_instance_valid(summon) or summon.is_queued_for_deletion():
		return
	var radius: float = maxf(float(params.get("radius", params.get("range", 180.0))), 1.0)
	var max_targets: int = maxi(int(params.get("max_targets", 1)), 1)
	var target_group: StringName = StringName(String(params.get("target_group", context.get("target_group", &"enemies"))))
	var targets: Array[Node2D] = _find_targets_around(summon.global_position, radius, target_group)
	var affected: int = 0
	for target: Node2D in targets:
		if affected >= max_targets:
			break
		var summon_context: Dictionary = context.duplicate(true)
		summon_context["target"] = target
		summon_context["source"] = summon
		var damage_params: Dictionary = params.duplicate(true)
		if not damage_params.has("damage_type"):
			damage_params["damage_type"] = "summon_damage"
		if not damage_params.has("damage_origin"):
			damage_params["damage_origin"] = "special"
		_deal_damage(damage_params, summon_context)
		affected += 1


func _configure_gpu_particles(particles: GPUParticles2D, params: Dictionary, color: Color) -> void:
	if particles == null:
		return
	var profile: String = String(params.get("profile", "fire"))
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = maxf(float(params.get("emission_radius", 16.0)), 1.0)
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = float(params.get("spread", 360.0))
	material.gravity = Vector3(0.0, float(params.get("gravity_y", -18.0)), 0.0)
	material.initial_velocity_min = float(params.get("velocity_min", 32.0))
	material.initial_velocity_max = float(params.get("velocity_max", 92.0))
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.scale_min = float(params.get("scale_min", 0.45))
	material.scale_max = float(params.get("scale_max", 1.6))
	material.color = color
	if profile.contains("targeted"):
		material.direction = Vector3(0.0, -0.35, 0.0)
		material.initial_velocity_max = maxf(material.initial_velocity_max, 130.0)
	elif profile.contains("summon"):
		material.emission_sphere_radius = maxf(material.emission_sphere_radius, 22.0)
		material.initial_velocity_min = 10.0
		material.initial_velocity_max = 46.0

	particles.amount = maxi(int(params.get("amount", 36)), 1)
	particles.lifetime = maxf(float(params.get("particle_lifetime", 0.45)), 0.05)
	particles.one_shot = bool(params.get("one_shot", true))
	particles.explosiveness = float(params.get("explosiveness", 0.72))
	particles.randomness = float(params.get("randomness", 0.62))
	particles.local_coords = bool(params.get("local_coords", false))
	particles.process_material = material


func _knockback(params: Dictionary, context: Dictionary) -> bool:
	var target: Node2D = context.get("target") as Node2D
	var caster: Node2D = context.get("caster") as Node2D
	if target == null or caster == null:
		return false

	var direction: Vector2 = caster.global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		return false

	target.global_position += direction.normalized() * float(params.get("force", 10.0))
	return true


func _chain_to_targets(params: Dictionary, context: Dictionary) -> int:
	var origin: Node2D = context.get("target") as Node2D
	if origin == null:
		origin = context.get("source") as Node2D
	if origin == null:
		origin = context.get("caster") as Node2D
	if origin == null:
		return 0

	var radius: float = clampf(float(params.get("radius", 160.0)), 1.0, 600.0)
	var max_targets: int = maxi(int(params.get("count", params.get("max_targets", 3))), 1)
	var target_group: StringName = StringName(String(params.get("target_group", context.get("target_group", &"enemies"))))
	var actions: Array = _get_array(params.get("actions", []))
	var candidates: Array[Node2D] = _find_targets_around(origin.global_position, radius, target_group, context.get("target"))
	var affected: int = 0

	for candidate: Node2D in candidates:
		if affected >= max_targets:
			break
		var chained_context: Dictionary = context.duplicate(true)
		chained_context["target"] = candidate
		chained_context["source"] = origin
		if actions.is_empty():
			_deal_damage(params, chained_context)
			_apply_status(params, chained_context)
		else:
			execute_actions(actions, chained_context)
		affected += 1

	return affected


func _consume_status_stack(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false

	var status_id: StringName = StringName(String(params.get("status_id", "")))
	if status_id == &"":
		return false

	var stacks: int = maxi(int(params.get("stacks", params.get("stack", 1))), 1)
	if target.has_method("consume_status_stack"):
		return bool(target.call("consume_status_stack", status_id, stacks))

	var manager: Node = target.get_node_or_null("StatusEffectManager")
	if manager != null and manager.has_method("consume_status_stack"):
		return bool(manager.call("consume_status_stack", status_id, stacks))

	if status_id == &"shock" and target.has_method("consume_shock_stack"):
		var consumed_any: bool = false
		for _stack_index in range(stacks):
			consumed_any = bool(target.call("consume_shock_stack")) or consumed_any
		return consumed_any

	return false


func _damage_by_status_stack(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("take_damage"):
		return false

	var status_ids: Array[StringName] = _get_status_ids(params)
	if status_ids.is_empty():
		return false

	var stack_count: int = 0
	for status_id: StringName in status_ids:
		if target.has_method("get_status_stack"):
			stack_count += int(target.call("get_status_stack", status_id))

	if stack_count <= 0:
		return false

	var amount_per_stack: float = float(params.get("amount_per_stack", params.get("damage_per_stack", 1.0)))
	var base_amount: float = float(params.get("amount", 0.0))
	var amount: int = maxi(roundi(base_amount + amount_per_stack * float(stack_count)), 1)
	var origin: String = _get_damage_origin(params, context, "skill")
	target.call("take_damage", _build_damage_packet(params, context, amount, "skill"), _get_damage_type(params, context, "skill", origin))

	if bool(params.get("consume", false)):
		for status_id: StringName in status_ids:
			_consume_status_stack({"status_id": status_id, "stacks": int(params.get("consume_stacks", 1))}, context)

	return true


func _heal_owner(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return false

	var amount: int = maxi(int(params.get("amount", 0)), 0)
	if amount <= 0:
		return false

	var max_health: int = int(caster.get("max_health"))
	var current_health: int = int(caster.get("current_health"))
	caster.set("current_health", mini(current_health + amount, max_health))
	if caster.has_signal("health_changed"):
		caster.emit_signal("health_changed", int(caster.get("current_health")), max_health)
	return true


func _destroy_enemy_projectile(params: Dictionary, context: Dictionary) -> bool:
	var origin: Node2D = context.get("source") as Node2D
	if origin == null:
		origin = context.get("caster") as Node2D
	if origin == null:
		return false

	var radius: float = maxf(float(params.get("radius", 32.0)), 1.0)
	var radius_squared: float = radius * radius
	var tree: SceneTree = origin.get_tree()
	if tree == null:
		return false

	var destroyed_any: bool = false
	for group_name: StringName in [&"enemy_projectiles", &"enemy_projectile"]:
		for node: Node in tree.get_nodes_in_group(group_name):
			var projectile: Node2D = node as Node2D
			if projectile == null or not is_instance_valid(projectile):
				continue
			if projectile.global_position.distance_squared_to(origin.global_position) > radius_squared:
				continue
			projectile.queue_free()
			destroyed_any = true

	return destroyed_any


func _add_temporary_modifier(params: Dictionary, context: Dictionary) -> bool:
	var modifier: Dictionary = _build_modifier_from_params(params)
	if modifier.is_empty():
		return false

	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance != null:
		var runtime_modifiers: Dictionary = {}
		var runtime_variant: Variant = skill_instance.get("runtime_modifiers")
		if runtime_variant is Dictionary or runtime_variant is Array:
			runtime_modifiers = ModifierSourceScript.flatten(runtime_variant)
		ModifierSourceScript.merge_flat_values(runtime_modifiers, ModifierSourceScript.flatten(modifier))
		skill_instance.set("runtime_modifiers", runtime_modifiers)
		return true

	var skill_manager: Node = context.get("skill_manager") as Node
	if skill_manager != null and skill_manager.has_method("add_passive_modifier"):
		skill_manager.call("add_passive_modifier", modifier)
		return true
	return false


func _grant_shield(params: Dictionary, context: Dictionary) -> bool:
	var owner: Node = context.get("owner") as Node
	if owner == null:
		owner = context.get("caster") as Node
	if owner == null:
		return false

	var max_health: float = maxf(_get_float_property(owner, "max_health", 0.0), 0.0)
	var amount: int = maxi(roundi(_resolve_scaled_amount(params.get("amount", 0.0), context, "shield")), 0)
	if amount <= 0 and params.has("max_health_ratio"):
		amount = maxi(roundi(max_health * float(params.get("max_health_ratio", 0.0))), 0)
	if amount <= 0:
		return false

	var duration: float = maxf(float(params.get("duration", 6.0)), 0.05)
	var shield_type: String = String(params.get("shield_type", "fire_skill"))
	var current: int = int(owner.get_meta("fire_passive_shield", 0))
	owner.set_meta("fire_passive_shield", current + amount)
	owner.set_meta("fire_passive_shield_expires_at", _now_seconds() + duration)
	owner.set_meta("%s_shield" % shield_type, int(owner.get_meta("%s_shield" % shield_type, 0)) + amount)
	owner.set_meta("%s_shield_expires_at" % shield_type, _now_seconds() + duration)
	return true


func _pull(params: Dictionary, context: Dictionary) -> bool:
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		return false
	var origin_node: Node2D = context.get("source") as Node2D
	if origin_node == null:
		origin_node = context.get("caster") as Node2D
	if origin_node == null:
		return false

	var direction: Vector2 = target.global_position.direction_to(origin_node.global_position)
	if direction == Vector2.ZERO:
		return false
	var distance: float = maxf(float(params.get("distance", 0.0)), 0.0)
	if distance <= 0.0:
		distance = maxf(float(params.get("strength", 0.2)) * maxf(float(params.get("radius", 64.0)), 1.0), 1.0)
	if target.has_method("apply_pull"):
		target.call("apply_pull", direction, distance)
	else:
		target.global_position += direction.normalized() * distance
	return true


func _repeat_skill(params: Dictionary, context: Dictionary) -> bool:
	var actions: Array = _get_array(params.get("actions", []))
	if actions.is_empty():
		push_warning("[SkillActionExecutor] repeat_skill needs explicit actions in this runtime.")
		return false
	var times: int = maxi(int(params.get("times", params.get("count", 1))), 1)
	for _index in range(times):
		execute_actions(actions, context)
	return true


func _transform_area(params: Dictionary, context: Dictionary) -> bool:
	var area: Node = context.get("area") as Node
	if area == null:
		push_warning("[SkillActionExecutor] transform_area has no source area.")
		return false
	if params.has("area_id") or params.has("object_id"):
		var area_params: Dictionary = params.duplicate(true)
		if not area_params.has("position") and area is Node2D:
			area_params["position"] = (area as Node2D).global_position
		var spawned: bool = _spawn_area(area_params, context, "area")
		if spawned and bool(params.get("remove_source_area", false)) and area.has_method("queue_free"):
			area.call("queue_free")
		return spawned
	for key_variant: Variant in params.keys():
		var key: String = String(key_variant)
		if key == "type":
			continue
		area.set_meta(key, params[key_variant])
	return true


func _transfer_status(params: Dictionary, context: Dictionary) -> bool:
	var source: Node = context.get("source") as Node
	var target: Node = context.get("target") as Node
	if source == null:
		source = target
		target = context.get("caster") as Node
	if source == null or target == null:
		return false

	var status_id: StringName = StringName(String(params.get("status_id", params.get("status", ""))))
	if status_id == &"":
		return false
	var stacks: int = maxi(int(params.get("stacks", params.get("stack", 1))), 1)
	if source.has_method("get_status_stack"):
		stacks = mini(stacks, maxi(int(source.call("get_status_stack", status_id)), 0))
	if stacks <= 0:
		return false
	if not _apply_status_to_target(target, status_id, {"stacks": stacks}):
		return false
	_consume_status_stack_on_target(source, status_id, stacks)
	return true


func _consume_status_duration(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false
	var status_id: StringName = StringName(String(params.get("status_id", params.get("status", ""))))
	if status_id == &"":
		return false
	var seconds: float = maxf(float(params.get("duration", params.get("seconds", 0.0))), 0.0)
	var manager: Node = _get_status_manager(target)
	if manager != null and manager.has_method("consume_status_duration"):
		return bool(manager.call("consume_status_duration", status_id, seconds))
	if target.has_method("consume_status_duration"):
		return bool(target.call("consume_status_duration", status_id, seconds))
	push_warning("[SkillActionExecutor] consume_status_duration requires StatusEffectManager.consume_status_duration.")
	return false


func _trigger_overload(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false
	var overload_id: StringName = StringName(String(params.get("status_id", "overload")))
	return _apply_status_to_target(target, overload_id, {"stacks": 1, "duration": float(params.get("duration", 0.1))})


func _shatter_frozen(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false
	if target.has_method("get_status_stack") and int(target.call("get_status_stack", &"frozen")) <= 0:
		return false
	_consume_status_stack_on_target(target, &"frozen", 1)

	var damage_value: Variant = params.get("amount", params.get("damage", {"stat": "power", "scale": 0.25}))
	var damage_params: Dictionary = params.duplicate(true)
	damage_params["amount"] = damage_value
	if damage_value is Dictionary:
		var damage_dictionary: Dictionary = damage_value
		if damage_dictionary.has("power_scale"):
			damage_params["amount"] = {"stat": "power", "scale": float(damage_dictionary.get("power_scale", 0.0))}
		for key_variant: Variant in damage_dictionary.keys():
			if not damage_params.has(key_variant):
				damage_params[key_variant] = damage_dictionary[key_variant]
	_deal_damage(damage_params, context)
	if int(params.get("projectile_count", 0)) > 0:
		var burst_params: Dictionary = params.duplicate(true)
		burst_params["count"] = int(params.get("projectile_count", 0))
		burst_params["projectile_id"] = String(params.get("projectile_id", "shattered_ember"))
		_spawn_projectile_burst(burst_params, context)
	return true


func _spawn_projectile_burst(params: Dictionary, context: Dictionary) -> bool:
	var projectile_params: Dictionary = params.duplicate(true)
	if projectile_params.has("on_hit") and not projectile_params.has("actions_on_hit"):
		projectile_params["actions_on_hit"] = _effects_to_actions(_get_array(projectile_params.get("on_hit", [])))
	if projectile_params.has("effects_on_hit") and not projectile_params.has("actions_on_hit"):
		projectile_params["actions_on_hit"] = _effects_to_actions(_get_array(projectile_params.get("effects_on_hit", [])))
	if projectile_params.has("angle") and not projectile_params.has("spread_angle"):
		projectile_params["spread_angle"] = float(projectile_params.get("angle", 0.0))
	if not projectile_params.has("spawn_offset"):
		projectile_params["spawn_offset"] = float(projectile_params.get("radius", 24.0))
	return _spawn_projectile(projectile_params, context)


func _repeat_area_path(params: Dictionary, context: Dictionary) -> bool:
	var area_params: Dictionary = params.duplicate(true)
	if area_params.has("effects_on_tick") and not area_params.has("actions_on_tick"):
		area_params["actions_on_tick"] = _effects_to_actions(_get_array(area_params.get("effects_on_tick", [])))
	if not area_params.has("area_id"):
		area_params["area_id"] = String(params.get("source_area_tag", "repeated_area_path"))
	if not area_params.has("duration"):
		area_params["duration"] = float(params.get("duration", 2.0))
	return _spawn_area(area_params, context, "area")


func _spawn_area_from_existing_area(params: Dictionary, context: Dictionary) -> bool:
	var source_area: Node2D = context.get("area") as Node2D
	if source_area == null:
		source_area = context.get("source") as Node2D
	var area_params: Dictionary = params.duplicate(true)
	if area_params.has("effects_on_tick") and not area_params.has("actions_on_tick"):
		area_params["actions_on_tick"] = _effects_to_actions(_get_array(area_params.get("effects_on_tick", [])))
	if source_area != null and not area_params.has("position"):
		area_params["position"] = source_area.global_position
	if not area_params.has("radius") and source_area != null:
		area_params["radius"] = float(source_area.get("radius")) if _has_property(source_area, "radius") else 48.0
	return _spawn_area(area_params, context, "area")


func _resolve_position(params: Dictionary, context: Dictionary) -> Vector2:
	if params.has("position"):
		return _get_vector2(params["position"], Vector2.ZERO)

	var position_mode: String = String(params.get("position_mode", "target"))
	if position_mode == "caster" or position_mode == "owner" or position_mode == "self":
		var caster_for_mode: Node2D = context.get("caster") as Node2D
		return caster_for_mode.global_position if caster_for_mode != null else Vector2.ZERO

	var target: Node2D = context.get("target") as Node2D
	if target != null:
		return target.global_position

	var caster: Node2D = context.get("caster") as Node2D
	return caster.global_position if caster != null else Vector2.ZERO


func _resolve_cone_direction(params: Dictionary, context: Dictionary, area_position: Vector2) -> Vector2:
	if params.has("cone_direction"):
		var configured: Vector2 = _get_vector2(params["cone_direction"], Vector2.RIGHT)
		return configured.normalized() if configured.length_squared() > 0.0001 else Vector2.RIGHT
	var caster: Node2D = context.get("caster") as Node2D
	var target: Node2D = context.get("target") as Node2D
	if caster != null and target != null:
		var target_direction: Vector2 = target.global_position - caster.global_position
		if target_direction.length_squared() > 0.0001:
			return target_direction.normalized()
	if caster != null:
		var forward: Vector2 = area_position - caster.global_position
		if forward.length_squared() > 0.0001:
			return forward.normalized()
	return Vector2.RIGHT


func _resolve_area_tick_interval(area_source_id: StringName, params: Dictionary, special_rules: Dictionary) -> float:
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_tick_interval"):
		var rule: Dictionary = _get_dictionary(special_rules.get("acid_pressure_tick_interval", {}))
		return maxf(float(rule.get("tick_interval_override", params.get("tick_interval", 0.1))), 0.05)
	return maxf(float(params.get("tick_interval", 0.1)), 0.05)


func _get_damage_type(params: Dictionary, context: Dictionary, source_type: String = "skill", damage_origin: String = "") -> StringName:
	if params.has("damage_type"):
		var configured_damage_type: String = String(params["damage_type"])
		if _is_element_name(configured_damage_type):
			return _infer_damage_type(_get_element(params, context), source_type, damage_origin)
		return _normalize_configured_damage_type(configured_damage_type, _get_element(params, context), source_type, damage_origin)

	var context_damage_type: String = String(context.get("damage_type", ""))
	if context_damage_type != "":
		if _is_element_name(context_damage_type):
			return _infer_damage_type(StringName(_normalize_element_name(context_damage_type)), source_type, damage_origin)
		return _normalize_configured_damage_type(context_damage_type, _get_element(params, context), source_type, damage_origin)

	return _infer_damage_type(_get_element(params, context), source_type, damage_origin)


func _get_element(params: Dictionary, context: Dictionary) -> StringName:
	if params.has("element"):
		return StringName(_normalize_element_name(String(params["element"])))
	if params.has("damage_type") and _is_element_name(String(params["damage_type"])):
		return StringName(_normalize_element_name(String(params["damage_type"])))
	var context_element: String = String(context.get("element", ""))
	if context_element != "":
		return StringName(_normalize_element_name(context_element))
	var context_damage_type: String = String(context.get("damage_type", ""))
	if _is_element_name(context_damage_type):
		return StringName(_normalize_element_name(context_damage_type))
	return &"physical"


func _get_damage_origin(params: Dictionary, context: Dictionary, source_type: String) -> String:
	var configured: String = String(params.get("damage_origin", context.get("damage_origin", "")))
	match configured:
		"primary_attack", "status_dot", "reaction", "field", "trap", "special", "healing":
			return configured

	if source_type == "trap":
		return "trap"
	if source_type == "explosion":
		return "primary_attack"
	var field_model: String = String(params.get("field_damage_model", ""))
	if field_model == "dot_tick":
		return "status_dot"
	if source_type == "area":
		return "field"
	return "primary_attack"


func _normalize_configured_damage_type(value: String, element: StringName, source_type: String, damage_origin: String) -> StringName:
	return DamageRuleRegistryScript.normalize_configured_damage_type(value, element, source_type, damage_origin, "SkillActionExecutor")


func _infer_damage_type(element: StringName, source_type: String, damage_origin: String) -> StringName:
	return DamageRuleRegistryScript.infer_damage_type(element, source_type, damage_origin)


func _is_element_name(value: String) -> bool:
	return DamageRuleRegistryScript.is_element(value) or ELEMENT_ALIASES.has(value)


func _normalize_element_name(value: String) -> String:
	return String(ELEMENT_ALIASES.get(value, value))


func _build_damage_packet(params: Dictionary, context: Dictionary, amount: int, source_type: String) -> Dictionary:
	var damage_origin: String = _get_damage_origin(params, context, source_type)
	var damage_type: StringName = _get_damage_type(params, context, source_type, damage_origin)
	var element: StringName = _get_element(params, context)
	var caster: Node = context.get("caster") as Node
	var uses_skill_level: bool = bool(params.get("uses_skill_level_coefficient", damage_origin == "primary_attack" and context.get("skill_instance") != null))
	var packet: Dictionary = DamagePacketBuilderScript.from_skill_action({
		"params": params,
		"context": context,
		"amount": amount,
		"source_type": source_type,
		"damage_origin": damage_origin,
		"damage_type": damage_type,
		"element": element,
		"skill_level_coefficient": _get_skill_level_coefficient(context) if uses_skill_level else 1.0
	})
	_apply_damage_packet_modifiers(packet, params, context)
	_apply_shared_primary_attack_crit(packet, params, context, caster)
	return packet


func _apply_damage_packet_modifiers(packet: Dictionary, params: Dictionary, context: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var skill_modifiers: Dictionary = SkillStatServiceScript.get_combined_modifiers(
		skill_instance,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node
	)

	for key: String in _get_damage_packet_modifier_keys(packet):
		_add_numeric_packet_modifier(packet, key, params)
		_add_numeric_packet_modifier(packet, key, skill_modifiers)


func _get_damage_packet_modifier_keys(packet: Dictionary) -> Array[String]:
	var keys: Array[String] = [
		"crit_chance_add",
		"crit_damage_add",
		"primary_attack_damage_multiplier_add",
		"direct_damage_multiplier_add",
		"starting_skill_damage_add",
		"dot_damage_multiplier_add",
		"reaction_damage_multiplier_add",
		"field_damage_multiplier_add",
		"area_damage_multiplier_add",
		"trap_damage_multiplier_add",
		"boss_damage_multiplier_add",
		"elite_damage_multiplier_add"
	]
	var element: String = String(packet.get("element", ""))
	if element != "" and element != "neutral":
		keys.append("%s_damage_multiplier_add" % element)
	return keys


func _add_numeric_packet_modifier(packet: Dictionary, key: String, source: Dictionary) -> void:
	if source.has(key):
		packet[key] = float(packet.get(key, 0.0)) + float(source[key])


func _apply_shared_primary_attack_crit(packet: Dictionary, params: Dictionary, context: Dictionary, caster: Node) -> void:
	var packet_object: RefCounted = DamagePacketScript.from_dictionary(packet, caster, context.get("target") as Node)
	if not bool(packet_object.call("get_value", "can_crit", false)):
		return
	if String(packet_object.call("get_value", "damage_origin", "")) != "primary_attack":
		return
	if not bool(params.get("share_primary_attack_crit", true)):
		return
	if caster == null:
		return

	var cache_key: String = "shared_primary_attack_crit"
	if not context.has(cache_key):
		var damage_modifiers: Dictionary = ModifierAggregatorScript.collect(ModifierQueryScript.for_damage_any(packet_object, caster))
		var crit_chance: float = clampf(_get_float_property(caster, "crit_chance", 0.0) + float(packet_object.call("get_value", "crit_chance_add", params.get("crit_chance_add", 0.0))) + float(damage_modifiers.get("crit_chance_add", 0.0)), 0.0, 1.0)
		var crit_damage: float = maxf(_get_float_property(caster, "crit_damage", 1.5) + float(packet_object.call("get_value", "crit_damage_add", params.get("crit_damage_add", 0.0))) + float(damage_modifiers.get("crit_damage_add", 0.0)), 1.0)
		context[cache_key] = {
			"is_critical": randf() < crit_chance,
			"crit_multiplier": crit_damage
		}

	var crit_result: Dictionary = context.get(cache_key, {})
	var is_critical: bool = bool(crit_result.get("is_critical", false))
	packet["critical_resolved"] = true
	packet["is_critical"] = is_critical
	packet["crit_multiplier"] = float(crit_result.get("crit_multiplier", 1.0)) if is_critical else 1.0


func _default_can_crit(damage_origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_can_crit(damage_origin, damage_type)


func _default_uses_character_damage(damage_origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_uses_character_damage(damage_origin, damage_type)


func _get_skill_level_coefficient(context: Dictionary) -> float:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		push_warning("[SkillActionExecutor] Missing skill_instance for skill_level_coefficient; defaulting to 1.0.")
		return 1.0

	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	var scaling: Dictionary = {}
	if definition != null:
		var scaling_variant: Variant = definition.get("damage_scaling")
		if scaling_variant is Dictionary:
			scaling = scaling_variant
	var coefficients: Array = _get_array(scaling.get("skill_level_coefficients", []))
	if coefficients.is_empty():
		return 1.0

	var level_index: int = maxi(int(skill_instance.get("current_level")) - 1, 0)
	if level_index >= coefficients.size():
		push_warning("[SkillActionExecutor] skill_level_coefficients out of range for %s level %d; defaulting to 1.0." % [String(skill_instance.get("skill_id")), level_index + 1])
		return 1.0
	return maxf(float(coefficients[level_index]), 0.0)


func _build_orbit_params(params: Dictionary, context: Dictionary, caster: Node2D, orbit_radius: float, area_radius: float, source_id: StringName, angle: float) -> Dictionary:
	var damage: int = 0
	if params.has("damage"):
		damage = maxi(roundi(_resolve_scaled_amount(params["damage"], context, "damage")), 0)
	var orbit_packet_params: Dictionary = params.duplicate(true)
	if not orbit_packet_params.has("source_instance_id"):
		orbit_packet_params["source_instance_id"] = DamageSourceIdentityScript.for_orbit(caster, context.get("skill_id", ""), source_id)
	return {
		"owner": caster,
		"angle": angle,
		"damage": damage,
		"damage_type": _get_damage_type(orbit_packet_params, context, "area", _get_damage_origin(orbit_packet_params, context, "area")),
		"damage_packet": _build_damage_packet(orbit_packet_params, context, damage, "area"),
		"orbit_radius": orbit_radius,
		"rotation_speed": float(ModifierResolverScript.resolve_value(context, "rotation_speed", params.get("rotation_speed", 220.0))),
		"hit_interval": maxf(float(ModifierResolverScript.resolve_value(context, "hit_interval", params.get("hit_interval", 0.45))), 0.05),
		"area_radius": area_radius,
		"target_group": context.get("target_group", &"enemies"),
		"event_bus": context.get("event_bus"),
		"skill_instance": context.get("skill_instance"),
		"caster": caster,
		"skill_manager": context.get("skill_manager"),
		"relic_manager": context.get("relic_manager"),
		"source_id": source_id,
		"object_id": source_id,
		"event_on_hit": &"on_orbit_hit"
	}


func _get_orbit_objects(parent: Node, caster: Node2D, skill_id: StringName, source_id: StringName) -> Array[Node2D]:
	var objects: Array[Node2D] = []
	if parent == null or caster == null:
		return objects

	for child: Node in parent.get_children():
		var orbit_object: Node2D = child as Node2D
		if orbit_object == null or not orbit_object.has_meta("skill_id") or not orbit_object.has_meta("owner_instance_id"):
			continue
		if StringName(String(orbit_object.get_meta("skill_id"))) != skill_id:
			continue
		if int(orbit_object.get_meta("owner_instance_id")) != int(caster.get_instance_id()):
			continue
		if source_id != &"" and StringName(String(orbit_object.get_meta("source_id", ""))) != source_id:
			continue

		objects.append(orbit_object)

	return objects


func _get_parent_node(context: Dictionary) -> Node:
	var parent: Node = context.get("parent") as Node
	if parent != null:
		return parent

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		return tree.current_scene

	var caster: Node = context.get("caster") as Node
	return caster.get_parent() if caster != null else null


func _get_root_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


func _get_debug_attack_trace_id(context: Dictionary) -> int:
	var root: Node = _get_root_node()
	return DamageTraceContextScript.get_trace_id(context, root, true)


func _next_cast_instance_id(context: Dictionary) -> String:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var skill_key: String = String(context.get("skill_id", "skill"))
	if skill_instance == null:
		return "%s:%d" % [skill_key, Time.get_ticks_msec()]
	var nonce: int = int(skill_instance.get_meta("cast_instance_nonce", 0)) + 1
	skill_instance.set_meta("cast_instance_nonce", nonce)
	return "%s:%d" % [skill_key, nonce]


func _consume_hot_rapid_fire_pending(context: Dictionary) -> bool:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("hot_rapid_fire_next_cast", false)):
		return false
	skill_instance.set_meta("hot_rapid_fire_next_cast", false)
	return true


func _mark_storm_hail_cast(context: Dictionary, cast_instance_id: String) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("storm_hail_next_cast", false)):
		return
	skill_instance.set_meta("storm_hail_next_cast", false)
	skill_instance.set_meta("storm_hail_cast_instance_id", cast_instance_id)


func _consume_arcane_double_page_pending(context: Dictionary) -> int:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("arcane_double_page_next_cast", false)):
		return 0
	var extra_count: int = maxi(int(skill_instance.get_meta("arcane_double_page_extra_projectiles", 1)), 0)
	skill_instance.set_meta("arcane_double_page_next_cast", false)
	skill_instance.set_meta("arcane_double_page_extra_projectiles", 0)
	return extra_count


func _consume_forbidden_page_pending(context: Dictionary) -> bool:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("forbidden_page_next_cast", false)):
		return false
	skill_instance.set_meta("forbidden_page_next_cast", false)
	return true


func _cast_instance_id_for_area(context: Dictionary) -> String:
	var projectile: Node = context.get("projectile") as Node
	if projectile != null:
		var projectile_cast_id: String = String(projectile.get_meta("cast_instance_id", ""))
		if projectile_cast_id != "":
			return projectile_cast_id
	return _next_cast_instance_id(context)


func _get_storm_hail_rule_for_context(context: Dictionary) -> Dictionary:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return {}
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return {}
	if String(projectile.get_meta("cast_instance_id", "")) != String(skill_instance.get_meta("storm_hail_cast_instance_id", "")):
		return {}
	var rules_variant: Variant = skill_instance.get("runtime_special_rules")
	if not (rules_variant is Dictionary):
		return {}
	var rules: Dictionary = rules_variant
	var rule_variant: Variant = rules.get("storm_hail_every_n_casts", {})
	if rule_variant is Dictionary:
		return (rule_variant as Dictionary).duplicate(true)
	return {}


func _get_hot_rapid_fire_crit_chance_add(context: Dictionary) -> float:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return 0.0
	return float(skill_instance.get_meta("hot_rapid_fire_crit_chance_add", 0.0))


func _resolve_scaled_amount(value: Variant, context: Dictionary, stat_name: String = "damage") -> float:
	if value is Dictionary:
		var data: Dictionary = value
		if String(data.get("stat", "")) == "power":
			var power: float = float(ModifierResolverScript.resolve_value(context, stat_name, ModifierResolverScript.get_stat(context, "power", _get_caster_attack_power(context))))
			return power * float(data.get("scale", 1.0))
	return float(ModifierResolverScript.resolve_value(context, stat_name, value))


func _build_modifier_from_params(params: Dictionary) -> Dictionary:
	if params.has("stat") and params.has("value"):
		return params.duplicate(true)

	var modifier_name: String = String(params.get("modifier", ""))
	if modifier_name == "" or not params.has("value"):
		return {}

	var value: Variant = params.get("value")
	var values: Dictionary = {}
	match modifier_name:
		"attack_damage_multiplier":
			values["primary_attack_damage_multiplier_add"] = value
			var damage_type: String = String(params.get("damage_type", ""))
			if damage_type != "":
				values["%s_damage_multiplier_add" % damage_type] = value
		_:
			var key: String = modifier_name
			if key.ends_with("_multiplier") and not key.ends_with("_multiplier_add"):
				key = "%s_add" % key
			values[key] = value

	if values.is_empty():
		return {}
	return {
		"source": "skill",
		"values": values
	}


func _get_caster_attack_power(context: Dictionary) -> float:
	var caster: Object = context.get("caster") as Object
	if caster == null:
		return 1.0
	for property_name: String in ["attack_power", "damage", "base_damage"]:
		if _has_property(caster, property_name):
			return float(caster.get(property_name))
	return 1.0


func _apply_status_to_target(target: Node, status_id: StringName, status_params: Dictionary = {}) -> bool:
	if target == null or status_id == &"":
		return false
	if target.has_method("apply_status"):
		return bool(target.call("apply_status", status_id, status_params))
	if target.has_method("add_status_effect"):
		target.call("add_status_effect", status_id)
		return true
	var manager: Node = _get_status_manager(target)
	if manager != null and manager.has_method("apply_status"):
		return bool(manager.call("apply_status", status_id, status_params))
	return false


func _consume_status_stack_on_target(target: Node, status_id: StringName, stacks: int) -> bool:
	if target == null or status_id == &"":
		return false
	if target.has_method("consume_status_stack"):
		return bool(target.call("consume_status_stack", status_id, stacks))
	var manager: Node = _get_status_manager(target)
	if manager != null and manager.has_method("consume_status_stack"):
		return bool(manager.call("consume_status_stack", status_id, stacks))
	return false


func _get_status_manager(target: Node) -> Node:
	return target.get_node_or_null("StatusEffectManager") if target != null else null


func _effects_to_actions(effects: Array) -> Array:
	return SkillEffectAdapterScript.to_actions(effects)


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _has_property(object: Object, property: String) -> bool:
	if object == null:
		return false
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return true
	return false


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _get_runtime_special_rules(context: Dictionary) -> Dictionary:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return {}
	var special_rules_variant: Variant = skill_instance.get("runtime_special_rules")
	if special_rules_variant is Dictionary:
		return (special_rules_variant as Dictionary).duplicate(true)
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	return fallback


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_float_property(object: Object, property: String, fallback: float) -> float:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return float(object.get(property))
	return fallback


func _get_status_ids(params: Dictionary) -> Array[StringName]:
	var status_ids: Array[StringName] = []
	var ids_variant: Variant = params.get("status_ids", [])
	if ids_variant is Array:
		for id_variant: Variant in ids_variant:
			var status_id: StringName = StringName(String(id_variant))
			if status_id != &"" and not status_ids.has(status_id):
				status_ids.append(status_id)

	var single_id: StringName = StringName(String(params.get("status_id", "")))
	if single_id != &"" and not status_ids.has(single_id):
		status_ids.append(single_id)

	return status_ids


func _find_targets_around(origin: Vector2, radius: float, target_group: StringName, excluded: Variant = null) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return targets

	var radius_squared: float = radius * radius
	for node: Node in tree.get_nodes_in_group(target_group):
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target) or target == excluded:
			continue
		if target.has_method("is_dead") and bool(target.call("is_dead")):
			continue
		if origin.distance_squared_to(target.global_position) <= radius_squared:
			targets.append(target)

	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return targets


func _get_statuses_on_hit(params: Dictionary, context: Dictionary = {}) -> Array[StringName]:
	var statuses: Array[StringName] = []
	var statuses_variant: Variant = params.get("statuses_on_hit", [])
	if statuses_variant is Array:
		var status_items: Array = statuses_variant
		for status_variant: Variant in status_items:
			var status_id: StringName = StringName(String(status_variant))
			if status_id != &"" and not statuses.has(status_id):
				statuses.append(status_id)

	var single_status: StringName = StringName(String(params.get("status_id", params.get("status_on_hit", ""))))
	if single_status != &"" and not statuses.has(single_status):
		statuses.append(single_status)

	return statuses


func _get_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var status_params: Dictionary = _get_dictionary(params.get("status_params", {}))
	if params.has("status_duration") or params.has("duration"):
		status_params["duration"] = float(ModifierResolverScript.resolve_value(context, "status_duration", params.get("status_duration", params.get("duration"))))
	if params.has("status_damage"):
		status_params["damage"] = int(ModifierResolverScript.resolve_value(context, "status_damage", params["status_damage"]))
	if params.has("status_tick_interval"):
		status_params["tick_interval"] = float(ModifierResolverScript.resolve_value(context, "status_tick_interval", params["status_tick_interval"]))
	if params.has("stack"):
		status_params["stacks"] = int(params["stack"])
	if params.has("max_stacks"):
		status_params["max_stacks"] = int(params["max_stacks"])
	return DamageTraceContextScript.apply_to_status_params(status_params, context)
