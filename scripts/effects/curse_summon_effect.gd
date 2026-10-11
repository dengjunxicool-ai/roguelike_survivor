## Fixed articulated curse summons. Host delta, target, attack and lifetime are authoritative.
## Soul pearls idle around the crow; casting a projectile never invents a soul collection.
extends Node2D

const SOUL_SHADER: Shader=preload("res://resources/effects/curse_summon.gdshader")
const BONE: Color=Color(0.9,0.87,0.72)
const BONE_SHADE: Color=Color(0.52,0.48,0.4)
const IVORY: Color=Color(1.0,0.98,0.84)
const INK: Color=Color(0.055,0.025,0.095)
const PLUM: Color=Color(0.24,0.085,0.34)
const VIOLET: Color=Color(0.45,0.23,0.55)
const SOUL: Color=Color(0.36,0.96,0.58)
const SOUL_WHITE: Color=Color(0.78,1.0,0.75)
const ATTACK_DURATION: float=0.48
@export_enum("bone_servant","soul_crow") var visual_profile: String="bone_servant"
var _age: float=0.0
var _attack_remaining: float=0.0
var _target_offset: Vector2=Vector2.ZERO
var _facing: Vector2=Vector2.RIGHT
var _motion: Vector2=Vector2.ZERO
var _geometry: Node2D
var _body: Node2D
var _head: Node2D
var _tail: Node2D
var _legs: Array[Node2D]=[]
var _arms: Array[Node2D]=[]
var _wings: Array[Node2D]=[]
var _feathers: Array[Node2D]=[]
var _soul_orbs: Array[Node2D]=[]
var _soul_stream: Node2D
var _attack_flash: Node2D
var _material: ShaderMaterial

func _ready() -> void:
	_build_visual()
	set_process(false)
	_update_pose()

func configure_summon(visual: Dictionary) -> void:
	_build_visual()
	_age=0.0
	_attack_remaining=0.0
	_target_offset=Vector2.ZERO
	_facing=Vector2.RIGHT
	_motion=Vector2.ZERO
	scale=Vector2.ONE*clampf(float(visual.get("effect_scale",1.0)),0.25,3.0)
	modulate.a=1.0
	visible=true
	set_process(false)
	_update_pose()

func face_direction(direction: Vector2) -> void:
	if direction.length_squared()>0.0001: _facing=direction.normalized()

func set_attack_target(offset: Vector2) -> void:
	_target_offset=offset
	face_direction(offset)

func play_attack() -> void:
	_attack_remaining=ATTACK_DURATION
	_update_pose()

func update_summon(delta: float,motion: Vector2,remaining: float) -> void:
	_age+=maxf(delta,0.0)
	_motion=motion
	_attack_remaining=maxf(_attack_remaining-maxf(delta,0.0),0.0)
	modulate.a=clampf(remaining/0.45,0.0,1.0)
	_update_pose()

func deactivate() -> void:
	_attack_remaining=0.0
	visible=false
	_update_pose()

func _build_visual() -> void:
	if is_instance_valid(_geometry): return
	_material=ShaderMaterial.new()
	_material.shader=SOUL_SHADER
	_geometry=_pivot(self,"Geometry",Vector2.ZERO)
	_geometry.material=_material
	_geometry.use_parent_material=false
	_body=_pivot(_geometry,"Body",Vector2.ZERO)
	if visual_profile=="bone_servant": _build_bones()
	else: _build_crow()
	_attack_flash=_pivot(_body,"AttackFlash",Vector2(20,-12))
	if visual_profile=="bone_servant":
		for index: int in 3:
			_line(_attack_flash,"BoneSlash%d" % index,[Vector2(8+index*3,-15),Vector2(19+index*4,-3),Vector2(13+index*3,10)],SOUL_WHITE,1.4)
	else:
		_polygon(_attack_flash,"LaunchFlame",[Vector2(0,-3),Vector2(11,-6),Vector2(26,0),Vector2(12,4),Vector2(0,3)],SOUL)
	_soul_stream=_pivot(_geometry,"SoulAbsorption",Vector2.ZERO)
	# Reserved presentation geometry stays dormant: this API receives attack launch, not hit/death evidence.
	_line(_soul_stream,"DormantTether",[Vector2(30,-12),Vector2(10,-8),Vector2(0,-12)],SOUL,1.2)
	_soul_stream.visible=false

