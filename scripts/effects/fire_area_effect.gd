## Fire ground geometry and elevated flame motion read the host's geometry and age.
extends Node2D

@export var effect_style: String = "fire_path"
const FireShader := preload("res://resources/effects/fire_area.gdshader")
const SPARK_COUNT := 24
const FLAME_COUNT := 20
const STYLES := {"fire_path": 0, "meteor_crater": 1, "lava_rift": 2, "scorching_vortex": 3, "fire_burst": 4}
var effect_radius := 100.0
var effect_duration := 3.0
var effect_age := 0.0
var effect_shape := "circle"
var _length := 100.0
var _width := 30.0
var _heading := Vector2.RIGHT
var _angle := 60.0
var _phase := 0.0
var _pending_geometry: Dictionary = {}
var _pending_style := ""
var _surface: Polygon2D
var _column: Polygon2D
var _sparks: MeshInstance2D
var _tongues: MeshInstance2D
var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
	_ensure_visuals()

func _ensure_visuals() -> void:
	if _surface != null:
		return
	_surface = Polygon2D.new()
	_surface.name = "FireSurface"
	_surface.material = _new_material(0)
	add_child(_surface)
	_column = Polygon2D.new()
	_column.name = "FireColumn"
	_column.material = _new_material(1)
	_column.visible = false
	add_child(_column)
	_tongues = MeshInstance2D.new()
	_tongues.name = "FireTongues"
	_tongues.material = _new_material(3)
	add_child(_tongues)
	_sparks = MeshInstance2D.new()
	_sparks.name = "FireSparks"
	_sparks.material = _new_material(2)
	add_child(_sparks)

