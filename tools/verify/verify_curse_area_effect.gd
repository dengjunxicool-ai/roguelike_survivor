extends SceneTree

var failures: Array[String] = []
const STYLES := ["soul_chain_link", "doom_circle_delay", "doom_circle_burst", "curse_whisper", "soul_explosion"]

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var scene_path := "res://scenes/effects/curse_area_effect.tscn"
	_check(ResourceLoader.exists(scene_path), "Curse area scene must exist")
	_check(ResourceLoader.exists("res://resources/effects/curse_area.gdshader"), "Curse area shader must exist")
	if not failures.is_empty():
		print("CURSE_AREA: FAIL (missing resources)")
		quit(1)
		return
	var packed: PackedScene = load(scene_path)
	var first = packed.instantiate()
	var second = packed.instantiate()
	var snapshot := {"shape":"line", "length":240.0, "width":36.0, "direction":Vector2.DOWN}
	first.set_effect_style("doom_circle_delay")
	first.set_effect_geometry(snapshot)
	snapshot["length"] = 999.0
	first.configure(70.0, 2.0, 12.0)
	second.set_effect_style("soul_explosion")
	second.configure(90.0, 3.0, 2.0)
	root.add_child(first)
	root.add_child(second)
	var surface: Polygon2D = first.get_node("CurseSurface")
	var material: ShaderMaterial = surface.material
	_check(first.effect_shape == "line", "Pre-tree configure must retain host shape")
	_check(is_equal_approx(surface.polygon[1].y, 240.0), "Geometry snapshot must preserve actual directed length")
	_check(is_equal_approx(absf(surface.polygon[0].x), 18.0), "Host half-width must remain 18")
	_check(material != second.get_node("CurseSurface").material, "Instances must isolate material uniforms")
	for node_name: String in ["CurseSurface", "CurseCore", "CurseThreads", "CurseFlames"]:
		_check(first.get_node(node_name).material != second.get_node(node_name).material, "Each batch must own an isolated material: " + node_name)
	first.update_state(70.0, 0.4, 2.0)
	var mesh: Mesh = first.get_node("CurseThreads").mesh
	var flames: Mesh = first.get_node("CurseFlames").mesh
	paused = true
	await process_frame
	await process_frame
	_check(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.4), "Pause must preserve host age")
	paused = false
	first.update_state(70.0, 0.8, 2.0)
	for child: CanvasItem in first.get_children():
		_check(is_equal_approx(float(child.material.get_shader_parameter("effect_age")), 0.8), "Every layer must receive the same host-owned age")
	_check(first.get_node("CurseThreads").mesh == mesh and first.get_node("CurseFlames").mesh == flames, "Age-only updates must reuse static meshes")
	_check(is_equal_approx(float(material.get_shader_parameter("progress")), 0.4), "Delay must receive exact host progress")
	_check(not first.get_node("CurseCore").visible and not first.get_node("CurseFlames").visible, "Delay must not show burst core or blast flames")
	for vertex: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		_check(vertex.y >= 0.0 and vertex.y <= 240.0 and absf(vertex.x) <= 18.0, "Line soul threads must stay within actual footprint")
	_check(is_equal_approx(float(second.get_node("CurseSurface").material.get_shader_parameter("effect_age")), 0.0), "Updating one instance must not advance another")
	first.deactivate()
	first.rotation = 1.0
	first.scale = Vector2(3.0, 3.0)
	for style: String in STYLES:
		first.set_effect_style(style)
		first.configure(80.0, 1.0, 31.0)
		first.update_state(80.0, 0.2, 1.0)
		_check(first.effect_style == style and first.visible and first.modulate.a > 0.0, "Every style must activate: " + style)
		_check(first.effect_shape == "circle" and first.rotation == 0.0 and first.scale == Vector2.ONE, "Reuse must reset geometry and transform: " + style)
		_check(first.get_node("CurseCore").visible == (style in ["soul_chain_link", "doom_circle_burst", "soul_explosion"]), "Reuse must reset core visibility: " + style)
		_check(first.get_node("CurseFlames").visible == (style in ["soul_chain_link", "doom_circle_burst", "soul_explosion"]), "Reuse must reset flame visibility: " + style)
		_check(first.get_child_count() <= 4, "Area node budget must stay fixed across reuse")
		_check(first.get_node("CurseThreads").mesh.get_surface_count() == 1 and first.get_node("CurseThreads").mesh.surface_get_array_len(0) <= 144, "Soul threads must use a bounded single batch")
		_check(first.get_node("CurseFlames").mesh.surface_get_array_len(0) <= 120, "Soul flames must use a bounded batch")
		first.update_state(80.0, 1.0, 1.0)
		if style == "doom_circle_delay":
			_check(first.modulate.a > 0.0, "Delay must remain visible through the final pre-explosion countdown frame")
		else:
			_check(first.modulate.a == 0.0, "Expired transient must fade completely: " + style)
		first.deactivate()
	first.configure(80.0, 2.0, 42.0)
	first.set_effect_radius(180.0)
	_check(is_equal_approx(float(material.get_shader_parameter("effect_radius")), 180.0) and surface.polygon[1].x == 180.0, "Radius updates must resize exact footprint")
	seed(804)
	var expected := randf()
	seed(804)
	first.configure(80.0, 1.0, 42.0)
	_check(is_equal_approx(randf(), expected), "Visual configuration must preserve gameplay RNG")
	var deterministic: Array = first.get_node("CurseThreads").mesh.surface_get_arrays(0)
	first.configure(80.0, 1.0, 42.0)
	_check(first.get_node("CurseThreads").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == deterministic[Mesh.ARRAY_VERTEX], "Equal seeds must reproduce soul thread geometry")
	first.configure(80.0, 1.0, 43.0)
	_check(first.get_node("CurseThreads").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != deterministic[Mesh.ARRAY_VERTEX], "Different seeds must vary soul thread arrangement")
	first.set_effect_geometry({"shape":"cross", "length":180.0, "width":20.0, "direction":Vector2.RIGHT})
	first.configure(80.0, 0.3, 5.0)
	_check(first.effect_shape == "cross" and absf(surface.polygon[0].x) == 90.0 and absf(surface.polygon[0].y) == 90.0, "Cross must preserve host length")
	_check(is_equal_approx(float(material.get_shader_parameter("footprint_width")), 20.0), "Cross must preserve host width")
	for vertex: Vector3 in first.get_node("CurseThreads").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		_check((absf(vertex.x) <= 90.0 and absf(vertex.y) <= 10.0) or (absf(vertex.y) <= 90.0 and absf(vertex.x) <= 10.0), "Cross thread vertices must remain in actual arms")
	first.set_effect_geometry({"shape":"cone", "angle":75.0, "direction":Vector2.LEFT})
	first.configure(80.0, 1.0, 5.0)
	for vertex: Vector3 in first.get_node("CurseThreads").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point := Vector2(vertex.x, vertex.y)
		_check(point.length() <= 80.0 and absf(Vector2.LEFT.angle_to(point)) <= deg_to_rad(37.5), "Cone thread vertices must stay in actual directed sector")
	first.set_effect_style("unknown")
	first.set_effect_geometry({"shape":"cone", "angle":75.0, "direction":Vector2.LEFT})
	first.configure(-2.0, 0.0, 5.0)
	_check(first.effect_radius == 1.0 and first.effect_duration == 0.05 and first.effect_style == "soul_chain_link", "Invalid input must normalize")
	_check(is_equal_approx(float(material.get_shader_parameter("cone_angle")), deg_to_rad(75.0)) and material.get_shader_parameter("heading") == Vector2.LEFT, "Cone must use actual host angle and direction")
	first.deactivate()
	first.update_state(40.0, 0.1, 1.0)
	_check(not first.visible and first.modulate.a == 0.0, "Inactive instance must remain hidden")
	first.free()
	second.free()
	print("CURSE_AREA: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
