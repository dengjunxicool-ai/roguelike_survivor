## Pure presentation: faceted wolf anatomy or hovering crystal. The summon host owns clocks and cues.
extends Node2D

const ICE_SHADER: Shader = preload("res://resources/effects/frost_summon.gdshader")
const DARK: Color = Color(0.11, 0.36, 0.54, 0.87)
const BLUE: Color = Color(0.27, 0.64, 0.84, 0.84)
const PALE: Color = Color(0.62, 0.89, 0.99, 0.87)
const WHITE: Color = Color(0.88, 0.98, 1.0, 0.94)

@export_enum("wolf", "guard") var visual_profile: String = "wolf"

var _age: float = 0.0
var _motion: Vector2 = Vector2.ZERO
var _attack_remaining: float = 0.0
var _gait: float = 0.0
var _facing: Vector2 = Vector2.RIGHT
var _geometry: Node2D
var _body: Node2D
var _head: Node2D
var _jaw: Node2D
var _tail: Node2D
var _legs: Array[Node2D] = []
var _lower_legs: Array[Node2D] = []
var _shards: Array[Node2D] = []
var _halo: Line2D
var _pulse: Line2D
var _snow: GPUParticles2D
var _ice_material: ShaderMaterial

func _ready() -> void:
	_build_visual()
	_update_pose(0.0)

## effect_scale scales authored pixel geometry, independent of legacy texture scale.
func configure_summon(visual: Dictionary) -> void:
	_build_visual()
	_age = 0.0
	_gait = 0.0
	_motion = Vector2.ZERO
	_attack_remaining = 0.0
	_facing = Vector2.RIGHT
	scale = Vector2.ONE * clampf(float(visual.get("effect_scale", 1.0)), 0.25, 3.0)
	_snow.emitting = false
	_update_pose(0.0)
	modulate.a = 1.0

func face_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		_facing = direction.normalized()

func play_attack() -> void:
	_attack_remaining = 0.32

## No autonomous clock: follow, chase, return, attack, pause and expiry use host state.
func update_summon(delta: float, motion: Vector2, remaining: float) -> void:
	var step: float = maxf(delta, 0.0)
	_age += step
	_motion = motion
	_attack_remaining = maxf(_attack_remaining - step, 0.0)
	_gait += minf(motion.length(), 280.0) * step * 0.075
	modulate.a = clampf(remaining / 0.45, 0.0, 1.0)
	_snow.emitting = remaining > 0.0 and (visual_profile == "guard" or motion.length_squared() > 36.0)
	_update_pose(step)

func _build_visual() -> void:
	if is_instance_valid(_geometry):
		return
	_ice_material = ShaderMaterial.new()
	_ice_material.shader = ICE_SHADER
	_geometry = _pivot(self, "Geometry", Vector2.ZERO)
	_geometry.use_parent_material = false
	_geometry.material = _ice_material
	if visual_profile == "guard":
		_build_guard()
	else:
		_build_wolf()
	_build_snow()

