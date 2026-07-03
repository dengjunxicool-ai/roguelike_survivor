extends Node2D
class_name InstantAreaHitVisual


const POOL_KEY_META: StringName = &"runtime_pool_key"
const POOL_OWNER_META: StringName = &"runtime_pool_owner"

var _age: float = 0.0
var _duration: float = 0.12
var _radius: float = 48.0
var _visual_color: Color = Color(0.7, 0.2, 1.0, 0.32)
var _visual_ring_color: Color = Color(0.3, 1.0, 0.9, 0.72)


func setup(params: Dictionary) -> void:
	_age = 0.0
	_duration = maxf(float(params.get("duration", 0.12)), 0.05)
	_radius = maxf(float(params.get("radius", 48.0)), 1.0)
	_visual_color = _get_color(params.get("visual_color", _visual_color), _visual_color)
	_visual_ring_color = _get_color(params.get("visual_ring_color", _visual_ring_color), _visual_ring_color)
	visible = true
	set_process(true)
	queue_redraw()


func prepare_for_pool_spawn(params: Dictionary) -> void:
	setup(params)


func prepare_for_pool_despawn() -> void:
	visible = false
	set_process(false)


func despawn_or_free() -> void:
	if has_meta(POOL_OWNER_META) and has_meta(POOL_KEY_META):
		var pool_variant: Variant = get_meta(POOL_OWNER_META)
		var key: StringName = StringName(String(get_meta(POOL_KEY_META)))
		if pool_variant is Node and is_instance_valid(pool_variant) and (pool_variant as Node).has_method("despawn"):
			prepare_for_pool_despawn()
			(pool_variant as Node).call("despawn", key, self)
			return
	queue_free()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		despawn_or_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / maxf(_duration, 0.05), 0.0, 1.0)
	var fade: float = 1.0 - progress
	var pulse: float = 1.0 + sin(progress * PI) * 0.08
	draw_circle(Vector2.ZERO, _radius * pulse, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_arc(Vector2.ZERO, _radius * (0.92 + pulse * 0.04), 0.0, TAU, 48, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.5, true)


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			var alpha: float = float(items[3]) if items.size() > 3 else fallback.a
			return Color(float(items[0]), float(items[1]), float(items[2]), alpha)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return fallback
