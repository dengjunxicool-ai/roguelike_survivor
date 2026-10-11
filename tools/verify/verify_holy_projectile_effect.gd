extends SceneTree

const EFFECT_PATH: String = "res://scenes/effects/holy_projectile_effect.tscn"
const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")
var _failed: bool = false
var _checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(ResourceLoader.exists(EFFECT_PATH), "holy projectile scene exists")
	if _failed:
		quit(1)
		return
	var scene: PackedScene = load(EFFECT_PATH) as PackedScene
	var effects: Array[Node2D] = []
	var styles: Array[String] = ["holy_ray", "holy_ray_beam", "seraph_bolt", "seraph_holy_bolt"]
	for index: int in range(styles.size()):
		var effect: Node2D = scene.instantiate() as Node2D
		effect.call("configure_projectile", {"style": styles[index], "radius": 12.0, "speed": 900.0, "lifetime": 2.0, "seed": 37.0})
		var envelope: ColorRect = effect.get_node("HolyEnvelope") as ColorRect
		var material: ShaderMaterial = envelope.material as ShaderMaterial
		var feathers: MeshInstance2D = effect.get_node("BatchedFeathers") as MeshInstance2D
		_expect(int(material.get_shader_parameter("style_kind")) == index / 2, "%s selects intended silhouette" % styles[index])
		_expect(feathers.mesh is ArrayMesh and feathers.mesh.surface_get_array_len(0) <= 144, "feather wake is a fixed bounded batch")
		var extent: Vector2 = envelope.size
		effect.call("update_projectile", 0.37)
		root.add_child(effect)
		_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.37), "ready preserves off-tree host age")
		_expect(not effect.is_processing() and not effect.is_physics_processing(), "visual has no independent clock")
		var mesh: Mesh = feathers.mesh
		var count: int = effect.get_child_count()
		var location: Vector2 = effect.position
		for frame: int in range(120):
			effect.call("update_projectile", float(frame) / 120.0)
		_expect(feathers.mesh == mesh and effect.get_child_count() == count and effect.position == location, "updates retain geometry and leave motion to host")
		effect.call("update_projectile", 2.0)
		_expect(is_zero_approx(effect.modulate.a), "expiry fades every layer")
		effect.call("deactivate")
		effect.call("update_projectile", 0.1)
		_expect(not effect.visible, "deactivated presentation stays hidden")
		effect.call("configure_projectile", {"style": styles[index], "radius": 24.0, "speed": 900.0, "lifetime": 2.0})
		_expect(envelope.size.y > extent.y * 1.9, "radius scales silhouette")
		_expect(envelope.material == material and feathers.mesh == mesh, "pool reset retains material and mesh")
		_expect(effect.visible and is_equal_approx(effect.modulate.a, 1.0) and is_zero_approx(float(material.get_shader_parameter("effect_age"))), "pool reset restores opacity and zero age")
		effects.append(effect)
	var first: ShaderMaterial = effects[0].get_node("HolyEnvelope").material as ShaderMaterial
	var second: ShaderMaterial = effects[1].get_node("HolyEnvelope").material as ShaderMaterial
	_expect(first != second, "instances isolate shader state")
	_expect(effects[0].get_node("BatchedFeathers").mesh == effects[1].get_node("BatchedFeathers").mesh, "instances share immutable feather geometry")
	effects[1].call("update_projectile", 0.81)
	_expect(is_zero_approx(float(first.get_shader_parameter("effect_age"))), "another instance cannot change clock")
	seed(92871)
	var expected_rng: int = randi()
	seed(92871)
	effects[0].call("configure_projectile", {"style": "holy_ray", "radius": 58.8, "seed": 51.0})
	effects[0].call("update_projectile", 0.54)
	_expect(randi() == expected_rng, "presentation preserves gameplay random sequence")
	paused = true
	await process_frame
	await process_frame
	_expect(is_equal_approx(float(first.get_shader_parameter("effect_age")), 0.54), "pause leaves host age unchanged")
	paused = false
	effects[0].call("configure_projectile", {"style": "unknown", "radius": -5.0, "speed": -20.0, "lifetime": 0.0})
	effects[0].call("update_projectile", -1.0)
	_expect(is_equal_approx(float(first.get_shader_parameter("effect_radius")), 1.0) and is_zero_approx(float(first.get_shader_parameter("effect_age"))), "invalid bounds normalize without invalid geometry")
	effects[0].call("update_projectile", 999.0)
	_expect(is_zero_approx(effects[0].modulate.a), "overshoot age fully expires visual")
	effects[0].call("configure_projectile", {"style": "seraph_bolt", "radius": INF, "speed": NAN, "lifetime": INF, "seed": NAN})
	effects[0].call("update_projectile", NAN)
	_expect(is_equal_approx(float(first.get_shader_parameter("effect_radius")), 12.0) and is_zero_approx(float(first.get_shader_parameter("effect_seed"))) and is_zero_approx(float(first.get_shader_parameter("effect_age"))), "nonfinite inputs use finite defaults")
	effects[0].call("configure_projectile", {"style": "holy_ray", "radius": 99999.0, "speed": 99999.0, "lifetime": 99999.0, "seed": -9000.0})
	var envelope: ColorRect = effects[0].get_node("HolyEnvelope") as ColorRect
	_expect(envelope.size.is_finite() and float(first.get_shader_parameter("effect_radius")) <= 256.0 and float(first.get_shader_parameter("wake_length")) <= 1792.0 and float(first.get_shader_parameter("effect_seed")) >= 0.0, "extreme inputs retain bounded finite drawing envelope")
	effects[0].call("update_projectile", 999999.0)
	_expect(is_zero_approx(effects[0].modulate.a), "extreme bounded lifetime expires completely")
	_verify_host()
	for effect: Node2D in effects:
		effect.free()
	if "--render-projectiles" in OS.get_cmdline_user_args():
		await _verify_render(scene)
	print("[holy_projectile_effect] %d checks; failed=%s" % [_checks, _failed])
	quit(1 if _failed else 0)

