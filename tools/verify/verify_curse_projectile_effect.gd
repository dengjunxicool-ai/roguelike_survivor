extends SceneTree

const EFFECT_PATH: String = "res://scenes/effects/curse_projectile_effect.tscn"
const LINK_PATH: String = "res://scripts/effects/curse_link_effect.gd"
var _failed: bool = false
var _checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(ResourceLoader.exists(EFFECT_PATH), "production curse projectile scene exists")
	_expect(ResourceLoader.exists(LINK_PATH), "pooled curse soul link exists")
	if _failed:
		quit(1)
		return
	var scene: PackedScene = load(EFFECT_PATH) as PackedScene
	var effects: Array[Node2D] = []
	var styles: Array[String] = ["black_serpent", "death_scythe", "soul_bolt", "soul_storm"]
	for index: int in range(styles.size()):
		var effect: Node2D = scene.instantiate() as Node2D
		effect.call("configure_projectile", {"style": styles[index], "radius": 12.0, "speed": 600.0, "direction": Vector2.UP, "lifetime": 2.0})
		var envelope: ColorRect = effect.get_node("CurseEnvelope") as ColorRect
		var material: ShaderMaterial = envelope.material as ShaderMaterial
		var wisps: MeshInstance2D = effect.get_node("BatchedSouls") as MeshInstance2D
		_expect(int(material.get_shader_parameter("style_kind")) == index, "%s selects distinct silhouette" % styles[index])
		_expect(wisps.mesh is ArrayMesh and wisps.mesh.surface_get_array_len(0) <= 144, "soul trail is bounded immutable batch")
		var extent: Vector2 = envelope.size
		effect.call("update_projectile", 0.37)
		root.add_child(effect)
		_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.37), "ready preserves configured age")
		_expect(not effect.is_processing() and not effect.is_physics_processing(), "projectile presentation has no clock")
		_expect(is_zero_approx(effect.rotation) and effect.position == Vector2.ZERO, "visual spinning does not displace or rotate flight")
		var mesh: Mesh = wisps.mesh
		var child_count: int = effect.get_child_count()
		for frame: int in range(120):
			effect.call("update_projectile", frame / 120.0)
		_expect(wisps.mesh == mesh and effect.get_child_count() == child_count, "flight never replaces geometry or nodes")
		effect.call("update_projectile", 2.0)
		_expect(is_zero_approx(effect.modulate.a), "lifetime fades every layer")
		effect.call("deactivate")
		effect.call("update_projectile", 0.1)
		_expect(not effect.visible, "inactive projectile stays hidden")
		effect.call("configure_projectile", {"style": styles[index], "radius": 24.0, "speed": 600.0, "lifetime": 2.0})
		_expect(envelope.size.y > extent.y * 1.9, "radius scales silhouette and canvas bounds")
		_expect(envelope.material == material and wisps.mesh == mesh, "pool reuse retains material and shared mesh")
		_expect(effect.visible and is_equal_approx(effect.modulate.a, 1.0) and is_zero_approx(float(material.get_shader_parameter("effect_age"))), "reuse resets visibility and clock")
		effects.append(effect)
	var first_material: ShaderMaterial = effects[0].get_node("CurseEnvelope").material as ShaderMaterial
	var other_material: ShaderMaterial = effects[1].get_node("CurseEnvelope").material as ShaderMaterial
	_expect(first_material != other_material, "live projectiles isolate shader material")
	_expect(effects[0].get_node("BatchedSouls").mesh == effects[1].get_node("BatchedSouls").mesh, "projectiles share fixed soul mesh")
	effects[1].call("update_projectile", 0.81)
	_expect(is_zero_approx(float(first_material.get_shader_parameter("effect_age"))), "another projectile cannot change first clock")
	seed(70923)
	var expected_rng: int = randi()
	seed(70923)
	effects[0].call("configure_projectile", {"style": "soul_storm", "radius": 19.0, "seed": 8.0})
	effects[0].call("update_projectile", 0.54)
	_expect(randi() == expected_rng, "projectile preserves gameplay RNG")
	paused = true
	await process_frame
	await process_frame
	_expect(is_equal_approx(float(first_material.get_shader_parameter("effect_age")), 0.54), "paused projectile freezes at host age")
	paused = false
	_verify_boundaries(scene)
	if not "--module-only" in OS.get_cmdline_user_args():
		_verify_host()
	await _verify_link()
	for effect: Node2D in effects:
		effect.free()
	if "--render-projectiles" in OS.get_cmdline_user_args():
		await _verify_render(scene)
	print("[curse_projectile_effect] %d checks; failed=%s" % [_checks, _failed])
	quit(1 if _failed else 0)

