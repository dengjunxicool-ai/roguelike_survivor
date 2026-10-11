## Host-owned age and geometry; all motion stays inside static render batches.
extends Node2D

@export var effect_style: String = "ball_lightning_path"
const AreaShader := preload("res://resources/effects/thunder_area.gdshader")
const CloudShader := preload("res://resources/effects/thunder_cloud.gdshader")
const STYLES := {"ball_lightning_path":0, "ball_lightning_orb":1, "thunderstorm_cloud":2, "lightning_strike":3, "emp_ring":4, "overload_burst":5, "magnetic_pull":6}
const ARC_COUNT := 24
var effect_radius := 100.0
var effect_duration := 3.0
var effect_age := 0.0
var effect_shape := "circle"
var _length := 200.0
var _width := 50.0
var _heading := Vector2.RIGHT
var _angle := 360.0
var _phase := 0.0
var _pending_style := ""
var _pending_geometry: Dictionary = {}
var _surface: Polygon2D
var _core: Polygon2D
var _cloud: Polygon2D
var _arcs: MeshInstance2D
var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
	_ensure_visuals()

func _ensure_visuals() -> void:
	if _surface != null:
		return
	_surface = _new_plane("ThunderSurface", 0)
	_core = _new_plane("ThunderCore", 1)
	_cloud = Polygon2D.new()
	_cloud.name = "ThunderCloud"
	var material := ShaderMaterial.new()
	material.shader = CloudShader
	_cloud.material = material
	_materials.append(material)
	add_child(_cloud)
	_arcs = MeshInstance2D.new()
	_arcs.name = "ThunderArcs"
	_arcs.material = _new_material(2)
	add_child(_arcs)

func _new_material(layer: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = AreaShader
	material.set_shader_parameter("layer", layer)
	_materials.append(material)
	return material

func _new_plane(node_name: String, layer: int) -> Polygon2D:
	var plane := Polygon2D.new()
	plane.name = node_name
	plane.material = _new_material(layer)
	add_child(plane)
	return plane

func set_effect_style(style: String) -> void:
	_pending_style = style if STYLES.has(style) else "ball_lightning_path"

func set_effect_geometry(snapshot: Dictionary) -> void:
	_pending_geometry = snapshot.duplicate(true)

func configure(radius: float, duration: float, visual_phase: float) -> void:
	_ensure_visuals()
	visible = true
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	effect_style = _pending_style if not _pending_style.is_empty() else "ball_lightning_path"
	effect_shape = String(_pending_geometry.get("shape", "circle"))
	if effect_shape not in ["circle", "line", "cross", "cone"]:
		effect_shape = "circle"
	_length = maxf(float(_pending_geometry.get("length", radius * 2.0)), 1.0)
	_width = maxf(float(_pending_geometry.get("width", radius * 0.5)), 1.0)
	_heading = _pending_geometry.get("direction", Vector2.RIGHT)
	_heading = _heading.normalized() if _heading.length_squared() > 0.0001 else Vector2.RIGHT
	_angle = clampf(float(_pending_geometry.get("angle", 360.0)), 1.0, 360.0)
	_phase = visual_phase
	_pending_style = ""
	_pending_geometry.clear()
	_core.visible = effect_style in ["ball_lightning_orb", "lightning_strike", "overload_burst"]
	_cloud.visible = effect_style == "thunderstorm_cloud"
	set_effect_radius(radius)
	update_state(radius, 0.0, duration)

func update_state(radius: float, age: float, duration: float) -> void:
	if not visible:
		return
	_ensure_visuals()
	if not is_equal_approx(effect_radius, maxf(radius, 1.0)):
		set_effect_radius(radius)
	effect_age = maxf(age, 0.0)
	effect_duration = maxf(duration, 0.05)
	var progress := clampf(effect_age / effect_duration, 0.0, 1.0)
	var transient := effect_style in ["lightning_strike", "emp_ring", "overload_burst"]
	var attack := minf(0.018 if transient else 0.08, effect_duration * 0.12)
	var release := minf(0.20 if transient else 0.35, effect_duration * 0.32)
	modulate.a = smoothstep(0.0, attack, effect_age) * smoothstep(0.0, release, effect_duration - effect_age)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("effect_age", effect_age)
		material.set_shader_parameter("progress", progress)

func set_effect_radius(radius: float) -> void:
	effect_radius = maxf(radius, 1.0)
	if _surface == null:
		return
	_build_geometry()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("profile", STYLES.get(effect_style, 0))
		material.set_shader_parameter("phase", _phase)
		material.set_shader_parameter("effect_radius", effect_radius)
		material.set_shader_parameter("footprint_length", _length)
		material.set_shader_parameter("footprint_width", _width)
		material.set_shader_parameter("heading", _heading)
		material.set_shader_parameter("cone_angle", deg_to_rad(_angle))
		material.set_shader_parameter("shape_kind", ["circle", "line", "cross", "cone"].find(effect_shape))

func deactivate() -> void:
	visible = false
	modulate.a = 0.0
	_pending_style = ""
	_pending_geometry.clear()

func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)])

