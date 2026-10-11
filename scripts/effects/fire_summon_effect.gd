## Presentation only. Managed hosts provide delta; generic foxes opt into a pausable child clock.
extends Node2D

const FIRE_SHADER: Shader = preload("res://resources/effects/fire_summon.gdshader")
const RED: Color = Color(0.75, 0.065, 0.035)
const DARK: Color = Color(0.25, 0.025, 0.035)
const ORANGE: Color = Color(1.0, 0.29, 0.035)
const GOLD: Color = Color(1.0, 0.72, 0.20)
@export_enum("dragon", "fox") var visual_profile: String = "dragon"
var _age: float = 0.0
var _attack_remaining: float = 0.0
var _facing: Vector2 = Vector2.RIGHT
var _target_offset: Vector2 = Vector2.ZERO
var _motion: Vector2 = Vector2.ZERO
var _autonomous: bool = false
var _remaining: float = 0.0
var _geometry: Node2D
var _body: Node2D
var _head: Node2D
var _tail: Node2D
var _wings: Array[Node2D] = []
var _legs: Array[Node2D] = []
var _embers: Array[Polygon2D] = []
var _breath: Array[Line2D] = []
var _impact: Node2D
var _impact_ring: Line2D
var _fire_material: ShaderMaterial

func _ready() -> void:
	_build_visual()
	_update_pose()

func configure_summon(visual: Dictionary) -> void:
	_build_visual()
	_age = 0.0
	_attack_remaining = 0.0
	_facing = Vector2.RIGHT
	_target_offset = Vector2.ZERO
	_motion = Vector2.ZERO
	_autonomous = bool(visual.get("autonomous_visual_clock", false))
	_remaining = maxf(float(visual.get("duration", 5.0)), 0.0)
	scale = Vector2.ONE * clampf(float(visual.get("effect_scale", 1.0)), 0.25, 3.0)
	visible = true
	modulate.a = 1.0
	set_process(_autonomous)
	_update_pose()

func _process(delta: float) -> void:
	if _autonomous:
		_remaining = maxf(_remaining - delta, 0.0)
		update_summon(delta, Vector2.ZERO, _remaining)

func face_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		_facing = direction.normalized()

## Offset is measured from the actual host, in world pixels. No target lookup or damage here.
func set_attack_target(offset: Vector2) -> void:
	_target_offset = offset.limit_length(336.0) if visual_profile == "dragon" else offset
	face_direction(offset)

func play_attack() -> void:
	_attack_remaining = 0.38
	_update_pose()

func update_summon(delta: float, motion: Vector2, remaining: float) -> void:
	_age += maxf(delta, 0.0)
	_motion = motion
	_attack_remaining = maxf(_attack_remaining - maxf(delta, 0.0), 0.0)
	modulate.a = clampf(remaining / 0.4, 0.0, 1.0)
	_update_pose()

func deactivate() -> void:
	_attack_remaining = 0.0
	_autonomous = false
	set_process(false)
	visible = false
	_update_pose()

func _build_visual() -> void:
	if is_instance_valid(_geometry):
		return
	_fire_material = ShaderMaterial.new()
	_fire_material.shader = FIRE_SHADER
	_geometry = _pivot(self, "Geometry", Vector2.ZERO)
	_geometry.material = _fire_material
	_geometry.use_parent_material = false
	_body = _pivot(_geometry, "Body", Vector2.ZERO)
	if visual_profile == "dragon":
		_build_dragon()
	else:
		_build_fox()
	for i: int in range(12):
		var ember: Polygon2D = _polygon(self, "Ember%d" % i, [Vector2(0,-2), Vector2(1,0), Vector2(0,2), Vector2(-1,0)], GOLD)
		_embers.append(ember)
	_impact = _pivot(self, "ConfirmedImpact", Vector2.ZERO)
	var ring_points: Array[Vector2] = []
	for i: int in range(25):
		ring_points.append(Vector2(10,0).rotated(float(i)*TAU/24.0))
	_impact_ring = _line(_impact, "SparkRing", ring_points, GOLD, 1.5)
	for i: int in range(8):
		var angle: float = float(i) * TAU / 8.0
		_line(_impact, "Spark%d" % i, [Vector2(7,0).rotated(angle), Vector2(15,0).rotated(angle)], ORANGE, 1.5)

