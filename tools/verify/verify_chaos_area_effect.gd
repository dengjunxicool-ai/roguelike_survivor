extends SceneTree

const SCENE := "res://scenes/effects/chaos_area_effect.tscn"
const STYLES := ["chaos_rift", "void_rift_field", "chaos_weak_hit", "mutation_pulse_area", "instability_fission_burst", "chaos_exchange_line", "chaos_singularity_field", "chaos_singularity_burst"]
const RADII := [84.0, 210.0, 54.6, 252.0, 151.2, 160.0, 504.0, 504.0]
const DURATIONS := [4.0, 4.0, 0.12, 0.24, 0.22, 0.3, 2.0, 0.28]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_check(ResourceLoader.exists(SCENE), "Chaos area scene must exist")
	_check(ResourceLoader.exists("res://resources/effects/chaos_area.gdshader"), "Chaos area shader must exist")
	if not failures.is_empty():
		print("CHAOS_AREA: FAIL (missing resources)")
		quit(1)
		return
	var packed: PackedScene = load(SCENE)
	var first = packed.instantiate()
	var second = packed.instantiate()
	var snapshot := {"shape":"line", "length":240.0, "width":36.0, "direction":Vector2.DOWN, "position":Vector2(800, 900)}
	first.set_effect_style("chaos_exchange_line")
	first.set_effect_geometry(snapshot)
	snapshot.length = 999.0
	first.configure(70.0, 2.0, 12.0)
	first.update_state(70.0, 0.4, 2.0)
	second.configure(80.0, 1.0, 12.0)
	root.add_child(first)
	root.add_child(second)
	_check(first.effect_age == 0.4, "Ready preserves off-tree host age")
	_check(first.position == Vector2.ZERO, "Host snapshot position cannot double translate visual")
	var surface: Polygon2D = first.get_node("ChaosSurface")
	var material: ShaderMaterial = surface.material
	_check(first.effect_shape == "line" and surface.polygon[1].y == 240.0 and absf(surface.polygon[0].x) == 18.0, "Actual directed line snapshot dimensions retained")
	for node_name: String in ["ChaosSurface", "ChaosCore", "ChaosTears", "ChaosShards"]:
		_check(first.get_node(node_name).material != second.get_node(node_name).material, "Separate instance materials " + node_name)
		for other_name: String in ["ChaosSurface", "ChaosCore", "ChaosTears", "ChaosShards"]:
			if other_name != node_name:
				_check(first.get_node(node_name).material != first.get_node(other_name).material, "Layer materials isolated")
	var tears: Mesh = first.get_node("ChaosTears").mesh
	var shards: Mesh = first.get_node("ChaosShards").mesh
	paused = true
	await process_frame
	await process_frame
	_check(first.effect_age == 0.4, "Pause preserves host age")
	paused = false
	first.update_state(70.0, 0.8, 2.0)
	_check(first.get_node("ChaosTears").mesh == tears and first.get_node("ChaosShards").mesh == shards, "Age updates reuse fixed geometry")
	_check(material.get_shader_parameter("effect_age") == 0.8 and material.get_shader_parameter("progress") == 0.4, "Shader follows exact host age")
	_check(second.effect_age == 0.0, "Instance age isolated")
	_check_mesh(first, "line", 70.0, 240.0, 36.0, Vector2.DOWN, 360.0)
	for index: int in range(STYLES.size()):
		first.deactivate()
		first.rotation = 1.0
		first.scale = Vector2(3, 3)
		first.set_effect_style(STYLES[index])
		first.configure(RADII[index], DURATIONS[index], 4.0)
		first.update_state(RADII[index], DURATIONS[index] * 0.3, DURATIONS[index])
		_check(first.effect_style == STYLES[index] and first.visible and first.modulate.a > 0.0, "Profile active " + STYLES[index])
		_check(material.get_shader_parameter("profile") == index, "Profile dispatch " + STYLES[index])
		_check(first.effect_shape == "circle" and first.rotation == 0.0 and first.scale == Vector2.ONE, "Reuse resets transforms and actual circle")
		_check(first.get_child_count() == 4, "Bounded four node presentation")
		_check(is_equal_approx(surface.polygon[1].x, RADII[index]), "Actual profile radius retained")
		first.update_state(RADII[index], DURATIONS[index], DURATIONS[index])
		_check(first.modulate.a == 0.0, "Host expiry hides " + STYLES[index])
	first.deactivate()
	first.set_effect_style("void_rift_field")
	first.set_effect_geometry({"shape":"circle","has_pull":false})
	first.configure(168.0,0.35,42.0)
	_check(material.get_shader_parameter("has_pull") == false,"Actual maw pulse cannot imply suction")
	first.deactivate()
	first.set_effect_style("void_rift_field")
	first.configure(210.0,4.0,42.0)
	_check(material.get_shader_parameter("has_pull") == true,"Pool reuse restores actual pull field")
	first.deactivate()
	first.configure(80.0, 2.0, 42.0)
	first.set_effect_radius(180.0)
	_check(surface.polygon[1].x == 180.0 and material.get_shader_parameter("effect_radius") == 180.0, "Radius resizes footprint")
	seed(804)
	var expected := randf()
	seed(804)
	first.configure(80.0, 1.0, 42.0)
	_check(is_equal_approx(randf(), expected), "Visual cannot alter gameplay RNG")
	var deterministic: Array = first.get_node("ChaosTears").mesh.surface_get_arrays(0)
	first.configure(80.0, 1.0, 42.0)
	_check(first.get_node("ChaosTears").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == deterministic[Mesh.ARRAY_VERTEX], "Equal seed reproduces geometry")
	first.configure(80.0, 1.0, 43.0)
	_check(first.get_node("ChaosTears").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != deterministic[Mesh.ARRAY_VERTEX], "Distinct seed changes tear arrangement")
	for shape: String in ["cross", "cone"]:
		first.set_effect_geometry({"shape":shape,"length":180.0,"width":20.0,"direction":Vector2.LEFT,"angle":75.0})
		first.configure(80.0, 1.0, 5.0)
		_check_mesh(first, shape, 80.0, 180.0, 20.0, Vector2.LEFT, 75.0)
	first.set_effect_style("unknown")
	first.set_effect_geometry({"shape":"line","length":-4.0,"width":-5.0,"direction":Vector2.ZERO,"angle":-4.0})
	first.configure(-2.0, 0.0, 5.0)
	first.update_state(-2.0, -1.0, -2.0)
	_check(first.effect_radius == 1.0 and first.effect_duration == 0.05 and first.effect_age == 0.0 and first.effect_style == "chaos_rift", "Invalid inputs normalized")
	_check(material.get_shader_parameter("footprint_length") == 1.0 and material.get_shader_parameter("footprint_width") == 1.0 and material.get_shader_parameter("heading") == Vector2.RIGHT, "Invalid geometry normalized")
	first.deactivate()
	first.update_state(40.0, 0.1, 1.0)
	_check(not first.visible and first.modulate.a == 0.0, "Inactive update remains hidden")
	await _test_hosts()
	first.free()
	second.free()
	print("CHAOS_AREA: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

func _check_mesh(effect: Node, shape: String, radius: float, length: float, width: float, heading: Vector2, angle: float) -> void:
	for node_name: String in ["ChaosTears", "ChaosShards"]:
		var mesh: Mesh = effect.get_node(node_name).mesh
		_check(mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) <= 144, "Bounded single mesh batch")
		for vertex: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point := Vector2(vertex.x, vertex.y)
			var q := Vector2(point.dot(heading), point.dot(heading.orthogonal()))
			if shape == "line":
				_check(q.x >= 0.0 and q.x <= length and absf(q.y) <= width * 0.5, "Line batch inside actual footprint")
			elif shape == "cross":
				_check((absf(q.x) <= length * 0.5 and absf(q.y) <= width * 0.5) or (absf(q.y) <= length * 0.5 and absf(q.x) <= width * 0.5), "Cross batch inside actual arms")
			else:
				_check(point.length() <= radius and absf(heading.angle_to(point)) <= deg_to_rad(angle * 0.5), "Cone batch inside actual sector")

