extends RefCounted
class_name SkillActionExecutor


const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const DamageSourceIdentityScript: Script = preload("res://scripts/combat/damage_source_identity.gd")
const ModifierResolverScript: Script = preload("res://scripts/skills/modifier_resolver.gd")
const SkillEffectAdapterScript: Script = preload("res://scripts/skills/skill_effect_adapter.gd")
const SkillRangeUnitScript: Script = preload("res://scripts/skills/skill_range_unit.gd")
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const SkillSpecialRuleExecutorScript: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")
const TargetingServiceScript: Script = preload("res://scripts/skills/targeting_service.gd")
const ConditionEvaluatorScript: Script = preload("res://scripts/skills/condition_evaluator.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const MetadataKeyScript: Script = preload("res://scripts/core/metadata_key.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")
const SummonDefinitionScript: Script = preload("res://scripts/summons/summon_definition.gd")
const SummonManagerScript: Script = preload("res://scripts/summons/summon_manager.gd")

const ELEMENT_ALIASES: Dictionary = {
	"frost": "ice",
	"thunder": "lightning",
	"curse": "arcane"
}

var _special_rule_executor: RefCounted = SkillSpecialRuleExecutorScript.new()


func execute_actions(actions: Array, context: Dictionary) -> void:
	for action_variant: Variant in actions:
		if action_variant is Dictionary:
			execute_action(action_variant, context)


func execute_action(action: Dictionary, context: Dictionary) -> Variant:
	var action_type: String = str(action.get("type", ""))
	var params: Dictionary = SkillRangeUnitScript.resolve_action_params(_get_dictionary(action.get("params", {})))
	var conditions: Array = _get_array(action.get("conditions", params.get("conditions", [])))
	if not conditions.is_empty() and not ConditionEvaluatorScript.evaluate_all(conditions, context):
		return null

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
		"swap_targets":
			return _swap_targets(params, context)
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
		"mark_target":
			return _mark_target(params, context)
		_:
			push_warning("[SkillActionExecutor] Unsupported action type: %s" % action_type)
			return null


func _deal_damage(params: Dictionary, context: Dictionary) -> bool:
	context = _context_with_resolved_target(params, context)
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("take_damage"):
		return false

	var base_amount: Variant = params.get("amount", ModifierResolverScript.get_stat(context, "damage", 0))
	var amount: int = maxi(roundi(_resolve_scaled_amount(base_amount, context, "damage")), 0)
	var damage_type: StringName = _get_damage_type(params, context, "skill", _get_damage_origin(params, context, "skill"))
	var targets: Array[Node] = _resolve_damage_targets(params, context, target)
	var requires_low_hp_execute: bool = params.has("low_hp_execute_threshold") and float(params.get("low_hp_execute_threshold", 0.0)) > 0.0
	var damaged_any: bool = false
	for damage_target: Node in targets:
		if damage_target == null or not damage_target.has_method("take_damage"):
			continue
		var target_context: Dictionary = context.duplicate(true)
		target_context["target"] = damage_target
		var execute_triggered: bool = _should_execute_low_hp_target(params, damage_target)
		if requires_low_hp_execute and not execute_triggered:
			continue
		var target_amount: int = _get_low_hp_execute_amount(damage_target, amount) if execute_triggered else amount
		var packet: Dictionary = _build_damage_packet(params, target_context, target_amount, "skill")
		_inherit_projectile_runtime_damage_packet(packet, target_context, damage_target)
		if execute_triggered:
			_apply_low_hp_execute_packet(packet, params, damage_target)
		packet = _special_rule_executor.call("adjust_damage_packet", packet, target_context)
		damage_target.call("take_damage", packet, &"true_damage" if execute_triggered else damage_type)
		damaged_any = true
	return damaged_any


func _should_execute_low_hp_target(params: Dictionary, target: Node) -> bool:
	var threshold: float = clampf(float(params.get("low_hp_execute_threshold", 0.0)), 0.0, 1.0)
	if threshold <= 0.0 or target == null:
		return false
	var max_health: float = maxf(_get_float_property(target, "max_health", 0.0), 1.0)
	var current_health: float = clampf(_get_float_property(target, "current_health", max_health), 0.0, max_health)
	if current_health <= 0.0:
		return false
	return current_health / max_health <= threshold


func _get_low_hp_execute_amount(target: Node, fallback_amount: int) -> int:
	if target == null:
		return fallback_amount
	var max_health: float = maxf(_get_float_property(target, "max_health", 0.0), 1.0)
	var current_health: float = clampf(_get_float_property(target, "current_health", max_health), 0.0, max_health)
	return maxi(ceili(current_health + max_health), fallback_amount)


func _apply_low_hp_execute_packet(packet: Dictionary, params: Dictionary, target: Node) -> void:
	var amount: int = _get_low_hp_execute_amount(target, int(packet.get("amount", packet.get("raw_amount", 0))))
	packet["raw_amount"] = amount
	packet["amount"] = amount
	packet["damage_origin"] = &"special"
	packet["damage_type"] = &"true_damage"
	packet["low_hp_execute"] = true
	packet["low_hp_execute_threshold"] = clampf(float(params.get("low_hp_execute_threshold", 0.0)), 0.0, 1.0)


func _resolve_damage_targets(params: Dictionary, context: Dictionary, primary_target: Node) -> Array[Node]:
	var targets: Array[Node] = [primary_target]
	var radius: float = maxf(float(params.get("radius", 0.0)), 0.0)
	var center: Node2D = primary_target as Node2D
	if radius <= 0.0 or center == null:
		return targets
	var target_group: StringName = StringName(str(params.get("target_group", context.get("target_group", &"enemies"))))
	for candidate: Node2D in _find_targets_around(center.global_position, radius, target_group, primary_target):
		targets.append(candidate)
	return targets


func _inherit_projectile_runtime_damage_packet(packet: Dictionary, context: Dictionary, target: Node) -> void:
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return
	var runtime_packet: Dictionary = _get_dictionary(projectile.get("damage_packet"))
	if runtime_packet.is_empty():
		return
	for key_variant: Variant in runtime_packet.keys():
		var key: String = str(key_variant)
		if key == "raw_amount" or key == "amount" or key == "target_id":
			continue
		packet[key] = runtime_packet[key_variant]
	if target != null:
		packet["target_id"] = str(target.get_instance_id())


func _apply_status(params: Dictionary, context: Dictionary) -> bool:
	context = _context_with_resolved_target(params, context)
	var target: Node = context.get("target") as Node
	if target == null:
		return false

	var chance: float = clampf(float(params.get("chance", 1.0)), 0.0, 1.0)
	if randf() > chance:
		return false

	var status_id: StringName = StringName(str(params.get("status_id", "")))
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
	if not status_params.has("power"):
		var status_power: float = _get_status_power_from_context(context)
		if status_power > 0.0:
			status_params["power"] = status_power
	status_params = DamageTraceContextScript.apply_to_status_params(status_params, context)
	status_params = _special_rule_executor.call("get_status_params", status_id, status_params, context)

	if target.has_method("apply_status"):
		return bool(target.call("apply_status", status_id, status_params))
	if target.has_method("add_status_effect"):
		target.call("add_status_effect", status_id)
		return true

	return false


func _spawn_projectile(params: Dictionary, context: Dictionary) -> bool:
	context = _context_with_resolved_target(params, context)
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
	var source_id: StringName = StringName(str(params.get("projectile_id", params.get("source_id", ""))))
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
		var curve_target_position: Vector2 = target.global_position
		if params.has("visual_start_offset"):
			var visual_start_offset: Vector2 = _get_vector2(params.get("visual_start_offset"), Vector2.ZERO)
			if str(params.get("visual_start_relative_to", "caster")) == "target":
				projectile_position = curve_target_position + visual_start_offset
			else:
				projectile_position += visual_start_offset
			direction = projectile_position.direction_to(curve_target_position)
			if direction == Vector2.ZERO:
				direction = base_direction
		var trajectory_mode: String = str(params.get("trajectory_mode", "linear"))
		CombatObjectFactoryScript.create_projectile(_build_projectile_spawn_params(
			params,
			projectile_params,
			context,
			parent,
			caster,
			source_id,
			projectile_position,
			direction,
			damage,
			_build_damage_packet(projectile_params, context, damage, "projectile"),
			speed,
			pierce,
			radius,
			lifetime,
			statuses_on_hit,
			cast_instance_id,
			trajectory_mode,
			projectile_position,
			curve_target_position,
			{
				"hot_rapid_fire_crit": use_hot_rapid_fire,
				"hot_rapid_fire_crit_chance_add": hot_rapid_fire_crit_chance_add if use_hot_rapid_fire else 0.0,
				"forbidden_page": forbidden_page_pending and projectile_index == 0
			}
		))

	return true


func _spawn_projectiles_at_targets(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return false

	var count: int = maxi(int(ModifierResolverScript.resolve_value(context, "projectile_count", params.get("count", 1))), 1)
	var range: float = maxf(float(ModifierResolverScript.resolve_value(context, "range", params.get("range", ModifierResolverScript.get_stat(context, "range", INF)))), 1.0)
	var targets: Array = TargetingServiceScript.find_targets(caster, str(params.get("targeting_mode", params.get("targeting", "around_player"))), {
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
	var source_id: StringName = StringName(str(params.get("projectile_id", params.get("source_id", ""))))
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
		if params.has("visual_start_offset"):
			var visual_start_offset: Vector2 = _get_vector2(params.get("visual_start_offset"), Vector2.ZERO)
			if str(params.get("visual_start_relative_to", "caster")) == "target":
				visual_start_position = visual_target_position + visual_start_offset
			else:
				visual_start_position += visual_start_offset

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
		CombatObjectFactoryScript.create_projectile(_build_projectile_spawn_params(
			params,
			projectile_params,
			projectile_context,
			parent,
			caster,
			source_id,
			visual_start_position,
			direction.normalized(),
			damage,
			damage_packet,
			speed,
			pierce,
			radius,
			lifetime,
			statuses_on_hit,
			cast_instance_id,
			str(params.get("trajectory_mode", "curve")),
			visual_start_position,
			visual_target_position
		))
		spawned += 1

	return spawned > 0


func _build_projectile_spawn_params(params: Dictionary, projectile_params: Dictionary, context: Dictionary, parent: Node, caster: Node2D, source_id: StringName, position: Vector2, direction: Vector2, damage: int, damage_packet: Dictionary, speed: float, pierce: int, radius: float, lifetime: float, statuses_on_hit: Array[StringName], cast_instance_id: String, trajectory_mode: String, curve_start_position: Vector2, curve_target_position: Vector2, extra_params: Dictionary = {}) -> Dictionary:
	var spawn_params: Dictionary = {
		"parent": parent,
		"projectile_id": source_id,
		"position": position,
		"direction": direction,
		"damage": damage,
		"damage_type": _get_damage_type(projectile_params, context, "projectile", _get_damage_origin(projectile_params, context, "projectile")),
		"damage_packet": damage_packet,
		"speed": speed,
		"pierce": pierce,
		"radius": radius,
		"lifetime": lifetime,
		"status_on_hit": StringName(str(params.get("status_id", params.get("status_on_hit", "")))),
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
		"trajectory_mode": trajectory_mode,
		"curve_start_position": curve_start_position,
		"curve_target_position": curve_target_position,
		"curve_height": float(params.get("curve_height", 64.0)),
		"homing_enabled": bool(params.get("homing_enabled", false)),
		"homing_turn_rate": float(params.get("homing_turn_rate", 8.0)),
		"homing_seek_range": float(params.get("homing_seek_range", params.get("range", 0.0)))
	}
	for key: Variant in extra_params.keys():
		spawn_params[key] = extra_params[key]
	return spawn_params


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
	if str(packet.get("special_final_modifier_source", "")) == "":
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
	context = _context_with_resolved_target(params, context)
	var parent: Node = _get_parent_node(context)
	var position: Vector2 = _resolve_position(params, context)
	var radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "area_radius", params.get("radius", params.get("collision_radius", 48.0)))), 1.0)
	var area_params: Dictionary = params.duplicate(true)
	var area_source_id: StringName = StringName(str(area_params.get("area_id", area_params.get("object_id", ""))))
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
	var max_active: int = _resolve_area_max_active(area_source_id, area_params, context, source_type, special_rules, holy_field_capacity)
	var debug_trace_id: int = _get_debug_attack_trace_id(context)
	if not area_params.has("source_instance_id"):
		var cast_instance_id: String = _cast_instance_id_for_area(context)
		area_params["source_instance_id"] = DamageSourceIdentityScript.for_area(cast_instance_id, source_type, area_source_id)
	var damage_packet: Dictionary = _build_damage_packet(area_params, context, damage, source_type)
	if max_active > 0:
		_enforce_max_active_areas(parent, source_type, area_source_id, max_active)

	var duration: float = _resolve_area_duration(area_source_id, area_params, context, special_rules)
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_zones"):
		var fire_oil_merge: Dictionary = _get_dictionary(special_rules.get("fire_oil_merge_zones", {}))
		if bool(fire_oil_merge.get("enabled", false)) and _merge_existing_fire_oil_area(parent, position, radius, duration, damage, fire_oil_merge):
			return true

	var area_effect_params: Dictionary = _build_area_effect_spawn_params(
		area_params,
		context,
		source_type,
		parent,
		area_source_id,
		position,
		damage,
		damage_packet,
		duration,
		radius,
		max_targets,
		statuses_on_hit,
		special_rules
	)
	var area_effect: Node2D = CombatObjectFactoryScript.create_area_effect(area_effect_params)
	if area_effect != null:
		area_effect.set_meta("source_type", source_type)
		area_effect.set_meta("source_id", area_source_id)
		area_effect.set_meta("source_instance_id", str(area_params.get("source_instance_id", "")))
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
			str(context.get("skill_id", area_params.get("source_id", ""))),
			str(area_params.get("source_instance_id", "")),
			debug_trace_id,
			damage_packet
		)
		if debug_trace_id > 0 and area_effect.has_method("apply_immediate_tick_once"):
			area_effect.call("apply_immediate_tick_once")
	return area_effect != null


