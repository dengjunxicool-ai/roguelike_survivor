extends Node2D
class_name FireTornadoEffect

@export_range(0.1, 30.0, 0.1, "or_greater") var lifetime: float = 3.2
@export_range(0.1, 10.0, 0.1, "or_greater") var fade_out_time: float = 0.75
@export_range(0.1, 20.0, 0.1, "or_greater") var spin_speed: float = 5.8
@export_range(1.0, 220.0, 1.0, "or_greater") var base_radius: float = 50.0
@export_range(1.0, 220.0, 1.0, "or_greater") var column_height: float = 126.0

var _age: float = 0.0
var _base_modulate: Color = Color.WHITE

@onready var _heat_core: Node2D = get_node_or_null("HeatCore") as Node2D
@onready var _base_fire_ring: GPUParticles2D = get_node_or_null("BaseFireRing") as GPUParticles2D
@onready var _spiral_a: GPUParticles2D = get_node_or_null("SpiralEmitterA") as GPUParticles2D
@onready var _spiral_b: GPUParticles2D = get_node_or_null("SpiralEmitterB") as GPUParticles2D
@onready var _ember_spray: GPUParticles2D = get_node_or_null("EmberSpray") as GPUParticles2D
@onready var _smoke_wisps: GPUParticles2D = get_node_or_null("SmokeWisps") as GPUParticles2D
@onready var _outer_embers: GPUParticles2D = get_node_or_null("OuterEmbers") as GPUParticles2D


func _ready() -> void:
	_base_modulate = modulate
	_warn_missing_children()
	_configure_particle_emitters()
	_restart_particles()
	set_process(true)
	queue_redraw()


func _configure_particle_emitters() -> void:
	_configure_particles(_base_fire_ring, {
		"amount": 170,
		"lifetime": 0.95,
		"color": Color(1.0, 0.18, 0.025, 0.72),
		"velocity_min": 24.0,
		"velocity_max": 112.0,
		"spread": 360.0,
		"emission_radius": base_radius * 0.42,
		"gravity": Vector2(0.0, -28.0),
		"scale_min": 1.0,
		"scale_max": 3.2,
	})
	_configure_particles(_spiral_a, {
		"amount": 108,
		"lifetime": 0.92,
		"color": Color(1.0, 0.24, 0.035, 0.62),
		"velocity_min": 20.0,
		"velocity_max": 76.0,
		"spread": 28.0,
		"emission_radius": base_radius * 0.10,
		"gravity": Vector2(0.0, -34.0),
		"scale_min": 1.1,
		"scale_max": 3.2,
	})
	_configure_particles(_spiral_b, {
		"amount": 96,
		"lifetime": 0.88,
		"color": Color(1.0, 0.52, 0.11, 0.46),
		"velocity_min": 18.0,
		"velocity_max": 68.0,
		"spread": 32.0,
		"emission_radius": base_radius * 0.08,
		"gravity": Vector2(0.0, -30.0),
		"scale_min": 0.9,
		"scale_max": 2.6,
	})
	_configure_particles(_ember_spray, {
		"amount": 155,
		"lifetime": 1.35,
		"color": Color(1.0, 0.34, 0.055, 0.68),
		"velocity_min": 58.0,
		"velocity_max": 176.0,
		"spread": 360.0,
		"emission_radius": base_radius * 0.28,
		"gravity": Vector2(0.0, 20.0),
		"scale_min": 0.55,
		"scale_max": 1.9,
	})
	_configure_particles(_smoke_wisps, {
		"amount": 92,
		"lifetime": 1.85,
		"color": Color(0.06, 0.035, 0.028, 0.36),
		"velocity_min": 8.0,
		"velocity_max": 42.0,
		"spread": 360.0,
		"emission_radius": base_radius * 0.58,
		"gravity": Vector2(0.0, -12.0),
		"scale_min": 7.0,
		"scale_max": 15.0,
	})
	_configure_particles(_outer_embers, {
		"amount": 128,
		"lifetime": 1.55,
		"color": Color(1.0, 0.21, 0.035, 0.46),
		"velocity_min": 42.0,
		"velocity_max": 132.0,
		"spread": 360.0,
		"emission_radius": base_radius * 0.72,
		"gravity": Vector2(0.0, -8.0),
		"scale_min": 0.45,
		"scale_max": 1.55,
	})


