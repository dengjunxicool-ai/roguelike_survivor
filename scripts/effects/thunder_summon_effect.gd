## Fixed articulated geometry. The managed summon supplies the only animation clock.
## All target vectors are presentation offsets; combat remains in SummonController.
extends Node2D

const ELECTRIC_SHADER: Shader = preload("res://resources/effects/thunder_summon.gdshader")
const INK: Color = Color(0.035,0.07,0.17)
const BLUE: Color = Color(0.14,0.32,0.52)
const SILVER: Color = Color(0.55,0.75,0.86)
const ICE: Color = Color(0.73,0.95,1.0)
const GOLD: Color = Color(1.0,0.91,0.47)
@export_enum("lynx","crow") var visual_profile: String = "lynx"
var _age: float = 0.0
var _attack_remaining: float = 0.0
var _target_offset: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.RIGHT
var _motion: Vector2 = Vector2.ZERO
var _geometry: Node2D
var _body: Node2D
var _head: Node2D
var _tail: Node2D
var _legs: Array[Node2D] = []
var _wings: Array[Node2D] = []
var _feathers: Array[Node2D] = []
var _electric_material: ShaderMaterial
var _charge: Node2D
var _claw_flash: Node2D
const ATTACK_DURATION: float = 0.42

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
	_age += maxf(delta,0.0)
	_motion = motion
	_attack_remaining = maxf(_attack_remaining-maxf(delta,0.0),0.0)
	modulate.a = clampf(remaining/0.4,0.0,1.0)
	_update_pose()

func deactivate() -> void:
	_attack_remaining = 0.0
	visible = false
	_update_pose()

func _build_visual() -> void:
	if is_instance_valid(_geometry): return
	_electric_material = ShaderMaterial.new()
	_electric_material.shader = ELECTRIC_SHADER
	_geometry = _pivot(self,"Geometry",Vector2.ZERO)
	_geometry.material = _electric_material
	_geometry.use_parent_material = false
	_body = _pivot(_geometry,"Body",Vector2.ZERO)
	if visual_profile == "lynx": _build_lynx()
	else: _build_crow()
	_charge = _pivot(_body,"AttackCharge",Vector2(27,-20))
	for i: int in 3:
		var arc: Array[Vector2] = []
		for point: Vector2 in [Vector2(0,0),Vector2(5,-5),Vector2(8,1),Vector2(15,-3),Vector2(21,2)]:
			arc.append(point.rotated(float(i-1)*0.38))
		_line(_charge,"Discharge%d" % i,arc,ICE,1.2)
	_claw_flash = _pivot(_body,"ConfirmedClaw",Vector2(25,4))
	for i: int in 3:
		_line(_claw_flash,"Claw%d" % i,[Vector2(i*3,-8),Vector2(10+i*3,-2),Vector2(3+i*3,6)],GOLD,1.3)

