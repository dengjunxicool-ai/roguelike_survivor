extends RefCounted
class_name SkillActionAreaBuilder


static func build_effect_spawn_params(input: Dictionary) -> Dictionary:
	var area_params: Dictionary = _get_dictionary(input.get("area_params", input.get("params", {})))
	var context: Dictionary = _get_dictionary(input.get("context", {}))
	var damage_packet: Dictionary = _get_dictionary(input.get("damage_packet", {}))
	var area_source_id: StringName = StringName(str(input.get("area_source_id", &"")))
	var impact_target: Node = context.get("target") as Node
	var dash_path_filter: bool = bool(area_params.get("dash_path_filter", false))
	var area_effect_params: Dictionary = {
		"parent": input.get("parent"),
		"area_id": area_source_id,
		"position": _get_vector2(input.get("position", Vector2.ZERO), Vector2.ZERO),
		"damage": int(input.get("damage", 0)),
		"damage_type": StringName(str(input.get("damage_type", ""))),
		"damage_packet": damage_packet,
		"source_origin_id": StringName(str(damage_packet.get("source_origin_id", context.get("source_origin_id", "")))),
		"source_skill_id": StringName(str(damage_packet.get("source_skill_id", context.get("skill_id", "")))),
		"duration": float(input.get("duration", 0.12)),
		"tick_interval": float(input.get("tick_interval", 1.0)),
		"radius": float(input.get("radius", 48.0)),
		"cone_width_degrees": float(area_params.get("cone_width_degrees", 0.0)),
		"cone_direction": _get_vector2(input.get("cone_direction", Vector2.RIGHT), Vector2.RIGHT),
		"move_direction": _get_vector2(input.get("move_direction", Vector2.ZERO), Vector2.ZERO),
		"move_speed": maxf(float(area_params.get("move_speed", 0.0)), 0.0),
		"max_targets": int(input.get("max_targets", 0)),
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": area_params.get("visual_color", Color(1.0, 0.38, 0.05, 0.32)),
		"status_on_hit": StringName(str(area_params.get("status_id", area_params.get("status_on_hit", "")))),
		"statuses_on_hit": input.get("statuses_on_hit", []),
		"status_params": _get_dictionary(input.get("status_params", {})),
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
		"relic_manager": context.get("relic_manager"),
		"dash_path_filter": dash_path_filter
	}
	if dash_path_filter:
		area_effect_params["dash_path_start"] = context.get("dash_path_start", Vector2.ZERO)
		area_effect_params["dash_path_end"] = context.get("dash_path_end", Vector2.ZERO)
	if area_params.has("visual_style"):
		area_effect_params["visual_style"] = str(area_params.get("visual_style", ""))
	return area_effect_params


static func build_instant_hit_visual_params(params: Dictionary, definition: Dictionary, radius: float) -> Dictionary:
	var visual_params: Dictionary = {
		"radius": radius,
		"duration": float(params.get("visual_duration", params.get("duration", 0.12))),
	}
	for key: String in ["visual_color", "visual_ring_color"]:
		if params.has(key):
			visual_params[key] = params[key]
		elif definition.has(key):
			visual_params[key] = definition[key]
	return visual_params


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
