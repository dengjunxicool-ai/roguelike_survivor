## Pure fixed-geometry presentation. The managed summon owns attack confirmation,
## target offsets, motion and lifetime; launch light never applies combat effects.
extends Node2D

const HOLY_SHADER: Shader = preload("res://resources/effects/holy_summon.gdshader")
const INK: Color = Color(0.12,0.13,0.18)
const SHADOW: Color = Color(0.36,0.32,0.25)
const BRONZE: Color = Color(0.70,0.49,0.20)
const GOLD: Color = Color(1.0,0.77,0.30)
const IVORY: Color = Color(0.93,0.89,0.75)
const WHITE: Color = Color(1.0,0.98,0.88)
const ATTACK_DURATION: float = 0.38
const GUARD_DURATION: float = 0.32
@export_enum("seraph","guardian") var visual_profile: String = "seraph"
var _age: float = 0.0
var _attack_remaining: float = 0.0
var _guard_remaining: float = 0.0
var _target_offset: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.RIGHT
var _motion: Vector2 = Vector2.ZERO
var _geometry: Node2D
var _body: Node2D
var _head: Node2D
var _halo: Node2D
var _shield: Node2D
var _arm: Node2D
var _launch_light: Node2D
var _guard_light: Node2D
var _wings: Array[Node2D] = []
var _legs: Array[Node2D] = []
var _feathers: Array[Node2D] = []
var _holy_material: ShaderMaterial

func _ready() -> void:
	_build_visual()
	set_process(false)
	_update_pose()
func configure_summon(visual: Dictionary) -> void:
	_build_visual()
	_age = 0.0
	_attack_remaining = 0.0
	_guard_remaining = 0.0
	_target_offset = Vector2.ZERO
	_facing = Vector2.RIGHT
	_motion = Vector2.ZERO
	scale = Vector2.ONE * clampf(float(visual.get("effect_scale",1.0)),0.25,3.0)
	modulate.a = 1.0
	visible = true
	set_process(false)
	_update_pose()
func face_direction(direction: Vector2) -> void:
	if direction.length_squared()>0.0001: _facing = direction.normalized()
func set_attack_target(offset: Vector2) -> void:
	_target_offset = offset
	face_direction(offset)
func play_attack() -> void:
	_attack_remaining = ATTACK_DURATION
	_update_pose()
## Called only by the damage pipeline after this guardian absorbs a positive amount.
func play_guard() -> void:
	if visual_profile != "guardian": return
	_guard_remaining = GUARD_DURATION
	_update_pose()
func update_summon(delta: float, motion: Vector2, remaining: float) -> void:
	_age += maxf(delta,0.0)
	_motion = motion
	_attack_remaining = maxf(_attack_remaining-maxf(delta,0.0),0.0)
	_guard_remaining = maxf(_guard_remaining-maxf(delta,0.0),0.0)
	modulate.a = clampf(remaining/0.4,0.0,1.0)
	_update_pose()
func deactivate() -> void:
	_attack_remaining = 0.0
	_guard_remaining = 0.0
	visible = false
	_update_pose()
func _build_visual() -> void:
	if is_instance_valid(_geometry): return
	_holy_material = ShaderMaterial.new()
	_holy_material.shader = HOLY_SHADER
	_geometry = _pivot(self,"Geometry",Vector2.ZERO)
	_geometry.material = _holy_material
	_geometry.use_parent_material = false
	_body = _pivot(_geometry,"Body",Vector2.ZERO)
	if visual_profile == "seraph": _build_seraph()
	else: _build_guardian()
	_launch_light = _pivot(_body,"LaunchLight",Vector2(24,-17))
	# These short streaks stay on the launcher. They are neither a projectile nor hit feedback.
	for i: int in 5:
		_line(_launch_light,"Ray%d" % i,[Vector2(2+i*2,-7+i*3),Vector2(19+i*2,-5+i*2)],WHITE if i%2==0 else GOLD,1.25)
	_ring(_launch_light,"MuzzleRing",7.0,4.0,Vector2(8,0),GOLD,1.1)
