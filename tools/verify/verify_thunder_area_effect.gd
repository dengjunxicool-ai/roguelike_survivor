extends SceneTree

var failures: Array[String] = []
const STYLES := ["ball_lightning_path", "ball_lightning_orb", "thunderstorm_cloud", "lightning_strike", "emp_ring", "overload_burst", "magnetic_pull"]

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var path := "res://scenes/effects/thunder_area_effect.tscn"
	_check(ResourceLoader.exists(path), "Thunder area scene must exist")
	if not failures.is_empty():
		quit(1)
		return
	var scene: PackedScene = load(path)
	var first = scene.instantiate()
	var second = scene.instantiate()
	# Gameplay configures pooled effects before they enter the tree.
	var geometry := {"shape":"line", "length":240.0, "width":36.0, "direction":Vector2.DOWN}
	first.set_effect_style("ball_lightning_path")
	first.set_effect_geometry(geometry)
	geometry["length"] = 999.0
	first.configure(70.0, 2.0, 12.0)
	second.set_effect_style("ball_lightning_orb")
	second.configure(90.0, 3.0, 2.0)
	root.add_child(first)
	root.add_child(second)
	_check(first.effect_shape == "line", "Host line geometry must survive pre-tree configure")
	var surface: Polygon2D = first.get_node("ThunderSurface")
	var points: PackedVector2Array = surface.polygon
	_check(is_equal_approx(points[1].y, 240.0), "Snapshot must be copied and preserve actual directed length")
	_check(is_equal_approx(absf(points[0].x), 18.0), "Line must preserve actual half-width")
	var mat: ShaderMaterial = surface.material
	_check(mat != second.get_node("ThunderSurface").material, "Pooled effects must own independent shader materials")
	first.update_state(70.0, 0.4, 2.0)
	var mesh: Mesh = first.get_node("ThunderArcs").mesh
	var age: float = mat.get_shader_parameter("effect_age")
	paused = true
	await process_frame
	await process_frame
	_check(is_equal_approx(float(mat.get_shader_parameter("effect_age")), age), "Pause must not advance shader age")
	paused = false
	first.update_state(70.0, 0.6, 2.0)
	_check(first.get_node("ThunderArcs").mesh == mesh, "Age-only updates must not upload geometry")
	var path_vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in path_vertices:
		_check(vertex.y >= 0.0 and vertex.y <= 240.0 and absf(vertex.x) <= 18.0, "Path arc batch must stay inside true directed line footprint")
	_check(is_equal_approx(float(second.get_node("ThunderSurface").material.get_shader_parameter("effect_age")), 0.0), "One effect age must not leak into another material")
	first.deactivate()
	first.rotation = 0.6
	first.scale = Vector2(4.0, 4.0)
	first.set_effect_style("thunderstorm_cloud")
	first.configure(120.0, 4.0, 4.0)
	_check(first.effect_shape == "circle" and first.rotation == 0.0 and first.scale == Vector2.ONE, "Pool reuse must reset shape and transforms")
	_check(first.get_node("ThunderCloud").visible, "Storm profile must show elevated cloud")
	first.set_effect_radius(180.0)
	_check(is_equal_approx(float(mat.get_shader_parameter("effect_radius")), 180.0), "Radius change must reach the footprint shader")
	_check(is_equal_approx(surface.polygon[1].x, 180.0), "Storm footprint radius must remain real gameplay radius")
	var storm_mesh: Mesh = first.get_node("ThunderArcs").mesh
	first.update_state(180.0, 1.0, 4.0)
	_check(first.get_node("ThunderArcs").mesh == storm_mesh, "Stable storm radius must not rebuild a mesh every tick")
	first.set_effect_radius(200.0)
	_check(first.get_node("ThunderArcs").mesh != storm_mesh, "Radius change must resize the actual arc geometry")
	_check(is_equal_approx(float(first.get_node("ThunderCloud").material.get_shader_parameter("effect_age")), 1.0), "Cloud motion must read the same host-owned age")
	for style: String in STYLES:
		first.deactivate()
		first.set_effect_style(style)
		first.configure(80.0, 1.0, 31.0)
		first.update_state(80.0, 0.2, 1.0)
		_check(first.effect_style == style and first.visible and first.modulate.a > 0.0, "Profile must activate: " + style)
		_check(first.get_node("ThunderArcs").mesh.get_surface_count() == 1, "Profile must use bounded arc batch: " + style)
		_check(first.get_node("ThunderArcs").mesh.surface_get_array_len(0) == 144, "Arc batch must remain bounded across pool reuse: " + style)
		_check(first.get_node("ThunderCloud").visible == (style == "thunderstorm_cloud"), "Pool reuse must clear cloud visibility: " + style)
		_check(first.get_node("ThunderCore").visible == (style in ["ball_lightning_orb", "lightning_strike", "overload_burst"]), "Pool reuse must clear elevated core visibility: " + style)
		_check(is_equal_approx(float(mat.get_shader_parameter("progress")), 0.2), "Profile motion must receive host normalized age: " + style)
		first.update_state(80.0, 1.0, 1.0)
		_check(first.modulate.a == 0.0, "Expired visual must fade completely: " + style)
	seed(804)
	var expected := randf()
	seed(804)
	first.configure(80.0, 1.0, 42.0)
	_check(is_equal_approx(randf(), expected), "Visual setup must not consume gameplay RNG")
	var deterministic: Array = first.get_node("ThunderArcs").mesh.surface_get_arrays(0)
	first.configure(80.0, 1.0, 42.0)
	_check(first.get_node("ThunderArcs").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == deterministic[Mesh.ARRAY_VERTEX], "Equal visual seed must reproduce arc geometry")
	first.configure(80.0, 1.0, 43.0)
	_check(first.get_node("ThunderArcs").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != deterministic[Mesh.ARRAY_VERTEX], "Different seed must vary the circular arc arrangement")
	first.set_effect_style("emp_ring")
	first.set_effect_geometry({"shape":"cross", "length":180.0, "width":20.0, "direction":Vector2.RIGHT})
	first.configure(80.0, 0.3, 5.0)
	_check(first.effect_shape == "cross" and absf(surface.polygon[0].x) == 90.0 and absf(surface.polygon[0].y) == 90.0, "Cross extent must use host length")
	_check(is_equal_approx(float(mat.get_shader_parameter("footprint_width")), 20.0), "Cross arm width must reach shape clipping shader")
	first.set_effect_style("unknown")
	first.set_effect_geometry({"shape":"cone", "angle":75.0, "direction":Vector2.LEFT})
	first.configure(-2.0, 0.0, 5.0)
	_check(first.effect_radius == 1.0 and first.effect_duration == 0.05 and first.effect_style == "ball_lightning_path", "Invalid radius, duration and style must normalize")
	_check(is_equal_approx(float(mat.get_shader_parameter("cone_angle")), deg_to_rad(75.0)), "Cone angle must use actual gameplay angle")
	_check(mat.get_shader_parameter("heading") == Vector2.LEFT, "Cone shader must keep actual host heading")
	first.deactivate()
	first.update_state(40.0, 0.1, 1.0)
	_check(not first.visible and first.modulate.a == 0.0, "Deactivated pooled effect must stay hidden")
	first.free()
	second.free()
	print("THUNDER_AREA: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