func _build_bones() -> void:
	# Far limbs are darkened; clavicles, spine and rib gaps leave a readable skeleton.
	for index: int in 2:
		var leg: Node2D=_pivot(_body,"Leg%d" % index,Vector2(-7 if index==0 else 7,7))
		leg.z_index=-1 if index==0 else 1
		_legs.append(leg)
		var tint: Color=BONE_SHADE if index==0 else BONE
		_line(leg,"Femur",[Vector2.ZERO,Vector2(-6,11)],tint,5.0)
		_disc(leg,"Knee",Vector2(-6,11),3.6,IVORY if index==1 else tint)
		_line(leg,"Tibia",[Vector2(-6,14),Vector2(-2,27)],tint,3.7)
		_line(leg,"Fibula",[Vector2(-9,14),Vector2(-5,27)],BONE_SHADE,1.4)
		_polygon(leg,"ToeBones",[Vector2(-6,26),Vector2(0,26),Vector2(9,30),Vector2(9,33),Vector2(-6,33)],tint)
		for toe: int in 3: _line(leg,"Toe%d" % toe,[Vector2(3+toe*2,29),Vector2(3+toe*2,33)],INK,0.8)
	_polygon(_body,"TatteredHipCloth",[Vector2(-13,0),Vector2(10,0),Vector2(13,18),Vector2(5,12),Vector2(0,21),Vector2(-6,13),Vector2(-12,19)],PLUM)
	_polygon(_body,"Pelvis",[Vector2(-12,-3),Vector2(-4,-1),Vector2(0,3),Vector2(5,-1),Vector2(12,-4),Vector2(11,4),Vector2(5,9),Vector2(-6,9),Vector2(-12,4)],BONE)
	_line(_body,"Spine",[Vector2(-2,-28),Vector2(-3,-15),Vector2(0,-1)],BONE_SHADE,3.0)
	for index: int in 5:
		_disc(_body,"Vertebra%d" % index,Vector2(-2,-24+index*5),2.3,BONE)
	for index: int in 4:
		var y: float=-26+index*5.0
		_line(_body,"Rib%d" % index,[Vector2(-2,y),Vector2(-12,y-1),Vector2(-15,y+2),Vector2(-9,y+5),Vector2(1,y+5),Vector2(12,y+1),Vector2(10,y-2),Vector2(3,y-1)],BONE,2.5)
	_line(_body,"Sternum",[Vector2(3,-26),Vector2(4,-11)],IVORY,2.4)
	_line(_body,"Clavicle",[Vector2(-17,-28),Vector2(-6,-31),Vector2(3,-29),Vector2(15,-26)],BONE,3.2)
	for index: int in 2:
		var arm: Node2D=_pivot(_body,"Arm%d" % index,Vector2(-14,-28) if index==0 else Vector2(14,-26))
		arm.z_index=-1 if index==0 else 2
		_arms.append(arm)
		var tint: Color=BONE_SHADE if index==0 else BONE
		_disc(arm,"Shoulder",Vector2.ZERO,4.1,tint)
		_line(arm,"Humerus",[Vector2(1,3),Vector2(6,16)],tint,4.4)
		_disc(arm,"Elbow",Vector2(6,17),3.3,IVORY if index==1 else tint)
		_line(arm,"Forearm",[Vector2(7,19),Vector2(12,27)],tint,3.0)
		_line(arm,"Ulna",[Vector2(4,20),Vector2(8,28)],BONE_SHADE,1.8)
		_disc(arm,"Wrist",Vector2(11,28),3.0,tint)
		for claw: int in 3:
			_line(arm,"Phalange%d" % claw,[Vector2(10+claw*2,27),Vector2(17+claw*3,30),Vector2(20+claw*3,35)],tint,1.6)
		if index==1:
			_polygon(arm,"BoneBlade",[Vector2(13,27),Vector2(20,25),Vector2(39,9),Vector2(33,25),Vector2(21,34),Vector2(15,32)],IVORY)
			_line(arm,"BladeMarrow",[Vector2(19,29),Vector2(30,21),Vector2(36,13)],BONE_SHADE,1.0)
	_head=_pivot(_body,"Skull",Vector2(5,-43))
	_polygon(_head,"Cranium",[Vector2(-13,-6),Vector2(-10,-16),Vector2(-2,-21),Vector2(9,-19),Vector2(16,-11),Vector2(17,-3),Vector2(12,6),Vector2(-6,6),Vector2(-13,1)],BONE)
	_polygon(_head,"TempleShadow",[Vector2(-13,-5),Vector2(-7,-8),Vector2(-6,2),Vector2(-2,6),Vector2(-7,7),Vector2(-13,1)],BONE_SHADE)
	_line(_head,"SkullCrack",[Vector2(-1,-19),Vector2(-4,-14),Vector2(0,-11),Vector2(-3,-8)],BONE_SHADE,1.1)
	for index: int in 2:
		var socket: Node2D=_pivot(_head,"EyeSocketFar" if index==0 else "EyeSocketNear",Vector2(-5,-5) if index==0 else Vector2(8,-5))
		_polygon(socket,"Cavity",[Vector2(-4,-4),Vector2(4,-3),Vector2(4,2),Vector2(0,5),Vector2(-4,2)],INK)
		_polygon(socket,"SoulFire",[Vector2(-2,2),Vector2(-3,-1),Vector2(-1,-6),Vector2(0,-2),Vector2(2,-5),Vector2(3,1),Vector2(1,3)],SOUL)
		_line(socket,"FlameHeart",[Vector2(0,2),Vector2(0,-2)],SOUL_WHITE,1.1)
	_polygon(_head,"NasalCavity",[Vector2(2,0),Vector2(5,5),Vector2(-1,5)],INK)
	_polygon(_head,"Jaw",[Vector2(-8,5),Vector2(12,5),Vector2(10,12),Vector2(-5,13),Vector2(-9,9)],IVORY)
	_line(_head,"Mouth",[Vector2(-6,7),Vector2(11,6)],INK,1.3)
	for tooth: int in 5: _line(_head,"Tooth%d" % tooth,[Vector2(-4+tooth*3,6),Vector2(-3+tooth*3,10)],BONE_SHADE,1.0)