func _build_seraph() -> void:
	# Three pairs are attached separately, with individual rachis and layered vanes.
	for side: int in [-1,1]:
		for rank: int in 3:
			var wing: Node2D = _pivot(_body,"Wing%d" % _wings.size(),Vector2(side*7,-25+rank*7))
			wing.scale.x = side
			wing.z_index = -2+rank
			_wings.append(wing)
			var tip: Vector2 = Vector2(58-rank*8,-47+rank*36)
			_polygon(wing,"WingMembrane",[Vector2(0,0),Vector2(14,-11),Vector2(29,-14+rank*6),tip,tip+Vector2(-1,12),Vector2(22,14),Vector2(7,9)],IVORY)
			for vane: int in 7:
				var feather_root: Vector2 = Vector2(10+vane*5,-5+rank*3)
				var feather_tip: Vector2 = feather_root + Vector2(12+vane*1.5,-24+rank*23-vane*2.0)
				var normal: Vector2 = (feather_tip-feather_root).orthogonal().normalized()*3.5
				_polygon(wing,"FlightFeather%d" % vane,[feather_root-normal,feather_tip-normal*0.35,feather_tip,feather_tip+normal*0.6,feather_root+normal],WHITE if vane%2==0 else IVORY)
				_line(wing,"GoldenRachis%d" % vane,[feather_root,feather_tip],GOLD,0.75)
			_line(wing,"WingJoint",[Vector2(0,0),Vector2(14,-7),Vector2(30,-6+rank*5)],BRONZE,2.0)
	_polygon(_body,"RobeShadow",[Vector2(-9,-30),Vector2(9,-30),Vector2(12,-7),Vector2(18,19),Vector2(7,14),Vector2(0,27),Vector2(-6,16),Vector2(-18,21),Vector2(-12,-5)],SHADOW)
	_polygon(_body,"WhiteVestment",[Vector2(-7,-27),Vector2(8,-27),Vector2(5,-8),Vector2(12,15),Vector2(3,10),Vector2(0,22),Vector2(-6,11),Vector2(-13,15),Vector2(-5,-9)],WHITE)
	_line(_body,"RobeFoldLeft",[Vector2(-5,-10),Vector2(-6,2),Vector2(-11,13)],BRONZE,1.0)
	_line(_body,"RobeFoldRight",[Vector2(4,-7),Vector2(4,5),Vector2(8,12)],GOLD,1.2)
	_polygon(_body,"ChestAegis",[Vector2(-9,-27),Vector2(0,-31),Vector2(10,-27),Vector2(5,-17),Vector2(0,-12),Vector2(-6,-18)],BRONZE)
	_polygon(_body,"ChestLight",[Vector2(-5,-25),Vector2(0,-28),Vector2(6,-25),Vector2(3,-18),Vector2(0,-16),Vector2(-3,-19)],GOLD)
	_arm = _pivot(_body,"CastingArm",Vector2(7,-26))
	_polygon(_arm,"Sleeve",[Vector2(0,-3),Vector2(10,1),Vector2(18,7),Vector2(13,13),Vector2(5,9),Vector2(-3,4)],IVORY)
	_polygon(_arm,"Gauntlet",[Vector2(12,6),Vector2(21,4),Vector2(26,7),Vector2(22,12),Vector2(14,12)],GOLD)
	_head = _pivot(_body,"VeiledHead",Vector2(0,-36))
	_polygon(_head,"Hood",[Vector2(-8,0),Vector2(-6,-12),Vector2(0,-17),Vector2(7,-11),Vector2(9,0),Vector2(5,7),Vector2(-4,7)],IVORY)
	_polygon(_head,"Veil",[Vector2(-5,-7),Vector2(5,-8),Vector2(6,1),Vector2(0,5),Vector2(-5,1)],INK)
	_line(_head,"EyesOfLight",[Vector2(-3,-3),Vector2(3,-3)],WHITE,1.0)
	_line(_head,"HoodGold",[Vector2(-7,0),Vector2(-5,-10),Vector2(0,-14),Vector2(6,-9),Vector2(8,0)],GOLD,1.2)
	_halo = _pivot(_body,"CelestialHalo",Vector2(0,-58))
	_ring(_halo,"HaloOuter",15.0,4.5,Vector2.ZERO,GOLD,1.7)
	_ring(_halo,"HaloInner",11.0,3.0,Vector2.ZERO,WHITE,0.8)
	for i: int in 8:
		var phase: float = float(i)*TAU/8.0
		var point: Vector2 = Vector2(cos(phase)*15,sin(phase)*4.5)
		_line(_halo,"Seal%d" % i,[point+Vector2(-1,-2),point+Vector2(2,1),point+Vector2(1,3)],WHITE,0.8)
	for i: int in 10:
		var feather: Node2D = _pivot(_geometry,"FeatherMote%d" % i,Vector2.ZERO)
		_polygon(feather,"Vane",[Vector2(0,-5),Vector2(3,-2),Vector2(2,2),Vector2(0,7),Vector2(-2,2),Vector2(-2,-2)],IVORY)
		_line(feather,"Rachis",[Vector2(0,-4),Vector2(0,6)],GOLD,0.65)
		_feathers.append(feather)
