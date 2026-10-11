extends SceneTree

const SCENE := "res://scenes/effects/holy_area_effect.tscn"
const STYLES := ["heavenly_wings_path", "divine_barrier_field", "judgment_hammer", "guardian_counter_wave", "divine_punishment", "counter_seal_wave", "absolution_light_burst", "holy_beam", "holy_healing", "holy_sanctuary", "holy_telegraph"]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_check(ResourceLoader.exists(SCENE), "Holy area scene must exist")
	_check(ResourceLoader.exists("res://resources/effects/holy_area.gdshader"), "Holy area shader must exist")
	if not failures.is_empty():
		print("HOLY_AREA: FAIL (missing resources)")
		quit(1)
		return
	var packed: PackedScene = load(SCENE)
	if OS.get_cmdline_user_args().has("--render-areas"):
		await _render_areas(packed)
		return
	var first = packed.instantiate()
	var second = packed.instantiate()
	var snapshot := {"shape":"line", "length":240.0, "width":36.0, "direction":Vector2.DOWN, "position":Vector2(800, 900)}
	first.set_effect_style("holy_beam")
	first.set_effect_geometry(snapshot)
	snapshot.length = 999.0
	first.configure(70.0, 2.0, 12.0)
	first.update_state(70.0, 0.4, 2.0)
	second.configure(80.0, 1.0, 12.0)
	root.add_child(first)
	root.add_child(second)
	_check(first.effect_age == 0.4, "Ready must preserve off-tree host age")
	_check(first.position == Vector2.ZERO, "World position in host geometry must not double translate local visual")
	var surface: Polygon2D = first.get_node("HolySurface")
	var material: ShaderMaterial = surface.material
	_check(first.effect_shape == "line" and surface.polygon[1].y == 240.0 and absf(surface.polygon[0].x) == 18.0, "Directed line must use host snapshot length and width")
	for node_name: String in ["HolySurface", "HolyCore", "HolyRays", "HolyFeathers"]:
		_check(first.get_node(node_name).material != second.get_node(node_name).material, "Materials must be isolated: " + node_name)
		for other_name: String in ["HolySurface", "HolyCore", "HolyRays", "HolyFeathers"]:
			if other_name != node_name:
				_check(first.get_node(node_name).material != first.get_node(other_name).material, "Each layer owns a material")
	var rays: Mesh = first.get_node("HolyRays").mesh
	var feathers: Mesh = first.get_node("HolyFeathers").mesh
	paused = true
	await process_frame
	await process_frame
	_check(first.effect_age == 0.4, "Pause must preserve age")
	paused = false
	first.update_state(70.0, 0.8, 2.0)
	_check(first.get_node("HolyRays").mesh == rays and first.get_node("HolyFeathers").mesh == feathers, "Age updates must reuse fixed geometry")
	_check(material.get_shader_parameter("effect_age") == 0.8 and material.get_shader_parameter("progress") == 0.4, "Shader must use exact host age and progress")
	_check(second.effect_age == 0.0, "Independent instance age must remain unchanged")
	_check_mesh(first, "line", 70.0, 240.0, 36.0, Vector2.DOWN, 360.0)
	for style: String in STYLES:
		first.deactivate()
		first.rotation = 1.0
		first.scale = Vector2(3, 3)
		first.set_effect_style(style)
		first.configure(80.0, 1.0, 4.0)
		first.update_state(80.0, 0.2, 1.0)
		_check(first.effect_style == style and first.visible and first.modulate.a > 0.0, "Reuse activates " + style)
		_check(first.effect_shape == "circle" and first.rotation == 0.0 and first.scale == Vector2.ONE, "Reuse resets transforms and shape")
		_check(first.get_child_count() == 4, "Fixed 4-node budget")
		_check(first.get_node("HolyCore").visible == (style not in ["holy_telegraph", "holy_healing", "holy_sanctuary", "divine_barrier_field", "heavenly_wings_path"]), "Correct core visibility " + style)
		first.update_state(80.0, 1.0, 1.0)
		_check(first.modulate.a > 0.0 if style == "holy_telegraph" else first.modulate.a == 0.0, "Expiry / final telegraph visibility " + style)
	first.deactivate()
	first.configure(80.0, 2.0, 42.0)
	first.set_effect_radius(180.0)
	_check(surface.polygon[1].x == 180.0 and material.get_shader_parameter("effect_radius") == 180.0, "Radius resizes footprint")
	seed(804)
	var expected := randf()
	seed(804)
	first.configure(80.0, 1.0, 42.0)
	_check(is_equal_approx(randf(), expected), "Visual does not alter gameplay RNG")
	var deterministic: Array = first.get_node("HolyRays").mesh.surface_get_arrays(0)
	first.configure(80.0, 1.0, 42.0)
	_check(first.get_node("HolyRays").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == deterministic[Mesh.ARRAY_VERTEX], "Equal seeds reproduce geometry")
	first.configure(80.0, 1.0, 43.0)
	_check(first.get_node("HolyRays").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != deterministic[Mesh.ARRAY_VERTEX], "Seed changes arrangement")
	for shape: String in ["cross", "cone"]:
		first.set_effect_geometry({"shape":shape,"length":180.0,"width":20.0,"direction":Vector2.LEFT,"angle":75.0})
		first.configure(80.0, 1.0, 5.0)
		_check_mesh(first, shape, 80.0, 180.0, 20.0, Vector2.LEFT, 75.0)
	first.set_effect_style("unknown")
	first.set_effect_geometry({"shape":"line","length":-4.0,"width":-5.0,"direction":Vector2.ZERO,"angle":-4.0})
	first.configure(-2.0, 0.0, 5.0)
	first.update_state(-2.0, -1.0, -2.0)
	_check(first.effect_radius == 1.0 and first.effect_duration == 0.05 and first.effect_age == 0.0 and first.effect_style == "divine_barrier_field", "Negative input normalized")
	_check(material.get_shader_parameter("footprint_length") == 1.0 and material.get_shader_parameter("footprint_width") == 1.0 and material.get_shader_parameter("heading") == Vector2.RIGHT, "Invalid geometry normalized")
	first.deactivate()
	first.update_state(40.0, 0.1, 1.0)
	_check(not first.visible and first.modulate.a == 0.0, "Inactive update stays hidden")
	await _test_hosts()
	first.free()
	second.free()
	print("HOLY_AREA: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

func _check_mesh(effect: Node, shape: String, radius: float, length: float, width: float, heading: Vector2, angle: float) -> void:
	for node_name: String in ["HolyRays", "HolyFeathers"]:
		var mesh: Mesh = effect.get_node(node_name).mesh
		_check(mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) <= 144, "Bounded single mesh batch")
		for vertex: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point := Vector2(vertex.x, vertex.y)
			var q := Vector2(point.dot(heading), point.dot(heading.orthogonal()))
			if shape == "line":
				_check(q.x >= 0.0 and q.x <= length and absf(q.y) <= width * 0.5, "Line batch stays in footprint")
			elif shape == "cross":
				_check((absf(q.x) <= length * 0.5 and absf(q.y) <= width * 0.5) or (absf(q.y) <= length * 0.5 and absf(q.x) <= width * 0.5), "Cross batch stays in arms")
			else:
				_check(point.length() <= radius and absf(heading.angle_to(point)) <= deg_to_rad(angle * 0.5), "Cone batch stays in sector")