func _build_lynx() -> void:
	_tail = _pivot(_body,"ElectricTail",Vector2(-24,-3))
	_polygon(_tail,"Bobtail",[Vector2(2,-4),Vector2(-9,-9),Vector2(-14,-19),Vector2(-18,-15),Vector2(-14,-3),Vector2(-4,4),Vector2(3,3)],BLUE)
	_line(_tail,"TailArc",[Vector2(-3,-3),Vector2(-10,-10),Vector2(-16,-7),Vector2(-21,-20),Vector2(-24,-14)],ICE,1.7)
	# Far limbs precede the flank; near limbs have clear paw and claw shapes.
	for i: int in 4:
		var leg: Node2D = _pivot(_body,"Leg%d" % i,Vector2(-16 if i<2 else 13,1))
		leg.z_index = -1 if i%2==0 else 1
		_legs.append(leg)
		_polygon(leg,"JointedLeg",[Vector2(-4,-4),Vector2(4,-3),Vector2(3,5),Vector2(-1,11),Vector2(7,14),Vector2(6,18),Vector2(-5,17),Vector2(-6,10)],BLUE if i%2==0 else SILVER)
		_line(leg,"ElectricShin",[Vector2(1,0),Vector2(-2,6),Vector2(1,7),Vector2(-2,13)],ICE,1.3)
		for j: int in 3: _line(leg,"Claw%d" % j,[Vector2(2+j*2,15),Vector2(4+j*2,17)],GOLD,1.1)
	_polygon(_body,"LynxFlank",[Vector2(-28,-7),Vector2(-19,-19),Vector2(3,-21),Vector2(19,-26),Vector2(26,-15),Vector2(18,3),Vector2(-3,8),Vector2(-22,5)],SILVER)
	_polygon(_body,"ShadowBelly",[Vector2(-26,-3),Vector2(-8,1),Vector2(17,-5),Vector2(18,3),Vector2(-3,8),Vector2(-22,5)],BLUE)
	_polygon(_body,"Ruff",[Vector2(12,-23),Vector2(21,-28),Vector2(27,-13),Vector2(22,-9),Vector2(28,-7),Vector2(18,3),Vector2(11,-7)],ICE)
	for i: int in 4:
		_line(_body,"LightningStripe%d" % i,[Vector2(-20+i*8,-15),Vector2(-16+i*8,-10),Vector2(-20+i*8,-7),Vector2(-14+i*8,-2)],BLUE,2.1)
		_line(_body,"StripeCore%d" % i,[Vector2(-20+i*8,-15),Vector2(-16+i*8,-10),Vector2(-20+i*8,-7)],ICE,0.8)
	_head = _pivot(_body,"LynxHead",Vector2(23,-24))
	_polygon(_head,"CheekRuff",[Vector2(-10,-3),Vector2(-2,-12),Vector2(13,-8),Vector2(20,0),Vector2(14,9),Vector2(3,11),Vector2(-8,7),Vector2(-6,3),Vector2(-12,2)],SILVER)
	_polygon(_head,"EarFar",[Vector2(-7,-7),Vector2(-9,-21),Vector2(0,-11)],BLUE)
	_polygon(_head,"EarNear",[Vector2(3,-9),Vector2(7,-24),Vector2(12,-7)],SILVER)
	_polygon(_head,"EarTuftFar",[Vector2(-10,-19),Vector2(-12,-33),Vector2(-7,-20)],INK)
	_polygon(_head,"EarTuftNear",[Vector2(5,-22),Vector2(7,-38),Vector2(10,-23)],INK)
	_line(_head,"TuftElectric",[Vector2(7,-35),Vector2(9,-29),Vector2(7,-27)],ICE,1.1)
	_polygon(_head,"EarInside",[Vector2(5,-12),Vector2(7,-20),Vector2(9,-11)],INK)
	_polygon(_head,"ShortMuzzle",[Vector2(9,0),Vector2(20,1),Vector2(17,7),Vector2(7,7)],ICE)
	_polygon(_head,"Nose",[Vector2(18,0),Vector2(22,2),Vector2(18,4)],INK)
	_line(_head,"EyeRim",[Vector2(7,-5),Vector2(15,-3)],INK,2.5)
	_line(_head,"Eye",[Vector2(8,-4),Vector2(13,-3)],GOLD,1.4)
	_line(_head,"WhiskerA",[Vector2(13,5),Vector2(24,7)],BLUE,0.9)
	_line(_head,"WhiskerB",[Vector2(13,5),Vector2(23,10)],BLUE,0.9)

