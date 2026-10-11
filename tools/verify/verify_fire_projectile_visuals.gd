extends SceneTree

const EFFECT_PATH: String = "res://scenes/effects/fire_projectile_effect.tscn"
const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")
var _failed: bool = false
var _checks: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(EFFECT_PATH), "production fire projectile effect is available")
	if _failed:
		quit(1)
		return
	var scene: PackedScene = load(EFFECT_PATH) as PackedScene
	var effects: Array[Node2D] = []
	for style: String in ["fireball_shader", "fireball", "meteor", "meteor_rain_meteor", "inferno_cycle_meteor", "ember_attachment_bolt", "fire_ember"]:
		var effect: Node2D = scene.instantiate() as Node2D
		effect.call("configure_projectile", {"style": style, "radius": 12.0, "speed": 520.0, "direction": Vector2.UP, "lifetime": 2.0})
		var flame: ColorRect = effect.get_node("FireEnvelope") as ColorRect
		var material: ShaderMaterial = flame.material as ShaderMaterial
		var embers: MeshInstance2D = effect.get_node("BatchedEmbers") as MeshInstance2D
		_expect(embers.mesh is ArrayMesh, "%s batches embers into a fixed GPU mesh" % style)
		_expect(embers.mesh.surface_get_array_len(0) <= 96, "%s keeps a bounded ember vertex budget" % style)
		var size_before: Vector2 = flame.size
		var kind: int = int(material.get_shader_parameter("style_kind"))
		if style.contains("meteor"):
			_expect(kind == 1 and size_before.x > 140.0, "%s selects armored meteor with a long tail" % style)
		elif style in ["ember_attachment_bolt", "fire_ember"]:
			_expect(kind == 2 and size_before.y < 28.0, "%s selects a compact pointed homing ember" % style)
		else:
			_expect(kind == 0 and size_before.y > 32.0, "%s selects the molten fireball" % style)
		effect.call("update_projectile", 0.37)
		root.add_child(effect)
		_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.37), "ready preserves off-tree configured age")
		_expect(not effect.is_processing() and not effect.is_physics_processing(), "fire visual never owns a gameplay clock")
		effect.call("configure_projectile", {"style": style, "radius": 24.0, "speed": 520.0, "lifetime": 2.0})
		_expect(is_equal_approx(flame.size.y, size_before.y * 2.0), "%s radius upgrade scales the visible envelope" % style)
		_expect(flame.material == material, "reconfiguration retains an isolated instance material")
		_expect(is_zero_approx(float(material.get_shader_parameter("effect_age"))), "reconfiguration resets shader age")
		var child_count: int = effect.get_child_count()
		var mesh: Mesh = embers.mesh
		for index: int in range(120):
			effect.call("update_projectile", float(index) / 120.0)
		_expect(embers.mesh == mesh and effect.get_child_count() == child_count, "flight creates no nodes or replacement meshes")
		effect.call("update_projectile", 2.0)
		_expect(is_zero_approx(effect.modulate.a), "lifetime removes body, tail and batched embers together")
		effect.call("deactivate")
		effect.call("update_projectile", 0.2)
		_expect(not effect.visible and is_zero_approx(effect.modulate.a), "inactive update cannot resurrect pooled fire")
		effect.call("configure_projectile", {"style": style, "radius": 12.0, "speed": 520.0, "lifetime": 2.0})
		_expect(effect.visible and is_equal_approx(effect.modulate.a, 1.0), "pool reuse restores visibility and opacity")
		effects.append(effect)
	var first_material: ShaderMaterial = effects[0].get_node("FireEnvelope").material as ShaderMaterial
	var other_material: ShaderMaterial = effects[1].get_node("FireEnvelope").material as ShaderMaterial
	_expect(first_material != other_material, "different live fire projectiles isolate shader state")
	effects[1].call("update_projectile", 0.81)
	_expect(is_zero_approx(float(first_material.get_shader_parameter("effect_age"))), "another projectile cannot advance the first flame")
	_expect(effects[0].get_node("BatchedEmbers").mesh == effects[1].get_node("BatchedEmbers").mesh, "all fire projectiles share one immutable ember mesh")
	seed(70923)
	var expected_rng: int = randi()
	seed(70923)
	effects[0].call("configure_projectile", {"style": "meteor", "radius": 19.0})
	effects[0].call("update_projectile", 0.54)
	_expect(randi() == expected_rng, "fire presentation preserves global gameplay RNG")
	paused = true
	await process_frame
	await process_frame
	_expect(is_equal_approx(float(first_material.get_shader_parameter("effect_age")), 0.54), "paused flame clock stays at authoritative age")
	paused = false
	_verify_host_lifecycle()
	for effect: Node2D in effects:
		effect.free()
	if "--render-projectiles" in OS.get_cmdline_user_args():
		await _verify_rendered(scene)
	print("[fire_projectile_visuals] %d checks; failed=%s" % [_checks, _failed])
	quit(1 if _failed else 0)


