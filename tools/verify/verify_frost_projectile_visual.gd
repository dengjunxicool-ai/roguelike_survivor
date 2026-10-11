extends SceneTree

const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")
const FactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")
const EFFECT_PATH: String = "res://scenes/effects/frost_projectile_effect.tscn"
var _failed: bool = false
var _checks: int = 0


class FactoryBurst:
	extends Node2D
	signal spawned
	var projectiles: Array[Node2D] = []

	func _physics_process(_delta: float) -> void:
		set_physics_process(false)
		for index: int in range(3):
			var projectile: Node2D = FactoryScript.create_projectile({
				"projectile_id": "glacial_lance_projectile", "parent": self, "position": Vector2(index * 100, 0),
				"direction": Vector2.UP, "radius": 24.0, "speed": 300.0, "lifetime": 2.0
			})
			if projectile != null:
				projectile.set_physics_process(false)
				projectiles.append(projectile)
		spawned.emit()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(EFFECT_PATH), "frost projectile scene is available to the production hook")
	if _failed:
		quit(1)
		return
	var scene: PackedScene = load(EFFECT_PATH) as PackedScene
	await _verify_factory_burst()
	_verify_off_tree_host()
	for style: String in ["ice_shard", "glacial_lance", "ice_crack_shard"]:
		var effect: Node2D = scene.instantiate() as Node2D
		root.add_child(effect)
		_expect(effect.has_method("configure_projectile") and effect.has_method("update_projectile") and effect.has_method("deactivate"), "%s exposes presentation lifecycle" % style)
		effect.call("configure_projectile", {"style": style, "radius": 12.0, "speed": 520.0, "lifetime": 2.0})
		var glints: MeshInstance2D = effect.get_node_or_null("CrystalGlints") as MeshInstance2D
		_expect(glints != null and glints.mesh != null, "%s draws its bounded diamond wake as one GPU mesh" % style)
		var body: Polygon2D = effect.get_node("CrystalBody") as Polygon2D
		var bounds: Rect2 = _bounds(body.polygon)
		_expect(bounds.size.x > bounds.size.y * 1.6, "%s has a directional crystal silhouette" % style)
		if style == "glacial_lance":
			_expect(bounds.size.x > 60.0 and bounds.size.y < 18.0, "lance is long and narrow")
		elif style == "ice_crack_shard":
			_expect(bounds.size.x < 38.0, "chain splinter stays compact")
		else:
			_expect(bounds.size.x > 38.0 and bounds.size.x < 60.0, "ice shard has its intermediate silhouette")
		effect.call("configure_projectile", {"style": style, "radius": 24.0, "speed": 520.0, "lifetime": 2.0})
		_expect(_bounds(body.polygon).size.is_equal_approx(bounds.size * 2.0), "radius upgrade scales the %s crystal" % style)
		effect.call("update_projectile", 0.42)
		var trail: ColorRect = effect.get_node("FrostTrail") as ColorRect
		var material: ShaderMaterial = trail.material as ShaderMaterial
		_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), 0.42), "trail uses authoritative age")
		if glints != null:
			var glint_material: ShaderMaterial = glints.material as ShaderMaterial
			_expect(is_equal_approx(float(glint_material.get_shader_parameter("effect_age")), 0.42), "batched diamond wake uses authoritative age")
		var same_age: float = float(material.get_shader_parameter("effect_age"))
		paused = true
		await process_frame
		await process_frame
		_expect(is_equal_approx(float(material.get_shader_parameter("effect_age")), same_age), "paused presentation clock does not advance")
		paused = false
		_expect(not effect.is_processing() and not effect.is_physics_processing(), "effect never starts an independent clock")
		_expect(_particle_budget(effect) <= 24, "%s has bounded particle cost" % style)
		var count: int = effect.get_child_count()
		for index: int in range(120):
			effect.call("update_projectile", float(index) / 120.0)
		_expect(effect.get_child_count() == count, "flight does not create accumulating effect nodes")
		effect.call("deactivate")
		_expect(not effect.visible and _all_particles_stopped(effect), "deactivation hides crystal and stops emission")
		effect.free()
	await _verify_host_lifecycle(scene)
	await _verify_pool_visual_reuse()
	if "--render-projectiles" in OS.get_cmdline_user_args():
		await _verify_rendered(scene)
	print("[frost_projectile_visual] %d checks; failed=%s" % [_checks, _failed])
	quit(1 if _failed else 0)