func _resolve_area_max_active(area_source_id: StringName, area_params: Dictionary, context: Dictionary, source_type: String, special_rules: Dictionary, holy_field_capacity: Dictionary) -> int:
	if source_type == "trap":
		return maxi(int(ModifierResolverScript.resolve_value(context, "max_active_traps", area_params.get("max_active", 0))), 0)
	if area_source_id == &"holy_field_area":
		return maxi(int(ModifierResolverScript.resolve_value(context, "max_active_fields", area_params.get("max_active", 0))) + int(holy_field_capacity.get("max_active_add", 0)), 0)
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_zones"):
		return maxi(int(_get_dictionary(special_rules.get("fire_oil_merge_zones", {})).get("max_active", area_params.get("max_active", 0))), 0)
	return maxi(int(area_params.get("max_active", 0)), 0)


func _resolve_area_duration(area_source_id: StringName, area_params: Dictionary, context: Dictionary, special_rules: Dictionary) -> float:
	var duration: float = maxf(float(ModifierResolverScript.resolve_value(context, "duration", area_params.get("duration", 0.12))), 0.05)
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_duration_tuning"):
		duration += float(_get_dictionary(special_rules.get("fire_oil_duration_tuning", {})).get("duration_add", 0.0))
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_duration_damage"):
		duration += float(_get_dictionary(special_rules.get("acid_pressure_duration_damage", {})).get("duration_add", 0.0))
	return duration


