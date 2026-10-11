extends SceneTree

const EFFECT_PATH: String = "res://scenes/effects/thunder_projectile_effect.tscn"
const ARC_PATH: String = "res://scripts/effects/thunder_arc_effect.gd"
const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")
var _failed: bool = false
var _checks: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(EFFECT_PATH), "production thunder projectile scene exists")
	_expect(ResourceLoader.exists(ARC_PATH), "pooled thunder arc script exists")
	if _failed:
		quit(1)
		return
	var scene: PackedScene = load(EFFECT_PATH) as PackedScene
	var effects: Array[Node2D] = []
	var styles: Array[String] = ["lightning_orb", "lightning_orb_projectile", "chain_lightning", "chain_lightning_bolt", "thunder_arc", "thunder_arc_bolt"]
	for index: int in range(styles.size()):
		var effect: Node2D = scene.instantiate() as Node2D
		effect.call("configure_projectile", {"style": styles[index], "radius": 12.0, "speed": 600.0, "direction": Vector2.UP, "lifetime": 2.0})
		var envelope: ColorRect = effect.get_node("ElectricEnvelope") as ColorRect
		var material: ShaderMaterial = envelope.material as ShaderMaterial
		var ribbons: MeshInstance2D = effect.get_node("BatchedLightning") as MeshInstance2D
		_expect(int(material.get_shader_parameter("style_kind")) == index / 2, "%s chooses its distinct profile" % styles[index])
		_expect(ribbons.mesh is ArrayMesh and ribbons.mesh.surface_get_array_len(0) <= 432, "lightning is a bounded immutable batch")
		var extent: Vector2 = envelope.size
		effect.call("update_projectile", 0.37)
		root.add_child(effect)
		_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.37), "ready preserves pre-tree configured age")
		_expect(not effect.is_processing() and not effect.is_physics_processing(), "projectile presentation has no clock")
		var mesh: Mesh = ribbons.mesh
		var child_count: int = effect.get_child_count()
		for frame: int in range(120):
			effect.call("update_projectile", frame / 120.0)
		_expect(ribbons.mesh == mesh and effect.get_child_count() == child_count, "flight never replaces geometry or nodes")
		effect.call("update_projectile", 2.0)
		_expect(is_zero_approx(effect.modulate.a), "lifetime fades all layers")
		effect.call("deactivate")
		effect.call("update_projectile", 0.1)
		_expect(not effect.visible, "inactive projectile stays hidden")
		effect.call("configure_projectile", {"style": styles[index], "radius": 24.0, "speed": 600.0, "lifetime": 2.0})
		_expect(envelope.size.y > extent.y * 1.9, "radius scales the electric silhouette")
		_expect(envelope.material == material and ribbons.mesh == mesh, "pool reuse retains material and shared mesh")
		_expect(effect.visible and is_equal_approx(effect.modulate.a, 1.0) and is_zero_approx(float(material.get_shader_parameter("effect_age"))), "pool reuse resets visibility and clock")
		effects.append(effect)
	var first_material: ShaderMaterial = effects[0].get_node("ElectricEnvelope").material as ShaderMaterial
	var other_material: ShaderMaterial = effects[1].get_node("ElectricEnvelope").material as ShaderMaterial
	_expect(first_material != other_material, "live projectiles isolate shader material")
	_expect(effects[0].get_node("BatchedLightning").mesh == effects[1].get_node("BatchedLightning").mesh, "live projectiles share fixed lightning mesh")
	effects[1].call("update_projectile", 0.81)
	_expect(is_zero_approx(float(first_material.get_shader_parameter("effect_age"))), "another projectile cannot change first clock")
	seed(70923)
	var expected_rng: int = randi()
	seed(70923)
	effects[0].call("configure_projectile", {"style": "thunder_arc", "radius": 19.0})
	effects[0].call("update_projectile", 0.54)
	_expect(randi() == expected_rng, "projectile preserves gameplay RNG")
	paused = true
	await process_frame
	await process_frame
	_expect(is_equal_approx(float(first_material.get_shader_parameter("effect_age")), 0.54), "paused projectile freezes at host age")
	paused = false
	_verify_host()
	await _verify_arc()
	for effect: Node2D in effects:
		effect.free()
	if "--render-projectiles" in OS.get_cmdline_user_args():
		await _verify_render(scene)
	print("[thunder_projectile_effect] %d checks; failed=%s" % [_checks, _failed])
	quit(1 if _failed else 0)


func _verify_host() -> void:
	var host: Node2D = ProjectileScript.new() as Node2D
	var params: Dictionary = {"visual_effect_scene": EFFECT_PATH, "visual_mode": "programmatic", "visual_style": "lightning_orb", "radius": 12.0, "direction": Vector2.UP, "speed": 600.0, "lifetime": 2.0}
	host.call("setup", params)
	var effect: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(effect != null and not effect.is_inside_tree(), "host configures thunder off-tree")
	root.add_child(host)
	host.set_physics_process(false)
	host.call("_physics_process", 0.2)
	_expect(host.position.is_equal_approx(Vector2(0, -120)), "thunder leaves authoritative motion unchanged")
	_expect(is_equal_approx(effect.global_rotation, -PI / 2.0), "host owns lightning direction")
	_expect(is_equal_approx(float((effect.get_node("ElectricEnvelope").material as ShaderMaterial).get_shader_parameter("effect_age")), 0.2), "host forwards authoritative age")
	host.call("prepare_for_pool_despawn")
	_expect(not effect.visible, "host return hides lightning")
	params["visual_style"] = "chain_lightning"
	params["direction"] = Vector2.DOWN
	host.call("prepare_for_pool_spawn", params)
	host.set_physics_process(false)
	_expect(host.get("_visual_effect_node") == effect, "host pool reuse keeps lightning node")
	_expect(int((effect.get_node("ElectricEnvelope").material as ShaderMaterial).get_shader_parameter("style_kind")) == 1, "host reuse switches orb to chain bolt")
	_expect(is_equal_approx(effect.global_rotation, PI / 2.0), "reuse restores current direction")
	host.free()


