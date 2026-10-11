## 真实工厂路径：验证暴雪表现装配、范围/寿命同步、私有随机流与对象池清理。
extends SceneTree

const Factory = preload("res://scripts/combat/combat_object_factory.gd")
var failed := false

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)

func run() -> void:
	await process_frame
	var world := Node2D.new()
	root.add_child(world)
	var area := Factory.create_area_effect({"parent": world, "area_id": "blizzard_cloud", "source_id": "blizzard_cloud", "duration": 5.0, "radius": 168.0, "move_direction": Vector2.LEFT, "move_speed": 42.0}) as AreaEffect
	check(area != null, "production factory creates blizzard area")
	var effect: Node2D = area.get_node_or_null("AreaVisualEffect") if area != null else null
	check(effect != null, "production blizzard uses dedicated procedural VFX")
	if effect == null:
		world.queue_free()
		await process_frame
		quit(1)
		return
	area.set_physics_process(false)
	# Godot's GPUParticles2D constructor consumes an engine seed even with use_fixed_seed.
	# The runtime configure/update/reuse path must never consume additional global RNG.
	seed(7193)
	var expected_random := randf()
	seed(7193)
	effect.configure(168.0, 5.0, 4.0)
	effect.update_state(168.0, 0.1, 5.0)
	check(is_equal_approx(randf(), expected_random), "visual runtime does not consume gameplay RNG")
	check(not area.get_node("Sprite2D").visible, "fallback sprite hidden")
	check(is_equal_approx(float(effect.get("effect_radius")), 168.0), "effect matches gameplay radius")
	check(is_equal_approx(float(effect.get("effect_duration")), 5.0), "effect matches gameplay lifetime")
	var emitters := effect.find_children("*", "GPUParticles2D", true, false)
	var particle_count := 0
	for emitter: GPUParticles2D in emitters:
		particle_count += emitter.amount
		check(emitter.local_coords, "particles follow moving area")
		check(emitter.emitting, "particle layer emitting after configure")
	check(emitters.size() >= 3 and particle_count <= 256, "layered GPU particles have bounded per-cloud budget")
	area.set_effect_radius(224.0)
	check(is_equal_approx(float(effect.get("effect_radius")), 224.0), "radius changes reach visual layer")
	area._physics_process(1.0)
	check(is_equal_approx(float(effect.get("effect_age")), 1.0), "visual clock follows area clock")
	check(area.global_position.is_equal_approx(Vector2(-42, 0)), "VFX preserves production area movement")
	var cloud_material: ShaderMaterial = effect.get_node("CloudCanopy").material
	area.prepare_for_pool_despawn()
	check(not effect.visible, "pool despawn hides VFX")
	for emitter: GPUParticles2D in emitters:
		check(not emitter.emitting, "pool despawn stops GPU emission")
	area.prepare_for_pool_spawn({"duration": 6.8, "radius": 96.0, "visual_mode": "programmatic", "visual_style": "blizzard_cloud", "visual_effect_scene": "res://scenes/effects/blizzard_cloud_effect.tscn"})
	area.set_physics_process(false)
	check(area.get_node("AreaVisualEffect") == effect, "pooled spawn reuses same VFX nodes")
	check(effect.visible and is_zero_approx(float(effect.get("effect_age"))), "pooled spawn resets visible clock")
	check(is_equal_approx(float(effect.get("effect_duration")), 6.8), "passive duration reaches reused VFX")
	var second := Factory.create_area_effect({"parent": world, "area_id": "blizzard_cloud", "duration": 5.0}) as AreaEffect
	second.set_physics_process(false)
	var second_material: ShaderMaterial = second.get_node("AreaVisualEffect/CloudCanopy").material
	check(cloud_material != second_material, "concurrent clouds own independent shader uniforms")
	area.prepare_for_pool_despawn()
	area.prepare_for_pool_spawn({"duration": 1.0, "radius": 52.0, "visual_style": "fire_burst", "visual_mode": "programmatic"})
	area.set_physics_process(false)
	check(not effect.visible, "pool reuse as another area leaves no blizzard residue")
	second.prepare_for_pool_despawn()
	world.queue_free()
	await process_frame
	print("Blizzard visual runtime: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
