extends SceneTree


const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")
const EFFECT_SCENE_PATH: String = "res://scenes/effects/mars_spark_missile_effect.tscn"
const EFFECT_CLASS_NAME: String = "MarsSparkMissileEffect"
const MIN_GPU_PARTICLE_NODES: int = 3


var _failed: bool = false
var _instances: Array[Node] = []
var _registered_enemies: Array[Node] = []


func _init() -> void:
	process_frame.connect(_run_check, CONNECT_ONE_SHOT)


func _run_check() -> void:
	var packed_scene: PackedScene = load(EFFECT_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "Mars Spark Missile scene loads")
	if packed_scene == null:
		_finish()
		return

	var continuous_effect: Node2D = _instantiate_effect(packed_scene, "continuous")
	if continuous_effect == null:
		_finish()
		return

	var particles: Array[GPUParticles2D] = _gpu_particles(continuous_effect)
	_expect(_is_mars_spark_root(continuous_effect), "Mars Spark Missile scene root is MarsSparkMissileEffect/Node2D")
	_expect(_can_set_mode(continuous_effect), "Mars Spark Missile exposes set_continuous(bool) or configure(..., continuous)")
	_expect(particles.size() >= MIN_GPU_PARTICLE_NODES, "Mars Spark Missile has at least three GPUParticles2D nodes")
	for particle_node: GPUParticles2D in particles:
		_expect(particle_node.process_material is ParticleProcessMaterial, "%s uses ParticleProcessMaterial" % particle_node.name)

	_start_mode(continuous_effect, true)
	await process_frame
	await process_frame
	_expect(_has_active_particles(continuous_effect), "Mars Spark Missile continuous mode emits particles")

	var single_effect: Node2D = _instantiate_effect(packed_scene, "single")
	if single_effect != null:
		_start_mode(single_effect, false)
		await process_frame
		await process_frame
		_expect(_has_active_particles(single_effect), "Mars Spark Missile single mode starts particle emission")

	var homing_effect: Node2D = _instantiate_effect(packed_scene, "homing")
	if homing_effect != null:
		_expect(_has_homing_exports(homing_effect), "Mars Spark Missile exposes homing controls for dev tuning")
		var enemy: Node2D = Node2D.new()
		enemy.name = "RuntimeHomingEnemy"
		enemy.global_position = Vector2(96.0, -180.0)
		enemy.add_to_group(&"enemies")
		root.add_child(enemy)
		_register_enemy(enemy)
		_instances.append(enemy)
		if homing_effect.has_method("configure"):
			homing_effect.call("configure", Vector2.ZERO, Vector2(260.0, 0.0), false)
		var start_position: Vector2 = homing_effect.global_position
		for frame in range(8):
			homing_effect.call("_process", 0.05)
		_expect(
			is_instance_valid(homing_effect) and homing_effect.global_position.y < start_position.y - 8.0,
			"Mars Spark Missile homes toward the nearest enemy instead of only following its initial aim"
		)

	_finish()


func _instantiate_effect(packed_scene: PackedScene, label: String) -> Node2D:
	var effect: Node2D = packed_scene.instantiate() as Node2D
	_expect(effect != null, "Mars Spark Missile %s scene instantiates as Node2D" % label)
	if effect == null:
		return null
	root.add_child(effect)
	_instances.append(effect)
	return effect


func _is_mars_spark_root(effect: Node2D) -> bool:
	if effect == null:
		return false
	if effect.name == EFFECT_CLASS_NAME:
		return true
	var script: Script = effect.get_script() as Script
	return script != null and script.get_global_name() == EFFECT_CLASS_NAME


func _can_set_mode(effect: Node2D) -> bool:
	return effect != null and (effect.has_method("set_continuous") or effect.has_method("configure"))


func _has_homing_exports(effect: Node2D) -> bool:
	if effect == null:
		return false
	var properties: Array = effect.get_property_list()
	var has_homing_enabled: bool = false
	var has_target_group: bool = false
	for property: Dictionary in properties:
		var property_name: String = String(property.get("name", ""))
		has_homing_enabled = has_homing_enabled or property_name == "homing_enabled"
		has_target_group = has_target_group or property_name == "target_group"
	return has_homing_enabled and has_target_group


func _start_mode(effect: Node2D, continuous: bool) -> void:
	if effect == null:
		return
	if effect.has_method("set_continuous"):
		effect.call("set_continuous", continuous)
		return
	if effect.has_method("configure"):
		var origin: Vector2 = Vector2.ZERO
		var target: Vector2 = Vector2(160.0, 0.0)
		effect.call("configure", origin, target, continuous)


func _has_active_particles(effect: Node2D) -> bool:
	if effect == null or not is_instance_valid(effect):
		return false
	for particle_node: GPUParticles2D in _gpu_particles(effect):
		if particle_node.emitting:
			return true
	return false


func _gpu_particles(node: Node) -> Array[GPUParticles2D]:
	var particles: Array[GPUParticles2D] = []
	_collect_gpu_particles(node, particles)
	return particles


func _collect_gpu_particles(node: Node, particles: Array[GPUParticles2D]) -> void:
	if node is GPUParticles2D:
		particles.append(node as GPUParticles2D)
	for child: Node in node.get_children():
		_collect_gpu_particles(child, particles)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
	else:
		_failed = true
		push_error("FAIL %s" % message)


func _finish() -> void:
	var registry: Node = CombatTargetRegistryScript.get_or_create(root)
	for enemy: Node in _registered_enemies:
		registry.call("unregister_enemy", enemy)
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.queue_free()
	if _failed:
		quit(1)
		return
	print("Mars Spark Missile runtime scene verified.")
	quit(0)


func _register_enemy(enemy: Node) -> void:
	var registry: Node = CombatTargetRegistryScript.get_or_create(root)
	registry.call("register_enemy", enemy)
	_registered_enemies.append(enemy)