func _verify_boundaries(scene: PackedScene) -> void:
	var effect: Node2D = scene.instantiate() as Node2D
	effect.call("configure_projectile", {"style": "unknown", "radius": -2.0, "speed": -9.0, "lifetime": 0.0})
	var envelope: ColorRect = effect.get_node("CurseEnvelope") as ColorRect
	var material: ShaderMaterial = envelope.material as ShaderMaterial
	var batch_material: ShaderMaterial = effect.get_node("BatchedSouls").material as ShaderMaterial
	_expect(int(material.get_shader_parameter("style_kind")) == 0, "unknown profile safely falls back to serpent")
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_radius")), 1.0), "nonpositive radius becomes finite minimum")
	_expect(envelope.size.x > 0.0 and envelope.size.y > 0.0 and envelope.size.is_finite(), "zero lifetime and negative speed keep finite canvas")
	effect.call("update_projectile", -3.0)
	_expect(is_zero_approx(float(material.get_shader_parameter("effect_age"))) and is_equal_approx(effect.modulate.a, 1.0), "negative host age clamps to beginning")
	effect.call("update_projectile", 5.0)
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.1) and is_zero_approx(effect.modulate.a), "host age clamps to minimum lifetime and fades")
	_expect(is_equal_approx(float(batch_material.get_shader_parameter("effect_age")), 0.1), "batched trail shares clamped host clock")
	effect.call("configure_projectile", {"style": "soul_storm", "radius": 12.0, "speed": 600.0, "lifetime": 2.0})
	var rect: Rect2 = Rect2(envelope.position, envelope.size)
	_expect(rect.has_point(Vector2(-110, 20)) and rect.has_point(Vector2(16, -20)), "storm canvas encloses wake and off-axis soul cores")
	var mesh: Mesh = effect.get_node("BatchedSouls").mesh
	var mesh_arrays: Array = (mesh as ArrayMesh).surface_get_arrays(0)
	effect.call("update_projectile", 0.78)
	_expect((mesh as ArrayMesh).surface_get_arrays(0) == mesh_arrays, "age never mutates shared vertex arrays")
	effect.free()

func _verify_host() -> void:
	var script: Script = load("res://scripts/combat/projectile.gd") as Script
	var host: Node2D = script.new() as Node2D
	var params: Dictionary = {"visual_effect_scene": EFFECT_PATH, "visual_mode": "programmatic", "visual_style": "black_serpent", "radius": 12.0, "direction": Vector2.UP, "speed": 600.0, "lifetime": 2.0}
	host.call("setup", params)
	var effect: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(effect != null and not effect.is_inside_tree(), "host configures curse off-tree")
	root.add_child(host)
	host.set_physics_process(false)
	host.call("_physics_process", 0.2)
	_expect(host.position.is_equal_approx(Vector2(0, -120)), "curse leaves authoritative motion unchanged")
	_expect(is_equal_approx(effect.global_rotation, -PI / 2.0), "host owns curse direction")
	var material: ShaderMaterial = effect.get_node("CurseEnvelope").material as ShaderMaterial
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.2), "host forwards authoritative age")
	host.call("prepare_for_pool_despawn")
	_expect(not effect.visible, "host return hides curse")
	params["visual_style"] = "death_scythe"
	params["direction"] = Vector2.DOWN
	host.call("prepare_for_pool_spawn", params)
	host.set_physics_process(false)
	_expect(host.get("_visual_effect_node") == effect, "host pool reuse keeps curse node")
	_expect(int(material.get_shader_parameter("style_kind")) == 1, "host reuse switches serpent to scythe")
	_expect(is_equal_approx(effect.global_rotation, PI / 2.0), "reuse restores actual direction")
	host.free()