func _verify_host_lifecycle(scene: PackedScene) -> void:
	var host: Node2D = ProjectileScript.new() as Node2D
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	host.add_child(sprite)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = CircleShape2D.new()
	host.add_child(collision)
	root.add_child(host)
	host.call("setup", _params("ice_shard", Vector2.UP))
	host.set_physics_process(false)
	var effect: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(effect != null, "host attaches configured frost scene")
	if effect == null:
		host.free()
		return
	_expect(not sprite.visible, "custom crystal hides placeholder sprite")
	_expect(is_equal_approx(effect.global_rotation, -PI / 2.0), "crystal faces the spawn direction")
	host.call("_physics_process", 0.2)
	_expect(is_equal_approx(float((effect.get_node("FrostTrail").material as ShaderMaterial).get_shader_parameter("effect_age")), 0.2), "host forwards flight age")
	_expect(host.global_position.is_equal_approx(Vector2(0.0, -104.0)), "presentation preserves authoritative projectile movement")
	_expect(is_equal_approx((collision.shape as CircleShape2D).radius, 12.0), "presentation preserves collision radius")
	host.set("direction", Vector2.LEFT)
	host.call("_update_direction_state")
	_expect(is_equal_approx(absf(effect.global_rotation), PI), "crystal follows direction changes")
	host.call("prepare_for_pool_despawn")
	_expect(not effect.visible and not effect.is_queued_for_deletion(), "pool return retains a stopped configurable visual")
	host.call("prepare_for_pool_spawn", {"visual_mode": "programmatic", "visual_style": "hunter_arrow", "direction": Vector2.RIGHT})
	host.set_physics_process(false)
	_expect(host.get("_visual_effect_node") == null, "non-frost reuse cannot inherit previous effect scene")
	await process_frame
	host.call("prepare_for_pool_spawn", _params("glacial_lance", Vector2.DOWN))
	host.set_physics_process(false)
	var lance: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(_bounds((lance.get_node("CrystalBody") as Polygon2D).polygon).size.x > 60.0, "cross-profile reuse configures the new lance")
	var other: Node2D = scene.instantiate() as Node2D
	root.add_child(other)
	other.call("configure_projectile", {"style": "ice_crack_shard", "radius": 9.0})
	var lance_material: ShaderMaterial = lance.get_node("FrostTrail").material as ShaderMaterial
	var other_material: ShaderMaterial = other.get_node("FrostTrail").material as ShaderMaterial
	_expect(lance_material != other_material, "live projectiles have independent trail material state")
	other.call("update_projectile", 0.9)
	_expect(is_zero_approx(float(lance_material.get_shader_parameter("effect_age"))), "another projectile cannot advance lance shader age")
	seed(70123)
	var expected_rng: int = randi()
	seed(70123)
	other.call("configure_projectile", {"style": "glacial_lance", "radius": 17.0})
	other.call("update_projectile", 0.31)
	_expect(randi() == expected_rng, "presentation configuration and updates preserve global gameplay RNG")
	host.call("setup", _params("ice_shard", Vector2.RIGHT))
	host.set("_return_once", true)
	host.set_physics_process(false)
	host.call("_physics_process", 1.05)
	var returning: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(is_equal_approx(absf(returning.global_rotation), PI), "return flight rotates custom crystal to actual travel direction")
	host.call("setup", {"visual_effect_scene": "", "visual_mode": "programmatic", "visual_style": "hunter_arrow"})
	host.set_physics_process(false)
	_expect(not returning.visible and host.get("_visual_effect_node") == null, "setup clears an existing custom visual even when new scene is empty")
	other.free()
	host.free()
	await process_frame