func _build_guardian() -> void:
	for side: int in [-1,1]:
		var leg: Node2D = _pivot(_body,"Leg%d" % _legs.size(),Vector2(side*8,-3))
		_legs.append(leg)
		_polygon(leg,"Greave",[Vector2(-5,-1),Vector2(4,-1),Vector2(6,8),Vector2(3,16),Vector2(8,19),Vector2(8,23),Vector2(-6,23),Vector2(-7,17),Vector2(-4,8)],IVORY)
		_polygon(leg,"KneePlate",[Vector2(-6,6),Vector2(0,3),Vector2(6,7),Vector2(3,12),Vector2(-4,12)],BRONZE)
		_line(leg,"ShinInlay",[Vector2(0,13),Vector2(0,19),Vector2(5,21)],GOLD,1.2)
	_polygon(_body,"Cloak",[Vector2(-15,-33),Vector2(8,-32),Vector2(13,10),Vector2(0,7),Vector2(-17,15),Vector2(-23,10)],SHADOW)
	_polygon(_body,"ArmoredTorso",[Vector2(-13,-32),Vector2(11,-33),Vector2(16,-18),Vector2(10,-4),Vector2(-9,-4),Vector2(-17,-18)],BRONZE)
	_polygon(_body,"BreastPlate",[Vector2(-9,-29),Vector2(8,-30),Vector2(11,-18),Vector2(5,-11),Vector2(-7,-12),Vector2(-12,-18)],IVORY)
	_line(_body,"TorsoEtching",[Vector2(-6,-24),Vector2(0,-20),Vector2(5,-24),Vector2(0,-15)],GOLD,1.5)
	_polygon(_body,"Fauld",[Vector2(-10,-10),Vector2(11,-10),Vector2(15,1),Vector2(4,4),Vector2(0,-1),Vector2(-5,4),Vector2(-15,1)],IVORY)
	_polygon(_body,"Pauldron",[Vector2(-16,-33),Vector2(-6,-36),Vector2(-3,-27),Vector2(-16,-20),Vector2(-23,-23)],WHITE)
	_line(_body,"PauldronRim",[Vector2(-22,-23),Vector2(-16,-31),Vector2(-7,-33)],GOLD,1.8)
	_head = _pivot(_body,"Helm",Vector2(0,-41))
	_polygon(_head,"SteelHelm",[Vector2(-8,1),Vector2(-7,-11),Vector2(0,-15),Vector2(8,-11),Vector2(10,2),Vector2(4,7),Vector2(-4,7)],IVORY)
	_polygon(_head,"Visor",[Vector2(-6,-5),Vector2(7,-5),Vector2(7,-1),Vector2(-5,0)],INK)
	_line(_head,"VisorLight",[Vector2(-4,-3),Vector2(6,-3)],GOLD,1.1)
	_polygon(_head,"HelmCrest",[Vector2(-3,-10),Vector2(-1,-23),Vector2(3,-19),Vector2(3,-10)],GOLD)
	_line(_head,"CheekGuard",[Vector2(7,0),Vector2(4,5),Vector2(0,7)],BRONZE,1.5)
	_arm = _pivot(_body,"SwordArm",Vector2(-16,-22))
	_polygon(_arm,"Gauntlet",[Vector2(-3,-2),Vector2(5,-1),Vector2(7,14),Vector2(-1,17),Vector2(-5,10)],IVORY)
	_polygon(_arm,"Blade",[Vector2(0,8),Vector2(3,-29),Vector2(7,-38),Vector2(10,-29),Vector2(7,9)],WHITE)
	_line(_arm,"SwordFuller",[Vector2(5,5),Vector2(7,-30)],GOLD,1.1)
	_line(_arm,"SwordGuard",[Vector2(-4,8),Vector2(14,8)],GOLD,2.4)
	_shield = _pivot(_body,"Shield",Vector2(18,-20))
	_polygon(_shield,"DarkRim",[Vector2(-14,-22),Vector2(0,-29),Vector2(16,-21),Vector2(17,3),Vector2(8,19),Vector2(0,26),Vector2(-11,17),Vector2(-16,2)],SHADOW)
	_polygon(_shield,"GoldRim",[Vector2(-12,-20),Vector2(0,-26),Vector2(14,-20),Vector2(14,3),Vector2(7,17),Vector2(0,22),Vector2(-9,16),Vector2(-13,2)],GOLD)
	_polygon(_shield,"PearlFace",[Vector2(-9,-18),Vector2(0,-22),Vector2(11,-17),Vector2(11,2),Vector2(5,14),Vector2(0,18),Vector2(-6,13),Vector2(-10,0)],IVORY)
	_line(_shield,"ShieldSpine",[Vector2(0,-19),Vector2(0,15)],BRONZE,1.7)
	_polygon(_shield,"RaisedBoss",[Vector2(0,-8),Vector2(5,-2),Vector2(0,5),Vector2(-5,-2)],BRONZE)
	_polygon(_shield,"BossLight",[Vector2(0,-5),Vector2(2,-2),Vector2(0,2),Vector2(-2,-2)],WHITE)
	var runes: Node2D = _pivot(_shield,"RunicBorder",Vector2.ZERO)
	for i: int in 5:
		for side: int in [-1,1]:
			var point: Vector2 = Vector2(side*8,-14+i*5)
			_line(runes,"Rune%d_%d" % [i,side],[point+Vector2(-1,-1),point+Vector2(1,-2),point+Vector2(2,1),point+Vector2(-1,2)],BRONZE,0.8)
	_guard_light = _pivot(_shield,"GuardLight",Vector2.ZERO)
	_line(_guard_light,"ConfirmedShieldRim",[Vector2(-13,-21),Vector2(0,-27),Vector2(15,-20),Vector2(15,4),Vector2(7,18),Vector2(0,24),Vector2(-10,16),Vector2(-14,1),Vector2(-13,-21)],WHITE,2.1)
	for side: int in [-1,1]:
		_line(_guard_light,"AbsorbStreak%d" % side,[Vector2(side*6,-18),Vector2(side*12,-6),Vector2(side*8,9)],WHITE,1.6)
	_halo = _pivot(_geometry,"GroundWard",Vector2(0,23))
	_halo.z_index = -3
	_ring(_halo,"WardRing",29,8,Vector2.ZERO,GOLD,1.0)
	_ring(_halo,"WardEcho",23,6,Vector2.ZERO,BRONZE,0.7)
	for i: int in 12:
		var phase: float = float(i)*TAU/12.0
		var point: Vector2 = Vector2(cos(phase)*27,sin(phase)*7)
		_line(_halo,"WardTick%d" % i,[point,point*1.1],WHITE,1.1)
