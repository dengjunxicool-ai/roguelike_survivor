## 混沌球纯展示：裂纹玻璃壳、青白核心、多边形环及固定碎片尾迹。
## 朝向、位置和年龄来自实际 Projectile；几何分支只标识本次发射类型。
extends Node2D

@export_enum("chaos_orb") var profile: String = "chaos_orb"
var _age: float = 0.0
var _radius: float = 14.0
var _lifetime: float = 2.0
var _active: bool = false
var _configured: bool = false
var _wake_length: float = 48.0
var _envelope: ColorRect
var _envelope_material: ShaderMaterial
var _fragments: MeshInstance2D
var _fragment_material: ShaderMaterial
static var _fragment_mesh: ArrayMesh

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_ensure_visual_nodes()
	if not _configured:
		configure_projectile({"style": profile})

func _ensure_visual_nodes() -> void:
	if _envelope_material != null:
		return
	_envelope = get_node("ChaosEnvelope") as ColorRect
	_envelope_material = _envelope.material.duplicate() as ShaderMaterial
	_envelope.material = _envelope_material
	_fragments = MeshInstance2D.new()
	_fragments.name = "BatchedFragments"
	_fragments.mesh = _get_fragment_mesh()
	_fragment_material = ShaderMaterial.new()
	_fragment_material.shader = _envelope_material.shader
	_fragment_material.set_shader_parameter("fragment_pass", true)
	_fragments.material = _fragment_material
	add_child(_fragments)

## 24片碎晶共144顶点；实例共用不可变网格，飞行期间只改变材质参数。
static func _get_fragment_mesh() -> ArrayMesh:
	if _fragment_mesh != null:
		return _fragment_mesh
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			vertices.append(Vector3(corner.x, corner.y, 0.0))
			uv.append(Vector2(float(index), 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	_fragment_mesh = ArrayMesh.new()
	_fragment_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _fragment_mesh

func configure_projectile(params: Dictionary) -> void:
	_ensure_visual_nodes()
	_configured = true
	profile = "chaos_orb"
	_radius = clampf(_finite_number(params.get("radius", 14.0), 14.0), 1.0, 256.0)
	_lifetime = clampf(_finite_number(params.get("lifetime", 2.0), 2.0), 0.1, 120.0)
	var speed: float = clampf(_finite_number(params.get("speed", 360.0), 360.0), 0.0, 5000.0)
	var effect_seed: float = fposmod(_finite_number(params.get("seed", 0.0), 0.0), 4096.0)
	var raw_branch: float = _finite_number(params.get("geometry_branch", -1), -1.0)
	var branch: int = int(raw_branch) if raw_branch >= -1.0 and raw_branch <= 2.0 else -1
	_wake_length = clampf(speed * 0.14, _radius * 2.0, _radius * 6.0)
	_age = 0.0
	_active = true
	visible = true
	rotation = 0.0
	_envelope.position = Vector2(-_wake_length - _radius * 1.1, -_radius * 1.8)
	_envelope.size = Vector2(_wake_length + _radius * 2.9, _radius * 3.6)
	for material: ShaderMaterial in [_envelope_material, _fragment_material]:
		material.set_shader_parameter("effect_radius", _radius)
		material.set_shader_parameter("wake_length", _wake_length)
		material.set_shader_parameter("effect_seed", effect_seed)
		material.set_shader_parameter("geometry_branch", branch)
	_envelope_material.set_shader_parameter("canvas_origin", _envelope.position)
	_envelope_material.set_shader_parameter("canvas_extent", _envelope.size)
	RenderingServer.canvas_item_set_custom_rect(_fragments.get_canvas_item(), true, Rect2(_envelope.position, _envelope.size))
	update_projectile(0.0)

func update_projectile(age: float) -> void:
	if not _active:
		return
	_age = clampf(age if is_finite(age) else 0.0, 0.0, _lifetime)
	_envelope_material.set_shader_parameter("effect_age", _age)
	_fragment_material.set_shader_parameter("effect_age", _age)
	modulate.a = clampf((_lifetime - _age) / minf(0.16, _lifetime * 0.2), 0.0, 1.0)

func deactivate() -> void:
	_active = false
	visible = false

func _finite_number(value: Variant, fallback: float) -> float:
	var number: float = float(value)
	return number if is_finite(number) else fallback
