## 雷霆投射物纯展示。方向、运动与年龄均由投射物宿主提供。
extends Node2D

@export_enum("lightning_orb", "chain_lightning", "thunder_arc") var profile: String = "lightning_orb"

var _age: float = 0.0
var _radius: float = 12.0
var _lifetime: float = 2.0
var _active: bool = true
var _configured: bool = false
var _wake_length: float = 60.0
var _envelope: ColorRect
var _envelope_material: ShaderMaterial
var _lightning: MeshInstance2D
var _lightning_material: ShaderMaterial
static var _lightning_mesh: ArrayMesh


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_ensure_visual_nodes()
	if not _configured:
		configure_projectile({"style": profile})


## 可在入树前配置；实例材质、尾迹节点只创建一次。
func _ensure_visual_nodes() -> void:
	if _envelope_material != null:
		return
	_envelope = get_node("ElectricEnvelope") as ColorRect
	_envelope_material = _envelope.material.duplicate() as ShaderMaterial
	_envelope.material = _envelope_material
	_lightning = MeshInstance2D.new()
	_lightning.name = "BatchedLightning"
	_lightning.mesh = _get_lightning_mesh()
	_lightning_material = ShaderMaterial.new()
	_lightning_material.shader = _envelope_material.shader
	_lightning_material.set_shader_parameter("lightning_pass", true)
	_lightning.material = _lightning_material
	add_child(_lightning)


## 六条12段电丝（432顶点），共享不可变网格；折线与分叉位移只在顶点Shader中计算。
static func _get_lightning_mesh() -> ArrayMesh:
	if _lightning_mesh != null:
		return _lightning_mesh
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	for strand: int in range(6):
		for segment: int in range(12):
			var start: float = segment / 12.0
			var end: float = (segment + 1) / 12.0
			for corner: Vector2 in [Vector2(start, -1), Vector2(end, -1), Vector2(end, 1), Vector2(start, -1), Vector2(end, 1), Vector2(start, 1)]:
				vertices.append(Vector3(corner.x, corner.y, 0.0))
				uv.append(Vector2(float(strand), corner.x))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	_lightning_mesh = ArrayMesh.new()
	_lightning_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _lightning_mesh


func configure_projectile(params: Dictionary) -> void:
	_ensure_visual_nodes()
	_configured = true
	profile = String(params.get("style", "lightning_orb"))
	var kind: int = 0
	match profile:
		"chain_lightning", "chain_lightning_bolt":
			profile = "chain_lightning"
			kind = 1
		"thunder_arc", "thunder_arc_bolt":
			profile = "thunder_arc"
			kind = 2
		_:
			profile = "lightning_orb"
	_radius = maxf(float(params.get("radius", 12.0)), 1.0)
	_lifetime = maxf(float(params.get("lifetime", 2.0)), 0.1)
	_age = 0.0
	_active = true
	visible = true
	rotation = 0.0
	var speed: float = maxf(float(params.get("speed", 600.0)), 0.0)
	var visual_radius: float = _radius * (1.0 if kind == 0 else 0.82 if kind == 1 else 0.67)
	_wake_length = clampf(speed * (0.1 if kind == 0 else 0.15 if kind == 1 else 0.065), visual_radius * 3.0, visual_radius * (8.0 if kind == 1 else 6.0))
	_envelope.position = Vector2(-_wake_length - visual_radius, -visual_radius * 2.0)
	_envelope.size = Vector2(_wake_length + visual_radius * 3.0, visual_radius * 4.0)
	for material: ShaderMaterial in [_envelope_material, _lightning_material]:
		material.set_shader_parameter("style_kind", kind)
		material.set_shader_parameter("effect_radius", visual_radius)
		material.set_shader_parameter("wake_length", _wake_length)
	_envelope_material.set_shader_parameter("canvas_origin", _envelope.position)
	_envelope_material.set_shader_parameter("canvas_extent", _envelope.size)
	# 顶点位移后的电丝尾迹包围盒，保留弹体中心离屏时的可见尾部。
	RenderingServer.canvas_item_set_custom_rect(_lightning.get_canvas_item(), true,
		Rect2(Vector2(-_wake_length - visual_radius * 1.5, -visual_radius * 2.0),
			Vector2(_wake_length + visual_radius * 3.0, visual_radius * 4.0)))
	update_projectile(0.0)


func update_projectile(age: float) -> void:
	if not _active:
		return
	_age = clampf(age, 0.0, _lifetime)
	_envelope_material.set_shader_parameter("effect_age", _age)
	_lightning_material.set_shader_parameter("effect_age", _age)
	modulate.a = clampf((_lifetime - _age) / minf(0.14, _lifetime * 0.2), 0.0, 1.0)


func deactivate() -> void:
	_active = false
	visible = false
