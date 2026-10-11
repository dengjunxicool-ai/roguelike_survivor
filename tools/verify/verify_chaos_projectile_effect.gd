extends SceneTree

const EFFECT_PATH: String = "res://scenes/effects/chaos_projectile_effect.tscn"
const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")
var _failed: bool = false
var _checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(ResourceLoader.exists(EFFECT_PATH), "chaos orb scene exists")
	if _failed:
		quit(1)
		return
	var scene: PackedScene = load(EFFECT_PATH) as PackedScene
	var effects: Array[Node2D] = []
	for branch: int in [-1, 0, 1, 2]:
		var effect: Node2D = scene.instantiate() as Node2D
		effect.call("configure_projectile", {"style": "chaos_orb", "radius": 14.0, "speed": 360.0, "lifetime": 2.0, "seed": 37.0, "geometry_branch": branch})
		var envelope: ColorRect = effect.get_node("ChaosEnvelope") as ColorRect
		var material: ShaderMaterial = envelope.material as ShaderMaterial
		var fragments: MeshInstance2D = effect.get_node("BatchedFragments") as MeshInstance2D
		_expect(effect.get("profile") == "chaos_orb" and int(material.get_shader_parameter("geometry_branch")) == branch, "canonical orb accepts actual branch %d" % branch)
		_expect(is_equal_approx(float(material.get_shader_parameter("effect_radius")), 14.0), "orb uses actual collision radius")
		_expect(fragments.mesh is ArrayMesh and fragments.mesh.surface_get_array_len(0) <= 144, "fragment wake is a bounded fixed batch")
		var extent: Vector2 = envelope.size
		effect.call("update_projectile", 0.37)
		root.add_child(effect)
		_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.37), "ready preserves off-tree authoritative age")
		_expect(not effect.is_processing() and not effect.is_physics_processing(), "orb has no independent clock")
		var mesh: Mesh = fragments.mesh
		var count: int = effect.get_child_count()
		var location: Vector2 = effect.position
		for frame: int in range(120):
			effect.call("update_projectile", float(frame) / 120.0)
		_expect(fragments.mesh == mesh and effect.get_child_count() == count and effect.position == location, "updates retain geometry and host motion")
		effect.call("update_projectile", 2.0)
		_expect(is_zero_approx(effect.modulate.a), "expiry fades orb and fragments")
		effect.call("deactivate")
		effect.call("update_projectile", 0.1)
		_expect(not effect.visible, "deactivated orb cannot reappear")
		effect.call("configure_projectile", {"style": "chaos_orb", "radius": 28.0, "speed": 360.0, "lifetime": 2.0})
		_expect(envelope.size.y > extent.y * 1.9, "collision radius scales orb presentation")
		_expect(envelope.material == material and fragments.mesh == mesh, "pool reuse retains material and mesh")
		_expect(effect.visible and is_equal_approx(effect.modulate.a, 1.0) and is_zero_approx(float(material.get_shader_parameter("effect_age"))) and int(material.get_shader_parameter("geometry_branch")) == -1, "pool reset clears branch age and opacity")
		effects.append(effect)
	var first: ShaderMaterial = effects[0].get_node("ChaosEnvelope").material as ShaderMaterial
	var second: ShaderMaterial = effects[1].get_node("ChaosEnvelope").material as ShaderMaterial
	_expect(first != second, "instances isolate shader state")
	_expect(effects[0].get_node("BatchedFragments").mesh == effects[1].get_node("BatchedFragments").mesh, "instances share immutable fragment mesh")
	effects[1].call("update_projectile", 0.81)
	_expect(is_zero_approx(float(first.get_shader_parameter("effect_age"))), "other orb cannot advance this clock")
	seed(92871)
	var expected_rng: int = randi()
	seed(92871)
	effects[0].call("configure_projectile", {"style": "chaos_orb", "radius": 14.0, "seed": 51.0})
	effects[0].call("update_projectile", 0.54)
	_expect(randi() == expected_rng, "orb preserves gameplay random sequence")
	paused = true
	await process_frame
	await process_frame
	_expect(is_equal_approx(float(first.get_shader_parameter("effect_age")), 0.54), "pause keeps host age frozen")
	paused = false
	effects[0].call("configure_projectile", {"style": "unknown", "radius": -5.0, "speed": -20.0, "lifetime": 0.0, "geometry_branch": -5})
	effects[0].call("update_projectile", -1.0)
	_expect(effects[0].get("profile") == "chaos_orb" and is_equal_approx(float(first.get_shader_parameter("effect_radius")), 1.0) and is_zero_approx(float(first.get_shader_parameter("effect_age"))) and int(first.get_shader_parameter("geometry_branch")) == -1, "invalid style bounds and branch normalize safely")
	effects[0].call("update_projectile", 999.0)
	_expect(is_zero_approx(effects[0].modulate.a), "overshoot age fully expires visual")
	effects[0].call("configure_projectile", {"radius": INF, "speed": NAN, "lifetime": INF, "seed": NAN, "geometry_branch": INF})
	effects[0].call("update_projectile", NAN)
	_expect(is_equal_approx(float(first.get_shader_parameter("effect_radius")), 14.0) and is_zero_approx(float(first.get_shader_parameter("effect_seed"))) and is_zero_approx(float(first.get_shader_parameter("effect_age"))) and int(first.get_shader_parameter("geometry_branch")) == -1, "nonfinite inputs use finite defaults")
	effects[0].call("configure_projectile", {"radius": 99999.0, "speed": 99999.0, "lifetime": 99999.0, "seed": -9000.0})
	var envelope: ColorRect = effects[0].get_node("ChaosEnvelope") as ColorRect
	_expect(envelope.size.is_finite() and float(first.get_shader_parameter("effect_radius")) <= 256.0 and float(first.get_shader_parameter("wake_length")) <= 1536.0 and float(first.get_shader_parameter("effect_seed")) >= 0.0, "extreme inputs retain bounded finite envelope")
	effects[0].call("update_projectile", INF)
	_expect(is_zero_approx(float(first.get_shader_parameter("effect_age"))), "nonfinite age cannot reach shader")
	effects[0].call("update_projectile", 999999.0)
	_expect(is_zero_approx(effects[0].modulate.a), "extreme lifetime expires completely")
	_verify_host()
	for effect: Node2D in effects:
		effect.free()
	if "--render-projectiles" in OS.get_cmdline_user_args():
		await _verify_render(scene)
	print("[chaos_projectile_effect] %d checks; failed=%s" % [_checks, _failed])
	quit(1 if _failed else 0)