func _process(delta: float) -> void:
	_age += delta
	_update_spiral_emitters(_age)
	_update_fade()
	queue_redraw()
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	var fade: float = _get_fade_alpha()
	var loop_alpha: float = _get_gif_loop_alpha()
	var dissolve: float = _get_dissolve_alpha()
	_draw_dissolve_ash_cloud(fade)
	_draw_smoke_wisps(fade)
	_draw_tornado_body(fade * loop_alpha)
	_draw_smooth_fire_column(fade * loop_alpha)
	_draw_spiral_fire_ribbons(fade * loop_alpha)
	_draw_gif_base_ember_ring(fade)
	_draw_base_eruption(fade * (0.38 + loop_alpha * 0.62))
	_draw_ember_streaks(fade * (0.48 + dissolve * 0.85))


func _get_growth_alpha() -> float:
	return smoothstep(0.0, 0.22, _get_life_progress())


func _get_dissolve_alpha() -> float:
	return smoothstep(0.72, 1.0, _get_life_progress())


func _get_gif_loop_alpha() -> float:
	return _get_growth_alpha() * (1.0 - _get_dissolve_alpha() * 0.82)


func _get_life_progress() -> float:
	return clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)


func _draw_tornado_body(fade: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 5.4)
	for level: int in range(12):
		var t: float = float(level) / 11.0
		var center: Vector2 = _column_center(t, _age)
		var radius: float = _column_radius(t, pulse)
		var outer_color: Color = Color(0.11, 0.030, 0.018, (0.20 - t * 0.065) * fade)
		var mid_color: Color = Color(0.58, 0.095 + t * 0.06, 0.018, (0.11 - t * 0.028) * fade)
		var hot_color: Color = Color(1.0, 0.52, 0.10, (0.055 - t * 0.014) * fade)
		_draw_filled_ellipse(center, Vector2(radius * 0.92, radius * 0.24), outer_color)
		_draw_filled_ellipse(center + Vector2(0.0, -2.0), Vector2(radius * 0.52, radius * 0.14), mid_color)
		if level % 2 == 0:
			_draw_filled_ellipse(center + Vector2(sin(_age * 3.0 + t * TAU) * radius * 0.10, -1.0), Vector2(radius * 0.20, radius * 0.06), hot_color)


func _draw_smooth_fire_column(fade: float) -> void:
	for ribbon_index: int in range(5):
		var phase: float = float(ribbon_index) * TAU / 5.0
		var points: PackedVector2Array = PackedVector2Array()
		for segment: int in range(54):
			var t: float = float(segment) / 53.0
			var twist: float = _age * (2.15 + float(ribbon_index) * 0.08) + t * TAU * 2.72 + phase
			var center: Vector2 = _column_center(t, _age * 0.92)
			var radius: float = _column_radius(t, 0.12) * (0.42 + 0.08 * sin(_age * 2.4 + t * TAU + phase))
			points.append(center + Vector2(cos(twist) * radius, sin(twist) * radius * 0.30))
		var alpha: float = (0.18 + float(ribbon_index % 2) * 0.04) * fade
		draw_polyline(points, Color(0.24, 0.035, 0.010, alpha), 5.4, true)
		draw_polyline(points, Color(1.0, 0.18, 0.025, alpha * 1.8), 2.7, true)
		draw_polyline(points, Color(1.0, 0.58, 0.12, alpha * 1.10), 1.1, true)


func _draw_spiral_fire_ribbons(fade: float) -> void:
	for ribbon_index: int in range(4):
		var points: PackedVector2Array = PackedVector2Array()
		var phase: float = float(ribbon_index) * TAU / 4.0
		for segment: int in range(48):
			var t: float = float(segment) / 47.0
			var twist: float = _age * (2.25 + float(ribbon_index) * 0.10) + t * TAU * (2.45 + float(ribbon_index % 2) * 0.18) + phase
			var center: Vector2 = _column_center(t, _age)
			var radius: float = _column_radius(t, 0.18) * (0.58 + 0.10 * sin(_age * 2.4 + t * TAU + phase))
			points.append(center + Vector2(cos(twist) * radius, sin(twist) * radius * 0.34))
		var intensity: float = 0.70 + 0.30 * sin(_age * 3.8 + phase)
		draw_polyline(points, Color(0.20, 0.035, 0.012, 0.28 * fade), 6.4, true)
		draw_polyline(points, Color(1.0, 0.18, 0.025, 0.42 * fade), 3.0, true)
		draw_polyline(points, Color(1.0, 0.58, 0.12, intensity * 0.46 * fade), 1.2, true)


