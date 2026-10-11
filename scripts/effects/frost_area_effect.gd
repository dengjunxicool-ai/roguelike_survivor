## 寒霜范围表现：宿主拥有半径和寿命，本节点仅绘制霜纹、冰晶和 GPU 雪尘。
extends Node2D

@export_enum("Field", "Path", "Ring", "Shatter", "AbsoluteZero") var profile: int = 0
const FrostShader = preload("res://resources/effects/frost_area.gdshader")
const ParticleShader = preload("res://resources/effects/blizzard_particle.gdshader")
var effect_radius := 100.0
var effect_duration := 3.0
var effect_age := 0.0
var _phase := 0.0
var _geometry_transient := false
var _surface: Polygon2D
var _material: ShaderMaterial
var _dust: GPUParticles2D

func _ready() -> void:
	_ensure_visuals()

func _ensure_visuals() -> void:
	if _surface != null:
		return
	_surface = Polygon2D.new()
	_surface.name = "FrostSurface"
	_surface.polygon = PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
	_material = ShaderMaterial.new()
	_material.shader = FrostShader
	_material.set_shader_parameter("profile", profile)
	_surface.material = _material
	add_child(_surface)
	if profile in [0, 1, 4]:
		_build_dust()

func configure(radius: float, duration: float, visual_phase: float) -> void:
	_ensure_visuals()
	visible = true
	effect_duration = maxf(duration, 0.05)
	effect_age = 0.0
	_phase = visual_phase
	_material.set_shader_parameter("phase", visual_phase)
	set_effect_radius(radius)
	if _dust != null:
		_dust.modulate.a = 1.0
		_dust.seed = absi(int(visual_phase * 104729.0)) + 1
		_dust.restart(true)
		_dust.emitting = duration > 0.4
	update_state(radius, 0.0, duration)

func update_state(radius: float, age: float, duration: float) -> void:
	if not visible:
		return
	if not is_equal_approx(radius, effect_radius):
		set_effect_radius(radius)
	effect_age = maxf(age, 0.0)
	effect_duration = maxf(duration, 0.05)
	var progress := clampf(effect_age / effect_duration, 0.0, 1.0)
	var transient := profile in [2, 3] or effect_duration < 0.4
	var fade_in := smoothstep(0.0, minf(0.24, effect_duration * 0.16), effect_age)
	var fade_out := smoothstep(0.0, minf(0.55, effect_duration * (0.65 if transient else 0.3)), effect_duration - effect_age)
	modulate.a = fade_in * fade_out
	_material.set_shader_parameter("effect_age", effect_age)
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("transient", transient)
	_material.set_shader_parameter("wide_front", effect_radius > 500.0)
	if _dust != null:
		_dust.emitting = not transient and effect_duration - effect_age > 0.3
	# Persistent ice geometry is static: only uniforms/opacity advance each tick.
	# Rebuilding its polygons every frame would upload identical meshes repeatedly.
	if transient or transient != _geometry_transient:
		queue_redraw()
	_geometry_transient = transient

func set_effect_radius(radius: float) -> void:
	effect_radius = maxf(radius, 1.0)
	if _surface != null:
		_surface.scale = Vector2.ONE * effect_radius * 1.06
	if _dust != null:
		var process_material: ParticleProcessMaterial = _dust.process_material
		process_material.emission_sphere_radius = effect_radius * 0.82
		_dust.visibility_rect = Rect2(Vector2.ONE * -effect_radius * 1.25, Vector2.ONE * effect_radius * 2.5)
	queue_redraw()

func deactivate() -> void:
	visible = false
	if _dust != null:
		_dust.emitting = false
		_dust.modulate.a = 0.0

func _draw() -> void:
	if not visible or effect_radius > 500.0:
		return
	var t := clampf(effect_age / effect_duration, 0.0, 1.0)
	var transient := profile in [2, 3] or effect_duration < 0.4
	var travel := lerpf(0.2, 0.93, ease(minf(t / 0.45, 1.0), 0.55)) if transient else 0.87
	var count := 18 if profile == 1 else 24
	for index: int in range(count):
		var angle := float(index) * TAU / count + _phase * 0.1
		var axis := Vector2.from_angle(angle)
		var tangent := axis.orthogonal()
		var ripple := sin(float(index) * 7.7 + _phase) * 0.5 + 0.5
		var length := minf(effect_radius * 0.19, 24.0) * (0.45 + ripple)
		var base := axis * effect_radius * travel
		var tip := base + axis * length
		var left := base - tangent * length * 0.24
		var right := base + tangent * length * 0.24
		draw_colored_polygon(PackedVector2Array([left, tip, base]), Color(0.35,0.72,0.94,0.35 if profile == 1 else 0.65))
		draw_colored_polygon(PackedVector2Array([base, tip, right]), Color(0.8,0.97,1.0,0.4 if profile == 1 else 0.86))
		draw_line(left, tip, Color(0.89,0.99,1.0,0.6), 1.0, true)
		if profile == 3:
			draw_line(axis * effect_radius * t * 0.4, base, Color(0.68,0.91,1.0,0.3), 1.2, true)

func _build_dust() -> void:
	_dust = GPUParticles2D.new()
	_dust.name = "FrostDust"
	_dust.amount = 24 if profile == 1 else 48
	_dust.lifetime = 1.1
	_dust.local_coords = true
	_dust.use_fixed_seed = true
	_dust.fixed_fps = 30
	_dust.interpolate = true
	_dust.preprocess = 0.35
	var texture := GradientTexture2D.new()
	texture.width = 12
	texture.height = 12
	_dust.texture = texture
	var shader_material := ShaderMaterial.new()
	shader_material.shader = ParticleShader
	shader_material.set_shader_parameter("particle_style", 0)
	_dust.material = shader_material
	var process_material := ParticleProcessMaterial.new()
	process_material.particle_flag_disable_z = true
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.gravity = Vector3(8, -12, 0)
	process_material.direction = Vector3(1, -1, 0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 5.0
	process_material.initial_velocity_max = 18.0
	process_material.scale_min = 0.18
	process_material.scale_max = 0.45
	process_material.color = Color(0.8,0.96,1,0.6)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.2,0.75,1])
	gradient.colors = PackedColorArray([Color(1,1,1,0),Color.WHITE,Color.WHITE,Color(1,1,1,0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process_material.color_ramp = ramp
	_dust.process_material = process_material
	_dust.modulate.a = 1.0
	add_child(_dust)