func _build_dragon() -> void:
	# Each wing has a dark rim, translucent crimson membrane and molten finger bones.
	for i: int in range(2):
		var wing: Node2D = _pivot(_body, "Wing%d" % i, Vector2(-5,-12))
		_wings.append(wing)
		wing.z_index = -1 if i == 0 else 1
		wing.scale = Vector2(0.78,0.78) if i == 0 else Vector2.ONE
		_polygon(wing, "Rim", [Vector2(0,3),Vector2(-13,-16),Vector2(-12,-47),Vector2(8,-35),Vector2(30,-17),Vector2(15,-15),Vector2(10,-4)], DARK)
		_polygon(wing, "Membrane", [Vector2(-1,-1),Vector2(-11,-17),Vector2(-10,-41),Vector2(7,-31),Vector2(25,-18),Vector2(13,-13),Vector2(8,-3)], Color(0.90,0.12,0.04,0.8))
		_line(wing, "FingerA", [Vector2(0,1),Vector2(-10,-17),Vector2(-10,-41)], GOLD, 1.1)
		_line(wing, "FingerB", [Vector2(-10,-17),Vector2(7,-31)], ORANGE, 1.0)
		_line(wing, "FingerC", [Vector2(-10,-17),Vector2(25,-18)], ORANGE, 1.0)
	_tail = _pivot(_body, "Tail", Vector2(-24,0))
	_polygon(_tail, "LongTail", [Vector2(3,-5),Vector2(-15,-2),Vector2(-28,-9),Vector2(-37,-18),Vector2(-33,-5),Vector2(-18,7),Vector2(1,6)], RED)
	_polygon(_tail, "TailTip", [Vector2(-31,-13),Vector2(-39,-25),Vector2(-40,-12),Vector2(-33,-5)], ORANGE)
	_polygon(_body, "Flank", [Vector2(-27,-6),Vector2(-16,-17),Vector2(7,-17),Vector2(19,-24),Vector2(25,-13),Vector2(18,2),Vector2(-6,9),Vector2(-22,6)], RED)
	_polygon(_body, "MoltenBelly", [Vector2(-21,3),Vector2(-6,2),Vector2(17,-8),Vector2(18,2),Vector2(-6,9)], ORANGE)
	for i: int in range(5):
		var x: float = -18 + i * 7
		_polygon(_body, "Spine%d" % i, [Vector2(x,-15),Vector2(x+2,-25),Vector2(x+6,-15)], GOLD)
	_build_leg(Vector2(-17,4), "HindClaw")
	_build_leg(Vector2(13,0), "ForeClaw")
	_head = _pivot(_body, "HornedHead", Vector2(22,-22))
	_polygon(_head, "Skull", [Vector2(-7,-7),Vector2(6,-12),Vector2(16,-5),Vector2(30,0),Vector2(28,7),Vector2(9,9),Vector2(-5,4)], RED)
	_polygon(_head, "Muzzle", [Vector2(11,1),Vector2(30,0),Vector2(28,7),Vector2(9,9)], ORANGE)
	_polygon(_head, "NearHorn", [Vector2(-1,-8),Vector2(-7,-24),Vector2(6,-10)], GOLD)
	_polygon(_head, "FarHorn", [Vector2(7,-10),Vector2(4,-23),Vector2(13,-7)], GOLD)
	_polygon(_head, "EyeSocket", [Vector2(10,-5),Vector2(18,-3),Vector2(12,0)], DARK)
	_polygon(_head, "Eye", [Vector2(11,-4),Vector2(16,-3),Vector2(12,-2)], Color(1,0.92,0.52))
	_line(_head, "Jaw", [Vector2(10,5),Vector2(26,4)], DARK, 1.4)
	_polygon(_head, "Fang", [Vector2(20,4),Vector2(23,4),Vector2(22,8)], GOLD)
	for i: int in range(3):
		var line: Line2D = _line(self, "Breath%d" % i, [], [Color(0.85,0.06,0.01,0.35),ORANGE,GOLD][i], [23.0,11.0,3.0][i])
		_breath.append(line)

func _build_fox() -> void:
	_tail = _pivot(_body, "FlameTail", Vector2(-21,-4))
	_polygon(_tail, "BushyTail", [Vector2(3,-5),Vector2(-14,-10),Vector2(-29,-27),Vector2(-25,-9),Vector2(-33,-11),Vector2(-25,4),Vector2(-11,10),Vector2(2,5)], ORANGE)
	_polygon(_tail, "WhiteHotTip", [Vector2(-29,-27),Vector2(-25,-9),Vector2(-33,-11),Vector2(-25,4),Vector2(-21,-6)], GOLD)
	for i: int in range(4):
		_build_leg(Vector2(-15 if i < 2 else 13,1), "Leg%d" % i)
	_polygon(_body, "SlimFlank", [Vector2(-23,-9),Vector2(-15,-15),Vector2(6,-12),Vector2(18,-21),Vector2(22,-11),Vector2(17,1),Vector2(-3,5),Vector2(-21,2)], ORANGE)
	_polygon(_body, "Chest", [Vector2(15,-18),Vector2(21,-11),Vector2(17,1),Vector2(8,1)], GOLD)
	_head = _pivot(_body, "FoxHead", Vector2(19,-22))
	_polygon(_head, "SharpSkull", [Vector2(-6,-5),Vector2(5,-9),Vector2(12,-3),Vector2(26,3),Vector2(13,8),Vector2(1,8),Vector2(-6,2)], ORANGE)
	_polygon(_head, "FarEar", [Vector2(-4,-5),Vector2(-5,-23),Vector2(4,-8)], RED)
	_polygon(_head, "NearEar", [Vector2(3,-7),Vector2(8,-26),Vector2(13,-4)], ORANGE)
	_polygon(_head, "EarInside", [Vector2(6,-8),Vector2(8,-20),Vector2(10,-7)], DARK)
	_polygon(_head, "Muzzle", [Vector2(11,1),Vector2(26,3),Vector2(13,8),Vector2(8,4)], GOLD)
	_polygon(_head, "Nose", [Vector2(24,1),Vector2(28,3),Vector2(24,5)], DARK)
	_polygon(_head, "Eye", [Vector2(10,-3),Vector2(15,-1),Vector2(10,1)], Color(1,0.97,0.72))