func _verify_pool_visual_reuse() -> void:
	var host: Node2D = ProjectileScript.new() as Node2D
	root.add_child(host)
	host.call("setup", _params("ice_shard", Vector2.RIGHT))
	host.set_physics_process(false)
	var original: Node2D = host.get("_visual_effect_node") as Node2D
	var original_material: ShaderMaterial = original.get_node("FrostTrail").material as ShaderMaterial
	host.call("_physics_process", 0.8)
	host.call("prepare_for_pool_despawn")
	_expect(host.get("_visual_effect_node") == original and not original.visible, "pool return keeps configurable effect and disables presentation")
	var params: Dictionary = _params("ice_shard", Vector2.DOWN)
	params["radius"] = 18.0
	params["lifetime"] = 1.1
	host.call("prepare_for_pool_spawn", params)
	host.set_physics_process(false)
	var reused: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(reused == original, "same scene pool reuse keeps the exact visual node")
	_expect(reused.get_node("FrostTrail").material == original_material, "same scene pool reuse keeps independent shader material")
	_expect(reused.visible and is_zero_approx(float(original_material.get_shader_parameter("effect_age"))), "reuse restarts visible shader and age at zero")
	_expect(is_equal_approx(reused.get("_lifetime"), 1.1) and is_equal_approx(_bounds((reused.get_node("CrystalBody") as Polygon2D).polygon).size.x, 61.2), "reuse rebuilds radius and lifetime from new spawn")
	params["visual_style"] = "glacial_lance"
	host.call("prepare_for_pool_despawn")
	host.call("prepare_for_pool_spawn", params)
	host.set_physics_process(false)
	var lance: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(lance == original and _bounds((lance.get_node("CrystalBody") as Polygon2D).polygon).size.x > 100.0, "same scene cross-profile reuse rebuilds lance without stale shard geometry")
	host.call("setup", {"visual_effect_scene": "res://scenes/effects/blizzard_cloud_effect.tscn", "visual": {"modulate": [1, 1, 1, 1]}})
	host.set_physics_process(false)
	var legacy: Node2D = host.get("_visual_effect_node") as Node2D
	_expect((host.get_node("Sprite2D") as Sprite2D).visible, "legacy additive effect preserves authored host sprite")
	_expect(original.is_queued_for_deletion() and not original.visible, "different scene releases old custom visual immediately")
	host.call("prepare_for_pool_despawn")
	_expect(legacy.is_queued_for_deletion() and host.get("_visual_effect_node") == null, "legacy effects without projectile lifecycle still release on pool return")
	host.free()
	await process_frame


func _verify_factory_burst() -> void:
	var runner: FactoryBurst = FactoryBurst.new()
	root.add_child(runner)
	await runner.spawned
	_expect(runner.projectiles.size() == 3, "real factory prepares a three-lance burst in a physics frame")
	for projectile: Node2D in runner.projectiles:
		_expect(not projectile.is_inside_tree(), "physics-frame factory prepares visual before deferred tree entry")
		var effect: Node2D = projectile.get("_visual_effect_node") as Node2D
		_expect(effect != null and is_equal_approx(_bounds((effect.get_node("CrystalBody") as Polygon2D).polygon).size.x, 139.2), "real factory maps and configures upgraded frost lance off-tree")
	await process_frame
	for projectile: Node2D in runner.projectiles:
		var effect: Node2D = projectile.get("_visual_effect_node") as Node2D
		_expect(projectile.is_inside_tree() and effect != null and is_equal_approx(_bounds((effect.get_node("CrystalBody") as Polygon2D).polygon).size.x, 139.2), "deferred burst tree entry preserves configured visual")
		projectile.call("despawn_or_free")
	runner.free()
	await process_frame


func _verify_off_tree_host() -> void:
	var host: Node2D = ProjectileScript.new() as Node2D
	var params: Dictionary = _params("glacial_lance", Vector2.UP)
	params["radius"] = 24.0
	host.call("setup", params)
	var effect: Node2D = host.get("_visual_effect_node") as Node2D
	_expect(effect != null and not effect.is_inside_tree(), "pending factory spawn mounts effect before entering the tree")
	if effect == null:
		host.free()
		return
	var body: Polygon2D = effect.get_node("CrystalBody") as Polygon2D
	_expect(is_equal_approx(_bounds(body.polygon).size.x, 139.2), "off-tree setup builds upgraded lance geometry immediately")
	host.set("_age", 0.15)
	host.call("_update_visual_effect")
	var trail: ColorRect = effect.get_node("FrostTrail") as ColorRect
	_expect(is_equal_approx(float((trail.material as ShaderMaterial).get_shader_parameter("effect_age")), 0.15), "off-tree configuration initializes shader state")
	root.add_child(host)
	host.set_physics_process(false)
	_expect(is_equal_approx(_bounds(body.polygon).size.x, 139.2), "ready preserves geometry configured by pending burst spawn")
	_expect(is_equal_approx(float((trail.material as ShaderMaterial).get_shader_parameter("effect_age")), 0.15), "ready preserves authoritative age configured before entering tree")
	host.free()