func _verify_link() -> void:
	var script: Script = load(LINK_PATH) as Script
	var container: Node2D = Node2D.new()
	container.position = Vector2(90, 40)
	container.rotation = 0.4
	container.scale = Vector2(1.5, 0.7)
	root.add_child(container)
	var link: Node2D = script.new() as Node2D
	link.call("configure", Vector2(10, 20), Vector2(210, 90), 42.0, 0)
	container.add_child(link)
	link.set_process(false)
	var core: Line2D = link.get_node("Core") as Line2D
	var souls: MeshInstance2D = link.get_node("BatchedSouls") as MeshInstance2D
	var material: ShaderMaterial = souls.material as ShaderMaterial
	_expect(link.is_set_as_top_level() and link.global_position.is_equal_approx(Vector2(10, 20)), "link source remains in world coordinates")
	_expect(is_zero_approx(link.global_rotation) and link.global_scale.is_equal_approx(Vector2.ONE), "parent transforms cannot distort real link endpoints")
	_expect(core.points[0].is_equal_approx(Vector2.ZERO) and core.points[-1].is_equal_approx(Vector2(200, 70)), "link connects exact real source and target")
	_expect(link.get_child_count() >= 4 and link.get_child_count() <= 6, "soul chain has fixed bounded layers")
	var points: PackedVector2Array = core.points.duplicate()
	var mesh: Mesh = souls.mesh
	var count: int = link.get_child_count()
	link.call("_process", 0.05)
	_expect(core.points == points and souls.mesh == mesh and link.get_child_count() == count, "link playback never regenerates geometry")
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.05), "soul beads use pausable delta clock")
	link.call("configure", Vector2(10, 20), Vector2(210, 90), 42.0, 0)
	link.set_process(false)
	_expect(core.points == points, "seed reproduces curved path")
	seed(80121)
	var expected_rng: int = randi()
	seed(80121)
	link.call("configure", Vector2(300, 100), Vector2(420, 100), 43.0, 1)
	link.set_process(false)
	_expect(randi() == expected_rng, "link preserves gameplay RNG")
	_expect(int(material.get_shader_parameter("link_kind")) == 1, "epidemic wisps flow to destination")
	_expect(core.points[-1].is_equal_approx(Vector2(120, 0)) and link.global_position.is_equal_approx(Vector2(300, 100)), "reuse resets world endpoints")
	var other: Node2D = script.new() as Node2D
	other.call("configure", Vector2.ZERO, Vector2.ONE * 100.0, 1.0)
	container.add_child(other)
	other.set_process(false)
	_expect(other.get_node("BatchedSouls").mesh == mesh and other.get_node("BatchedSouls").material != material, "links share mesh but isolate live uniforms")
	link.set_process(true)
	paused = true
	var age: float = float(link.get("_age"))
	await process_frame
	await process_frame
	_expect(is_equal_approx(float(link.get("_age")), age), "link delta clock obeys scene pause")
	paused = false
	link.set_process(false)
	link.call("_process", 0.8)
	_expect(not link.visible and not link.is_processing(), "expired link deactivates for pool reuse")
	link.call("configure", Vector2.ZERO, Vector2.ZERO, 3.0)
	_expect(link.visible and is_equal_approx(link.modulate.a, 1.0) and core.points[-1] == Vector2.ZERO, "zero-length reuse remains finite and resets opacity")
	link.call("_process", -1.0)
	_expect(is_zero_approx(float(material.get_shader_parameter("effect_age"))) and is_equal_approx(link.modulate.a, 1.0), "negative link delta cannot reverse clock")
	link.call("configure", Vector2(400, 300), Vector2(-120, -200), -55.0, 8)
	link.set_process(false)
	_expect(core.points[0] == Vector2.ZERO and core.points[-1] == Vector2(-520, -500), "negative and reverse endpoint spans connect exactly")
	_expect(int(material.get_shader_parameter("link_kind")) == 1, "out-of-range link kind clamps to epidemic")
	link.call("deactivate")
	_expect(not link.visible and not link.is_processing(), "explicit deactivate disables link")
	container.free()

func _verify_render(scene: PackedScene) -> void:
	_expect(DisplayServer.get_name() != "headless", "pixel verification requires GPU renderer")
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("E:/codex/curse-projectiles/render")
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(960, 620)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(960, 620)
	background.color = Color(0.024, 0.026, 0.038)
	viewport.add_child(background)
	var effects: Array[Node2D] = []
	var styles: Array[String] = ["black_serpent", "death_scythe", "soul_bolt", "soul_storm"]
	for row: int in range(4):
		for column: int in range(2):
			var effect: Node2D = scene.instantiate() as Node2D
			viewport.add_child(effect)
			effect.position = Vector2(480 + column * 340, 65 + row * 110)
			effect.call("configure_projectile", {"style": styles[row], "radius": 16.0 if column == 0 else 9.0, "speed": 650.0, "lifetime": 2.0})
			effect.call("update_projectile", 0.35)
			effects.append(effect)
		var label: Label = Label.new()
		label.position = Vector2(24, 55 + row * 110)
		label.text = styles[row]
		viewport.add_child(label)
	var link_script: Script = load(LINK_PATH) as Script
	var links: Array[Node2D] = []
	for kind: int in range(2):
		var link: Node2D = link_script.new() as Node2D
		viewport.add_child(link)
		link.call("configure", Vector2(160, 510 + kind * 65), Vector2(820, 510 + kind * 65), 37.0, kind)
		link.call("_process", 0.11)
		link.set_process(false)
		links.append(link)
	await _draw_frames()
	var image: Image = viewport.get_texture().get_image()
	_expect(image.save_png("E:/codex/curse-projectiles/render/projectile_profiles.png") == OK, "GPU capture saves to E drive")
	for row: int in range(4):
		var lit: int = 0
		for y: int in range(45 + row * 110, 85 + row * 110):
			for x: int in range(455, 505):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.g > 0.3 or pixel.b > 0.3:
					lit += 1
		_expect(lit > 65, "%s has readable curse body (%d pixels)" % [styles[row], lit])
	paused = true
	await _draw_frames()
	var frozen: PackedByteArray = viewport.get_texture().get_image().get_data()
	await create_timer(0.1, true).timeout
	await RenderingServer.frame_post_draw
	_expect(viewport.get_texture().get_image().get_data() == frozen, "curse pixels freeze when clocks stop")
	paused = false
	for effect: Node2D in effects:
		effect.call("update_projectile", 2.0)
	for link: Node2D in links:
		link.call("deactivate")
	await _draw_frames()
	var faded: Image = viewport.get_texture().get_image()
	var remaining: int = 0
	for y: int in range(30, 610):
		for x: int in range(280, 940):
			if faded.get_pixel(x, y).b > 0.08:
				remaining += 1
	_expect(remaining == 0, "expired curse leaves no lingering pixels")
	viewport.free()

func _draw_frames() -> void:
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % message)
	else:
		_failed = true
		push_error("[FAIL] %s" % message)
