extends RefCounted
class_name SkillActionProjectileBuilder


static func build_targeted_launch_data(params: Dictionary, caster_position: Vector2, target_position: Vector2, same_target_hit_index: int) -> Dictionary:
	var visual_start_position: Vector2 = _resolve_visual_start_position(caster_position, target_position, same_target_hit_index, params)
	var visual_target_position: Vector2 = _resolve_visual_target_position(target_position, same_target_hit_index, params)
	visual_start_position = apply_visual_start_offset(visual_start_position, visual_target_position, params)
	var direction: Vector2 = visual_start_position.direction_to(visual_target_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	return {
		"position": visual_start_position,
		"target_position": visual_target_position,
		"direction": direction
	}


static func build_direct_launch_data(params: Dictionary, caster: Node2D, target: Node2D, base_direction: Vector2, start_angle: float, spread_angle: float, projectile_index: int) -> Dictionary:
	var direction: Vector2 = base_direction.rotated(start_angle + spread_angle * float(projectile_index)).normalized()
	var target_position: Vector2 = target.global_position
	var position: Vector2 = caster.global_position + direction * float(params.get("spawn_offset", 24.0))
	position = apply_visual_start_offset(position, target_position, params)
	if params.has("visual_start_offset"):
		direction = position.direction_to(target_position)
		if direction == Vector2.ZERO:
			direction = base_direction
	return {
		"position": position,
		"direction": direction,
		"target_position": target_position
	}


static func apply_visual_start_offset(start_position: Vector2, target_position: Vector2, params: Dictionary) -> Vector2:
	if not params.has("visual_start_offset"):
		return start_position
	var visual_start_offset: Vector2 = _get_vector2(params.get("visual_start_offset"), Vector2.ZERO)
	if str(params.get("visual_start_relative_to", "caster")) == "target":
		return target_position + visual_start_offset
	return start_position + visual_start_offset


static func resolve_visual_start_position(start_position: Vector2, target_position: Vector2, same_target_hit_index: int, params: Dictionary) -> Vector2:
	return _resolve_visual_start_position(start_position, target_position, same_target_hit_index, params)


static func resolve_visual_target_position(target_position: Vector2, same_target_hit_index: int, params: Dictionary) -> Vector2:
	return _resolve_visual_target_position(target_position, same_target_hit_index, params)


static func build_spawn_params(input: Dictionary) -> Dictionary:
	var params: Dictionary = _get_dictionary(input.get("params", {}))
	var projectile_params: Dictionary = _get_dictionary(input.get("projectile_params", {}))
	var context: Dictionary = _get_dictionary(input.get("context", {}))
	var source_id: StringName = StringName(str(input.get("source_id", &"")))
	var spawn_params: Dictionary = {
		"parent": input.get("parent"),
		"projectile_id": source_id,
		"position": _get_vector2(input.get("position", Vector2.ZERO), Vector2.ZERO),
		"direction": _get_vector2(input.get("direction", Vector2.RIGHT), Vector2.RIGHT),
		"damage": int(input.get("damage", 0)),
		"damage_type": StringName(str(input.get("damage_type", ""))),
		"damage_packet": _get_dictionary(input.get("damage_packet", {})),
		"speed": float(input.get("speed", 420.0)),
		"pierce": int(input.get("pierce", 0)),
		"radius": float(input.get("radius", 10.0)),
		"lifetime": float(input.get("lifetime", 2.0)),
		"status_on_hit": StringName(str(params.get("status_id", params.get("status_on_hit", "")))),
		"statuses_on_hit": input.get("statuses_on_hit", []),
		"status_params": _get_dictionary(input.get("status_params", {})),
		"target_group": context.get("target_group", &"enemies"),
		"event_bus": context.get("event_bus"),
		"skill_instance": context.get("skill_instance"),
		"caster": input.get("caster"),
		"skill_manager": context.get("skill_manager"),
		"relic_manager": context.get("relic_manager"),
		"source_id": source_id,
		"event_on_hit": &"on_projectile_hit",
		"actions_on_hit": _get_array(projectile_params.get("actions_on_hit", [])),
		"cast_instance_id": str(input.get("cast_instance_id", "")),
		"trajectory_mode": str(input.get("trajectory_mode", "linear")),
		"curve_start_position": _get_vector2(input.get("curve_start_position", Vector2.ZERO), Vector2.ZERO),
		"curve_target_position": _get_vector2(input.get("curve_target_position", Vector2.ZERO), Vector2.ZERO),
		"curve_height": float(params.get("curve_height", 64.0)),
		"homing_enabled": bool(params.get("homing_enabled", false)),
		"homing_turn_rate": float(params.get("homing_turn_rate", 8.0)),
		"homing_seek_range": float(params.get("homing_seek_range", params.get("range", 0.0)))
	}
	for key: Variant in _get_dictionary(input.get("extra_params", {})).keys():
		spawn_params[key] = input["extra_params"][key]
	return spawn_params


static func build_target_sequence(targets: Array, count: int) -> Array:
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


static func _resolve_visual_start_position(start_position: Vector2, target_position: Vector2, same_target_hit_index: int, params: Dictionary) -> Vector2:
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


static func _resolve_visual_target_position(target_position: Vector2, same_target_hit_index: int, params: Dictionary) -> Vector2:
	if same_target_hit_index <= 0:
		return target_position
	var spread_radius: float = maxf(float(params.get("same_target_curve_spread_radius", 18.0)), 0.0)
	if spread_radius <= 0.0:
		return target_position
	var angle: float = -PI * 0.5 + float(same_target_hit_index - 1) * TAU / 3.0
	return target_position + Vector2(cos(angle), sin(angle)) * spread_radius


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	return fallback


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