func _build_crow() -> void:
	# The soul crow is an upright broad-winged specter with long drooping finger feathers.
	# Storm crow has a short horizontal body, upward flight wings and lightning vanes.
	for index: int in 2:
		var wing: Node2D=_pivot(_body,"Wing%d" % index,Vector2(-5,-18))
		wing.z_index=-1 if index==0 else 1
		wing.scale=Vector2(0.86,0.86) if index==0 else Vector2.ONE
		_wings.append(wing)
		_polygon(wing,"WingShoulder",[Vector2(3,3),Vector2(-12,-14),Vector2(-39,-15),Vector2(-54,-2),Vector2(-44,6),Vector2(-23,12),Vector2(-4,14)],PLUM if index==1 else INK)
		for feather: int in 5:
			var vane: Node2D=_pivot(wing,"FingerFeather%d" % feather,Vector2(-15-feather*7,-8+feather*1.0))
			_polygon(vane,"PointedVane",[Vector2(0,-4),Vector2(-7,0),Vector2(-10,15+feather*3),Vector2(-6,27+feather*2),Vector2(-1,15),Vector2(4,2)],INK)
			_line(vane,"PurpleRachis",[Vector2(0,0),Vector2(-5,14),Vector2(-6,23+feather*2)],VIOLET,1.0)
			_polygon(vane,"PlumCovert",[Vector2(0,-3),Vector2(-5,0),Vector2(-7,10),Vector2(-3,7),Vector2(1,2)],PLUM)
			_feathers.append(vane)
		_line(wing,"ShoulderSeam",[Vector2(0,-3),Vector2(-13,-13),Vector2(-35,-13),Vector2(-48,-4)],VIOLET,1.8)
	_tail=_pivot(_body,"LongTail",Vector2(-8,5))
	for index: int in 3:
		_polygon(_tail,"TailFeather%d" % index,[Vector2(index*4-5,0),Vector2(index*5-13,31),Vector2(index*5-6,24),Vector2(index*4+1,0)],INK)
		_line(_tail,"TailVane%d" % index,[Vector2(index*4-2,3),Vector2(index*5-9,24)],VIOLET,0.9)
	_polygon(_body,"SpectralBody",[Vector2(-15,-22),Vector2(-7,-33),Vector2(7,-29),Vector2(14,-14),Vector2(8,7),Vector2(-3,15),Vector2(-14,2)],INK)
	_polygon(_body,"BreastPlum",[Vector2(2,-24),Vector2(12,-15),Vector2(7,7),Vector2(-1,12),Vector2(-7,0)],PLUM)
	var core: Node2D=_pivot(_body,"SoulCore",Vector2(2,-8))
	_polygon(core,"Cage",[Vector2(0,-11),Vector2(8,-4),Vector2(5,7),Vector2(-1,12),Vector2(-6,4),Vector2(-6,-5)],VIOLET)
	_polygon(core,"SoulFlame",[Vector2(0,-9),Vector2(4,-3),Vector2(3,4),Vector2(-1,8),Vector2(-4,2),Vector2(-3,-3)],SOUL)
	_polygon(core,"Heart",[Vector2(0,-4),Vector2(2,0),Vector2(0,5),Vector2(-2,1)],SOUL_WHITE)
	for index: int in 2:
		_line(_body,"HookTalon%d" % index,[Vector2(3+index*5,7),Vector2(3+index*5,18),Vector2(9+index*5,20),Vector2(12+index*5,15)],BONE_SHADE,1.5)
	_head=_pivot(_body,"CrowSkull",Vector2(8,-34))
	_polygon(_head,"Hood",[Vector2(-9,-2),Vector2(-12,-15),Vector2(-6,-21),Vector2(5,-21),Vector2(15,-12),Vector2(14,-1),Vector2(5,8),Vector2(-7,6)],INK)
	_polygon(_head,"HoodCrest",[Vector2(-12,-11),Vector2(-17,-27),Vector2(-4,-19),Vector2(1,-25),Vector2(7,-19)],PLUM)
	_polygon(_head,"Mask",[Vector2(-3,-16),Vector2(7,-16),Vector2(13,-9),Vector2(10,-2),Vector2(3,1),Vector2(-3,-4)],VIOLET)
	_polygon(_head,"HookedBeak",[Vector2(11,-8),Vector2(28,-4),Vector2(24,6),Vector2(21,0),Vector2(10,-1)],BONE_SHADE)
	_line(_head,"BeakEdge",[Vector2(13,-5),Vector2(25,-3),Vector2(24,1)],BONE,1.2)
	_polygon(_head,"SoulEye",[Vector2(3,-11),Vector2(10,-9),Vector2(6,-5),Vector2(2,-7)],SOUL)
	_disc(_head,"EyeHeart",Vector2(6,-8),1.4,SOUL_WHITE)
	for index: int in 3:
		var pearl: Node2D=_pivot(_geometry,"IdleSoulPearl%d" % index,Vector2.ZERO)
		_disc(pearl,"Halo",Vector2.ZERO,4.5,Color(0.17,0.6,0.35,0.28))
		_disc(pearl,"Pearl",Vector2.ZERO,2.5,SOUL)
		_disc(pearl,"PearlHeart",Vector2(-0.5,-0.6),1.0,SOUL_WHITE)
		_soul_orbs.append(pearl)