func _build_wolf() -> void:
	# Wide, faint ground mark keeps the transparent body separate from the map.
	_halo = _ring(self, "GroundMist", 26.0, 0.28, Color(0.34, 0.76, 0.95, 0.15), 2.5)
	_halo.position.y = 22.0
	_body = _pivot(_geometry, "ArticulatedBody", Vector2.ZERO)
	# Hind/front far-side legs remain visible behind the translucent flank.
	_build_leg("FarHind", Vector2(-17, 0), true, true)
	_build_leg("FarFore", Vector2(13, 0), false, true)
	_tail = _pivot(_body, "Tail", Vector2(-26, -7))
	_polygon(_tail, "TailIce", [Vector2(2, -3), Vector2(-9, -5), Vector2(-24, -17), Vector2(-18, -3), Vector2(-12, 5), Vector2(-3, 4)], BLUE)
	_polygon(_tail, "TailFacet", [Vector2(-24, -17), Vector2(-12, -6), Vector2(-3, 4), Vector2(-12, 5)], PALE)
	_polygon(_body, "Flank", [Vector2(-28, -8), Vector2(-24, -16), Vector2(-8, -17), Vector2(7, -15), Vector2(18, -24), Vector2(23, -17), Vector2(23, -2), Vector2(10, 7), Vector2(-5, 6), Vector2(-16, 2), Vector2(-23, 2)], BLUE)
	_polygon(_body, "FlankShadow", [Vector2(-23, 2), Vector2(-8, -7), Vector2(10, 7), Vector2(-5, 6), Vector2(-16, 2)], DARK)
	_polygon(_body, "BackPlane", [Vector2(-24, -16), Vector2(-8, -17), Vector2(7, -15), Vector2(-8, -7)], PALE)
	_polygon(_body, "ShoulderPlane", [Vector2(-8, -7), Vector2(7, -15), Vector2(18, -24), Vector2(23, -2), Vector2(10, 7)], Color(0.43, 0.77, 0.93, 0.82))
	_polygon(_body, "ChestPlane", [Vector2(18, -24), Vector2(23, -17), Vector2(23, -2), Vector2(17, 2)], PALE)
	# Angular ruff is fur-shaped ice rather than a generic diamond.
	_polygon(_body, "CrystalRuff", [Vector2(17, -25), Vector2(21, -30), Vector2(26, -24), Vector2(29, -14), Vector2(24, -11), Vector2(26, -5), Vector2(19, -10)], PALE)
	_build_leg("NearHind", Vector2(-17, 0), true, false)
	_build_leg("NearFore", Vector2(14, 0), false, false)
	_head = _pivot(_body, "Head", Vector2(22, -24))
	_polygon(_head, "Skull", [Vector2(-4, -7), Vector2(5, -12), Vector2(12, -8), Vector2(14, -3), Vector2(25, 0), Vector2(22, 5), Vector2(12, 8), Vector2(0, 8), Vector2(-4, 1)], BLUE)
	_polygon(_head, "Brow", [Vector2(-4, -7), Vector2(5, -12), Vector2(12, -8), Vector2(14, -3), Vector2(3, -1)], PALE)
	_polygon(_head, "Muzzle", [Vector2(14, -3), Vector2(25, 0), Vector2(22, 5), Vector2(8, 3)], WHITE)
	_polygon(_head, "FarEar", [Vector2(-2, -7), Vector2(-1, -21), Vector2(5, -12)], DARK)
	_polygon(_head, "NearEar", [Vector2(4, -9), Vector2(10, -23), Vector2(14, -8)], PALE)
	_polygon(_head, "EarFacet", [Vector2(7, -10), Vector2(10, -19), Vector2(11, -9)], DARK)
	_polygon(_head, "EyeSocket", [Vector2(10, -6), Vector2(16, -4), Vector2(12, -1), Vector2(9, -2)], DARK)
	_polygon(_head, "EyeGlow", [Vector2(11, -4), Vector2(15, -4), Vector2(12, -2)], WHITE)
	_polygon(_head, "Nose", [Vector2(23, -1), Vector2(26, 0), Vector2(24, 3), Vector2(22, 2)], DARK)
	_jaw = _pivot(_head, "Jaw", Vector2(8, 5))
	_polygon(_jaw, "LowerJaw", [Vector2(0, -1), Vector2(15, -1), Vector2(11, 4), Vector2(0, 3)], PALE)
	_polygon(_jaw, "Fang", [Vector2(9, -1), Vector2(11, -1), Vector2(10, 3)], WHITE)
	_lines(_body, "FlankCracks", [Vector2(-18, -12), Vector2(-8, -7), Vector2(0, -10), Vector2(7, -3), Vector2(17, -1)], Color(0.85, 0.97, 1, 0.55), 0.7)
	_lines(_body, "SpineLight", [Vector2(-23, -15), Vector2(-8, -16), Vector2(7, -14), Vector2(17, -23)], Color(0.84, 0.97, 1, 0.67), 0.9)

