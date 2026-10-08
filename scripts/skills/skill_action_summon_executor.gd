extends "res://scripts/skills/skill_action_support.gd"
class_name SkillActionSummonExecutor


func _spawn_particles(params: Dictionary, context: Dictionary) -> bool:
	var parent: Node = _get_parent_node(context)
	if parent == null:
		return false
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "SkillParticles_%s" % str(params.get("profile", "fire"))
	particles.global_position = _resolve_position(params, context)
	_configure_gpu_particles(particles, params, Color(1.0, 0.28, 0.04, 0.82))
	parent.add_child(particles)
	particles.restart()
	particles.emitting = true
	var lifetime: float = maxf(float(params.get("lifetime", 0.55)), 0.05)
	var tree: SceneTree = parent.get_tree()
	if tree != null:
		tree.create_timer(lifetime).timeout.connect(Callable(particles, "queue_free"))
	return true


func _spawn_summon(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node2D = context.get("caster") as Node2D
	var parent: Node = _get_parent_node(context)
	if caster == null or parent == null:
		return false
	if params.has("summon_definition_id"):
		return _spawn_managed_summon(params, context, caster, parent)

	var summon: Node2D = _create_summon_node(params)
	summon.name = str(params.get("summon_id", "skill_summon"))
	summon.global_position = caster.global_position + Vector2(float(params.get("spawn_offset", 48.0)), 0.0).rotated(randf() * TAU)
	parent.add_child(summon)
	if summon.has_method("setup"):
		var summon_params: Dictionary = params.duplicate(true)
		summon_params["caster"] = caster
		summon_params["parent"] = parent
		summon_params["action_executor"] = _dispatcher()
		summon_params["context"] = context.duplicate(true)
		summon.call("setup", summon_params)
		if summon.has_method("uses_internal_summon_runtime") and bool(summon.call("uses_internal_summon_runtime")):
			return true
	_attach_summon_visual(summon, params)

	_restart_summon_particles(summon, params)

	var attack_interval: float = maxf(float(params.get("attack_interval", 0.7)), 0.05)
	var duration: float = maxf(float(params.get("duration", 5.0)), attack_interval)
	var timer: Timer = Timer.new()
	timer.wait_time = attack_interval
	timer.one_shot = false
	timer.autostart = true
	summon.add_child(timer)
	timer.timeout.connect(func() -> void:
		_summon_tick(summon, params, context)
	)
	_summon_tick(summon, params, context)

	var tree: SceneTree = parent.get_tree()
	if tree != null:
		tree.create_timer(duration).timeout.connect(Callable(summon, "queue_free"))
	return true


func _spawn_managed_summon(params: Dictionary, context: Dictionary, caster: Node2D, parent: Node) -> bool:
	var manager: Node = caster.get_node_or_null("SummonManager")
	if manager == null:
		manager = SummonManagerScript.new()
		manager.name = "SummonManager"
		caster.add_child(manager)
	var definition: RefCounted = SummonDefinitionScript.from_id(params.get("summon_definition_id"))
	if definition == null:
		return false
	var summon_context: Dictionary = context.duplicate(true)
	summon_context["owner"] = caster
	summon_context["caster"] = caster
	summon_context["parent"] = parent
	summon_context["target_group"] = context.get("target_group", &"enemies")
	summon_context["action_executor"] = _dispatcher()
	summon_context["player_power"] = _get_caster_attack_power(context)
	var summon: Node2D = manager.call("spawn_summon", definition, summon_context) as Node2D
	return summon != null


func _create_summon_node(params: Dictionary) -> Node2D:
	var script_path: String = str(params.get("summon_script", ""))
	if script_path != "" and ResourceLoader.exists(script_path):
		var summon_script: Script = load(script_path) as Script
		if summon_script != null:
			var scripted_summon: Node2D = summon_script.new() as Node2D
			if scripted_summon != null:
				return scripted_summon
	return Node2D.new()


func _summon_tick(summon: Node2D, params: Dictionary, context: Dictionary) -> void:
	if summon == null or not is_instance_valid(summon) or summon.is_queued_for_deletion():
		return
	var radius: float = maxf(float(params.get("radius", params.get("range", 180.0))), 1.0)
	var max_targets: int = maxi(int(params.get("max_targets", 1)), 1)
	var target_group: StringName = StringName(str(params.get("target_group", context.get("target_group", &"enemies"))))
	var targets: Array[Node2D] = _find_targets_around(summon.global_position, radius, target_group)
	var affected: int = 0
	for target: Node2D in targets:
		if affected >= max_targets:
			break
		var summon_context: Dictionary = context.duplicate(true)
		summon_context["target"] = target
		summon_context["source"] = summon
		_update_summon_visual_facing(summon, target)
		_spawn_summon_breath_particles(summon, target, params)
		var damage_params: Dictionary = params.duplicate(true)
		if not damage_params.has("damage_type"):
			damage_params["damage_type"] = "summon_damage"
		if not damage_params.has("damage_origin"):
			damage_params["damage_origin"] = "special"
		_deal_damage(damage_params, summon_context)
		affected += 1


func _attach_summon_visual(summon: Node2D, params: Dictionary) -> void:
	var texture_path: String = str(params.get("visual_texture", ""))
	if summon == null or texture_path == "":
		return
	if not ResourceLoader.exists(texture_path):
		push_warning("[SkillActionExecutor] Missing summon visual_texture: %s" % texture_path)
		return
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "SummonVisual"
	sprite.texture = texture
	sprite.centered = true
	var visual_scale: float = maxf(float(params.get("visual_scale", 0.12)), 0.01)
	sprite.scale = Vector2(visual_scale, visual_scale)
	sprite.z_index = int(params.get("visual_z_index", 4))
	summon.add_child(sprite)
	summon.set_meta("summon_visual_texture", texture_path)


func _update_summon_visual_facing(summon: Node2D, target: Node2D) -> void:
	if summon == null or target == null:
		return
	var direction: Vector2 = target.global_position - summon.global_position
	if direction.length_squared() <= 0.0001:
		return
	var sprite: Sprite2D = summon.get_node_or_null("SummonVisual") as Sprite2D
	if sprite == null:
		return
	sprite.rotation = direction.angle() - PI * 0.5


func _spawn_summon_breath_particles(summon: Node2D, target: Node2D, params: Dictionary) -> void:
	if summon == null or target == null or not bool(params.get("breath_particles", false)):
		return
	var particles: GPUParticles2D = summon.get_node_or_null("DragonBreathParticles") as GPUParticles2D
	if particles == null:
		particles = GPUParticles2D.new()
		particles.name = "DragonBreathParticles"
		summon.add_child(particles)
	var direction: Vector2 = (target.global_position - summon.global_position).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	particles.position = direction * float(params.get("breath_offset", 48.0))
	particles.rotation = direction.angle()
	_configure_gpu_particles(particles, {
		"profile": "targeted_fire_breath",
		"amount": int(params.get("breath_particle_amount", 54)),
		"lifetime": 0.45,
		"particle_lifetime": 0.35,
		"emission_radius": 12.0,
		"velocity_min": 80.0,
		"velocity_max": 180.0,
		"spread": 28.0,
		"gravity_y": -2.0,
		"scale_min": 0.35,
		"scale_max": 1.1
	}, Color(1.0, 0.26, 0.03, 0.82))
	particles.restart()
	particles.emitting = true


func _restart_summon_particles(summon: Node2D, params: Dictionary) -> void:
	if summon == null or not is_instance_valid(summon) or summon.is_queued_for_deletion():
		return
	var particles: GPUParticles2D = summon.get_node_or_null("SummonParticles") as GPUParticles2D
	if particles == null:
		particles = GPUParticles2D.new()
		particles.name = "SummonParticles"
		summon.add_child(particles)
	_configure_gpu_particles(particles, {"profile": params.get("profile", "fire_summon"), "amount": 42, "lifetime": 0.75}, Color(1.0, 0.42, 0.08, 0.74))
	particles.restart()
	particles.emitting = true


func _configure_gpu_particles(particles: GPUParticles2D, params: Dictionary, color: Color) -> void:
	if particles == null:
		return
	var profile: String = str(params.get("profile", "fire"))
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = maxf(float(params.get("emission_radius", 16.0)), 1.0)
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = float(params.get("spread", 360.0))
	material.gravity = Vector3(0.0, float(params.get("gravity_y", -18.0)), 0.0)
	material.initial_velocity_min = float(params.get("velocity_min", 32.0))
	material.initial_velocity_max = float(params.get("velocity_max", 92.0))
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.scale_min = float(params.get("scale_min", 0.45))
	material.scale_max = float(params.get("scale_max", 1.6))
	material.color = color
	if profile.contains("targeted"):
		material.direction = Vector3(0.0, -0.35, 0.0)
		material.initial_velocity_max = maxf(material.initial_velocity_max, 130.0)
	elif profile.contains("summon"):
		material.emission_sphere_radius = maxf(material.emission_sphere_radius, 22.0)
		material.initial_velocity_min = 10.0
		material.initial_velocity_max = 46.0

	particles.amount = maxi(int(params.get("amount", 36)), 1)
	particles.lifetime = maxf(float(params.get("particle_lifetime", 0.45)), 0.05)
	particles.one_shot = bool(params.get("one_shot", true))
	particles.explosiveness = float(params.get("explosiveness", 0.72))
	particles.randomness = float(params.get("randomness", 0.62))
	particles.local_coords = bool(params.get("local_coords", false))
	particles.process_material = material