func _test_hosts() -> void:
	var host = load("res://scenes/combat/area_effect.tscn").instantiate()
	root.add_child(host)
	host.setup({"radius":90.0,"duration":2.0,"shape":"line","length":220.0,"width":26.0,"cone_direction":Vector2.DOWN,"visual_mode":"programmatic","visual_style":"holy_beam","visual_effect_scene":SCENE,"effects_on_apply":[],"effects_on_tick":[]})
	host.set_physics_process(false)
	var effect = host.get_node("AreaVisualEffect")
	_check(effect.effect_shape == "line", "Real area host forwards actual line")
	_check(effect.get_node("HolySurface").material.get_shader_parameter("footprint_width") == 26.0, "Real area host forwards width")
	_check(not effect.has_method("apply_damage") and not effect is Area2D, "Effect is presentation only")
	host.prepare_for_pool_despawn()
	_check(not effect.visible, "Area pool despawn hides effect")
	host.setup({"radius":70.0,"duration":1.0,"visual_mode":"programmatic","visual_style":"divine_barrier_field","visual_effect_scene":SCENE,"effects_on_apply":[],"effects_on_tick":[]})
	_check(effect.visible and effect.effect_shape == "circle", "Real host reuse resets prior line")
	var instant = load("res://scripts/combat/instant_area_hit_visual.gd").new()
	root.add_child(instant)
	instant.setup({"radius":55.0,"duration":0.2,"visual_style":"absolution_light_burst","visual_effect_scene":SCENE})
	instant.set_process(false)
	var impact = instant.get_node("InstantAreaVisualEffect")
	instant._process(0.06)
	_check(impact.effect_radius == 55.0 and is_equal_approx(impact.effect_age, 0.06), "Instant host owns burst footprint and age")
	instant.prepare_for_pool_despawn()
	_check(not impact.visible, "Instant pool despawn hides effect")
	instant.setup({"radius":35.0,"duration":0.15,"visual_style":"guardian_counter_wave","visual_effect_scene":SCENE})
	instant.set_process(false)
	_check(impact.visible and impact.effect_radius == 35.0 and impact.effect_age == 0.0, "Instant reuse restores geometry and age")
	instant.free()
	host.free()

func _render_areas(packed: PackedScene) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.035, 0.05, 0.065)
	background.size = Vector2(1600, 1200)
	viewport.add_child(background)
	for index: int in range(STYLES.size()):
		var origin := Vector2(200 + index % 4 * 400, 180 + index / 4 * 385)
		var caption := Label.new()
		caption.position = origin + Vector2(-180, -155)
		caption.text = STYLES[index]
		caption.add_theme_font_size_override("font_size", 21)
		viewport.add_child(caption)
		var effect = packed.instantiate()
		effect.position = origin
		effect.set_effect_style(STYLES[index])
		if STYLES[index] == "holy_beam":
			effect.set_effect_geometry({"shape":"line", "length":300.0,"width":70.0,"direction":Vector2.RIGHT})
			effect.position.x -= 150.0
		effect.configure(132.0, 1.0, float(index) + 5.0)
		effect.update_state(132.0, 0.27 if STYLES[index] != "holy_telegraph" else 0.72, 1.0)
		viewport.add_child(effect)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("E:/codex/holy-areas")
	var err := viewport.get_texture().get_image().save_png("E:/codex/holy-areas/holy-area-styles.png")
	_check(err == OK, "Render preview must save")
	print("HOLY_AREA_RENDER: ", "PASS" if err == OK else "FAIL")
	viewport.free()
	quit(0 if err == OK else 1)