func _build_leg(label: String, origin: Vector2, hind: bool, far: bool) -> void:
	var leg: Node2D = _pivot(_body, label, origin + Vector2(0, -2))
	_legs.append(leg)
	var knee: Vector2 = Vector2(-6, 11) if hind else Vector2(1, 11)
	_polygon(leg, "UpperFacet", [Vector2(-4, -5), Vector2(4, -4), knee + Vector2(3, 0), knee + Vector2(-2, 2)], DARK if far else BLUE)
	_polygon(leg, "UpperLight", [Vector2(2, -4), knee + Vector2(3, 0), knee, Vector2(-1, -2)], BLUE if far else PALE)
	var lower: Node2D = _pivot(leg, "LowerLeg", knee)
	_lower_legs.append(lower)
	_polygon(lower, "Shin", [Vector2(-2, 0), Vector2(3, 0), Vector2(2, 10), Vector2(-1, 11)], BLUE if far else PALE)
	_polygon(lower, "Paw", [Vector2(-2, 9), Vector2(3, 9), Vector2(7, 12), Vector2(6, 14), Vector2(-3, 14)], BLUE if far else PALE)
	_lines(lower, "PawClaws", [Vector2(2, 11), Vector2(2, 13), Vector2(5, 13)], WHITE if not far else BLUE, 0.7)

func _build_guard() -> void:
	_halo = _ring(_geometry, "SuspensionHalo", 28.0, 0.38, Color(0.49, 0.87, 1, 0.3), 1.0)
	_halo.position.y = 10
	_body = _pivot(_geometry, "FloatingCore", Vector2(0, -7))
	_polygon(_body, "CoreSilhouette", [Vector2(0, -33), Vector2(14, -13), Vector2(12, 8), Vector2(0, 24), Vector2(-12, 8), Vector2(-14, -13)], BLUE)
	_polygon(_body, "CoreLeft", [Vector2(0, -33), Vector2(-14, -13), Vector2(-12, 8), Vector2(0, 2)], PALE)
	_polygon(_body, "CoreRight", [Vector2(0, -33), Vector2(14, -13), Vector2(12, 8), Vector2(0, 2)], DARK)
	_polygon(_body, "CoreFront", [Vector2(0, -33), Vector2(6, -12), Vector2(0, 2), Vector2(-6, -12)], Color(0.73, 0.94, 1, 0.86))
	_polygon(_body, "CoreLower", [Vector2(-12, 8), Vector2(0, 2), Vector2(0, 24)], BLUE)
	_polygon(_body, "CoreLowerLight", [Vector2(0, 2), Vector2(12, 8), Vector2(0, 24)], PALE)
	_polygon(_body, "Heart", [Vector2(0, -17), Vector2(4, -9), Vector2(0, -3), Vector2(-4, -9)], WHITE)
	_lines(_body, "CoreSeam", [Vector2(0, -30), Vector2(0, 2), Vector2(0, 22)], Color(0.9, 0.99, 1, 0.8), 0.8)
	for i: int in range(6):
		var shard: Node2D = _pivot(_geometry, "OrbitShard%d" % i, Vector2.ZERO)
		_shards.append(shard)
		_polygon(shard, "Shard", [Vector2(0, -9), Vector2(4, -1), Vector2(0, 7), Vector2(-4, -1)], BLUE)
		_polygon(shard, "ShardLight", [Vector2(0, -9), Vector2(0, 7), Vector2(-4, -1)], PALE)
	_pulse = _ring(self, "AttackPulse", 22, 0.45, Color(0.6, 0.94, 1, 0.85), 1.5)
	_pulse.position.y = 8

