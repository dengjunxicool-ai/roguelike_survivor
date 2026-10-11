## Fixed presentation geometry. Managed replay / area launch owns confirmed attacks.
## This effect only consumes host delta, motion and lifetime; it cannot apply combat.
extends Node2D
const CHAOS_SHADER: Shader = preload("res://resources/effects/chaos_summon.gdshader")
const VIOLET: Color = Color(0.59,0.22,0.90,0.76)
const LILAC: Color = Color(0.82,0.56,1.0,0.90)
const CYAN: Color = Color(0.30,0.90,0.92,0.88)
const DARK: Color = Color(0.045,0.019,0.075,0.96)
const ATTACK_DURATION: float = 0.34
@export_enum("clone","maw") var visual_profile: String = "clone"
var _age: float = 0.0
var _attack_remaining: float = 0.0
var _target_offset: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.RIGHT
var _motion: Vector2 = Vector2.ZERO
var _geometry: Node2D
var _body: Node2D
var _arm: Node2D
var _head: Node2D
var _teeth: Node2D
var _aperture: Node2D
var _pulse: Node2D
var _material: ShaderMaterial
var _shards: Array[Node2D] = []
var _shard_origins: Array[Vector2] = []
var _legs: Array[Node2D] = []

func _ready() -> void:
	_build_visual()
	set_process(false)
	_update_pose()
func configure_summon(visual: Dictionary) -> void:
	_build_visual()
	_age = 0.0
	_attack_remaining = 0.0
	_target_offset = Vector2.ZERO
	_facing = Vector2.RIGHT
	_motion = Vector2.ZERO
	scale = Vector2.ONE * clampf(float(visual.get("effect_scale",1.0)),0.25,3.0)
	modulate.a = 1.0
	visible = true
	set_process(false)
	_update_pose()
func face_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001: _facing = direction.normalized()
func set_attack_target(offset: Vector2) -> void:
	_target_offset = offset
	face_direction(offset)
func play_attack() -> void:
	_attack_remaining = ATTACK_DURATION
	_update_pose()
func update_summon(delta: float, motion: Vector2, remaining: float) -> void:
	var elapsed: float = maxf(delta,0.0)
	_age += elapsed
	_motion = motion
	_attack_remaining = maxf(_attack_remaining - elapsed,0.0)
	modulate.a = clampf(remaining/0.4,0.0,1.0)
	_update_pose()
func deactivate() -> void:
	_attack_remaining = 0.0
	visible = false
	_update_pose()
func _build_visual() -> void:
	if is_instance_valid(_geometry): return
	_material = ShaderMaterial.new()
	_material.shader = CHAOS_SHADER
	_geometry = _pivot(self,"Geometry",Vector2.ZERO)
	_geometry.material = _material
	_geometry.use_parent_material = false
	if visual_profile == "clone": _build_clone()
	else: _build_maw()
	_pulse = _pivot(_geometry,"ConfirmedPulse",Vector2.ZERO)
	if visual_profile == "clone":
		_pulse.position = Vector2(25,-24)
		_ring(_pulse,"EchoSigil",9,9,LILAC,1.3)
		_line(_pulse,"OriginalCastEcho",[Vector2(-6,0),Vector2(0,-6),Vector2(6,0),Vector2(0,6),Vector2(-6,0)],CYAN,1.2)
	else:
		_ring(_pulse,"PulseOuter",58,35,VIOLET,1.8)
		_ring(_pulse,"PulseInner",45,27,CYAN,1.1)
		for i: int in 12:
			var phase: float = TAU*float(i)/12.0
			var point: Vector2 = Vector2(cos(phase)*51,sin(phase)*30)
			_line(_pulse,"PulseTick%d" % i,[point,point*1.14],LILAC,1.1)