func _build_leg(origin: Vector2, label: String) -> void:
	var leg: Node2D = _pivot(_body, label, origin)
	_legs.append(leg)
	_polygon(leg, "Limb", [Vector2(-3,-3),Vector2(3,-2),Vector2(0,10),Vector2(5,13),Vector2(-3,13)], RED)
	_line(leg, "Claw", [Vector2(0,12),Vector2(5,13)], GOLD, 1.2)

func _update_pose() -> void:
	var progress: float = clampf(1.0 - _attack_remaining / 0.38,0,1)
	var burst: float = sin(progress * PI) if _attack_remaining > 0.0 else 0.0
	_fire_material.set_shader_parameter("visual_clock", _age)
	_fire_material.set_shader_parameter("attack_light", burst)
	_geometry.scale.x = -1.0 if _facing.x < -0.08 else 1.0
	_geometry.rotation = _facing.y * 0.16 * _geometry.scale.x
	_geometry.position = Vector2.ZERO
	_body.position.y = sin(_age * (3.5 if visual_profile == "dragon" else 5.0)) * 2.5
	_tail.rotation = sin(_age * 4.0) * 0.12 - burst * 0.2
	_head.rotation = -burst * 0.1
	for i: int in range(_wings.size()):
		_wings[i].rotation = sin(_age * 7.5 + i * 0.5) * (0.25 if i == 0 else 0.38)
		_wings[i].scale.y = 0.72 + sin(_age * 7.5 + i * 0.5) * 0.20
	for i: int in range(_legs.size()):
		_legs[i].rotation = sin(_age * 8.0 + i * PI) * clampf(_motion.length() / 150,0,1) * 0.35 - burst * 0.25
	if visual_profile == "fox":
		_geometry.position = _facing * burst * minf(_target_offset.length() * 0.6, 42.0) / maxf(scale.x,0.001)
	var attacking: bool = _attack_remaining > 0.0 and _target_offset.length_squared() > 0.01
	_impact.visible = attacking
	for line: Line2D in _breath:
		line.visible = attacking
	# Idle/follow/expired summons never construct or rewrite hidden attack geometry.
	if attacking:
		var end: Vector2 = _target_offset / maxf(scale.x,0.001)
		var direction: Vector2 = end.normalized()
		var perpendicular: Vector2 = direction.orthogonal()
		for j: int in range(_breath.size()):
			var points: PackedVector2Array = PackedVector2Array()
			points.resize(13)
			for i: int in range(13):
				var t: float = float(i) / 12.0
				points[i] = direction * lerpf(minf(30.0,end.length()*0.25),end.length(),t) + perpendicular * sin(t * 16.0 - _age * 24.0) * sin(t*PI) * burst * (4.0-j)
			_breath[j].points = points
			_breath[j].modulate.a = burst
		_impact.position = end
		_impact.modulate.a = burst
		_impact.scale = Vector2.ONE * (0.35 + progress * 1.5)
	for i: int in range(_embers.size()):
		var phase: float = fposmod(_age * 0.72 + float(i) / 12.0, 1.0)
		_embers[i].position = Vector2(sin(float(i)*2.4) * 27 - phase * 7, 6 - phase*55)
		_embers[i].modulate.a = sin(phase * PI) * 0.65

func _pivot(parent: Node, label: String, origin: Vector2) -> Node2D:
	var node: Node2D = Node2D.new()
	node.name = label
	node.position = origin
	node.use_parent_material = true
	parent.add_child(node)
	return node

func _polygon(parent: Node2D, label: String, points: Array[Vector2], tint: Color) -> Polygon2D:
	var node: Polygon2D = Polygon2D.new()
	node.name = label
	node.polygon = PackedVector2Array(points)
	node.color = tint
	node.antialiased = true
	node.use_parent_material = true
	parent.add_child(node)
	return node

func _line(parent: Node2D, label: String, points: Array[Vector2], tint: Color, width: float) -> Line2D:
	var node: Line2D = Line2D.new()
	node.name = label
	node.points = PackedVector2Array(points)
	node.default_color = tint
	node.width = width
	node.antialiased = true
	node.use_parent_material = true
	parent.add_child(node)
	return node