func _new_material(layer: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = FireShader
	result.set_shader_parameter("layer", layer)
	_materials.append(result)
	return result

func set_effect_style(style: String) -> void:
	_pending_style = style if STYLES.has(style) else "fire_path"

func set_effect_geometry(snapshot: Dictionary) -> void:
	# Snapshot is owned by gameplay; do not hold or modify its reference.
	_pending_geometry = snapshot.duplicate(true)

func configure(radius: float, duration: float, visual_phase: float) -> void:
	_ensure_visuals()
	visible = true
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	effect_style = _pending_style if not _pending_style.is_empty() else "fire_path"
	effect_shape = String(_pending_geometry.get("shape", "circle"))
	if effect_shape not in ["circle", "line", "cross", "cone"]:
		effect_shape = "circle"
	_length = maxf(float(_pending_geometry.get("length", radius * 2.0)), 1.0)
	_width = maxf(float(_pending_geometry.get("width", radius * 0.5)), 1.0)
	_heading = _pending_geometry.get("direction", Vector2.RIGHT)
	_heading = _heading.normalized() if _heading.length_squared() > 0.0001 else Vector2.RIGHT
	_angle = clampf(float(_pending_geometry.get("angle", 60.0)), 1.0, 360.0)
	_pending_geometry.clear()
	_pending_style = ""
	_phase = visual_phase
	effect_age = 0.0
	effect_duration = maxf(duration, 0.05)
	_column.visible = effect_style == "scorching_vortex"
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
	var fade_in := smoothstep(0.0, minf(0.09, effect_duration * 0.12), effect_age)
	var fade_out := smoothstep(0.0, minf(0.45, effect_duration * 0.35), effect_duration - effect_age)
	modulate.a = fade_in * fade_out
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
	_pending_geometry.clear()
	_pending_style = ""

func _build_geometry() -> void:
	var normal := _heading.orthogonal()
	if effect_shape == "line":
		var half_width := normal * _width * 0.5
		_surface.polygon = PackedVector2Array([half_width, _heading * _length + half_width, _heading * _length - half_width, -half_width])
	elif effect_shape == "cross":
		var half_length := maxf(_length, _width) * 0.5
		_surface.polygon = PackedVector2Array([(-_heading - normal) * half_length, (_heading - normal) * half_length, (_heading + normal) * half_length, (-_heading + normal) * half_length])
	else:
		_surface.polygon = PackedVector2Array([Vector2(-effect_radius, -effect_radius), Vector2(effect_radius, -effect_radius), Vector2(effect_radius, effect_radius), Vector2(-effect_radius, effect_radius)])
	# The column and ember trajectory quads contain all shader motion. No vertex
	# displacement can escape the renderer's bounds, and age never uploads geometry.
	var height := clampf(effect_radius * 1.65, 40.0, 250.0)
	var half := effect_radius * 0.7
	_column.polygon = PackedVector2Array([Vector2(-half, -height), Vector2(half, -height), Vector2(half, effect_radius * 0.25), Vector2(-half, effect_radius * 0.25)])
	# Polygon2D has no texture: derive shader coordinates from its exact vertices.
	(_column.material as ShaderMaterial).set_shader_parameter("column_bounds", Vector4(-half, -height, half * 2.0, height + effect_radius * 0.25))
	_build_flames(normal)
	_build_sparks(normal)

func _build_flames(normal: Vector2) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var size_basis := _width if effect_shape in ["line", "cross"] else effect_radius
	var half_width := clampf(size_basis * 0.105, 4.0, 13.0)
	var height := clampf(size_basis * 0.37, 15.0, 45.0)
	for index: int in range(FLAME_COUNT):
		var fraction := (float(index) + 0.5) / FLAME_COUNT
		var seed_value := fposmod(float(index) * 0.618, 1.0)
		var angle := float(index) * 2.399963 + _phase * 0.07
		var base: Vector2
		if effect_shape == "line":
			base = _heading * _length * fraction + normal * _width * (0.31 if index % 2 == 0 else -0.31)
		elif effect_shape == "cross":
			var axis := _heading if index % 2 == 0 else normal
			base = axis * _length * (fraction - 0.5) * 0.88
		elif effect_shape == "cone":
			base = _heading.rotated(deg_to_rad(_angle) * (fraction - 0.5) * 0.92) * effect_radius * (0.48 if index % 5 == 0 else 0.88)
		else:
			base = Vector2.from_angle(angle) * effect_radius * (0.45 if index % 5 == 0 else 0.88)
		var flame_height := height * (0.7 + seed_value * 0.6)
		var points := [base + Vector2(-half_width, -flame_height), base + Vector2(half_width, -flame_height), base + Vector2(half_width, 2.0), base + Vector2(-half_width, 2.0)]
		var texcoords := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(Vector3(points[corner].x, points[corner].y, 0.0))
			uvs.append(texcoords[corner])
			colors.append(Color(fraction, seed_value, 1.0, 1.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_tongues.mesh = mesh

func _build_sparks(normal: Vector2) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var lift := clampf(effect_radius * 0.45, 18.0, 65.0)
	var half_width := 5.0
	for index: int in range(SPARK_COUNT):
		var fraction := (float(index) + 0.5) / SPARK_COUNT
		var angle := float(index) * 2.399963 + _phase * 0.07
		var base: Vector2
		if effect_shape == "line":
			base = _heading * _length * fraction + normal * _width * sin(float(index) * 7.7 + _phase) * 0.35
		elif effect_shape == "cross":
			var axis := _heading if index % 2 == 0 else normal
			base = axis * _length * (fraction - 0.5) * 0.85
		elif effect_shape == "cone":
			var cone_axis := _heading.rotated(deg_to_rad(_angle) * (fraction - 0.5) * 0.9)
			base = cone_axis * effect_radius * (0.4 + 0.42 * fposmod(float(index) * 0.618, 1.0))
		else:
			base = Vector2.from_angle(angle) * effect_radius * (0.4 + 0.44 * fposmod(float(index) * 0.618, 1.0))
		var points := [base + Vector2(-half_width, -lift), base + Vector2(half_width, -lift), base + Vector2(half_width, 3.0), base + Vector2(-half_width, 3.0)]
		var texcoords := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(Vector3(points[corner].x, points[corner].y, 0.0))
			uvs.append(texcoords[corner])
			colors.append(Color(fraction, fposmod(float(index) * 0.618, 1.0), 1.0, 1.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sparks.mesh = mesh