func _build_crow() -> void:
	# Layered flight feathers make each wing legible even at its folded extreme.
	for i: int in 2:
		var wing: Node2D = _pivot(_body,"Wing%d" % i,Vector2(-4,-16))
		wing.z_index = -1 if i==0 else 1
		wing.scale = Vector2(0.84,0.84) if i==0 else Vector2.ONE
		_wings.append(wing)
		_polygon(wing,"FlightWing",[Vector2(0,4),Vector2(-13,-9),Vector2(-34,-32),Vector2(-36,-49),Vector2(-27,-42),Vector2(-26,-52),Vector2(-18,-40),Vector2(-15,-47),Vector2(-9,-29),Vector2(4,-9)],INK)
		_polygon(wing,"BlueCoverts",[Vector2(0,-2),Vector2(-11,-15),Vector2(-24,-32),Vector2(-20,-38),Vector2(-10,-27),Vector2(3,-10)],BLUE)
		for j: int in 5:
			_line(wing,"FeatherRib%d" % j,[Vector2(-4,-8-j*3),Vector2(-13-j*4,-24-j*4),Vector2(-16-j*4,-33-j*3)],SILVER if j%2==0 else BLUE,1.1)
		_line(wing,"WingArc",[Vector2(0,-4),Vector2(-8,-13),Vector2(-6,-18),Vector2(-19,-24),Vector2(-16,-29),Vector2(-30,-39)],ICE,1.3)
	_tail = _pivot(_body,"FanTail",Vector2(-14,0))
	_polygon(_tail,"TailFeathers",[Vector2(4,-5),Vector2(-22,-3),Vector2(-31,4),Vector2(-20,4),Vector2(-24,11),Vector2(-13,8),Vector2(-12,15),Vector2(1,6)],INK)
	for i: int in 3: _line(_tail,"TailRib%d" % i,[Vector2(0,0),Vector2(-22+i*5,3+i*3)],BLUE,1.1)
	_polygon(_body,"CrowBody",[Vector2(-18,-12),Vector2(-9,-22),Vector2(8,-21),Vector2(17,-10),Vector2(8,4),Vector2(-5,8),Vector2(-17,1)],INK)
	_polygon(_body,"Breast",[Vector2(7,-18),Vector2(15,-9),Vector2(7,2),Vector2(-2,5),Vector2(-7,-1)],BLUE)
	_line(_body,"ChestArc",[Vector2(6,-13),Vector2(2,-9),Vector2(7,-6),Vector2(1,1)],ICE,1.3)
	for i: int in 2:
		_line(_body,"Talon%d" % i,[Vector2(1+i*7,4),Vector2(1+i*7,11),Vector2(6+i*7,12),Vector2(8+i*7,10)],SILVER,1.2)
	_head = _pivot(_body,"CrowHead",Vector2(13,-23))
	_polygon(_head,"Skull",[Vector2(-6,-1),Vector2(-5,-9),Vector2(4,-14),Vector2(13,-10),Vector2(17,-2),Vector2(11,6),Vector2(-2,7)],INK)
	_polygon(_head,"Brow",[Vector2(-3,-8),Vector2(6,-11),Vector2(13,-7),Vector2(11,-4),Vector2(2,-5)],BLUE)
	_polygon(_head,"PointedBeak",[Vector2(12,-3),Vector2(31,2),Vector2(13,5)],SILVER)
	_line(_head,"BeakSplit",[Vector2(14,1),Vector2(28,2)],INK,1.1)
	_line(_head,"Eye",[Vector2(8,-4),Vector2(12,-3)],GOLD,1.7)
	for i: int in 10:
		var feather: Node2D = _pivot(_geometry,"FloatingFeather%d" % i,Vector2.ZERO)
		_polygon(feather,"Barbs",[Vector2(0,-7),Vector2(3,-3),Vector2(2,3),Vector2(0,7),Vector2(-2,1),Vector2(-3,-2)],BLUE)
		_line(feather,"ElectricVane",[Vector2(0,-6),Vector2(-1,-1),Vector2(1,1),Vector2(0,6)],ICE,0.9)
		_feathers.append(feather)

func _update_pose() -> void:
	if not is_instance_valid(_geometry): return
	var progress: float = clampf(1.0-_attack_remaining/ATTACK_DURATION,0.0,1.0)
	var burst: float = sin(progress*PI) if _attack_remaining>0.0 else 0.0
	_electric_material.set_shader_parameter("visual_clock",_age)
	_electric_material.set_shader_parameter("attack_light",burst)
	_geometry.scale.x = -1.0 if _facing.x < -0.08 else 1.0
	_geometry.rotation = _facing.y*0.14*_geometry.scale.x
	var reach: float = minf(_target_offset.length()*0.55,38.0 if visual_profile=="lynx" else 16.0)
	_geometry.position = _facing*burst*reach/maxf(scale.x,0.001)
	_body.position.y = sin(_age*(6.0 if visual_profile=="lynx" else 4.4))*2.0-burst*(13.0 if visual_profile=="lynx" else 5.0)
	_body.rotation = -burst*0.10
	_head.rotation = burst*(0.11 if visual_profile=="crow" else -0.1)
	_tail.rotation = sin(_age*5.0)*0.15-burst*0.25
	var running: float = clampf(_motion.length()/180.0,0.0,1.0)
	for i: int in _legs.size():
		_legs[i].rotation = sin(_age*11.0+float(i)*PI*0.7)*running*0.48 + burst*(-0.65 if i<2 else 0.65)
	for i: int in _wings.size():
		var flap: float = sin(_age*9.0+float(i)*0.5)
		_wings[i].rotation = flap*0.46+burst*0.65
		_wings[i].scale.y = 0.78+flap*0.20-burst*0.15
	for i: int in _feathers.size():
		var phase: float = _age*0.75+float(i)*TAU/10.0
		_feathers[i].position = Vector2(cos(phase)*(28.0+float(i%3)*4.0),-15.0+sin(phase)*23.0)
		_feathers[i].rotation = sin(phase)*0.7+burst*0.6
		_feathers[i].modulate.a = 0.35+0.45*(0.5+0.5*sin(phase))
	_charge.visible = _attack_remaining > 0.0
	_charge.modulate.a = burst
	_charge.scale = Vector2.ONE*(0.55+burst*0.65)
	_claw_flash.visible = visual_profile=="lynx" and _attack_remaining>0.0
	_claw_flash.modulate.a = burst

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
