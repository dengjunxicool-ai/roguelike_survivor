extends "res://scripts/skills/skill_action_support.gd"
class_name SkillActionProjectileExecutor


func _spawn_projectile(params: Dictionary, context: Dictionary) -> bool:
	context = _context_with_resolved_target(params, context)
	var caster: Node2D = context.get("caster") as Node2D
	var target: Node2D = context.get("target") as Node2D
	if caster == null or target == null:
		return false

	var projectile_stats: Dictionary = _resolve_projectile_runtime_stats(params, context)
	var count: int = int(projectile_stats.get("count", 1))
	var runtime_data: Dictionary = _build_projectile_runtime_data(projectile_stats, params, context)
	var source_id: StringName = StringName(runtime_data.get("source_id", &""))
	var cast_instance_id: String = str(runtime_data.get("cast_instance_id", ""))
	var spread_angle: float = deg_to_rad(float(ModifierResolverScript.resolve_value(context, "spread_angle", params.get("spread_angle", 0.0))))
	var base_direction: Vector2 = caster.global_position.direction_to(target.global_position)
	if base_direction == Vector2.ZERO:
		return false

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
		_spawn_direct_projectile_instance(
			params,
			projectile_params,
			context,
			caster,
			target,
			runtime_data,
			base_direction,
			start_angle,
			spread_angle,
			projectile_index,
			forbidden_page_pending,
			hot_rapid_fire_pending,
			hot_rapid_fire_crit_chance_add
		)

	return true


func _spawn_projectiles_at_targets(params: Dictionary, context: Dictionary) -> bool:
	params = _prepare_projectile_burst_params(params)
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return false

	var projectile_stats: Dictionary = _resolve_projectile_runtime_stats(params, context)
	var count: int = int(projectile_stats.get("count", 1))
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

	var runtime_data: Dictionary = _build_projectile_runtime_data(projectile_stats, params, context)
	var cast_instance_id: String = str(runtime_data.get("cast_instance_id", ""))
	var source_id: StringName = StringName(runtime_data.get("source_id", &""))
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
		var projectile_context: Dictionary = context.duplicate(true)
		projectile_context["target"] = target
		var projectile_params: Dictionary = params.duplicate(true)
		if not projectile_params.has("source_instance_id"):
			projectile_params["source_instance_id"] = DamageSourceIdentityScript.for_projectile(cast_instance_id, spawned, source_id)
		_spawn_targeted_projectile_instance(
			params,
			projectile_params,
			projectile_context,
			caster,
			target,
			runtime_data,
			context,
			same_target_hit_index
		)
		spawned += 1

	return spawned > 0


func _spawn_direct_projectile_instance(params: Dictionary, projectile_params: Dictionary, context: Dictionary, caster: Node2D, target: Node2D, runtime_data: Dictionary, base_direction: Vector2, start_angle: float, spread_angle: float, projectile_index: int, forbidden_page_pending: bool, hot_rapid_fire_pending: bool, hot_rapid_fire_crit_chance_add: float) -> void:
	var use_hot_rapid_fire: bool = hot_rapid_fire_pending and projectile_index == 0
	var launch_data: Dictionary = _build_direct_projectile_launch_data(params, caster, target, base_direction, start_angle, spread_angle, projectile_index)
	var projectile_position: Vector2 = launch_data.get("position", caster.global_position)
	var direction: Vector2 = launch_data.get("direction", base_direction)
	var curve_target_position: Vector2 = launch_data.get("target_position", target.global_position)
	var damage: int = int(runtime_data.get("damage", 0))
	CombatObjectFactoryScript.create_projectile(_build_projectile_spawn_params(
		params,
		projectile_params,
		context,
		runtime_data.get("parent") as Node,
		caster,
		StringName(runtime_data.get("source_id", &"")),
		projectile_position,
		direction,
		damage,
		_build_damage_packet(projectile_params, context, damage, "projectile"),
		float(runtime_data.get("speed", 420.0)),
		int(runtime_data.get("pierce", 0)),
		float(runtime_data.get("radius", 10.0)),
		float(runtime_data.get("lifetime", 2.0)),
		_get_projectile_runtime_statuses_on_hit(runtime_data),
		str(runtime_data.get("cast_instance_id", "")),
		str(params.get("trajectory_mode", "linear")),
		projectile_position,
		curve_target_position,
		{
			"hot_rapid_fire_crit": use_hot_rapid_fire,
			"hot_rapid_fire_crit_chance_add": hot_rapid_fire_crit_chance_add if use_hot_rapid_fire else 0.0,
			"forbidden_page": forbidden_page_pending and projectile_index == 0
		}
	))


