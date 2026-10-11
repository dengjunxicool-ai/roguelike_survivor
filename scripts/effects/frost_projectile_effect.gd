## 文件用途：用切面冰晶、霜雾短尾和固定数量的碎光展示寒霜投射物。
## 使用方式：投射物宿主调用configure_projectile/update_projectile/deactivate；本节点不推进时间或战斗。
extends Node2D

@export_enum("ice_shard", "glacial_lance", "ice_crack_shard") var profile: String = "ice_shard"

var _age: float = 0.0
var _radius: float = 12.0
var _lifetime: float = 2.0
var _active: bool = true
var _configured: bool = false
var _glint_count: int = 8
var _trail_length: float = 48.0
var _trail_material: ShaderMaterial
var _glint_material: ShaderMaterial
static var _diamond_mesh: ArrayMesh

var _body: Polygon2D
var _upper: Polygon2D
var _lower: Polygon2D
var _spine: Line2D
var _trail: ColorRect
var _glints: MeshInstance2D


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_ensure_visual_nodes()
	if not _configured:
		configure_projectile({"style": profile})


## 作用：工厂可在入树前配置；节点引用与每实例材质只初始化一次，不依赖_ready顺序。
func _ensure_visual_nodes() -> void:
	if _trail_material != null:
		return
	_body = get_node("CrystalBody") as Polygon2D
	_upper = get_node("UpperFacet") as Polygon2D
	_lower = get_node("LowerFacet") as Polygon2D
	_spine = get_node("CrystalSpine") as Line2D
	_trail = get_node("FrostTrail") as ColorRect
	_trail_material = _trail.material.duplicate() as ShaderMaterial
	_trail.material = _trail_material
	_glints = MeshInstance2D.new()
	_glints.name = "CrystalGlints"
	_glints.mesh = _get_diamond_mesh()
	_glint_material = ShaderMaterial.new()
	_glint_material.shader = _trail_material.shader
	_glint_material.set_shader_parameter("glint_pass", true)
	_glints.material = _glint_material
	add_child(_glints)
	move_child(_glints, 0)


## 作用：共享72顶点的固定菱形网格；顶点Shader推进12个碎光，避免每物理帧重建绘图和上传。
static func _get_diamond_mesh() -> ArrayMesh:
	if _diamond_mesh != null:
		return _diamond_mesh
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	for index: int in range(12):
		for corner: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]:
			vertices.append(Vector3(corner.x, corner.y, 0.0))
			uv.append(Vector2(float(index), 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	_diamond_mesh = ArrayMesh.new()
	_diamond_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _diamond_mesh


## 作用：按宿主的风格、碰撞半径及寿命重建本地晶体轮廓并重置展示时钟。
## 使用：direction由宿主旋转继承；speed只控制霜尾长度，不影响运动或命中。
func configure_projectile(params: Dictionary) -> void:
	_ensure_visual_nodes()
	_configured = true
	profile = String(params.get("style", "ice_shard"))
	if profile not in ["ice_shard", "glacial_lance", "ice_crack_shard"]:
		profile = "ice_shard"
	_radius = maxf(float(params.get("radius", 12.0)), 1.0)
	_lifetime = maxf(float(params.get("lifetime", 2.0)), 0.1)
	_age = 0.0
	_active = true
	visible = true
	rotation = 0.0
	var tip: float = _radius * 1.9
	var back: float = _radius * 1.5
	var width: float = _radius * 0.6
	_glint_count = 8
	if profile == "glacial_lance":
		tip = _radius * 3.8
		back = _radius * 2.0
		width = _radius * 0.48
		_glint_count = 12
	elif profile == "ice_crack_shard":
		tip = _radius * 1.45
		back = _radius * 0.95
		width = _radius * 0.52
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(tip, 0.0), Vector2(-back * 0.15, -width), Vector2(-back * 0.86, -width * 0.42),
		Vector2(-back, width * 0.15), Vector2(-back * 0.65, width * 0.7), Vector2(-back * 0.08, width)
	])
	_body.polygon = points
	_upper.polygon = PackedVector2Array([points[0], points[1], points[2], Vector2(-back * 0.4, 0.0)])
	_lower.polygon = PackedVector2Array([points[0], Vector2(-back * 0.4, 0.0), points[4], points[5]])
	_spine.points = PackedVector2Array([Vector2(-back * 0.9, width * 0.1), Vector2(-back * 0.35, 0.0), points[0]])
	_spine.width = clampf(_radius * 0.095, 0.8, 2.3)
	_trail_length = clampf(float(params.get("speed", 520.0)) * 0.09, 22.0, 76.0)
	if profile == "glacial_lance":
		_trail_length *= 1.2
	elif profile == "ice_crack_shard":
		_trail_length *= 0.65
	_trail.position = Vector2(-back - _trail_length, -_radius * 1.1)
	_trail.size = Vector2(_trail_length + back * 0.65, _radius * 2.2)
	_trail_material.set_shader_parameter("profile_strength", 1.2 if profile == "glacial_lance" else 0.9)
	_glint_material.set_shader_parameter("effect_radius", _radius)
	_glint_material.set_shader_parameter("wake_length", _trail_length)
	_glint_material.set_shader_parameter("glint_count", _glint_count)
	RenderingServer.canvas_item_set_custom_rect(_glints.get_canvas_item(), true,
		Rect2(Vector2(-_radius - _trail_length - 3.0, -_radius - 1.0), Vector2(_trail_length + 6.0, _radius * 2.0 + 2.0)))
	update_projectile(0.0)


## 作用：从权威年龄更新霜尾与碎光；没有TIME、独立处理、全局随机或节点生成。
func update_projectile(age: float) -> void:
	if not _active:
		return
	_age = clampf(age, 0.0, _lifetime)
	_trail_material.set_shader_parameter("effect_age", _age)
	_glint_material.set_shader_parameter("effect_age", _age)
	var fade: float = clampf((_lifetime - _age) / minf(0.14, _lifetime * 0.2), 0.0, 1.0)
	modulate.a = fade


## 作用：池回收立即隐藏几何和霜尾；同场景复用保留节点，切换场景由宿主释放。
func deactivate() -> void:
	_active = false
	visible = false