func _build_area_effect_spawn_params(area_params: Dictionary, context: Dictionary, source_type: String, parent: Node, area_source_id: StringName, position: Vector2, damage: int, damage_packet: Dictionary, duration: float, radius: float, max_targets: int, statuses_on_hit: Array[StringName], special_rules: Dictionary) -> Dictionary:
	var impact_target: Node = context.get("target") as Node
	var area_effect_params: Dictionary = {
		"parent": parent,
		"area_id": area_source_id,
		"position": position,
		"damage": damage,
		"damage_type": _get_damage_type(area_params, context, source_type, _get_damage_origin(area_params, context, source_type)),
		"damage_packet": damage_packet,
		"source_origin_id": StringName(str(damage_packet.get("source_origin_id", context.get("source_origin_id", "")))),
		"source_skill_id": StringName(str(damage_packet.get("source_skill_id", context.get("skill_id", "")))),
		"duration": duration,
		"tick_interval": _resolve_area_tick_interval(area_source_id, area_params, special_rules),
		"radius": radius,
		"cone_width_degrees": float(area_params.get("cone_width_degrees", 0.0)),
		"cone_direction": _resolve_cone_direction(area_params, context, position),
		"move_direction": _resolve_area_move_direction(area_params, context, position),
		"move_speed": maxf(float(area_params.get("move_speed", 0.0)), 0.0),
		"max_targets": max_targets,
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": area_params.get("visual_color", Color(1.0, 0.38, 0.05, 0.32)),
		"status_on_hit": StringName(str(area_params.get("status_id", area_params.get("status_on_hit", "")))),
		"statuses_on_hit": statuses_on_hit,
		"status_params": _get_status_params(area_params, context),
		"source_id": area_source_id,
		"event_on_hit": StringName(str(area_params.get("event_on_hit", ""))),
		"event_on_expire": StringName(str(area_params.get("event_on_expire", ""))),
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
		area_effect_params["visual_style"] = str(area_params.get("visual_style", ""))
	return area_effect_params


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
		if str(child.get_meta("source_type", "")) != source_type:
			continue
		if StringName(str(child.get_meta("source_id", ""))) != source_id:
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
	var source_id: StringName = StringName(str(params.get("object_id", params.get("source_id", ""))))
	var parent: Node = _get_parent_node(context)
	var existing_objects: Array[Node2D] = _get_orbit_objects(parent, caster, StringName(str(context.get("skill_id", ""))), source_id)
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
			orbit_object.set_meta("skill_id", StringName(str(context.get("skill_id", ""))))
			orbit_object.set_meta("source_id", source_id)

	return true


func _spawn_orbitals(params: Dictionary, context: Dictionary) -> bool:
	var orbit_params: Dictionary = params.duplicate(true)
	if not orbit_params.has("object_id"):
		orbit_params["object_id"] = str(orbit_params.get("orbital_id", orbit_params.get("source_id", "")))
	if not orbit_params.has("orbit_radius"):
		orbit_params["orbit_radius"] = float(orbit_params.get("radius", 72.0))
	return _spawn_orbit_object(orbit_params, context)


func _spawn_particles(params: Dictionary, context: Dictionary) -> bool:
	var parent: Node = _get_parent_node(context)
	if parent == null:
		return false
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "SkillParticles_%s" % str(params.get("profile", "fire"))
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
	if params.has("summon_definition_id"):
		return _spawn_managed_summon(params, context, caster, parent)

	var summon: Node2D = _create_summon_node(params)
	summon.name = str(params.get("summon_id", "skill_summon"))
	summon.global_position = caster.global_position + Vector2(float(params.get("spawn_offset", 48.0)), 0.0).rotated(randf() * TAU)
	parent.add_child(summon)
	if summon.has_method("setup"):
		var summon_params: Dictionary = params.duplicate(true)
		summon_params["caster"] = caster
		summon_params["parent"] = parent
		summon_params["action_executor"] = self
		summon_params["context"] = context.duplicate(true)
		summon.call("setup", summon_params)
		if summon.has_method("uses_internal_summon_runtime") and bool(summon.call("uses_internal_summon_runtime")):
			return true
	_attach_summon_visual(summon, params)

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


func _spawn_managed_summon(params: Dictionary, context: Dictionary, caster: Node2D, parent: Node) -> bool:
	var manager: Node = caster.get_node_or_null("SummonManager")
	if manager == null:
		manager = SummonManagerScript.new()
		manager.name = "SummonManager"
		caster.add_child(manager)
	var definition: RefCounted = SummonDefinitionScript.from_id(params.get("summon_definition_id"))
	if definition == null:
		return false
	var summon_context: Dictionary = context.duplicate(true)
	summon_context["owner"] = caster
	summon_context["caster"] = caster
	summon_context["parent"] = parent
	summon_context["target_group"] = context.get("target_group", &"enemies")
	summon_context["action_executor"] = self
	summon_context["player_power"] = _get_caster_attack_power(context)
	var summon: Node2D = manager.call("spawn_summon", definition, summon_context) as Node2D
	return summon != null


func _create_summon_node(params: Dictionary) -> Node2D:
	var script_path: String = str(params.get("summon_script", ""))
	if script_path != "" and ResourceLoader.exists(script_path):
		var summon_script: Script = load(script_path) as Script
		if summon_script != null:
			var scripted_summon: Node2D = summon_script.new() as Node2D
			if scripted_summon != null:
				return scripted_summon
	return Node2D.new()


func _summon_tick(summon: Node2D, params: Dictionary, context: Dictionary) -> void:
	if summon == null or not is_instance_valid(summon) or summon.is_queued_for_deletion():
		return
	var radius: float = maxf(float(params.get("radius", params.get("range", 180.0))), 1.0)
	var max_targets: int = maxi(int(params.get("max_targets", 1)), 1)
	var target_group: StringName = StringName(str(params.get("target_group", context.get("target_group", &"enemies"))))
	var targets: Array[Node2D] = _find_targets_around(summon.global_position, radius, target_group)
	var affected: int = 0
	for target: Node2D in targets:
		if affected >= max_targets:
			break
		var summon_context: Dictionary = context.duplicate(true)
		summon_context["target"] = target
		summon_context["source"] = summon
		_update_summon_visual_facing(summon, target)
		_spawn_summon_breath_particles(summon, target, params)
		var damage_params: Dictionary = params.duplicate(true)
		if not damage_params.has("damage_type"):
			damage_params["damage_type"] = "summon_damage"
		if not damage_params.has("damage_origin"):
			damage_params["damage_origin"] = "special"
		_deal_damage(damage_params, summon_context)
		affected += 1


func _attach_summon_visual(summon: Node2D, params: Dictionary) -> void:
	var texture_path: String = str(params.get("visual_texture", ""))
	if summon == null or texture_path == "":
		return
	if not ResourceLoader.exists(texture_path):
		push_warning("[SkillActionExecutor] Missing summon visual_texture: %s" % texture_path)
		return
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "SummonVisual"
	sprite.texture = texture
	sprite.centered = true
	var visual_scale: float = maxf(float(params.get("visual_scale", 0.12)), 0.01)
	sprite.scale = Vector2(visual_scale, visual_scale)
	sprite.z_index = int(params.get("visual_z_index", 4))
	summon.add_child(sprite)
	summon.set_meta("summon_visual_texture", texture_path)


func _update_summon_visual_facing(summon: Node2D, target: Node2D) -> void:
	if summon == null or target == null:
		return
	var direction: Vector2 = target.global_position - summon.global_position
	if direction.length_squared() <= 0.0001:
		return
	var sprite: Sprite2D = summon.get_node_or_null("SummonVisual") as Sprite2D
	if sprite == null:
		return
	sprite.rotation = direction.angle() - PI * 0.5


func _spawn_summon_breath_particles(summon: Node2D, target: Node2D, params: Dictionary) -> void:
	if summon == null or target == null or not bool(params.get("breath_particles", false)):
		return
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "DragonBreathParticles"
	summon.add_child(particles)
	var direction: Vector2 = (target.global_position - summon.global_position).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	particles.position = direction * float(params.get("breath_offset", 48.0))
	particles.rotation = direction.angle()
	_configure_gpu_particles(particles, {
		"profile": "targeted_fire_breath",
		"amount": int(params.get("breath_particle_amount", 54)),
		"lifetime": 0.45,
		"particle_lifetime": 0.35,
		"emission_radius": 12.0,
		"velocity_min": 80.0,
		"velocity_max": 180.0,
		"spread": 28.0,
		"gravity_y": -2.0,
		"scale_min": 0.35,
		"scale_max": 1.1
	}, Color(1.0, 0.26, 0.03, 0.82))
	particles.restart()
	particles.emitting = true
	var tree: SceneTree = summon.get_tree()
	if tree != null:
		tree.create_timer(0.55).timeout.connect(Callable(particles, "queue_free"))


func _configure_gpu_particles(particles: GPUParticles2D, params: Dictionary, color: Color) -> void:
	if particles == null:
		return
	var profile: String = str(params.get("profile", "fire"))
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
	radius *= maxf(1.0 + _combined_modifier_value("lightning_chain_range_multiplier", context, 0.0), 0.05)
	var max_targets: int = maxi(int(params.get("count", params.get("max_targets", 3))), 1)
	var target_group: StringName = StringName(str(params.get("target_group", context.get("target_group", &"enemies"))))
	var actions: Array = _get_array(params.get("actions", []))
	var candidates: Array[Node2D] = _find_targets_around(origin.global_position, radius, target_group, context.get("target"))
	var targeting_mode: String = str(params.get("targeting", ""))
	if targeting_mode == "conductive_first_nearest":
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			var a_conductive: bool = _target_has_status(a, &"conductive")
			var b_conductive: bool = _target_has_status(b, &"conductive")
			if a_conductive != b_conductive:
				return a_conductive
			return origin.global_position.distance_squared_to(a.global_position) < origin.global_position.distance_squared_to(b.global_position)
		)
	elif targeting_mode == "cursed_first_nearest":
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			var a_cursed: bool = _target_has_status(a, &"cursed")
			var b_cursed: bool = _target_has_status(b, &"cursed")
			if a_cursed != b_cursed:
				return a_cursed
			return origin.global_position.distance_squared_to(a.global_position) < origin.global_position.distance_squared_to(b.global_position)
		)
	var affected: int = 0

	for candidate: Node2D in candidates:
		if affected >= max_targets:
			break
		var chained_context: Dictionary = context.duplicate(true)
		chained_context["target"] = candidate
		chained_context["source"] = origin
		var chain_actions: Array = _actions_with_chain_decay(actions, affected, params)
		if actions.is_empty():
			var chain_params: Dictionary = _params_with_chain_decay(params, affected)
			_deal_damage(chain_params, chained_context)
			_apply_status(chain_params, chained_context)
		else:
			execute_actions(chain_actions, chained_context)
		affected += 1

	return affected


