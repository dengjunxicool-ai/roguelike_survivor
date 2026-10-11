## 真实魂链/疫咒端点间的短寿命展示；外部管理24实例池，不触发战斗行为。
extends Node2D

const DURATION: float = 0.42
const SEGMENTS: int = 24
const LINK_SHADER: Shader = preload("res://resources/effects/curse_projectile_link.gdshader")
var _age: float = 0.0
var _active: bool = false
var _lines: Array[Line2D] = []
var _souls: MeshInstance2D
var _material: ShaderMaterial
static var _mesh: ArrayMesh

func _ready() -> void:
	_ensure_visual_nodes()
	set_process(_active)

func _ensure_visual_nodes() -> void:
	if not _lines.is_empty():
		return
	top_level = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 4
	for index: int in range(4):
		var line: Line2D = Line2D.new()
		line.name = "Core" if index == 3 else "SoulLayer%d" % index
		line.width = [10.0, 5.0, 2.5, 0.9][index]
		line.default_color = [Color(0.3, 0.08, 0.5, 0.2), Color(0.56, 0.18, 0.8, 0.4), Color(0.3, 0.8, 0.46, 0.65), Color(0.86, 0.93, 0.78, 0.88)][index]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		add_child(line)
		_lines.append(line)
	_souls = MeshInstance2D.new()
	_souls.name = "BatchedSouls"
	_souls.mesh = _get_mesh()
	_material = ShaderMaterial.new()
	_material.shader = LINK_SHADER
	_souls.material = _material
	add_child(_souls)

static func _get_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	for index: int in range(16):
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			vertices.append(Vector3(corner.x, corner.y, 0.0))
			uv.append(Vector2(float(index), 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh

## kind0装饰魂珠从目标朝施法者；kind1疫咒丝缕朝扩散目标。无伤害或事件。
func configure(from: Vector2, to: Vector2, seed: float, kind: int = 0) -> void:
	_ensure_visual_nodes()
	global_position = from
	global_rotation = 0.0
	global_scale = Vector2.ONE
	_age = 0.0
	_active = true
	visible = true
	modulate = Color.WHITE
	var span: Vector2 = to - from
	var length: float = span.length()
	var direction: Vector2 = span.normalized() if length > 0.001 else Vector2.RIGHT
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	# Deterministic local phase, independent of gameplay RNG.
	var phase: float = fposmod(seed * 1.618034, TAU)
	var bend: float = minf(length * 0.065, 22.0)
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(SEGMENTS + 1):
		var t: float = index / float(SEGMENTS)
		points.append(span * t + normal * bend * sin(t * PI) * sin(t * TAU + phase))
	points[0] = Vector2.ZERO
	points[SEGMENTS] = span
	for line: Line2D in _lines:
		line.points = points
	_material.set_shader_parameter("link_span", span)
	_material.set_shader_parameter("link_bend", bend)
	_material.set_shader_parameter("link_phase", phase)
	_material.set_shader_parameter("link_kind", clampi(kind, 0, 1))
	_material.set_shader_parameter("effect_age", 0.0)
	RenderingServer.canvas_item_set_custom_rect(_souls.get_canvas_item(), true,
		Rect2(Vector2(minf(span.x, 0.0), minf(span.y, 0.0)) - Vector2.ONE * (bend + 12.0),
			Vector2(absf(span.x), absf(span.y)) + Vector2.ONE * (bend + 12.0) * 2.0))
	set_process(true)

func _process(delta: float) -> void:
	if not _active:
		return
	_age += maxf(delta, 0.0)
	if _age >= DURATION:
		deactivate()
		return
	_material.set_shader_parameter("effect_age", _age)
	modulate.a = pow(1.0 - _age / DURATION, 0.65)

func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)
