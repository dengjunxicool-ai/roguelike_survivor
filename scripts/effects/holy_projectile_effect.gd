## 神圣弹体纯展示：白金硬光、符刻与羽光；运动、方向和年龄由Projectile驱动。
extends Node2D

@export_enum("holy_ray", "seraph_bolt") var profile: String = "holy_ray"
var _age: float = 0.0
var _radius: float = 12.0
var _lifetime: float = 2.0
var _active: bool = false
var _configured: bool = false
var _wake_length: float = 48.0
var _envelope: ColorRect
var _envelope_material: ShaderMaterial
var _feathers: MeshInstance2D
var _feather_material: ShaderMaterial
static var _feather_mesh: ArrayMesh

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_ensure_visual_nodes()
	if not _configured:
		configure_projectile({"style": profile})

## 支持树外配置；ready不会覆盖年龄。每实例仅一次初始化展示节点和隔离材质。
func _ensure_visual_nodes() -> void:
	if _envelope_material != null:
		return
	_envelope = get_node("HolyEnvelope") as ColorRect
	_envelope_material = _envelope.material.duplicate() as ShaderMaterial
	_envelope.material = _envelope_material
	_feathers = MeshInstance2D.new()
	_feathers.name = "BatchedFeathers"
	_feathers.mesh = _get_feather_mesh()
	_feather_material = ShaderMaterial.new()
	_feather_material.shader = _envelope_material.shader
	_feather_material.set_shader_parameter("feather_pass", true)
	_feathers.material = _feather_material
	add_child(_feathers)

## 24片144顶点的共用不可变羽光网格；飞行中只更新材质年龄，不生成节点。
static func _get_feather_mesh() -> ArrayMesh:
	if _feather_mesh != null:
		return _feather_mesh
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
	_feather_mesh = ArrayMesh.new()
	_feather_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _feather_mesh

func configure_projectile(params: Dictionary) -> void:
	_ensure_visual_nodes()
	_configured = true
	profile = String(params.get("style", "holy_ray"))
	if profile == "holy_ray_beam":
		profile = "holy_ray"
	elif profile == "seraph_holy_bolt":
		profile = "seraph_bolt"
	elif profile not in ["holy_ray", "seraph_bolt"]:
		profile = "holy_ray"
	var kind: int = 1 if profile == "seraph_bolt" else 0
	_radius = clampf(_finite_number(params.get("radius", 12.0), 12.0), 1.0, 256.0)
	_lifetime = clampf(_finite_number(params.get("lifetime", 2.0), 2.0), 0.1, 120.0)
	var speed: float = clampf(_finite_number(params.get("speed", 520.0), 520.0), 0.0, 5000.0)
	var effect_seed: float = fposmod(_finite_number(params.get("seed", 0.0), 0.0), 4096.0)
	_wake_length = clampf(speed * (0.14 if kind == 0 else 0.1), _radius * 2.0, _radius * 7.0)
	_age = 0.0
	_active = true
	visible = true
	rotation = 0.0
	_envelope.position = Vector2(-_wake_length - _radius * 1.4, -_radius * 1.65)
	_envelope.size = Vector2(_wake_length + _radius * 5.7, _radius * 3.3)
	for material: ShaderMaterial in [_envelope_material, _feather_material]:
		material.set_shader_parameter("style_kind", kind)
		material.set_shader_parameter("effect_radius", _radius)
		material.set_shader_parameter("wake_length", _wake_length)
		material.set_shader_parameter("effect_seed", effect_seed)
	_envelope_material.set_shader_parameter("canvas_origin", _envelope.position)
	_envelope_material.set_shader_parameter("canvas_extent", _envelope.size)
	RenderingServer.canvas_item_set_custom_rect(_feathers.get_canvas_item(), true, Rect2(_envelope.position, _envelope.size))
	update_projectile(0.0)

## 外部权威年龄驱动所有层；无TIME、处理时钟、全局随机或战斗调用。
func update_projectile(age: float) -> void:
	if not _active:
		return
	_age = clampf(age if is_finite(age) else 0.0, 0.0, _lifetime)
	_envelope_material.set_shader_parameter("effect_age", _age)
	_feather_material.set_shader_parameter("effect_age", _age)
	modulate.a = clampf((_lifetime - _age) / minf(0.16, _lifetime * 0.2), 0.0, 1.0)

func deactivate() -> void:
	_active = false
	visible = false

func _finite_number(value: Variant, fallback: float) -> float:
	var number: float = float(value)
	return number if is_finite(number) else fallback
