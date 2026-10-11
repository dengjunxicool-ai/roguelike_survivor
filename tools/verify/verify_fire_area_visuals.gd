extends SceneTree

const EFFECT_PATH := "res://scenes/effects/fire_area_effect.tscn"
const Geometry := preload("res://scripts/skills/skill_object_geometry.gd")
var _failed := false
var _checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(ResourceLoader.exists(EFFECT_PATH), "fire area scene exists")
	if _failed:
		quit(1)
		return
	var scene: PackedScene = load(EFFECT_PATH)
	var first: Node2D = scene.instantiate()
	# Configure before entering a tree, as pooled spawns may do.
	first.call("set_effect_style", "lava_rift")
	var geometry := {"shape": "line", "radius": 40.0, "length": 360.0, "width": 48.0, "direction": Vector2.UP}
	first.call("set_effect_geometry", geometry)
	first.call("configure", 40.0, 2.0, 7.0)
	root.add_child(first)
	var surface: Polygon2D = first.get_node("FireSurface")
	var expected: PackedVector2Array = Geometry.polygons(geometry)[0]
	_expect(surface.polygon == expected, "lava fissure polygon matches authoritative line from origin")
	_expect(first.get_node("FireColumn").visible == false, "line has no vortex column")
	var material: ShaderMaterial = surface.material
	var tongues: MeshInstance2D = first.get_node_or_null("FireTongues")
	_expect(tongues != null and tongues.mesh != null, "fire fields contain a fixed batch of elevated flame tongues")
	if tongues != null:
		_expect(tongues.mesh.get_surface_count() == 1 and tongues.mesh.surface_get_array_len(0) <= 120, "elevated flames keep fixed single mesh budget")
	first.call("update_state", 40.0, 0.6, 2.0)
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.6), "host age drives surface shader")
	_expect(first.modulate.a > 0.0, "active age has visible fade")
	var second: Node2D = scene.instantiate()
	second.call("set_effect_style", "scorching_vortex")
	second.call("set_effect_geometry", {"shape": "circle", "radius": 90.0})
	second.call("configure", 90.0, 3.0, 9.0)
	root.add_child(second)
	_expect(second.get_node("FireColumn").visible, "vortex adds elevated column")
	var column: Polygon2D = second.get_node("FireColumn")
	_expect(_bounds(column.polygon).position.y < -100.0, "vortex has substantial height above ground")
	var column_material: ShaderMaterial = column.material
	var column_bounds: Variant = column_material.get_shader_parameter("column_bounds")
	_expect(column_bounds is Vector4, "untextured vortex column provides vertex-derived UV bounds")
	if column_bounds is Vector4:
		var actual_bounds := _bounds(column.polygon)
		_expect(Vector2(column_bounds.x, column_bounds.y).is_equal_approx(actual_bounds.position) and Vector2(column_bounds.z, column_bounds.w).is_equal_approx(actual_bounds.size), "vortex shader normalization matches exact visible quad")
	_expect(second.get_node("FireSurface").material != material, "areas own independent materials")
	second.call("update_state", 90.0, 1.2, 3.0)
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.6), "other area does not advance shader age")
	var original_mesh: Mesh = first.get_node("FireSparks").mesh
	var original_polygon: PackedVector2Array = surface.polygon
	var child_count := first.get_child_count()
	for index: int in range(120):
		first.call("update_state", 40.0, float(index) / 100.0, 2.0)
	_expect(first.get_child_count() == child_count, "updates do not accumulate nodes")
	_expect(first.get_node("FireSparks").mesh == original_mesh and surface.polygon == original_polygon, "age updates keep static geometry and mesh")
	_expect(original_mesh.get_surface_count() == 1 and original_mesh.surface_get_array_len(0) <= 144, "sparks have fixed single batch budget")
	paused = true
	var old_age: float = material.get_shader_parameter("effect_age")
	await process_frame
	await process_frame
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), old_age), "pause freezes authoritative presentation")
	paused = false
	_expect(not first.is_processing() and not first.is_physics_processing(), "area does not own a clock")
	seed(501)
	var expected_rng := randi()
	seed(501)
	first.call("deactivate")
	_expect(not first.visible, "deactivation hides complete presentation")
	first.call("configure", 30.0, 0.3, 2.0)
	first.call("update_state", 30.0, 0.12, 0.3)
	_expect(randi() == expected_rng, "configuration and updates preserve gameplay RNG")
	_expect(first.get("effect_style") == "fire_path", "pool reset clears previous style if no replacement supplied")
	_expect(first.get("effect_shape") == "circle", "pool reset clears previous line geometry")
	_expect(is_equal_approx(first.rotation, 0.0) and is_equal_approx(first.scale.x, 1.0), "pool reset has no stale transform")
	first.call("update_state", 30.0, 0.3, 0.3)
	_expect(is_zero_approx(first.modulate.a), "expired area has zero opacity")
	first.call("set_effect_style", "lava_rift")
	var cross_shape := {"shape": "cross", "radius": 40.0, "length": 360.0, "width": 90.0, "direction": Vector2.RIGHT.rotated(0.2)}
	first.call("set_effect_geometry", cross_shape)
	first.call("configure", 40.0, 2.0, 0.0)
	var enclosed := true
	for arm: PackedVector2Array in Geometry.polygons(cross_shape):
		for point: Vector2 in arm:
			enclosed = enclosed and Geometry2D.is_point_in_polygon(point * 0.9999, surface.polygon)
	_expect(enclosed, "rotated cross surface encloses every authoritative arm corner")
	first.call("set_effect_geometry", {"shape": "cone", "radius": 60.0, "angle": 72.0, "direction": Vector2.LEFT})
	first.call("configure", 60.0, 2.0, 0.0)
	_expect(is_equal_approx(float(material.get_shader_parameter("cone_angle")), deg_to_rad(72.0)) and material.get_shader_parameter("heading") == Vector2.LEFT, "cone passes authoritative angle and orientation")
	first.call("set_effect_radius", 120.0)
	_expect(_bounds(surface.polygon).size == Vector2(240.0, 240.0), "radius update rebuilds real ground bounds")
	var spark_mesh: ArrayMesh = first.get_node("FireSparks").mesh
	var ember_bounds := spark_mesh.get_aabb()
	_expect(ember_bounds.size.y < 310.0 and ember_bounds.size.x <= 250.0, "all upward spark trajectories have explicit finite mesh bounds")
	for style: String in ["fire_path", "meteor_crater", "lava_rift", "scorching_vortex", "fire_burst"]:
		first.call("deactivate")
		first.call("set_effect_style", style)
		first.call("set_effect_geometry", {"shape": "circle", "radius": 120.0})
		first.call("configure", 120.0, 1.0, 3.0)
		_expect(first.visible and is_zero_approx(first.get("effect_age")), "%s resets lifecycle" % style)
	first.free()
	second.free()
	print("[fire_area_visuals] %d checks; failed=%s" % [_checks, _failed])
	quit(1 if _failed else 0)

func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		result = result.expand(point)
	return result

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % message)
	else:
		_failed = true
		push_error("[FAIL] %s" % message)