func _verify_rendered(scene: PackedScene) -> void:
	_expect(DisplayServer.get_name() != "headless", "projectile capture uses a real GPU renderer")
	if DisplayServer.get_name() == "headless":
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(720, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.015, 0.035, 0.06)
	background.size = Vector2(720, 360)
	viewport.add_child(background)
	var index: int = 0
	var effects: Array[Node2D] = []
	for style: String in ["ice_shard", "glacial_lance", "ice_crack_shard"]:
		var effect: Node2D = scene.instantiate() as Node2D
		viewport.add_child(effect)
		effect.position = Vector2(420, 80 + index * 100)
		effect.call("configure_projectile", {"style": style, "radius": 16.0, "speed": 650.0, "lifetime": 2.0})
		effect.call("update_projectile", 0.35)
		effects.append(effect)
		var label: Label = Label.new()
		label.text = style
		label.position = Vector2(32, 68 + index * 100)
		viewport.add_child(label)
		index += 1
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var shown: Image = viewport.get_texture().get_image()
	_expect(shown.save_png("E:/codex/frost-vfx/projectiles/projectile_profiles.png") == OK, "GPU profile capture saves on E drive")
	for row: int in range(3):
		var lit: int = 0
		for y: int in range(64 + row * 100, 96 + row * 100):
			for x: int in range(396, 438):
				if shown.get_pixel(x, y).b > 0.3:
					lit += 1
		_expect(lit > 220, "profile %d renders a readable cold crystal (%d pixels)" % [row, lit])
	for effect: Node2D in effects:
		effect.get_node("FrostTrail").visible = false
	for frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var no_trail: Image = viewport.get_texture().get_image()
	var changed: int = 0
	for y: int in range(360):
		for x: int in range(280, 385):
			var before: Color = shown.get_pixel(x, y)
			var after: Color = no_trail.get_pixel(x, y)
			if absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) > 0.015:
				changed += 1
	_expect(changed > 200, "frost shader contributes an actual visible wake (%d pixels)" % changed)
	for effect: Node2D in effects:
		effect.get_node("FrostTrail").visible = true
	paused = true
	for frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var paused_before: PackedByteArray = viewport.get_texture().get_image().get_data()
	await create_timer(0.2, true).timeout
	await RenderingServer.frame_post_draw
	_expect(viewport.get_texture().get_image().get_data() == paused_before, "paused GPU crystal and shader pixels are identical")
	paused = false
	for effect: Node2D in effects:
		effect.call("update_projectile", 2.0)
	for frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var faded: Image = viewport.get_texture().get_image()
	var background_pixel: Color = faded.get_pixel(600, 50)
	var lingering: int = 0
	for y: int in range(60, 310):
		for x: int in range(280, 510):
			if faded.get_pixel(x, y).b > background_pixel.b + 0.015:
				lingering += 1
	_expect(lingering == 0, "lifetime fade removes crystal, glints and shader wake (%d remaining pixels)" % lingering)
	for effect: Node2D in effects:
		effect.call("update_projectile", 0.35)
	for frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	_expect(viewport.get_texture().get_image().get_pixel(420, 80).b > 0.3, "reset age restores fully visible crystal after fade")
	var edge_effect: Node2D = scene.instantiate() as Node2D
	viewport.add_child(edge_effect)
	edge_effect.position = Vector2(756, 340)
	edge_effect.call("configure_projectile", {"style": "glacial_lance", "radius": 16.0, "speed": 650.0, "lifetime": 2.0})
	edge_effect.call("update_projectile", 0.35)
	for frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var edge_before: Image = viewport.get_texture().get_image()
	edge_effect.get_node("CrystalGlints").visible = false
	for frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var edge_after: Image = viewport.get_texture().get_image()
	var edge_glints: int = 0
	for y: int in range(324, 356):
		for x: int in range(665, 720):
			if absf(edge_before.get_pixel(x, y).b - edge_after.get_pixel(x, y).b) > 0.015:
				edge_glints += 1
	_expect(edge_glints > 3, "GPU wake remains visible when projectile center exits viewport (%d pixels)" % edge_glints)
	viewport.free()


func _params(style: String, heading: Vector2) -> Dictionary:
	return {"visual_effect_scene": EFFECT_PATH, "visual_mode": "programmatic", "visual_style": style,
		"direction": heading, "radius": 12.0, "speed": 520.0, "lifetime": 2.0}


func _bounds(points: PackedVector2Array) -> Rect2:
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	return bounds


func _particle_budget(node: Node) -> int:
	var result: int = 0
	if node is CPUParticles2D:
		_expect(false, "production crystal never uses CPU particles")
	if node is GPUParticles2D:
		result += (node as GPUParticles2D).amount
	for child: Node in node.get_children():
		result += _particle_budget(child)
	return result


func _all_particles_stopped(node: Node) -> bool:
	if node is GPUParticles2D and (node as GPUParticles2D).emitting:
		return false
	for child: Node in node.get_children():
		if not _all_particles_stopped(child):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % message)
	else:
		_failed = true
		push_error("[FAIL] %s" % message)
