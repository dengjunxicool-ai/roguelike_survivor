extends RefCounted
class_name SkillRangeUnit


const CONFIG_PATH: String = "res://data/skill_system_config.json"
const DEFAULT_RANGE_UNIT_PX: float = 84.0

static var _cached_range_unit_px: float = -1.0


static func get_range_unit_px() -> float:
	if _cached_range_unit_px > 0.0:
		return _cached_range_unit_px
	_cached_range_unit_px = _load_range_unit_px()
	return _cached_range_unit_px


static func clear_cache() -> void:
	_cached_range_unit_px = -1.0


static func resolve_pixels(value: Variant) -> float:
	return float(value) * get_range_unit_px()


static func resolve_action_params(params: Dictionary) -> Dictionary:
	var resolved: Dictionary = params.duplicate(true)
	_resolve_unit_field(resolved, "radius_r", "radius")
	_resolve_unit_field(resolved, "collision_radius_r", "collision_radius")
	_resolve_unit_field(resolved, "area_radius_r", "area_radius")
	_resolve_unit_field(resolved, "range_r", "range")
	_resolve_unit_field(resolved, "detect_range_r", "detect_range")
	_resolve_unit_field(resolved, "cluster_radius_r", "cluster_radius")
	_resolve_unit_field(resolved, "length_r", "length")
	_resolve_unit_field(resolved, "width_r", "width")
	_resolve_unit_field(resolved, "pull_radius_r", "radius")
	_resolve_unit_field(resolved, "spawn_offset_r", "spawn_offset")
	_resolve_unit_field(resolved, "position_offset_distance_r", "position_offset_distance")
	_resolve_unit_field(resolved, "orbit_radius_r", "orbit_radius")
	_resolve_unit_field(resolved, "pulse_radius_r", "pulse_radius")
	_resolve_unit_field(resolved, "attack_range_r", "attack_range")
	_resolve_unit_field(resolved, "expand_from_radius_r", "expand_from_radius")
	_resolve_unit_field(resolved, "expand_to_radius_r", "expand_to_radius")
	return resolved


static func display_radius(effect: Dictionary, key: String = "radius") -> float:
	if effect.has("%s_r" % key):
		return resolve_pixels(effect.get("%s_r" % key))
	if key == "radius" and effect.has("radius_r"):
		return resolve_pixels(effect.get("radius_r"))
	return float(effect.get(key, 0.0))


static func _resolve_unit_field(params: Dictionary, source_key: String, target_key: String) -> void:
	if not params.has(source_key):
		return
	if params.has(target_key):
		return
	params[target_key] = resolve_pixels(params[source_key])


static func _load_range_unit_px() -> float:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return DEFAULT_RANGE_UNIT_PX
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var config: Dictionary = parsed
		var configured: float = float(config.get("range_unit_px", DEFAULT_RANGE_UNIT_PX))
		if configured > 0.0:
			return configured
	return DEFAULT_RANGE_UNIT_PX
