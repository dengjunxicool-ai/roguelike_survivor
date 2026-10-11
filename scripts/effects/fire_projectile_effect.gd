## 火焰投射物展示：热核火球、带热壳的陨石、紧凑追踪余烬。
## 宿主负责方向和年龄；本节点不推进时间，不参与运动、碰撞或伤害。
extends Node2D

@export_enum("fireball", "meteor", "ember_attachment_bolt") var profile: String = "fireball"

var _age: float = 0.0
var _radius: float = 12.0
var _lifetime: float = 2.0
var _active: bool = true
var _configured: bool = false
var _wake_length: float = 48.0
var _flame: ColorRect
var _flame_material: ShaderMaterial
var _embers: MeshInstance2D
var _ember_material: ShaderMaterial
static var _ember_mesh: ArrayMesh


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_ensure_visual_nodes()
	if not _configured:
		configure_projectile({"style": profile})


## 工厂可能在入树前配置；子节点和实例材质只初始化一次。
func _ensure_visual_nodes() -> void:
	if _flame_material != null:
		return
	_flame = get_node("FireEnvelope") as ColorRect
	_flame_material = _flame.material.duplicate() as ShaderMaterial
	_flame.material = _flame_material
	_embers = MeshInstance2D.new()
	_embers.name = "BatchedEmbers"
	_embers.mesh = _get_ember_mesh()
	_ember_material = ShaderMaterial.new()
	_ember_material.shader = _flame_material.shader
	_ember_material.set_shader_parameter("ember_pass", true)
	_embers.material = _ember_material
	add_child(_embers)


## 16枚余烬的静态96顶点网格；位置、长度、亮度在顶点材质中计算。
static func _get_ember_mesh() -> ArrayMesh:
	if _ember_mesh != null:
		return _ember_mesh
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	for index: int in range(16):
		for corner: Vector2 in [Vector2(1, 0), Vector2(-0.35, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(-0.35, 1)]:
			vertices.append(Vector3(corner.x, corner.y, 0.0))
			uv.append(Vector2(float(index), 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	_ember_mesh = ArrayMesh.new()
	_ember_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _ember_mesh


## 按真实半径、速度与寿命重建轮廓；朝向继承宿主，避免direction二次旋转。
func configure_projectile(params: Dictionary) -> void:
	_ensure_visual_nodes()
	_configured = true
	profile = String(params.get("style", "fireball"))
	var style_kind: int = 0
	match profile:
		"meteor", "meteor_rain_meteor", "inferno_cycle_meteor":
			profile = "meteor"
			style_kind = 1
		"ember_attachment_bolt", "fire_ember":
			profile = "ember_attachment_bolt"
			style_kind = 2
		_:
			profile = "fireball"
	_radius = maxf(float(params.get("radius", 12.0)), 1.0)
	_lifetime = maxf(float(params.get("lifetime", 2.0)), 0.1)
	_age = 0.0
	_active = true
	visible = true
	rotation = 0.0
	var visual_radius: float = _radius
	var speed: float = maxf(float(params.get("speed", 520.0)), 0.0)
	var ember_count: int = 12
	_wake_length = clampf(speed * 0.075, _radius * 2.0, _radius * 5.0)
	if style_kind == 1:
		_wake_length = clampf(speed * 0.18, _radius * 6.0, _radius * 11.0) * 1.35
		ember_count = 16
	elif style_kind == 2:
		visual_radius *= 0.55
		_wake_length = clampf(speed * 0.035, _radius * 1.2, _radius * 2.8)
		ember_count = 6
	var height: float = visual_radius * (2.6 if style_kind == 2 else 3.6)
	_flame.position = Vector2(-_wake_length - visual_radius * 0.9, -height * 0.5)
	_flame.size = Vector2(_wake_length + visual_radius * 2.5, height)
	for material: ShaderMaterial in [_flame_material, _ember_material]:
		material.set_shader_parameter("style_kind", style_kind)
		material.set_shader_parameter("effect_radius", visual_radius)
		material.set_shader_parameter("wake_length", _wake_length)
		material.set_shader_parameter("ember_count", ember_count)
	_flame_material.set_shader_parameter("canvas_origin", _flame.position)
	_flame_material.set_shader_parameter("canvas_extent", _flame.size)
	# Shader位移超出原始微小网格；显式包围盒让出屏弹体的长尾仍能被裁剪系统保留。
	RenderingServer.canvas_item_set_custom_rect(_embers.get_canvas_item(), true,
		Rect2(Vector2(-_wake_length - visual_radius * 1.5 - 8.0, -visual_radius * 1.9 - 4.0),
			Vector2(_wake_length + visual_radius * 2.5 + 16.0, visual_radius * 3.8 + 8.0)))
	update_projectile(0.0)


## 全部火舌、热壳和余烬只读取权威年龄；保留父级COLOR保证末尾淡出。
func update_projectile(age: float) -> void:
	if not _active:
		return
	_age = clampf(age, 0.0, _lifetime)
	_flame_material.set_shader_parameter("effect_age", _age)
	_ember_material.set_shader_parameter("effect_age", _age)
	modulate.a = clampf((_lifetime - _age) / minf(0.16, _lifetime * 0.2), 0.0, 1.0)


## 回池立即关闭展示；复用保留材质和网格，configure重置年龄与形状。
func deactivate() -> void:
	_active = false
	visible = false