func _draw_gif_base_ember_ring(fade: float) -> void:
	var growth: float = _get_growth_alpha()
	var dissolve: float = _get_dissolve_alpha()
	var pulse: float = 0.5 + 0.5 * sin(_age * 8.4)
	var alpha: float = fade * (0.22 + growth * 0.54 + dissolve * 0.32)
	draw_arc(Vector2.ZERO, base_radius * (0.98 + pulse * 0.05), PI * 0.02, PI * 0.98, 96, Color(1.0, 0.18, 0.025, 0.64 * alpha), 2.5, true)
	draw_arc(Vector2.ZERO, base_radius * (0.70 + pulse * 0.07), PI * 0.12, PI * 0.88, 80, Color(1.0, 0.60, 0.12, 0.34 * alpha), 1.1, true)
	for index: int in range(26):
		var angle: float = PI + float(index) * PI / 25.0 + sin(_age * 4.0 + float(index)) * 0.035
		var inner: float = base_radius * (0.20 + float(index % 5) * 0.025)
		var outer: float = base_radius * (0.66 + pulse * 0.08 + float(index % 4) * 0.025)
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * inner
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * outer
		draw_line(start, end, Color(1.0, 0.25, 0.035, 0.22 * alpha), 0.8, true)


func _draw_base_eruption(fade: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 8.6)
	_draw_filled_ellipse(Vector2.ZERO, Vector2(base_radius * (0.72 + pulse * 0.05), base_radius * (0.72 + pulse * 0.05)), Color(1.0, 0.12, 0.012, 0.12 * fade))
	draw_arc(Vector2.ZERO, base_radius * (0.92 + pulse * 0.04), PI * 0.04, PI * 0.96, 80, Color(1.0, 0.27, 0.035, 0.34 * fade), 2.1, true)
	draw_arc(Vector2.ZERO, base_radius * (0.60 + pulse * 0.06), PI * 0.12, PI * 0.88, 72, Color(1.0, 0.58, 0.12, 0.25 * fade), 1.1, true)
	for index: int in range(16):
		var angle: float = PI + float(index) * PI / 15.0 + sin(_age * 5.2 + float(index)) * 0.08
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * base_radius * 0.30
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * base_radius * (0.64 + float(index % 3) * 0.07)
		draw_line(start, end, Color(1.0, 0.34, 0.055, 0.28 * fade), 0.9, true)


func _draw_smoke_wisps(fade: float) -> void:
	var dissolve: float = _get_dissolve_alpha()
	for index: int in range(12):
		var t: float = float(index) / 11.0
		var center: Vector2 = _column_center(t, _age * 0.62)
		var drift: float = sin(_age * 0.95 + float(index) * 1.7) * base_radius * (0.42 + t * 0.34 + dissolve * 0.16)
		var radius: float = _column_radius(t, 0.1) * (1.10 + 0.24 * sin(_age * 0.8 + float(index)))
		_draw_filled_ellipse(center + Vector2(drift, 0.0), Vector2(radius * 0.82, radius * 0.22), Color(0.015, 0.010, 0.006, (0.085 + dissolve * 0.05) * fade))


func _draw_dissolve_ash_cloud(fade: float) -> void:
	var dissolve: float = _get_dissolve_alpha()
	var growth: float = _get_growth_alpha()
	var veil_alpha: float = fade * (0.10 + dissolve * 0.18 + (1.0 - growth) * 0.12)
	_draw_filled_ellipse(Vector2(0.0, -column_height * 0.42), Vector2(base_radius * 1.20, column_height * 0.34), Color(0.015, 0.010, 0.006, veil_alpha))
	if dissolve <= 0.0:
		return
	for index: int in range(18):
		var t: float = float(index) / 17.0
		var angle: float = _age * 1.3 + float(index) * 2.399
		var center: Vector2 = _column_center(t, _age * 0.45)
		var radius: float = _column_radius(t, 0.0) * (0.72 + dissolve * 0.46)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.36) * radius
		_draw_filled_ellipse(pos, Vector2(5.0 + dissolve * 7.0, 2.0 + dissolve * 3.0), Color(0.05, 0.028, 0.018, 0.08 * dissolve * fade))


func _draw_ember_streaks(fade: float) -> void:
	for index: int in range(28):
		var t: float = fposmod(_age * (0.16 + float(index % 5) * 0.020) + float(index) * 0.071, 1.0)
		var angle: float = _age * 1.72 + float(index) * 2.399
		var center: Vector2 = _column_center(t, _age)
		var radius: float = _column_radius(t, 0.0) * (0.88 + float(index % 4) * 0.08)
		var start: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.38) * radius
		var end: Vector2 = start + Vector2(cos(angle + 0.45), sin(angle + 0.45)) * (7.0 + float(index % 5) * 2.4)
		var alpha: float = (0.14 + float(index % 3) * 0.04) * fade
		draw_line(start, end, Color(1.0, 0.28, 0.045, alpha), 0.8, true)