func _test_hosts() -> void:
	var host = load("res://scenes/combat/area_effect.tscn").instantiate()
	root.add_child(host)
	host.setup({"radius":90.0,"duration":2.0,"shape":"line","length":220.0,"width":26.0,"cone_direction":Vector2.DOWN,"visual_mode":"programmatic","visual_style":"chaos_exchange_line","visual_effect_scene":SCENE,"effects_on_apply":[],"effects_on_tick":[]})
	host.set_physics_process(false)
	var effect = host.get_node("AreaVisualEffect")
	_check(effect.effect_shape == "line", "Actual area host forwards actual line")
	_check(effect.get_node("ChaosSurface").material.get_shader_parameter("footprint_width") == 26.0, "Actual area host forwards width")
	_check(not effect.has_method("apply_damage") and not effect is Area2D, "Pure presentation has no combat authority")
	host.prepare_for_pool_despawn()
	_check(not effect.visible, "Area pool despawn hides presentation")
	host.setup({"radius":160.0,"duration":0.3,"shape":"circle","visual_mode":"programmatic","visual_style":"chaos_exchange_line","visual_effect_scene":SCENE,"effects_on_apply":[],"effects_on_tick":[]})
	_check(effect.visible and effect.effect_shape == "circle" and effect.effect_radius == 160.0, "Actual exchange circle survives prior line reuse")
	host.prepare_for_pool_despawn()
	host.setup({"radius":168.0,"duration":0.35,"visual_mode":"programmatic","visual_style":"void_rift_field","visual_effect_scene":SCENE,"actions_on_tick":[]})
	_check(effect.get_node("ChaosSurface").material.get_shader_parameter("has_pull") == false,"Actual maw pulse host forwards no pull")
	host.prepare_for_pool_despawn()
	host.setup({"radius":210.0,"duration":4.0,"visual_mode":"programmatic","visual_style":"void_rift_field","visual_effect_scene":SCENE,"actions_on_tick":[{"type":"pull","params":{"strength":0.32}}]})
	_check(effect.get_node("ChaosSurface").material.get_shader_parameter("has_pull") == true,"Actual void host forwards real pull after maw reuse")
	var instant = load("res://scripts/combat/instant_area_hit_visual.gd").new()
	root.add_child(instant)
	instant.setup({"radius":54.6,"duration":0.12,"visual_style":"chaos_weak_hit","visual_effect_scene":SCENE})
	instant.set_process(false)
	var impact = instant.get_node("InstantAreaVisualEffect")
	instant._process(0.04)
	_check(is_equal_approx(impact.effect_radius, 54.6) and is_equal_approx(impact.effect_age, 0.04), "Instant host owns footprint and age")
	instant.prepare_for_pool_despawn()
	_check(not impact.visible, "Instant despawn hides presentation")
	instant.setup({"radius":504.0,"duration":0.28,"visual_style":"chaos_singularity_burst","visual_effect_scene":SCENE})
	instant.set_process(false)
	_check(impact.visible and impact.effect_radius == 504.0 and impact.effect_age == 0.0, "Instant reuse resets geometry and age")
	instant.free()
	host.free()