func _actions_with_chain_decay(actions: Array, chain_index: int, params: Dictionary) -> Array:
	if actions.is_empty() or not params.has("damage_decay"):
		return actions
	var adjusted: Array = []
	for action_variant: Variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = (action_variant as Dictionary).duplicate(true)
		if str(action.get("type", "")) == "deal_damage":
			var action_params: Dictionary = _get_dictionary(action.get("params", {}))
			if not action_params.has("damage_decay"):
				action_params["damage_decay"] = params.get("damage_decay")
			action["params"] = _params_with_chain_decay(action_params, chain_index)
		adjusted.append(action)
	return adjusted


func _params_with_chain_decay(params: Dictionary, chain_index: int) -> Dictionary:
	if not params.has("damage_decay"):
		return params
	var adjusted: Dictionary = params.duplicate(true)
	var multiplier: float = pow(maxf(float(params.get("damage_decay", 1.0)), 0.0), float(chain_index))
	if adjusted.has("amount") and adjusted["amount"] is Dictionary:
		var amount: Dictionary = (adjusted["amount"] as Dictionary).duplicate(true)
		if amount.has("scale"):
			amount["scale"] = float(amount.get("scale", 0.0)) * multiplier
			adjusted["amount"] = amount
	elif adjusted.has("power_scale"):
		adjusted["power_scale"] = float(adjusted.get("power_scale", 0.0)) * multiplier
	return adjusted