func _configure_particles(particles: GPUParticles2D, config: Dictionary) -> void:
	if particles == null:
		return
	particles.emitting = false
	particles.amount = config["amount"]
	particles.lifetime = config["lifetime"]
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.72
	particles.local_coords = true
	particles.scale = config.get("node_scale", Vector2.ONE)
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = float(config.get("emission_radius", base_radius * 0.16))
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = config["spread"]
	var gravity: Vector2 = config.get("gravity", Vector2(0.0, -18.0))
	material.gravity = Vector3(gravity.x, gravity.y, 0.0)
	material.initial_velocity_min = config["velocity_min"]
	material.initial_velocity_max = config["velocity_max"]
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.scale_min = float(config.get("scale_min", 1.8))
	material.scale_max = float(config.get("scale_max", 4.8))
	material.color = config["color"]
	particles.process_material = material


func _restart_particles() -> void:
	for particles: GPUParticles2D in _get_emitters():
		if particles == null:
			continue
		particles.restart()
		particles.emitting = true


func _update_spiral_emitters(age: float) -> void:
	_position_spiral_emitter(_spiral_a, age, 0.0)
	_position_spiral_emitter(_spiral_b, age, PI)
	if _ember_spray != null:
		_ember_spray.scale = Vector2.ONE
		_ember_spray.rotation = age * spin_speed * 0.55
	if _smoke_wisps != null:
		_smoke_wisps.position = Vector2(sin(age * 0.65) * base_radius * 0.18, -column_height * 0.42)
		_smoke_wisps.scale = Vector2.ONE
		_smoke_wisps.rotation = age * spin_speed * 0.08
	if _outer_embers != null:
		_outer_embers.scale = Vector2.ONE
		_outer_embers.rotation = -age * spin_speed * 0.18


func _position_spiral_emitter(particles: GPUParticles2D, age: float, phase: float) -> void:
	if particles == null:
		return
	var cycle: float = fposmod(age * 0.64 + phase / TAU, 1.0)
	var angle: float = age * spin_speed + phase
	var radius: float = lerpf(base_radius * 0.42, base_radius * 0.14, cycle)
	particles.position = Vector2(cos(angle), sin(angle) * 0.38) * radius + Vector2(0.0, -column_height * cycle)
	particles.scale = Vector2.ONE
	particles.rotation = angle + PI * 0.5


func _update_fade() -> void:
	var fade: float = _get_fade_alpha()
	modulate = _base_modulate
	for particles: GPUParticles2D in _get_emitters():
		if particles != null:
			particles.modulate = Color(1.0, 1.0, 1.0, fade)
	if _heat_core != null:
		_heat_core.modulate = Color(1.0, 1.0, 1.0, fade)


func _get_fade_alpha() -> float:
	if fade_out_time <= 0.0:
		return 1.0
	var remaining: float = lifetime - _age
	if remaining >= fade_out_time:
		return 1.0
	return clampf(remaining / fade_out_time, 0.0, 1.0)


func _warn_missing_children() -> void:
	_warn_missing_child(_heat_core, "HeatCore", "Node2D")
	_warn_missing_child(_base_fire_ring, "BaseFireRing", "GPUParticles2D")
	_warn_missing_child(_spiral_a, "SpiralEmitterA", "GPUParticles2D")
	_warn_missing_child(_spiral_b, "SpiralEmitterB", "GPUParticles2D")
	_warn_missing_child(_ember_spray, "EmberSpray", "GPUParticles2D")
	_warn_missing_child(_smoke_wisps, "SmokeWisps", "GPUParticles2D")
	_warn_missing_child(_outer_embers, "OuterEmbers", "GPUParticles2D")


func _warn_missing_child(node: Node, child_name: String, expected_type: String) -> void:
	if node == null:
		push_warning("FireTornadoEffect is missing expected child '%s' (%s)." % [child_name, expected_type])


func _get_emitters() -> Array[GPUParticles2D]:
	return [_base_fire_ring, _spiral_a, _spiral_b, _ember_spray, _smoke_wisps, _outer_embers]


func _column_center(t: float, time: float) -> Vector2:
	var sway: float = sin(time * 0.95 + t * TAU * 1.32) * base_radius * (0.055 + t * 0.085)
	return Vector2(sway, -column_height * t)


func _column_radius(t: float, pulse: float) -> float:
	var waist: float = 1.0 - 0.38 * sin(clampf(t, 0.0, 1.0) * PI)
	var base_bloom: float = 0.26 * (1.0 - smoothstep(0.0, 0.26, t))
	var top_bloom: float = 0.18 * smoothstep(0.68, 1.0, t)
	return base_radius * (0.28 + waist * 0.34 + base_bloom + top_bloom) * (0.97 + pulse * 0.04)


func _draw_filled_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(center, radius, 40), color)


func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(segments):
		var angle: float = float(index) * TAU / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