func _build_geometry() -> void:
	var normal := _heading.orthogonal()
	if effect_shape == "line":
		var half := normal * _width * 0.5
		_surface.polygon = PackedVector2Array([half, _heading * _length + half, _heading * _length - half, -half])
	elif effect_shape == "cross":
		var half := maxf(_length, _width) * 0.5
		_surface.polygon = PackedVector2Array([(-_heading - normal) * half, (_heading - normal) * half, (_heading + normal) * half, (-_heading + normal) * half])
	else:
		_surface.polygon = _rect_points(Rect2(Vector2.ONE * -effect_radius, Vector2.ONE * effect_radius * 2.0))
	var height := clampf(effect_radius * 2.8, 85.0, 420.0)
	var bounds: Rect2
	if effect_style == "lightning_strike":
		bounds = Rect2(Vector2(-effect_radius * 0.55, -height), Vector2(effect_radius * 1.1, height + effect_radius * 0.18))
	elif effect_style == "overload_burst":
		bounds = Rect2(Vector2.ONE * -effect_radius * 0.72, Vector2.ONE * effect_radius * 1.44)
	else:
		# Suspended orb has room for its halo and bob within the static rectangle.
		bounds = Rect2(Vector2(-effect_radius * 0.6, -effect_radius * 1.4), Vector2(effect_radius * 1.2, effect_radius * 1.5))
	_core.polygon = _rect_points(bounds)
	(_core.material as ShaderMaterial).set_shader_parameter("core_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	var cloud_bounds := Rect2(Vector2(-effect_radius * 0.94, -height * 0.63), Vector2(effect_radius * 1.88, height * 0.58))
	_cloud.polygon = _rect_points(cloud_bounds)
	(_cloud.material as ShaderMaterial).set_shader_parameter("cloud_bounds", Vector4(cloud_bounds.position.x, cloud_bounds.position.y, cloud_bounds.size.x, cloud_bounds.size.y))
	_build_arcs(normal)

func _build_arcs(normal: Vector2) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	# Each arc's entire trajectory is inside a static quad. No vertex displacement,
	# particle simulation, global RNG, or geometry upload is used to advance age.
	for index: int in range(ARC_COUNT):
		var fraction := (float(index) + 0.5) / ARC_COUNT
		var angle := float(index) * 2.399963 + _phase * 0.13
		var axis := Vector2.from_angle(angle)
		var base := axis * effect_radius * 0.50
		var travel := effect_radius * 0.46
		var half_width := clampf(effect_radius * 0.11, 3.0, 19.0)
		if effect_shape == "line":
			axis = _heading
			base = _heading * _length * fraction * 0.86 + normal * _width * sin(float(index) * 7.13 + _phase) * 0.27
			travel = minf(_length / 12.0, 35.0)
			half_width = minf(_width * 0.18, 12.0)
		elif effect_shape == "cross":
			axis = _heading if index % 2 == 0 else normal
			base = axis * _length * (fraction - 0.5) * 0.85
			travel = minf(_length / 12.0, 35.0)
			half_width = minf(_width * 0.18, 12.0)
		elif effect_shape == "cone":
			axis = _heading.rotated(deg_to_rad(_angle) * (fraction - 0.5) * 0.82)
			base = axis * effect_radius * 0.48
		elif effect_style == "ball_lightning_orb":
			base = Vector2(0.0, -effect_radius * 0.63) + axis * effect_radius * 0.15
			travel = effect_radius * 0.43
		var tangent := axis.orthogonal() * half_width
		var points := [base - tangent, base + axis * travel - tangent, base + axis * travel + tangent, base + tangent]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(Vector3(points[corner].x, points[corner].y, 0.0))
			uvs.append([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN][corner])
			colors.append(Color(fraction, fposmod(float(index) * 0.618033 + _phase * 0.031, 1.0), 1.0, 1.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_arcs.mesh = mesh