func _verify_arc() -> void:
	var script: Script = load(ARC_PATH) as Script
	var container: Node2D = Node2D.new()
	container.position = Vector2(90, 40)
	container.rotation = 0.4
	root.add_child(container)
	var arc: Node2D = script.new() as Node2D
	arc.call("configure", Vector2(10, 20), Vector2(210, 90), 42.0)
	container.add_child(arc)
	arc.set_process(false)
	var core: Line2D = arc.get_node("Core") as Line2D
	_expect(arc.is_set_as_top_level() and arc.global_position.is_equal_approx(Vector2(10, 20)), "arc endpoints stay in world coordinates")
	_expect(core.points[0].is_equal_approx(Vector2.ZERO) and core.points[-1].is_equal_approx(Vector2(200, 70)), "arc connects exact real source and target")
	var points: PackedVector2Array = core.points.duplicate()
	var count: int = arc.get_child_count()
	arc.call("_process", 0.05)
	_expect(core.points == points and arc.get_child_count() == count, "arc playback never regenerates geometry")
	arc.call("configure", Vector2(10, 20), Vector2(210, 90), 42.0)
	arc.set_process(false)
	_expect(core.points == points, "seed reproduces jagged path")
	seed(80121)
	var expected_rng: int = randi()
	seed(80121)
	arc.call("configure", Vector2(300, 100), Vector2(420, 100), 43.0)
	arc.set_process(false)
	_expect(randi() == expected_rng, "arc preserves gameplay RNG")
	_expect(core.points[-1].is_equal_approx(Vector2(120, 0)) and arc.global_position.is_equal_approx(Vector2(300, 100)), "reconfigured arc resets endpoints")
	arc.set_process(true)
	paused = true
	var age: float = float(arc.get("_age"))
	await process_frame
	await process_frame
	_expect(is_equal_approx(float(arc.get("_age")), age), "arc delta clock obeys scene pause")
	paused = false
	arc.set_process(false)
	arc.call("_process", 0.3)
	_expect(not arc.visible and not arc.is_processing(), "expired arc deactivates for pool reuse")
	arc.call("configure", Vector2.ZERO, Vector2.ZERO, 3.0)
	_expect(arc.visible and is_equal_approx(arc.modulate.a, 1.0), "zero-length pooled arc config remains finite and resets opacity")
	arc.call("deactivate")
	_expect(not arc.visible and not arc.is_processing(), "explicit deactivate disables arc")
	container.free()


func _verify_render(scene: PackedScene) -> void:
	_expect(DisplayServer.get_name() != "headless", "pixel verification requires GPU renderer")
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("E:/codex/thunder-projectiles/render")
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(800, 460)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(800, 460)
	background.color = Color(0.022, 0.029, 0.047)
	viewport.add_child(background)
	var effects: Array[Node2D] = []
	var styles: Array[String] = ["lightning_orb", "chain_lightning", "thunder_arc"]
	for row: int in range(3):
		var effect: Node2D = scene.instantiate() as Node2D
		viewport.add_child(effect)
		effect.position = Vector2(510, 65 + row * 110)
		effect.call("configure_projectile", {"style": styles[row], "radius": 16.0, "speed": 650.0, "lifetime": 2.0})
		effect.call("update_projectile", 0.35)
		effects.append(effect)
		var label: Label = Label.new()
		label.position = Vector2(24, 55 + row * 110)
		label.text = styles[row]
		viewport.add_child(label)
	var arc_script: Script = load(ARC_PATH) as Script
	var arc: Node2D = arc_script.new() as Node2D
	viewport.add_child(arc)
	arc.call("configure", Vector2(180, 390), Vector2(680, 400), 37.0)
	arc.set_process(false)
	await _draw_frames()
	var image: Image = viewport.get_texture().get_image()
	_expect(image.save_png("E:/codex/thunder-projectiles/render/projectile_profiles.png") == OK, "GPU capture saves to E drive")
	for row: int in range(3):
		var lit: int = 0
		for y: int in range(45 + row * 110, 85 + row * 110):
			for x: int in range(490, 535):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.b > 0.4 and pixel.g > 0.3:
					lit += 1
		_expect(lit > 80, "%s has readable blue white electric body (%d pixels)" % [styles[row], lit])
	paused = true
	await _draw_frames()
	var frozen: PackedByteArray = viewport.get_texture().get_image().get_data()
	await create_timer(0.1, true).timeout
	await RenderingServer.frame_post_draw
	_expect(viewport.get_texture().get_image().get_data() == frozen, "all thunder pixels freeze while clocks stop")
	paused = false
	for effect: Node2D in effects:
		effect.call("update_projectile", 2.0)
	arc.call("deactivate")
	await _draw_frames()
	var faded: Image = viewport.get_texture().get_image()
	var remaining: int = 0
	for y: int in range(30, 445):
		for x: int in range(280, 730):
			if faded.get_pixel(x, y).b > 0.08:
				remaining += 1
	_expect(remaining == 0, "deactivated thunder leaves no lingering pixels")
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