func _verify_host() -> void:
	var host: Node2D = ProjectileScript.new() as Node2D
	var params: Dictionary = {"visual_effect_scene": EFFECT_PATH, "visual_mode": "programmatic", "visual_style": "chaos_orb", "radius": 14.0, "direction": Vector2.UP, "speed": 360.0, "lifetime": 2.0, "chaos_geometry_branch":2}
	host.call("setup", params)
	var effect: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(effect != null and not effect.is_inside_tree(), "actual Projectile configures chaos orb off-tree")
	root.add_child(host)
	host.set_physics_process(false)
	host.call("_physics_process", 0.2)
	_expect(host.position.is_equal_approx(Vector2(0, -72)), "host owns exact chaos orb motion")
	_expect(is_equal_approx(effect.global_rotation, -PI / 2.0), "host owns actual flight direction")
	var material: ShaderMaterial = effect.get_node("ChaosEnvelope").material as ShaderMaterial
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.2), "actual host forwards authoritative age")
	_expect(int(material.get_shader_parameter("geometry_branch")) == 2, "actual host snapshots real bounce branch")
	host.call("prepare_for_pool_despawn")
	_expect(not effect.visible, "actual host despawn hides orb")
	params["direction"] = Vector2.DOWN
	params["radius"] = 28.0
	params["chaos_geometry_branch"] = 1
	host.call("prepare_for_pool_spawn", params)
	host.set_physics_process(false)
	_expect(host.get("_visual_effect_node") == effect, "actual pool spawn retains orb presentation")
	_expect(is_equal_approx(float(material.get_shader_parameter("effect_radius")), 28.0) and is_zero_approx(float(material.get_shader_parameter("effect_age"))), "actual pool reuse adopts current radius and clears age")
	_expect(is_equal_approx(effect.global_rotation, PI / 2.0), "pool reuse restores current flight direction")
	_expect(int(material.get_shader_parameter("geometry_branch")) == 1, "actual pooled host resets bounce marker to real return branch")
	host.free()

func _verify_render(scene: PackedScene) -> void:
	_expect(DisplayServer.get_name() != "headless", "render verification requires GPU")
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("E:/codex/chaos-projectiles/render")
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1000, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color(0.022, 0.029, 0.047)
	viewport.add_child(background)
	var effects: Array[Node2D] = []
	for row: int in range(4):
		var effect: Node2D = scene.instantiate() as Node2D
		viewport.add_child(effect)
		effect.position = Vector2(640, 80 + row * 145)
		effect.call("configure_projectile", {"radius": 14.0 if row == 0 else 32.0, "speed": 360.0, "lifetime": 2.0, "seed": 37.0, "geometry_branch": row - 1})
		effect.call("update_projectile", 0.35)
		effects.append(effect)
		var label: Label = Label.new()
		label.position = Vector2(28, 10 + row * 145)
		label.text = "chaos_orb / branch %d" % (row - 1)
		viewport.add_child(label)
	await _draw_frames()
	var image: Image = viewport.get_texture().get_image()
	_expect(image.save_png("E:/codex/chaos-projectiles/render/projectile_profiles.png") == OK, "GPU capture saves on E drive")
	for row: int in range(4):
		var lit: int = 0
		for y: int in range(72 + row * 145, 89 + row * 145):
			for x: int in range(632, 649):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.g > 0.25 and pixel.b > 0.35:
					lit += 1
		_expect(lit > 40, "branch %d has readable cyan-white core (%d pixels)" % [row - 1, lit])
	paused = true
	await _draw_frames()
	var frozen: PackedByteArray = viewport.get_texture().get_image().get_data()
	await create_timer(0.1, true).timeout
	await RenderingServer.frame_post_draw
	_expect(viewport.get_texture().get_image().get_data() == frozen, "orb and fragment pixels freeze without host age")
	paused = false
	for effect: Node2D in effects:
		effect.call("update_projectile", 2.0)
	await _draw_frames()
	var faded: Image = viewport.get_texture().get_image()
	var remaining: int = 0
	for y: int in range(30, 600):
		for x: int in range(300, 980):
			if faded.get_pixel(x, y).r > 0.08:
				remaining += 1
	_expect(remaining == 0, "expired presentation leaves no pixels")
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
