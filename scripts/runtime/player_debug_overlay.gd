extends Node2D
class_name PlayerDebugOverlay


const RING_SEGMENTS: int = 96
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")

@export var enabled_in_debug_builds: bool = true
@export var pickup_color: Color = Color(0.25, 0.85, 1.0, 0.75)
@export var targeting_color: Color = Color(1.0, 0.72, 0.2, 0.75)
@export var orbit_color: Color = Color(0.95, 0.28, 0.22, 0.85)
@export var hitbox_color: Color = Color(1.0, 0.18, 0.18, 0.45)

var _player: Node


func _ready() -> void:
	_player = get_parent()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1000


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if _player == null:
		return

	_draw_pickup_radius()
	_draw_skill_ranges()


func _draw_pickup_radius() -> void:
	var pickup_radius: float = _get_effective_pickup_radius()
	if pickup_radius <= 0.0:
		return

	_draw_ring(Vector2.ZERO, pickup_radius, pickup_color, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(pickup_radius + 8.0, -4.0), "pickup %.0f" % pickup_radius, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, pickup_color)


func _draw_skill_ranges() -> void:
	var skill_manager: Node = _player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return

	var skill_instances_variant: Variant = skill_manager.call("get_all_skills")
	if not (skill_instances_variant is Array):
		return

	for skill_instance_variant: Variant in skill_instances_variant:
		var skill_instance: RefCounted = skill_instance_variant as RefCounted
		if skill_instance == null:
			continue

		var definition: RefCounted = skill_instance.get("definition") as RefCounted
		if definition == null:
			continue

		var skill_id: String = str(skill_instance.get("skill_id"))
		if _definition_has_tag(definition, "projectile"):
			_draw_projectile_skill_range(skill_instance, skill_id)
		elif _definition_has_tag(definition, "orbit"):
			_draw_orbit_skill_range(skill_instance, skill_id)
		elif _definition_has_tag(definition, "area"):
			_draw_area_skill_range(skill_instance, skill_id)


func _draw_projectile_skill_range(skill_instance: RefCounted, skill_id: String) -> void:
	var target_range: float = _get_skill_float(skill_instance, "range", 0.0)
	if target_range > 0.0:
		_draw_ring(Vector2.ZERO, target_range, targeting_color, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(target_range + 8.0, -18.0), "%s range %.0f" % [skill_id, target_range], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, targeting_color)

	var area_radius: float = _get_skill_float(skill_instance, "area_radius", 0.0)
	if area_radius > 0.0:
		_draw_ring(Vector2.ZERO, area_radius, hitbox_color, 1.0)


func _draw_area_skill_range(skill_instance: RefCounted, skill_id: String) -> void:
	var area_radius: float = _get_skill_float(skill_instance, "area_radius", 0.0)
	if area_radius <= 0.0:
		return

	_draw_ring(Vector2.ZERO, area_radius, hitbox_color, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(area_radius + 8.0, 14.0), "%s area %.0f" % [skill_id, area_radius], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, hitbox_color)


func _draw_orbit_skill_range(skill_instance: RefCounted, skill_id: String) -> void:
	var orbit_radius: float = _get_skill_float(skill_instance, "orbit_radius", 0.0)
	var area_radius: float = _get_skill_float(skill_instance, "area_radius", 0.0)
	if orbit_radius <= 0.0:
		return

	_draw_ring(Vector2.ZERO, orbit_radius, orbit_color, 2.0)
	if area_radius > 0.0:
		_draw_ring(Vector2.ZERO, maxf(orbit_radius - area_radius, 1.0), hitbox_color, 1.0)
		_draw_ring(Vector2.ZERO, orbit_radius + area_radius, hitbox_color, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(orbit_radius + 8.0, 14.0), "%s orbit %.0f hit %.0f" % [skill_id, orbit_radius, area_radius], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, orbit_color)


func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	if radius <= 0.0:
		return

	draw_arc(center, radius, 0.0, TAU, RING_SEGMENTS, color, width, true)


func _get_node_float(node: Node, property_name: String, default_value: float) -> float:
	var value: Variant = node.get(property_name)
	if value == null:
		return default_value

	return float(value)


func _get_effective_pickup_radius() -> float:
	if _player == null:
		return 0.0
	if _player.has_method("get_effective_pickup_radius"):
		return float(_player.call("get_effective_pickup_radius"))
	return _get_node_float(_player, "pickup_radius", 0.0)


func _get_skill_float(skill_instance: RefCounted, stat_name: String, default_value: float) -> float:
	var skill_manager: Node = _player.get_node_or_null("SkillManager") if _player != null else null
	var relic_manager: Node = _player.get_node_or_null("RelicManager") if _player != null else null
	var value: Variant = SkillStatServiceScript.get_effective_stat(skill_instance, stat_name, default_value, skill_manager, relic_manager, _player)
	if value == null:
		return default_value

	return float(value)


func _definition_has_tag(definition: RefCounted, tag: String) -> bool:
	return definition != null and definition.has_method("has_tag") and bool(definition.call("has_tag", tag))
