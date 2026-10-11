## 诅咒投射物纯展示；位置、方向、飞行与年龄完全由Projectile宿主驱动。
extends Node2D

@export_enum("black_serpent", "death_scythe", "soul_bolt", "soul_storm") var profile: String = "black_serpent"
var _age: float = 0.0
var _radius: float = 12.0
var _lifetime: float = 2.0
var _active: bool = false
var _configured: bool = false
var _wake_length: float = 48.0
var _envelope: ColorRect
var _envelope_material: ShaderMaterial
var _souls: MeshInstance2D
var _soul_material: ShaderMaterial
static var _soul_mesh: ArrayMesh

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_ensure_visual_nodes()
	if not _configured:
		configure_projectile({"style": profile})

## 支持工厂在入树前配置，ready不会重置外部传来的年龄。
func _ensure_visual_nodes() -> void:
	if _envelope_material != null:
		return
	_envelope = get_node("CurseEnvelope") as ColorRect
	_envelope_material = _envelope.material.duplicate() as ShaderMaterial
	_envelope.material = _envelope_material
	_souls = MeshInstance2D.new()
	_souls.name = "BatchedSouls"
	_souls.mesh = _get_soul_mesh()
	_soul_material = ShaderMaterial.new()
	_soul_material.shader = _envelope_material.shader
	_soul_material.set_shader_parameter("soul_pass", true)
	_souls.material = _soul_material
	add_child(_souls)

## 所有实例共用24枚144顶点网格；尾迹运动只发生在shader内。
static func _get_soul_mesh() -> ArrayMesh:
	if _soul_mesh != null:
		return _soul_mesh
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
	_soul_mesh = ArrayMesh.new()
	_soul_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _soul_mesh

func configure_projectile(params: Dictionary) -> void:
	_ensure_visual_nodes()
	_configured = true
	profile = String(params.get("style", "black_serpent"))
	var kind: int = ["black_serpent", "death_scythe", "soul_bolt", "soul_storm"].find(profile)
	if kind < 0:
		kind = 0
		profile = "black_serpent"
	_radius = maxf(float(params.get("radius", 12.0)), 1.0)
	_lifetime = maxf(float(params.get("lifetime", 2.0)), 0.1)
	_age = 0.0
	_active = true
	visible = true
	rotation = 0.0
	var speed: float = maxf(float(params.get("speed", 520.0)), 0.0)
	_wake_length = clampf(speed * (0.11 if kind == 0 else 0.085 if kind == 1 else 0.13 if kind == 2 else 0.17), _radius * 3.0, _radius * (7.0 if kind < 3 else 10.0))
	_envelope.position = Vector2(-_wake_length - _radius * 1.3, -_radius * 2.2)
	_envelope.size = Vector2(_wake_length + _radius * 3.1, _radius * 4.4)
	for material: ShaderMaterial in [_envelope_material, _soul_material]:
		material.set_shader_parameter("style_kind", kind)
		material.set_shader_parameter("effect_radius", _radius)
		material.set_shader_parameter("wake_length", _wake_length)
		material.set_shader_parameter("effect_seed", float(params.get("seed", 0.0)))
	_envelope_material.set_shader_parameter("canvas_origin", _envelope.position)
	_envelope_material.set_shader_parameter("canvas_extent", _envelope.size)
	RenderingServer.canvas_item_set_custom_rect(_souls.get_canvas_item(), true, Rect2(_envelope.position, _envelope.size))
	update_projectile(0.0)

func update_projectile(age: float) -> void:
	if not _active:
		return
	_age = clampf(age, 0.0, _lifetime)
	_envelope_material.set_shader_parameter("effect_age", _age)
	_soul_material.set_shader_parameter("effect_age", _age)
	modulate.a = clampf((_lifetime - _age) / minf(0.16, _lifetime * 0.2), 0.0, 1.0)

func deactivate() -> void:
	_active = false
	visible = false