func _verify_host_lifecycle() -> void:
	var host: Node2D = ProjectileScript.new() as Node2D
	var params: Dictionary = {"visual_effect_scene": EFFECT_PATH, "visual_mode": "programmatic", "visual_style": "fireball_shader", "radius": 12.0, "direction": Vector2.UP, "speed": 520.0, "lifetime": 2.0}
	host.call("setup", params)
	var effect: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(effect != null and not effect.is_inside_tree(), "real projectile host configures fire before deferred tree entry")
	root.add_child(host)
	host.set_physics_process(false)
	_expect(is_equal_approx(effect.global_rotation, -PI / 2.0), "flame follows authoritative spawn direction")
	host.call("_physics_process", 0.2)
	_expect(host.position.is_equal_approx(Vector2(0, -104)), "flame leaves real projectile motion unchanged")
	_expect(is_equal_approx(float((effect.get_node("FireEnvelope").material as ShaderMaterial).get_shader_parameter("effect_age")), 0.2), "host forwards actual flight age")
	host.set("direction", Vector2.LEFT)
	host.call("_update_direction_state")
	host.call("_update_visual_effect")
	_expect(is_equal_approx(absf(effect.global_rotation), PI), "homing turn rotates the entire flame and ember wake")
	host.call("prepare_for_pool_despawn")
	_expect(not effect.visible, "real pool return immediately hides fire")
	params["visual_style"] = "meteor"
	params["direction"] = Vector2.DOWN
	params["radius"] = 20.0
	host.call("prepare_for_pool_spawn", params)
	host.set_physics_process(false)
	_expect(host.get("_visual_effect_node") == effect, "real same-scene reuse preserves fire visual node")
	_expect(int((effect.get_node("FireEnvelope").material as ShaderMaterial).get_shader_parameter("style_kind")) == 1, "pool fireball-to-meteor reuse resets visual profile")
	_expect(is_equal_approx(effect.global_rotation, PI / 2.0) and is_equal_approx(effect.modulate.a, 1.0), "reuse restores current direction and opacity")
	host.free()


func _verify_rendered(scene: PackedScene) -> void:
	_expect(DisplayServer.get_name() != "headless", "fire profile pixels require a GPU renderer")
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("E:/codex/fire-projectile-check")
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(760, 390)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(760, 390)
	background.color = Color(0.022, 0.029, 0.047)
	viewport.add_child(background)
	var effects: Array[Node2D] = []
	var styles: Array[String] = ["fireball", "meteor", "ember_attachment_bolt"]
	for row: int in range(3):
		var effect: Node2D = scene.instantiate() as Node2D
		viewport.add_child(effect)
		effect.position = Vector2(500, 75 + row * 120)
		effect.call("configure_projectile", {"style": styles[row], "radius": 16.0, "speed": 650.0, "lifetime": 2.0})
		effect.call("update_projectile", 0.35)
		effects.append(effect)
		var label: Label = Label.new()
		label.position = Vector2(24, 65 + row * 120)
		label.text = styles[row]
		viewport.add_child(label)
	await _draw_frames()
	var shown: Image = viewport.get_texture().get_image()
	_expect(shown.save_png("E:/codex/fire-projectile-check/projectile_profiles.png") == OK, "GPU fire profile capture saves to E drive")
	for row: int in range(3):
		var lit: int = 0
		for y: int in range(55 + row * 120, 95 + row * 120):
			for x: int in range(480, 525):
				if shown.get_pixel(x, y).r > 0.3:
					lit += 1
		_expect(lit > (80 if row == 2 else 220), "%s has a readable hot body (%d pixels)" % [styles[row], lit])
	paused = true
	await _draw_frames()
	var before_pause: PackedByteArray = viewport.get_texture().get_image().get_data()
	await create_timer(0.15, true).timeout
	await RenderingServer.frame_post_draw
	_expect(viewport.get_texture().get_image().get_data() == before_pause, "GPU flame and embers freeze exactly when authoritative age stops")
	paused = false
	for effect: Node2D in effects:
		effect.call("update_projectile", 2.0)
	await _draw_frames()
	var faded: Image = viewport.get_texture().get_image()
	var lingering: int = 0
	for y: int in range(45, 345):
		for x: int in range(300, 540):
			if faded.get_pixel(x, y).r > 0.05:
				lingering += 1
	_expect(lingering == 0, "incoming COLOR fade removes all fire shader pixels (%d remain)" % lingering)
	var edge: Node2D = scene.instantiate() as Node2D
	viewport.add_child(edge)
	edge.position = Vector2(797, 370)
	edge.call("configure_projectile", {"style": "meteor", "radius": 16.0, "speed": 650.0, "lifetime": 2.0})
	edge.call("update_projectile", 0.35)
	await _draw_frames()
	var with_embers: Image = viewport.get_texture().get_image()
	edge.get_node("BatchedEmbers").visible = false
	await _draw_frames()
	var without_embers: Image = viewport.get_texture().get_image()
	var edge_pixels: int = 0
	for y: int in range(340, 390):
		for x: int in range(600, 760):
			if absf(with_embers.get_pixel(x, y).r - without_embers.get_pixel(x, y).r) > 0.01:
				edge_pixels += 1
	_expect(edge_pixels > 2, "displaced ember mesh remains visible with offscreen projectile center (%d pixels)" % edge_pixels)
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