func _spawn_targeted_projectile_instance(params: Dictionary, projectile_params: Dictionary, projectile_context: Dictionary, caster: Node2D, target: Node2D, runtime_data: Dictionary, source_context: Dictionary, same_target_hit_index: int) -> void:
	var spawn_delay: float = _same_target_projectile_spawn_delay(projectile_params, same_target_hit_index)
	if spawn_delay > 0.0:
		_spawn_targeted_projectile_instance_after_delay(
			params,
			projectile_params.duplicate(true),
			projectile_context.duplicate(true),
			caster,
			target,
			runtime_data.duplicate(true),
			source_context.duplicate(true),
			same_target_hit_index,
			spawn_delay
		)
		return
	_spawn_targeted_projectile_instance_now(params, projectile_params, projectile_context, caster, target, runtime_data, source_context, same_target_hit_index)


func _spawn_targeted_projectile_instance_after_delay(params: Dictionary, projectile_params: Dictionary, projectile_context: Dictionary, caster: Node2D, target: Node2D, runtime_data: Dictionary, source_context: Dictionary, same_target_hit_index: int, spawn_delay: float) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		_spawn_targeted_projectile_instance_now(params, projectile_params, projectile_context, caster, target, runtime_data, source_context, same_target_hit_index)
		return
	await tree.create_timer(spawn_delay).timeout
	if caster == null or target == null or not is_instance_valid(caster) or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	_spawn_targeted_projectile_instance_now(params, projectile_params, projectile_context, caster, target, runtime_data, source_context, same_target_hit_index)


func _spawn_targeted_projectile_instance_now(params: Dictionary, projectile_params: Dictionary, projectile_context: Dictionary, caster: Node2D, target: Node2D, runtime_data: Dictionary, source_context: Dictionary, same_target_hit_index: int) -> void:
	var launch_data: Dictionary = _build_targeted_projectile_launch_data(params, caster.global_position, target.global_position, same_target_hit_index)
	var visual_start_position: Vector2 = launch_data.get("position", caster.global_position)
	var visual_target_position: Vector2 = launch_data.get("target_position", target.global_position)
	var direction: Vector2 = launch_data.get("direction", Vector2.RIGHT)
	projectile_params = _projectile_params_for_same_target_hit(projectile_params, same_target_hit_index)
	var damage: int = int(runtime_data.get("damage", 0))
	var damage_packet: Dictionary = _build_damage_packet(projectile_params, projectile_context, damage, "projectile")
	_apply_projectile_damage_sequence(damage_packet, projectile_params, same_target_hit_index, source_context)
	CombatObjectFactoryScript.create_projectile(_build_projectile_spawn_params(
		params,
		projectile_params,
		projectile_context,
		runtime_data.get("parent") as Node,
		caster,
		StringName(runtime_data.get("source_id", &"")),
		visual_start_position,
		direction.normalized(),
		damage,
		damage_packet,
		float(runtime_data.get("speed", 420.0)),
		int(runtime_data.get("pierce", 0)),
		float(runtime_data.get("radius", 10.0)),
		float(runtime_data.get("lifetime", 2.0)),
		_get_projectile_runtime_statuses_on_hit(runtime_data),
		str(runtime_data.get("cast_instance_id", "")),
		str(params.get("trajectory_mode", "curve")),
		visual_start_position,
		visual_target_position
	))


func _same_target_projectile_spawn_delay(params: Dictionary, same_target_hit_index: int) -> float:
	return SkillActionProjectileBuilderScript.resolve_same_target_spawn_delay(params, same_target_hit_index)


func _projectile_params_for_same_target_hit(params: Dictionary, same_target_hit_index: int) -> Dictionary:
	return SkillActionProjectileBuilderScript.build_same_target_hit_params(params, same_target_hit_index)


func _damage_only_actions(actions: Array) -> Array:
	return SkillActionProjectileBuilderScript.filter_damage_actions(actions)


func _resolve_projectile_runtime_stats(params: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"count": maxi(int(ModifierResolverScript.resolve_value(context, "projectile_count", params.get("count", 1))), 1),
		"speed": maxf(float(ModifierResolverScript.resolve_value(context, "projectile_speed", params.get("speed", 420.0))), 1.0),
		"pierce": maxi(int(ModifierResolverScript.resolve_value(context, "pierce", params.get("pierce", 0))), 0),
		"radius": maxf(float(ModifierResolverScript.resolve_value(context, "area_radius", params.get("collision_radius", params.get("radius", 10.0)))), 1.0),
		"lifetime": maxf(float(params.get("lifetime", 2.0)), 0.1),
		"damage": maxi(roundi(_resolve_scaled_amount(params.get("damage", ModifierResolverScript.get_stat(context, "damage", 0)), context, "damage")), 0),
		"source_id": StringName(str(params.get("projectile_id", params.get("source_id", ""))))
	}


func _build_projectile_runtime_data(projectile_stats: Dictionary, params: Dictionary, context: Dictionary) -> Dictionary:
	return SkillActionProjectileBuilderScript.build_runtime_data({
		"speed": projectile_stats.get("speed", 420.0),
		"pierce": projectile_stats.get("pierce", 0),
		"radius": projectile_stats.get("radius", 10.0),
		"lifetime": projectile_stats.get("lifetime", 2.0),
		"damage": projectile_stats.get("damage", 0),
		"source_id": projectile_stats.get("source_id", &""),
		"statuses_on_hit": _get_statuses_on_hit(params, context),
		"parent": _get_parent_node(context),
		"cast_instance_id": _next_cast_instance_id(context),
	})