func _verify_host() -> void:
	var host: Node2D = ProjectileScript.new() as Node2D
	var params: Dictionary = {"visual_effect_scene": EFFECT_PATH, "visual_mode": "programmatic", "visual_style": "holy_ray", "radius": 58.8, "direction": Vector2.UP, "speed": 900.0, "lifetime": 2.0}
	host.call("setup", params)
	var effect: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(effect != null and not effect.is_inside_tree(), "actual Projectile configures holy visual off-tree")
	root.add_child(host)
	host.set_physics_process(false)
	host.call("_physics_process", 0.2)
	_expect(host.position.is_equal_approx(Vector2(0, -180)), "host owns exact holy ray motion")
	_expect(is_equal_approx(effect.global_rotation, -PI / 2.0), "host owns visual direction")
	var material: ShaderMaterial = effect.get_node("HolyEnvelope").material as ShaderMaterial
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.2), "actual host forwards authoritative age")
	host.call("prepare_for_pool_despawn")
	_expect(not effect.visible, "actual host despawn hides presentation")
	params["visual_style"] = "seraph_bolt"
	params["direction"] = Vector2.DOWN
	params["radius"] = 10.0
	host.call("prepare_for_pool_spawn", params)
	host.set_physics_process(false)
	_expect(host.get("_visual_effect_node") == effect, "actual host pool spawn retains presentation")
	_expect(int(material.get_shader_parameter("style_kind")) == 1 and is_equal_approx(float(material.get_shader_parameter("effect_radius")), 10.0), "reuse changes holy ray to small seraph feather")
	_expect(is_equal_approx(effect.global_rotation, PI / 2.0), "reuse restores current flight direction")
	host.free()

func _verify_render(scene: PackedScene) -> void:
	_expect(DisplayServer.get_name() != "headless", "render verification requires GPU")
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("E:/codex/holy-projectiles/render")
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1000, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color(0.022, 0.029, 0.047)
	viewport.add_child(background)
	var effects: Array[Node2D] = []
	var styles: Array[String] = ["holy_ray", "seraph_bolt"]
	for row: int in range(2):
		var effect: Node2D = scene.instantiate() as Node2D
		viewport.add_child(effect)
		effect.position = Vector2(640, 140 + row * 260)
		effect.call("configure_projectile", {"style": styles[row], "radius": 58.8 if row == 0 else 16.0, "speed": 900.0, "lifetime": 2.0, "seed": 37.0})
		effect.call("update_projectile", 0.35)
		effects.append(effect)
		var label: Label = Label.new()
		label.position = Vector2(28, 20 + row * 260)
		label.text = styles[row]
		viewport.add_child(label)
	await _draw_frames()
	var image: Image = viewport.get_texture().get_image()
	_expect(image.save_png("E:/codex/holy-projectiles/render/projectile_profiles.png") == OK, "GPU profile capture saves on E drive")
	for row: int in range(2):
		var lit: int = 0
		for y: int in range(120 + row * 260, 160 + row * 260):
			for x: int in range(620, 670):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.r > 0.5 and pixel.g > 0.4 and pixel.b > 0.25:
					lit += 1
		_expect(lit > 70, "%s has readable platinum body (%d pixels)" % [styles[row], lit])
	paused = true
	await _draw_frames()
	var frozen: PackedByteArray = viewport.get_texture().get_image().get_data()
	await create_timer(0.1, true).timeout
	await RenderingServer.frame_post_draw
	_expect(viewport.get_texture().get_image().get_data() == frozen, "holy pixels freeze when host clock stops")
	paused = false
	for effect: Node2D in effects:
		effect.call("update_projectile", 2.0)
	await _draw_frames()
	var faded: Image = viewport.get_texture().get_image()
	var remaining: int = 0
	for y: int in range(60, 500):
		for x: int in range(240, 980):
			if faded.get_pixel(x, y).r > 0.08:
				remaining += 1
	_expect(remaining == 0, "expired holy presentation leaves no pixels")
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
