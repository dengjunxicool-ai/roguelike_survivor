## Pure presentation: geometry and age always belong to the gameplay host.
extends Node2D

@export var effect_style: String = "chaos_rift"
const AreaShader := preload("res://resources/effects/chaos_area.gdshader")
const STYLES := {"chaos_rift":0, "void_rift_field":1, "chaos_weak_hit":2, "mutation_pulse_area":3, "instability_fission_burst":4, "chaos_exchange_line":5, "chaos_singularity_field":6, "chaos_singularity_burst":7}
const TEAR_COUNT := 24
const SHARD_COUNT := 18
var effect_radius := 100.0
var effect_duration := 1.0
var effect_age := 0.0
var effect_shape := "circle"
var _length := 200.0
var _width := 50.0
var _heading := Vector2.RIGHT
var _angle := 360.0
var _has_pull := true
var _phase := 0.0
var _pending_style := ""
var _pending_geometry: Dictionary = {}
var _surface: Polygon2D
var _core: Polygon2D
var _tears: MeshInstance2D
var _shards: MeshInstance2D
var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
	_ensure_visuals()

func _ensure_visuals() -> void:
	if _surface != null:
		return
	_surface = _new_plane("ChaosSurface", 0)
	_core = _new_plane("ChaosCore", 1)
	_tears = _new_batch("ChaosTears", 2)
	_shards = _new_batch("ChaosShards", 3)

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

func _new_batch(node_name: String, layer: int) -> MeshInstance2D:
	var batch := MeshInstance2D.new()
	batch.name = node_name
	batch.material = _new_material(layer)
	add_child(batch)
	return batch

func set_effect_style(style: String) -> void:
	_pending_style = style if STYLES.has(style) else "chaos_rift"

func set_effect_geometry(snapshot: Dictionary) -> void:
	_pending_geometry = snapshot.duplicate(true)

func configure(radius: float, duration: float, visual_phase: float) -> void:
	_ensure_visuals()
	visible = true
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	effect_style = _pending_style if not _pending_style.is_empty() else "chaos_rift"
	effect_shape = String(_pending_geometry.get("shape", "circle"))
	if effect_shape not in ["circle", "line", "cross", "cone"]:
		effect_shape = "circle"
	_length = maxf(float(_pending_geometry.get("length", radius * 2.0)), 1.0)
	_width = maxf(float(_pending_geometry.get("width", radius * 0.5)), 1.0)
	_heading = _pending_geometry.get("direction", Vector2.RIGHT)
	_heading = _heading.normalized() if _heading.length_squared() > 0.0001 else Vector2.RIGHT
	_angle = clampf(float(_pending_geometry.get("angle", 360.0)), 1.0, 360.0)
	_has_pull = bool(_pending_geometry.get("has_pull", true))
	_phase = visual_phase
	_pending_style = ""
	_pending_geometry.clear()
	_core.visible = true
	_shards.visible = true
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
	var attack := minf(0.018 if effect_style in ["chaos_weak_hit", "mutation_pulse_area", "instability_fission_burst", "chaos_singularity_burst"] else 0.06, effect_duration * 0.10)
	var release := smoothstep(0.0, minf(0.20, effect_duration * 0.30), effect_duration - effect_age)
	modulate.a = smoothstep(0.0, attack, effect_age) * release
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
		material.set_shader_parameter("has_pull", _has_pull)

func deactivate() -> void:
	visible = false
	modulate.a = 0.0
	_pending_style = ""
	_pending_geometry.clear()

func _build_geometry() -> void:
	var normal := _heading.orthogonal()
	if effect_shape == "line":
		var half := normal * _width * 0.5
		_surface.polygon = PackedVector2Array([half, _heading * _length + half, _heading * _length - half, -half])
	elif effect_shape == "cross":
		var half := maxf(_length, _width) * 0.5
		_surface.polygon = PackedVector2Array([(-_heading - normal) * half, (_heading - normal) * half, (_heading + normal) * half, (-_heading + normal) * half])
	else:
		_surface.polygon = PackedVector2Array([Vector2(-effect_radius, -effect_radius), Vector2(effect_radius, -effect_radius), Vector2(effect_radius, effect_radius), Vector2(-effect_radius, effect_radius)])
	_core.polygon = _surface.polygon
	_tears.mesh = _build_batch(TEAR_COUNT, false)
	_shards.mesh = _build_batch(SHARD_COUNT, true)

func _build_batch(count: int, flame: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var normal := _heading.orthogonal()
	for index: int in range(count):
		var fraction := (float(index) + 0.5) / count
		var variation := fposmod(float(index) * 0.618033 + _phase * 0.031, 1.0)
		var angle := float(index) * 2.399963 + _phase * 0.13
		var axis := Vector2.from_angle(angle)
		var start: Vector2
		var finish: Vector2
		var half_width := minf(effect_radius * (0.052 if flame else 0.027), 8.0)
		if effect_shape in ["line", "cross"]:
			axis = _heading if effect_shape == "line" or index % 2 == 0 else normal
			var lateral := axis.orthogonal() * _width * (variation - 0.5) * 0.62
			var offset := 0.0 if effect_shape == "line" else -_length * 0.5
			var span := _length * (0.15 if flame else 0.65)
			var along := offset + _length * (0.09 + fraction * (0.72 if flame else 0.12))
			start = axis * along + lateral
			finish = start + axis * span
			half_width = minf(half_width, _width * 0.13)
		elif effect_shape == "cone":
			axis = _heading.rotated(deg_to_rad(_angle) * (fraction - 0.5) * 0.76)
			start = axis * effect_radius * (0.30 + variation * 0.15 if flame else 0.18)
			finish = axis * effect_radius * (0.75 if flame else 0.91)
			half_width = minf(half_width, effect_radius * sin(deg_to_rad(_angle) * 0.06) * 0.15)
		else:
			start = axis * effect_radius * (0.16 + variation * 0.30 if flame else 0.13)
			finish = axis * effect_radius * (0.75 if flame else 0.93)
		var tangent := axis.orthogonal() * half_width
		var points := [start - tangent, finish - tangent, finish + tangent, start + tangent]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(Vector3(points[corner].x, points[corner].y, 0.0))
			uvs.append([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN][corner])
			colors.append(Color(fraction, variation, 1.0, 1.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