func _get_projectile_runtime_statuses_on_hit(runtime_data: Dictionary) -> Array[StringName]:
	return SkillActionProjectileBuilderScript.normalize_status_ids(_get_array(runtime_data.get("statuses_on_hit", [])))


func _build_targeted_projectile_launch_data(params: Dictionary, caster_position: Vector2, target_position: Vector2, same_target_hit_index: int) -> Dictionary:
	return SkillActionProjectileBuilderScript.build_targeted_launch_data(params, caster_position, target_position, same_target_hit_index)


func _build_direct_projectile_launch_data(params: Dictionary, caster: Node2D, target: Node2D, base_direction: Vector2, start_angle: float, spread_angle: float, projectile_index: int) -> Dictionary:
	return SkillActionProjectileBuilderScript.build_direct_launch_data(params, caster, target, base_direction, start_angle, spread_angle, projectile_index)


func _apply_projectile_visual_start_offset(start_position: Vector2, target_position: Vector2, params: Dictionary) -> Vector2:
	return SkillActionProjectileBuilderScript.apply_visual_start_offset(start_position, target_position, params)


func _build_projectile_spawn_params(params: Dictionary, projectile_params: Dictionary, context: Dictionary, parent: Node, caster: Node2D, source_id: StringName, position: Vector2, direction: Vector2, damage: int, damage_packet: Dictionary, speed: float, pierce: int, radius: float, lifetime: float, statuses_on_hit: Array[StringName], cast_instance_id: String, trajectory_mode: String, curve_start_position: Vector2, curve_target_position: Vector2, extra_params: Dictionary = {}) -> Dictionary:
	return SkillActionProjectileBuilderScript.build_spawn_params({
		"params": params,
		"projectile_params": projectile_params,
		"context": context,
		"parent": parent,
		"caster": caster,
		"source_id": source_id,
		"position": position,
		"direction": direction,
		"damage": damage,
		"damage_type": _get_damage_type(projectile_params, context, "projectile", _get_damage_origin(projectile_params, context, "projectile")),
		"damage_packet": damage_packet,
		"speed": speed,
		"pierce": pierce,
		"radius": radius,
		"lifetime": lifetime,
		"statuses_on_hit": statuses_on_hit,
		"status_params": _get_status_params(params, context),
		"cast_instance_id": cast_instance_id,
		"trajectory_mode": trajectory_mode,
		"curve_start_position": curve_start_position,
		"curve_target_position": curve_target_position,
		"extra_params": extra_params
	})


func _build_projectile_target_sequence(targets: Array, count: int) -> Array:
	return SkillActionProjectileBuilderScript.build_target_sequence(targets, count)


func _resolve_projectile_visual_start_position(start_position: Vector2, target_position: Vector2, same_target_hit_index: int, params: Dictionary) -> Vector2:
	return SkillActionProjectileBuilderScript.resolve_visual_start_position(start_position, target_position, same_target_hit_index, params)


func _resolve_projectile_visual_target_position(target_position: Vector2, same_target_hit_index: int, params: Dictionary) -> Vector2:
	return SkillActionProjectileBuilderScript.resolve_visual_target_position(target_position, same_target_hit_index, params)


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


func _spawn_projectile_burst(params: Dictionary, context: Dictionary) -> bool:
	return _spawn_projectile_burst_with_budget(_prepare_projectile_burst_params(params), context)


func _spawn_projectile_burst_with_budget(projectile_params: Dictionary, context: Dictionary) -> bool:
	var budget_key: String = str(projectile_params.get("defer_budget_key", "")).strip_edges()
	var max_per_frame: int = maxi(int(projectile_params.get("max_per_frame", projectile_params.get("per_frame_budget", 0))), 0)
	if budget_key == "" or max_per_frame <= 0:
		return _spawn_projectile(projectile_params, context)

	var cost: int = maxi(int(projectile_params.get("count", 1)), 1)
	var frame: int = Engine.get_physics_frames()
	if int(_projectile_burst_budget_frame_by_key.get(budget_key, -1)) != frame:
		_projectile_burst_budget_frame_by_key[budget_key] = frame
		_projectile_burst_budget_used_by_key[budget_key] = 0
	var used: int = int(_projectile_burst_budget_used_by_key.get(budget_key, 0))
	if used + cost > max_per_frame:
		_defer_projectile_burst_to_budget(projectile_params, context)
		return true
	_projectile_burst_budget_used_by_key[budget_key] = used + cost
	return _spawn_projectile(projectile_params, context)


func _defer_projectile_burst_to_budget(projectile_params: Dictionary, context: Dictionary) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		_spawn_projectile(projectile_params, context)
		return
	await tree.physics_frame
	_spawn_projectile_burst_with_budget(projectile_params, context)


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