func _build_clone() -> void:
	var ground: Node2D = _pivot(_geometry,"EchoFootprint",Vector2(0,23))
	_ring(ground,"Footprint",23,6,Color(0.35,0.78,0.88,0.35),0.9)
	_body = _pivot(_geometry,"Body",Vector2.ZERO)
	# Independent fractured plates preserve the recognisable shoulders/waist silhouette.
	_polygon(_body,"RearEcho",[Vector2(-17,-33),Vector2(7,-34),Vector2(13,-20),Vector2(7,1),Vector2(-17,4),Vector2(-23,-11)],Color(0.20,0.65,0.76,0.20))
	_polygon(_body,"TorsoLeft",[Vector2(-14,-32),Vector2(-1,-30),Vector2(-4,-17),Vector2(-1,-7),Vector2(-12,-5),Vector2(-17,-18)],VIOLET)
	_polygon(_body,"TorsoRight",[Vector2(2,-31),Vector2(13,-29),Vector2(15,-19),Vector2(5,-9),Vector2(2,-16)],Color(0.33,0.19,0.56,0.80))
	_polygon(_body,"WaistFragment",[Vector2(-10,-3),Vector2(4,-6),Vector2(12,3),Vector2(5,8),Vector2(-9,6)],VIOLET)
	_line(_body,"SternumFracture",[Vector2(1,-30),Vector2(-2,-22),Vector2(3,-18),Vector2(0,-11)],CYAN,1.1)
	_line(_body,"ShoulderRim",[Vector2(-17,-20),Vector2(-14,-31),Vector2(-2,-34),Vector2(11,-30)],LILAC,1.1)
	_polygon(_body,"LeftPauldron",[Vector2(-17,-30),Vector2(-23,-24),Vector2(-21,-17),Vector2(-14,-18),Vector2(-11,-26)],LILAC)
	_polygon(_body,"HangingArm",[Vector2(-22,-16),Vector2(-17,-17),Vector2(-18,-2),Vector2(-22,3),Vector2(-25,-2)],VIOLET)
	_line(_body,"HandEcho",[Vector2(-23,2),Vector2(-24,7),Vector2(-20,6)],CYAN,1.2)
	_arm = _pivot(_body,"CastingArm",Vector2(11,-26))
	_polygon(_arm,"UpperArm",[Vector2(-1,-3),Vector2(5,-3),Vector2(11,4),Vector2(8,10),Vector2(2,7)],VIOLET)
	_polygon(_arm,"Forearm",[Vector2(8,8),Vector2(11,4),Vector2(21,-1),Vector2(23,4),Vector2(16,10)],LILAC)
	_line(_arm,"CastingFingers",[Vector2(21,0),Vector2(27,-4),Vector2(26,2),Vector2(29,4)],CYAN,1.3)
	_head = _pivot(_body,"Head",Vector2(0,-39))
	_polygon(_head,"HoodLeft",[Vector2(-8,4),Vector2(-10,-8),Vector2(-3,-17),Vector2(1,-14),Vector2(-2,-3),Vector2(0,7)],VIOLET)
	_polygon(_head,"HoodRight",[Vector2(3,-14),Vector2(9,-8),Vector2(9,3),Vector2(3,7),Vector2(1,-3)],LILAC)
	_polygon(_head,"VoidFace",[Vector2(-5,-7),Vector2(5,-8),Vector2(6,0),Vector2(0,4),Vector2(-5,0)],DARK)
	_line(_head,"CyanGaze",[Vector2(-4,-4),Vector2(0,-3),Vector2(4,-5)],CYAN,1.1)
	for side: int in [-1,1]:
		var leg: Node2D = _pivot(_body,"Leg%d" % _legs.size(),Vector2(side*6,5))
		_legs.append(leg)
		_polygon(leg,"UpperLeg",[Vector2(-4,0),Vector2(4,0),Vector2(3,10),Vector2(-3,11)],VIOLET)
		_polygon(leg,"LowerLeg",[Vector2(-3,13),Vector2(3,12),Vector2(4,19),Vector2(9,20),Vector2(8,23),Vector2(-4,22)],LILAC)
		_line(leg,"ShinFracture",[Vector2(1,13),Vector2(0,18),Vector2(4,20)],CYAN,0.8)
	for i: int in 8:
		var origin: Vector2 = Vector2((-1 if i%2 == 0 else 1)*(23+i%3*5),-48+i*9)
		var shard: Node2D = _pivot(_geometry,"EchoShard%d" % i,origin)
		_polygon(shard,"Plate",[Vector2(-3,-5),Vector2(3,-2),Vector2(2,4),Vector2(-2,7)],CYAN if i%3==0 else VIOLET)
		_shards.append(shard)
		_shard_origins.append(origin)