func _consume_status_stack(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false

	var status_id: StringName = StringName(str(params.get("status_id", "")))
	if status_id == &"":
		return false

	var stacks: int = maxi(int(params.get("stacks", params.get("stack", 1))), 1)
	if params.has("retain_stacks_modifier"):
		var retain_stacks: int = maxi(int(_combined_modifier_value(str(params.get("retain_stacks_modifier", "")), context, 0.0)), 0)
		if retain_stacks > 0 and target.has_method("get_status_stack"):
			var current_stacks: int = int(target.call("get_status_stack", status_id))
			stacks = maxi(current_stacks - retain_stacks, 0)
			if stacks <= 0:
				return true
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

	var amount_per_stack: float = _resolve_scaled_amount(params.get("amount_per_stack", params.get("damage_per_stack", 1.0)), context, "damage")
	var base_amount: float = _resolve_scaled_amount(params.get("amount", 0.0), context, "damage")
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
	if amount <= 0 and params.has("max_health_ratio"):
		var max_health_for_ratio: int = maxi(int(caster.get("max_health")), 1)
		amount = maxi(roundi(float(max_health_for_ratio) * float(params.get("max_health_ratio", 0.0))), 1)
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

	if str(params.get("modifier", "")) == "burning_damage_taken_multiplier":
		return _add_status_damage_taken_modifier(&"burning", modifier, params, context)

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


func _add_status_damage_taken_modifier(status_id: StringName, modifier: Dictionary, params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null or status_id == &"":
		return false
	var manager: Node = _get_status_manager(target)
	if manager == null or not manager.has_method("apply_status"):
		return false
	var values: Dictionary = ModifierSourceScript.flatten(modifier)
	if values.is_empty():
		return false
	var duration: float = maxf(float(params.get("duration", 0.6)), 0.05)
	if manager.has_method("merge_status_fields"):
		return bool(manager.call("merge_status_fields", status_id, values, duration))
	var status_params: Dictionary = values.duplicate(true)
	status_params["stacks"] = 1
	status_params["duration"] = duration
	return bool(manager.call("apply_status", status_id, status_params))


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
	amount = maxi(roundi(float(amount) * maxf(1.0 + _combined_modifier_value("holy_shield_restore_multiplier", context, 0.0), 0.05)), 0)
	if amount <= 0:
		return false

	var duration: float = maxf(float(params.get("duration", 6.0)), 0.05)
	var shield_type: String = str(params.get("shield_type", "fire_skill"))
	var current: int = int(owner.get_meta("fire_passive_shield", 0))
	var expires_at: float = float(owner.get_meta("fire_passive_shield_expires_at", 0.0))
	if expires_at > 0.0 and expires_at <= _now_seconds():
		current = 0
	var final_amount: int = current + amount
	var overflow: int = 0
	if bool(params.get("respect_shield_cap", false)) and max_health > 0.0:
		var cap_ratio: float = maxf(float(params.get("shield_cap_health_ratio", 0.35)), 0.01)
		cap_ratio *= maxf(1.0 + _combined_modifier_value("holy_shield_cap_multiplier", context, 0.0), 0.05)
		var cap: int = maxi(roundi(max_health * cap_ratio), amount)
		if final_amount > cap:
			overflow = final_amount - cap
			final_amount = cap

	context["shield_overflowed"] = overflow > 0
	context["shield_overflow_amount"] = overflow
	context["shield_gained_amount"] = maxi(final_amount - current, 0)

	owner.set_meta("fire_passive_shield", final_amount)
	owner.set_meta("fire_passive_shield_expires_at", _now_seconds() + duration)
	var shield_meta_key: String = _metadata_key(shield_type, "shield")
	var shield_expires_meta_key: String = _metadata_key(shield_type, "shield_expires_at")
	owner.set_meta(shield_meta_key, int(owner.get_meta(shield_meta_key, 0)) + maxi(final_amount - current, 0))
	owner.set_meta(shield_expires_meta_key, _now_seconds() + duration)
	var event_bus: Node = context.get("event_bus") as Node
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		var shield_context: Dictionary = context.duplicate(true)
		shield_context["owner"] = owner
		shield_context["shield_type"] = shield_type
		shield_context["shield_amount"] = maxi(final_amount - current, 0)
		shield_context["shield_overflowed"] = overflow > 0
		shield_context["shield_overflow_amount"] = overflow
		event_bus.call("emit_skill_event", &"shield_gained", shield_context)
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


func _swap_targets(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node = context.get("caster") as Node
	var targeting: String = str(params.get("targeting", "instability_stack_highest"))
	var target_params: Dictionary = params.duplicate(true)
	target_params["count"] = maxi(int(params.get("count", 2)), 2)
	if not params.has("target_range") and not params.has("detect_range") and not params.has("range"):
		target_params.erase("radius")
	elif params.has("target_range"):
		target_params["range"] = float(params.get("target_range"))
	elif params.has("detect_range"):
		target_params["range"] = float(params.get("detect_range"))
	if not target_params.has("origin") and caster is Node2D:
		target_params["origin"] = caster
	var targets: Array = TargetingServiceScript.find_targets(caster, targeting, target_params)
	var first: Node2D = null
	var second: Node2D = null
	for target_variant: Variant in targets:
		var candidate: Node2D = target_variant as Node2D
		if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if candidate.has_method("is_dead") and bool(candidate.call("is_dead")):
			continue
		if first == null:
			first = candidate
		elif second == null and candidate != first:
			second = candidate
			break
	if first == null or second == null:
		return false

	var first_position: Vector2 = first.global_position
	var second_position: Vector2 = second.global_position
	first.global_position = second_position
	second.global_position = first_position

	if params.has("area_id"):
		var area_params: Dictionary = {
			"area_id": str(params.get("area_id")),
			"position": (first_position + second_position) * 0.5,
			"radius": maxf(float(params.get("radius", 0.0)), first_position.distance_to(second_position) * 0.5),
			"duration": maxf(float(params.get("duration", 0.18)), 0.05),
			"effects_on_apply": [
				{
					"type": "damage",
					"damage_type": str(params.get("damage_type", "chaos")),
					"source_type": "power",
					"power_scale": float(params.get("power_scale", 0.0))
				}
			]
		}
		for key_variant: Variant in params.keys():
			var key: String = str(key_variant)
			if not area_params.has(key) and key not in ["targeting", "count", "power_scale", "damage_type"]:
				area_params[key] = params[key_variant]
		var area_context: Dictionary = context.duplicate(true)
		area_context["position"] = area_params["position"]
		area_context["target"] = first
		_spawn_area(area_params, area_context, "area")
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
		var key: String = str(key_variant)
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

	var status_id: StringName = StringName(str(params.get("status_id", params.get("status", ""))))
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
	var status_id: StringName = StringName(str(params.get("status_id", params.get("status", ""))))
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
	var overload_id: StringName = StringName(str(params.get("status_id", "overload")))
	return _apply_status_to_target(target, overload_id, {"stacks": 1, "duration": float(params.get("duration", 0.1))})


func _shatter_frozen(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false
	if target.has_method("get_status_stack") and int(target.call("get_status_stack", &"frozen")) <= 0:
		return false
	_consume_status_stack_on_target(target, &"frozen", 1)

	_deal_damage(_prepare_shatter_damage_params(params), context)
	if int(params.get("projectile_count", 0)) > 0:
		var burst_params: Dictionary = params.duplicate(true)
		burst_params["count"] = int(params.get("projectile_count", 0))
		burst_params["projectile_id"] = str(params.get("projectile_id", "shattered_ember"))
		_spawn_projectile_burst(burst_params, context)
	return true


func _prepare_shatter_damage_params(params: Dictionary) -> Dictionary:
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
	return damage_params


func _spawn_projectile_burst(params: Dictionary, context: Dictionary) -> bool:
	return _spawn_projectile(_prepare_projectile_burst_params(params), context)


func _prepare_projectile_burst_params(params: Dictionary) -> Dictionary:
	var projectile_params: Dictionary = params.duplicate(true)
	if projectile_params.has("damage") and projectile_params.get("damage") is Dictionary:
		var damage: Dictionary = projectile_params.get("damage")
		if damage.has("power_scale"):
			projectile_params["damage"] = {"stat": "power", "scale": float(damage.get("power_scale", 0.0))}
		for key_variant: Variant in damage.keys():
			var key: String = str(key_variant)
			if key != "power_scale" and not projectile_params.has(key):
				projectile_params[key] = damage[key_variant]
	if projectile_params.has("on_hit") and not projectile_params.has("actions_on_hit"):
		projectile_params["actions_on_hit"] = _effects_to_actions(_get_array(projectile_params.get("on_hit", [])))
	if projectile_params.has("effects_on_hit") and not projectile_params.has("actions_on_hit"):
		projectile_params["actions_on_hit"] = _effects_to_actions(_get_array(projectile_params.get("effects_on_hit", [])))
	if projectile_params.has("angle") and not projectile_params.has("spread_angle"):
		projectile_params["spread_angle"] = float(projectile_params.get("angle", 0.0))
	if not projectile_params.has("spawn_offset"):
		projectile_params["spawn_offset"] = float(projectile_params.get("radius", 24.0))
	return projectile_params


func _repeat_area_path(params: Dictionary, context: Dictionary) -> bool:
	var area_params: Dictionary = _prepare_area_tick_action_params(params)
	if not area_params.has("area_id"):
		area_params["area_id"] = str(params.get("source_area_tag", "repeated_area_path"))
	if not area_params.has("duration"):
		area_params["duration"] = float(params.get("duration", 2.0))
	return _spawn_area(area_params, context, "area")


func _spawn_area_from_existing_area(params: Dictionary, context: Dictionary) -> bool:
	var source_area: Node2D = context.get("area") as Node2D
	if source_area == null:
		source_area = context.get("source") as Node2D
	var area_params: Dictionary = _prepare_area_tick_action_params(params)
	if source_area != null and not area_params.has("position"):
		area_params["position"] = source_area.global_position
	if not area_params.has("radius") and source_area != null:
		area_params["radius"] = float(source_area.get("radius")) if _has_property(source_area, "radius") else 48.0
	return _spawn_area(area_params, context, "area")


func _prepare_area_tick_action_params(params: Dictionary) -> Dictionary:
	var area_params: Dictionary = params.duplicate(true)
	if area_params.has("effects_on_tick") and not area_params.has("actions_on_tick"):
		area_params["actions_on_tick"] = _effects_to_actions(_get_array(area_params.get("effects_on_tick", [])))
	return area_params


func _mark_target(params: Dictionary, context: Dictionary) -> bool:
	var resolved_context: Dictionary = _context_with_resolved_target(params, context)
	var target: Node = resolved_context.get("target") as Node
	if target == null:
		return false

	var mark: String = str(params.get("mark", params.get("key", ""))).strip_edges()
	if mark == "":
		return false

	var mark_key: String = _metadata_identifier(mark)
	target.set_meta(mark_key, true)
	if params.has("duration"):
		target.set_meta(_metadata_key(mark, "expires_at"), float(Time.get_ticks_msec()) / 1000.0 + maxf(float(params.get("duration", 0.0)), 0.0))
	return true


func _resolve_position(params: Dictionary, context: Dictionary) -> Vector2:
	if params.has("position"):
		return _get_vector2(params["position"], Vector2.ZERO)

	if context.has("position") and not params.has("position_mode"):
		return _get_vector2(context.get("position"), Vector2.ZERO)

	var position_mode: String = str(params.get("position_mode", "target"))
	if position_mode == "caster" or position_mode == "owner" or position_mode == "self":
		var caster_for_mode: Node2D = context.get("caster") as Node2D
		var base_position: Vector2 = caster_for_mode.global_position if caster_for_mode != null else Vector2.ZERO
		return base_position + _resolve_position_offset(params, context, base_position)

	var target: Node2D = context.get("target") as Node2D
	if target != null:
		return target.global_position

	var caster: Node2D = context.get("caster") as Node2D
	return caster.global_position if caster != null else Vector2.ZERO


func _resolve_position_offset(params: Dictionary, context: Dictionary, base_position: Vector2) -> Vector2:
	if params.has("position_offset"):
		return _get_vector2(params["position_offset"], Vector2.ZERO)
	var distance: float = float(params.get("position_offset_distance", 0.0))
	if distance <= 0.0:
		return Vector2.ZERO
	return _resolve_named_direction(str(params.get("position_offset_direction", "towards_target")), context, base_position) * distance


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


func _resolve_area_move_direction(params: Dictionary, context: Dictionary, area_position: Vector2) -> Vector2:
	if not params.has("move_direction"):
		return Vector2.ZERO
	var direction_value: Variant = params.get("move_direction")
	if direction_value is String:
		return _resolve_named_direction(str(direction_value), context, area_position)
	var direction: Vector2 = _get_vector2(direction_value, Vector2.ZERO)
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.ZERO


func _resolve_named_direction(name: String, context: Dictionary, origin: Vector2) -> Vector2:
	match name:
		"towards_target", "target":
			var target: Node2D = context.get("target") as Node2D
			if target != null:
				var target_direction: Vector2 = target.global_position - origin
				if target_direction.length_squared() > 0.0001:
					return target_direction.normalized()
				var caster_for_same_position: Node2D = context.get("caster") as Node2D
				if caster_for_same_position != null:
					var caster_to_target: Vector2 = target.global_position - caster_for_same_position.global_position
					if caster_to_target.length_squared() > 0.0001:
						return caster_to_target.normalized()
		"away_from_target":
			var target_for_away: Node2D = context.get("target") as Node2D
			if target_for_away != null:
				var away_direction: Vector2 = origin - target_for_away.global_position
				if away_direction.length_squared() > 0.0001:
					return away_direction.normalized()
		"caster_forward":
			var caster: Node2D = context.get("caster") as Node2D
			if caster != null:
				var caster_forward: Vector2 = origin - caster.global_position
				if caster_forward.length_squared() > 0.0001:
					return caster_forward.normalized()
	return Vector2.RIGHT


func _context_with_resolved_target(params: Dictionary, context: Dictionary) -> Dictionary:
	var target: Node2D = context.get("target") as Node2D
	var force_configured_targeting: bool = params.has("targeting") or params.has("targeting_mode")
	if not force_configured_targeting and target != null and is_instance_valid(target) and not target.is_queued_for_deletion():
		return context
	var resolved_target: Node2D = _resolve_action_target(params, context)
	if resolved_target == null:
		return context
	var resolved_context: Dictionary = context.duplicate(true)
	resolved_context["target"] = resolved_target
	resolved_context["enemy"] = resolved_target
	return resolved_context


func _resolve_action_target(params: Dictionary, context: Dictionary) -> Node2D:
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return null
	var mode: String = str(params.get("targeting", params.get("targeting_mode", "nearest_enemy")))
	if mode == "":
		return null
	var range: float = float(params.get("range", params.get("detect_range", ModifierResolverScript.get_stat(context, "range", INF))))
	return TargetingServiceScript.find_target(caster, mode, {
		"origin": caster,
		"range": range,
		"radius": range,
		"cluster_radius": float(params.get("cluster_radius", params.get("radius", 168.0))),
		"count": 1
	})


func _resolve_area_tick_interval(area_source_id: StringName, params: Dictionary, special_rules: Dictionary) -> float:
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_tick_interval"):
		var rule: Dictionary = _get_dictionary(special_rules.get("acid_pressure_tick_interval", {}))
		return maxf(float(rule.get("tick_interval_override", params.get("tick_interval", 0.1))), 0.05)
	return maxf(float(params.get("tick_interval", 0.1)), 0.05)


func _get_damage_type(params: Dictionary, context: Dictionary, source_type: String = "skill", damage_origin: String = "") -> StringName:
	if params.has("damage_type"):
		var configured_damage_type: String = str(params["damage_type"])
		if _is_element_name(configured_damage_type):
			return _infer_damage_type(_get_element(params, context), source_type, damage_origin)
		return _normalize_configured_damage_type(configured_damage_type, _get_element(params, context), source_type, damage_origin)

	var context_damage_type: String = str(context.get("damage_type", ""))
	if context_damage_type != "":
		if _is_element_name(context_damage_type):
			return _infer_damage_type(StringName(_normalize_element_name(context_damage_type)), source_type, damage_origin)
		return _normalize_configured_damage_type(context_damage_type, _get_element(params, context), source_type, damage_origin)

	return _infer_damage_type(_get_element(params, context), source_type, damage_origin)


func _get_element(params: Dictionary, context: Dictionary) -> StringName:
	if params.has("element"):
		return StringName(_normalize_element_name(str(params["element"])))
	if params.has("damage_type") and _is_element_name(str(params["damage_type"])):
		return StringName(_normalize_element_name(str(params["damage_type"])))
	var context_element: String = str(context.get("element", ""))
	if context_element != "":
		return StringName(_normalize_element_name(context_element))
	var context_damage_type: String = str(context.get("damage_type", ""))
	if _is_element_name(context_damage_type):
		return StringName(_normalize_element_name(context_damage_type))
	return &"physical"


func _get_damage_origin(params: Dictionary, context: Dictionary, source_type: String) -> String:
	var configured: String = str(params.get("damage_origin", context.get("damage_origin", "")))
	match configured:
		"primary_attack", "status_dot", "reaction", "field", "trap", "special", "healing":
			return configured
		"status":
			return "status_dot"

	if source_type == "trap":
		return "trap"
	if source_type == "explosion":
		return "primary_attack"
	if source_type == "status":
		return "status_dot"
	var field_model: String = str(params.get("field_damage_model", ""))
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
	return str(ELEMENT_ALIASES.get(value, value))


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
	if str(packet.get("element", "")) == "lightning" and _target_has_status(context.get("target") as Node, &"conductive"):
		packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(skill_modifiers.get("conductive_lightning_damage_taken_multiplier", 0.0))
	if str(packet.get("element", "")) == "holy" and _target_has_status(context.get("target") as Node, &"judgment"):
		var judgment_stacks: int = maxi(_target_status_stack(context.get("target") as Node, &"judgment"), 1)
		packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(skill_modifiers.get("judgment_holy_damage_taken_multiplier", 0.0)) * float(judgment_stacks)


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
	var element: String = str(packet.get("element", ""))
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
	if str(packet_object.call("get_value", "damage_origin", "")) != "primary_attack":
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
		push_warning("[SkillActionExecutor] skill_level_coefficients out of range for %s level %d; defaulting to 1.0." % [str(skill_instance.get("skill_id")), level_index + 1])
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
		if StringName(str(orbit_object.get_meta("skill_id"))) != skill_id:
			continue
		if int(orbit_object.get_meta("owner_instance_id")) != int(caster.get_instance_id()):
			continue
		if source_id != &"" and StringName(str(orbit_object.get_meta("source_id", ""))) != source_id:
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
	var skill_key: String = str(context.get("skill_id", "skill"))
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
		var projectile_cast_id: String = str(projectile.get_meta("cast_instance_id", ""))
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
	if str(projectile.get_meta("cast_instance_id", "")) != str(skill_instance.get_meta("storm_hail_cast_instance_id", "")):
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
		if str(data.get("stat", "")) == "power":
			if context.has("power"):
				return float(context.get("power", 0.0)) * float(data.get("scale", 1.0))
			var power: float = float(ModifierResolverScript.resolve_value(context, stat_name, ModifierResolverScript.get_stat(context, "power", _get_caster_attack_power(context))))
			return power * float(data.get("scale", 1.0))
	return float(ModifierResolverScript.resolve_value(context, stat_name, value))


func _build_modifier_from_params(params: Dictionary) -> Dictionary:
	if params.has("stat") and params.has("value"):
		return params.duplicate(true)

	var modifier_name: String = str(params.get("modifier", ""))
	if modifier_name == "" or not params.has("value"):
		return {}

	var value: Variant = params.get("value")
	var values: Dictionary = {}
	match modifier_name:
		"attack_damage_multiplier":
			values["primary_attack_damage_multiplier_add"] = value
		"burning_damage_taken_multiplier":
			values["status_dot_damage_taken_multiplier_add_per_stack"] = value
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


func _get_status_power_from_context(context: Dictionary) -> float:
	for packet_key: String in ["damage_packet", "source_packet", "packet"]:
		var packet_variant: Variant = context.get(packet_key)
		if packet_variant is Dictionary:
			var packet: Dictionary = packet_variant
			var amount: float = float(packet.get("raw_amount", packet.get("amount", 0.0)))
			if amount > 0.0:
				return amount
	var amount: float = float(context.get("amount", 0.0))
	if amount > 0.0:
		return amount
	return _get_caster_attack_power(context)


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
		if str(property_info.get("name", "")) == property:
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
		if str(property_info.get("name", "")) == property:
			return float(object.get(property))
	return fallback


func _combined_modifier_value(key: String, context: Dictionary, fallback: float = 0.0) -> float:
	if key == "":
		return fallback
	var modifiers: Dictionary = SkillStatServiceScript.get_combined_modifiers(
		context.get("skill_instance") as RefCounted,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	)
	return float(modifiers.get(key, fallback))


func _target_has_status(target: Node, status_id: StringName) -> bool:
	if target == null or status_id == &"":
		return false
	if target.has_method("has_status") and bool(target.call("has_status", status_id)):
		return true
	var manager: Node = target.get_node_or_null("StatusEffectManager")
	return manager != null and manager.has_method("has_status") and bool(manager.call("has_status", status_id))


func _target_status_stack(target: Node, status_id: StringName) -> int:
	if target == null or status_id == &"":
		return 0
	if target.has_method("get_status_stack"):
		return int(target.call("get_status_stack", status_id))
	var manager: Node = target.get_node_or_null("StatusEffectManager")
	if manager != null and manager.has_method("get_status_stack"):
		return int(manager.call("get_status_stack", status_id))
	return 1 if _target_has_status(target, status_id) else 0


func _get_status_ids(params: Dictionary) -> Array[StringName]:
	var status_ids: Array[StringName] = []
	var ids_variant: Variant = params.get("status_ids", [])
	if ids_variant is Array:
		for id_variant: Variant in ids_variant:
			var status_id: StringName = StringName(str(id_variant))
			if status_id != &"" and not status_ids.has(status_id):
				status_ids.append(status_id)

	var single_id: StringName = StringName(str(params.get("status_id", "")))
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
			var status_id: StringName = StringName(str(status_variant))
			if status_id != &"" and not statuses.has(status_id):
				statuses.append(status_id)

	var single_status: StringName = StringName(str(params.get("status_id", params.get("status_on_hit", ""))))
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


func _metadata_key(namespace_text: String, suffix: String) -> String:
	return MetadataKeyScript.key(namespace_text, suffix, "skill_action")


func _metadata_identifier(raw_key: String) -> String:
	return MetadataKeyScript.identifier(raw_key, "skill_action")