func _update_pose() -> void:
	if not is_instance_valid(_geometry): return
	var progress: float = clampf(1.0-_attack_remaining/ATTACK_DURATION,0.0,1.0)
	var launch: float = sin(progress*PI) if _attack_remaining>0.0 else 0.0
	_holy_material.set_shader_parameter("visual_clock",_age)
	_holy_material.set_shader_parameter("launch_light",launch)
	_geometry.scale.x = -1.0 if _facing.x < -0.08 else 1.0
	_geometry.rotation = _facing.y*0.08*_geometry.scale.x
	_geometry.position = _facing*launch*minf(_target_offset.length()*0.4,13.0 if visual_profile=="seraph" else 25.0)/maxf(scale.x,0.001)
	_body.position.y = sin(_age*(3.2 if visual_profile=="seraph" else 6.0))*(2.5 if visual_profile=="seraph" else 1.0)-launch*3.0
	_head.rotation = -launch*0.09
	_arm.rotation = -launch*(0.55 if visual_profile=="seraph" else 0.8)
	_halo.modulate.a = 0.70+sin(_age*2.0)*0.15
	var running: float = clampf(_motion.length()/180.0,0.0,1.0)
	for i: int in _wings.size():
		var side: float = -1.0 if i<3 else 1.0
		var rank: float = float(i%3)
		_wings[i].rotation = side*(sin(_age*5.0+rank*0.65)*0.13+launch*(0.22-rank*0.06))
		_wings[i].scale.y = 0.92+sin(_age*5.0+rank*0.65)*0.08+launch*0.08
	for i: int in _legs.size(): _legs[i].rotation = sin(_age*10.0+float(i)*PI)*running*0.30+launch*(-0.23 if i==0 else 0.22)
	if is_instance_valid(_shield):
		var guard: float = sin(clampf(1.0-_guard_remaining/GUARD_DURATION,0.0,1.0)*PI) if _guard_remaining>0.0 else 0.0
		_shield.rotation = -launch*0.28+guard*0.12
		_shield.position.x = 18.0+launch*9.0+guard*5.0
		_guard_light.visible = _guard_remaining>0.0
		_guard_light.modulate.a = guard
	for i: int in _feathers.size():
		var phase: float = _age*0.75+float(i)*TAU/10.0
		_feathers[i].position = Vector2(cos(phase)*(43.0+float(i%3)*5.0),-20.0+sin(phase)*35.0)
		_feathers[i].rotation = sin(phase)*0.8
		_feathers[i].modulate.a = 0.22+0.35*(0.5+0.5*sin(phase))
	_launch_light.visible = _attack_remaining > 0.0
	_launch_light.modulate.a = launch
	_launch_light.scale = Vector2.ONE*(0.65+launch*0.7)
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
func _ring(parent: Node2D, label: String, radius_x: float, radius_y: float, origin: Vector2, tint: Color, width: float) -> void:
	var points: Array[Vector2] = []
	for i: int in 49:
		var phase: float = float(i)*TAU/48.0
		points.append(origin+Vector2(cos(phase)*radius_x,sin(phase)*radius_y))
	_line(parent,label,points,tint,width)