func _build_maw() -> void:
	_aperture = _pivot(_geometry,"Aperture",Vector2.ZERO)
	# Solid ink center, layered irregular lips and inward-facing teeth form a mouth.
	var rim: Array[Vector2] = []
	for i: int in 48:
		var phase: float = TAU*float(i)/48.0
		var ripple: float = 1.0 + sin(phase*7.0)*0.045
		rim.append(Vector2(cos(phase)*44,sin(phase)*27)*ripple)
	_polygon(_aperture,"OuterLip",rim,VIOLET)
	var cavity: Array[Vector2] = []
	for i: int in 48:
		var phase: float = TAU*float(i)/48.0
		cavity.append(Vector2(cos(phase)*37,sin(phase)*21))
	_polygon(_aperture,"BlackCavity",cavity,Color(0.007,0.005,0.017,1.0))
	_ring(_aperture,"InnerLip",39,23,LILAC,1.0)
	_ring(_aperture,"CavityEcho",29,15,Color(0.23,0.12,0.38,0.60),0.9)
	_teeth = _pivot(_geometry,"Teeth",Vector2.ZERO)
	for i: int in 22:
		var phase: float = TAU*float(i)/22.0
		var root_point: Vector2 = Vector2(cos(phase)*38,sin(phase)*23)
		var tangent: Vector2 = Vector2(-sin(phase),cos(phase))*3.2
		var tip: Vector2 = Vector2(cos(phase)*(26-i%3),sin(phase)*(13-i%3))
		_polygon(_teeth,"Tooth%d" % i,[root_point-tangent,root_point+tangent,tip],CYAN if i%5==0 else LILAC)
		_line(_teeth,"ToothRoot%d" % i,[root_point-tangent,root_point+tangent],VIOLET,1.4)
	for i: int in 12:
		var phase: float = TAU*float(i)/12.0
		var origin: Vector2 = Vector2(cos(phase)*51,sin(phase)*33)
		var shard: Node2D = _pivot(_geometry,"RiftShard%d" % i,origin)
		shard.rotation = phase
		_polygon(shard,"Fragment",[Vector2(-5,-1),Vector2(2,-3),Vector2(7,1),Vector2(1,3)],VIOLET if i%2==0 else CYAN)
		_shards.append(shard)
		_shard_origins.append(origin)
func _update_pose() -> void:
	if not is_instance_valid(_geometry): return
	var progress: float = clampf(1.0-_attack_remaining/ATTACK_DURATION,0.0,1.0)
	var gesture: float = sin(progress*PI) if _attack_remaining > 0.0 else 0.0
	_material.set_shader_parameter("visual_clock",_age)
	_material.set_shader_parameter("confirmed_pulse",gesture)
	_pulse.visible = _attack_remaining > 0.0
	_pulse.modulate.a = gesture
	if visual_profile == "clone":
		_geometry.scale.x = -1.0 if _facing.x < -0.08 else 1.0
		_body.position.y = sin(_age*3.0)*1.4 - gesture*2.0
		_arm.rotation = -gesture*0.8
		_head.rotation = -gesture*0.09
		_pulse.scale = Vector2.ONE*(0.65+gesture*0.55)
		var stride: float = clampf(_motion.length()/180.0,0.0,1.0)
		for i: int in _legs.size(): _legs[i].rotation = sin(_age*9.0+float(i)*PI)*stride*0.24
	else:
		_geometry.position = Vector2.ZERO
		_aperture.scale.y = 0.88+sin(_age*2.8)*0.035+gesture*0.30
		_teeth.scale.y = _aperture.scale.y
		_pulse.scale = Vector2.ONE*(0.70+progress*0.55)
	for i: int in _shards.size():
		var phase: float = _age*2.0+float(i)*1.7
		_shards[i].position = _shard_origins[i]+Vector2(sin(phase)*1.4,cos(phase)*2.0)
		_shards[i].modulate.a = 0.52+0.24*sin(phase)+gesture*0.20
func _pivot(parent: Node, label: String, origin: Vector2) -> Node2D:
	var node: Node2D = Node2D.new()
	node.name = label
	node.position = origin
	node.use_parent_material = true
	parent.add_child(node)
	return node
func _polygon(parent: Node2D, label: String, points: Array[Vector2], tint: Color) -> void:
	var node: Polygon2D = Polygon2D.new()
	node.name = label
	node.polygon = PackedVector2Array(points)
	node.color = tint
	node.antialiased = true
	node.use_parent_material = true
	parent.add_child(node)
func _line(parent: Node2D, label: String, points: Array[Vector2], tint: Color, width: float) -> void:
	var node: Line2D = Line2D.new()
	node.name = label
	node.points = PackedVector2Array(points)
	node.default_color = tint
	node.width = width
	node.antialiased = true
	node.use_parent_material = true
	parent.add_child(node)
func _ring(parent: Node2D, label: String, radius_x: float, radius_y: float, tint: Color, width: float) -> void:
	var points: Array[Vector2] = []
	for i: int in 49:
		var phase: float = float(i)*TAU/48.0
		points.append(Vector2(cos(phase)*radius_x,sin(phase)*radius_y))
	_line(parent,label,points,tint,width)