func _update_pose() -> void:
	if not is_instance_valid(_geometry): return
	var progress: float=clampf(1.0-_attack_remaining/ATTACK_DURATION,0.0,1.0)
	var burst: float=sin(progress*PI) if _attack_remaining>0.0 else 0.0
	_material.set_shader_parameter("visual_clock",_age)
	_material.set_shader_parameter("attack_light",burst)
	_geometry.scale.x=-1.0 if _facing.x < -0.08 else 1.0
	_geometry.rotation=_facing.y*0.11*_geometry.scale.x
	_geometry.position=_facing*burst*minf(_target_offset.length()*0.5,30.0 if visual_profile=="bone_servant" else 12.0)/maxf(scale.x,0.001)
	var running: float=clampf(_motion.length()/170.0,0.0,1.0)
	_body.position.y=sin(_age*(8.0 if visual_profile=="bone_servant" else 3.2))*(running*1.8 if visual_profile=="bone_servant" else 3.0)-burst*3.0
	_body.rotation=burst*(-0.14 if visual_profile=="bone_servant" else 0.12)
	_head.rotation=sin(_age*2.6)*0.045-burst*0.11
	for index: int in _legs.size(): _legs[index].rotation=sin(_age*9.0+index*PI)*running*0.43+burst*(-0.2 if index==0 else 0.2)
	for index: int in _arms.size(): _arms[index].rotation=sin(_age*9.0+index*PI)*running*0.16-burst*(0.35 if index==0 else 1.3)
	if is_instance_valid(_tail): _tail.rotation=sin(_age*3.6)*0.12+burst*0.18
	for index: int in _wings.size():
		_wings[index].rotation=sin(_age*5.5+index*0.8)*0.23+burst*0.46
		_wings[index].scale.y=0.9+sin(_age*5.5+index*0.8)*0.12
	for index: int in _feathers.size(): _feathers[index].rotation=sin(_age*3.2+index*0.45)*0.10+burst*0.12
	for index: int in _soul_orbs.size():
		var phase: float=_age*0.8+index*TAU/3.0
		_soul_orbs[index].position=Vector2(cos(phase)*29.0,-17.0+sin(phase)*22.0)
		_soul_orbs[index].modulate.a=0.5+0.25*sin(phase)
	_attack_flash.visible=_attack_remaining>0.0
	_attack_flash.modulate.a=burst
	_soul_stream.visible=false

func _pivot(parent: Node,label: String,origin: Vector2) -> Node2D:
	var node: Node2D=Node2D.new()
	node.name=label
	node.position=origin
	node.use_parent_material=true
	parent.add_child(node)
	return node

func _polygon(parent: Node2D,label: String,points: Array[Vector2],tint: Color) -> Polygon2D:
	var node: Polygon2D=Polygon2D.new()
	node.name=label
	node.polygon=PackedVector2Array(points)
	node.color=tint
	node.antialiased=true
	node.use_parent_material=true
	parent.add_child(node)
	return node

func _line(parent: Node2D,label: String,points: Array[Vector2],tint: Color,width: float) -> Line2D:
	var node: Line2D=Line2D.new()
	node.name=label
	node.points=PackedVector2Array(points)
	node.default_color=tint
	node.width=width
	node.antialiased=true
	node.use_parent_material=true
	parent.add_child(node)
	return node

func _disc(parent: Node2D,label: String,center: Vector2,radius: float,tint: Color) -> Polygon2D:
	var points: Array[Vector2]=[]
	for index: int in 12: points.append(center+Vector2.from_angle(index*TAU/12.0)*radius)
	return _polygon(parent,label,points,tint)