func _build_snow() -> void:
	_snow = GPUParticles2D.new()
	_snow.name = "CrystalDust"
	_snow.amount = 18 if visual_profile == "wolf" else 24
	_snow.lifetime = 0.65
	_snow.local_coords = false
	_snow.use_fixed_seed = true
	_snow.seed = 7139
	_snow.visibility_rect = Rect2(-120, -120, 240, 240)
	_snow.emitting = false
	var particles: ParticleProcessMaterial = ParticleProcessMaterial.new()
	particles.particle_flag_disable_z = true
	particles.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 18.0
	particles.direction = Vector3(-0.35, -1, 0)
	particles.spread = 38.0
	particles.gravity = Vector3(0, 5, 0)
	particles.initial_velocity_min = 7.0
	particles.initial_velocity_max = 16.0
	particles.scale_min = 0.9
	particles.scale_max = 1.8
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0.7, 0.95, 1, 0), Color(0.75, 0.96, 1, 0.45), Color(0.6, 0.85, 1, 0)])
	gradient.offsets = PackedFloat32Array([0, 0.15, 1])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = gradient
	particles.color_ramp = ramp
	_snow.process_material = particles
	add_child(_snow)

func _update_pose(_step: float) -> void:
	var burst: float = sin(clampf((0.32 - _attack_remaining) / 0.32, 0, 1) * PI) if _attack_remaining > 0 else 0.0
	_ice_material.set_shader_parameter("visual_clock", _age)
	_ice_material.set_shader_parameter("attack_light", burst)
	if visual_profile == "guard":
		_body.position.y = -7.0 + sin(_age * 2.2) * 3.0
		_body.rotation = sin(_age * 0.85) * 0.12
		_body.scale = Vector2.ONE * (1.0 + burst * 0.09)
		for i: int in range(_shards.size()):
			var phase: float = _age * 0.7 + float(i) * TAU / 6.0
			_shards[i].position = Vector2(cos(phase) * (28 + burst * 6), sin(phase) * 12 - 9)
			_shards[i].rotation = sin(phase) * 0.3
			_shards[i].z_index = -1 if sin(phase) < 0 else 1
			_shards[i].scale = Vector2.ONE * (0.75 + (sin(phase) + 1) * 0.12)
		_pulse.modulate.a = burst * 0.65
		_pulse.scale = Vector2.ONE * (1.0 + (1.0 - _attack_remaining / 0.32) * 1.8)
	else:
		var running: float = clampf(_motion.length() / 160.0, 0, 1)
		_geometry.scale.x = -1.0 if _facing.x < -0.08 else 1.0
		_geometry.rotation = _facing.y * 0.13 * _geometry.scale.x
		_body.position = Vector2(burst * 8.0, sin(_gait * 2) * running * 1.5 - burst * 2.0)
		_body.rotation = -burst * 0.07
		for i: int in range(_legs.size()):
			var stride: float = sin(_gait + (PI if i == 0 or i == 3 else 0.0))
			_legs[i].rotation = stride * running * 0.48 - burst * (0.35 if i % 2 == 1 else -0.18)
			_lower_legs[i].rotation = maxf(-stride, 0) * running * 0.58
		_tail.rotation = sin(_age * 3.0) * 0.09 + running * sin(_gait) * 0.1
		_head.rotation = -burst * 0.12 + sin(_age * 1.7) * 0.018
		_jaw.rotation = burst * 0.24

func _pivot(parent: Node, label: String, origin: Vector2) -> Node2D:
	var node: Node2D = Node2D.new()
	node.name = label
	node.position = origin
	node.use_parent_material = true
	parent.add_child(node)
	return node

func _polygon(parent: Node2D, label: String, points: Array[Vector2], tint: Color) -> void:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.name = label
	polygon.polygon = PackedVector2Array(points)
	polygon.color = tint
	polygon.use_parent_material = true
	polygon.antialiased = true
	parent.add_child(polygon)

func _lines(parent: Node2D, label: String, points: Array[Vector2], tint: Color, width: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.name = label
	line.points = PackedVector2Array(points)
	line.default_color = tint
	line.width = width
	line.antialiased = true
	line.use_parent_material = true
	parent.add_child(line)
	return line

func _ring(parent: Node2D, label: String, radius: float, flatten: float, tint: Color, width: float) -> Line2D:
	var points: Array[Vector2] = []
	for i: int in range(49):
		var angle: float = float(i) * TAU / 48
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * flatten))
	return _lines(parent, label, points, tint, width)
