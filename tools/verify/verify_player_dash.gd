extends SceneTree

const DataManagerScript: Script = preload("res://scripts/core/data_manager.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")


class RecordingEnemy:
	extends CharacterBody2D

	var damage_packets: Array = []

	func _init() -> void:
		add_to_group(&"enemies")

	func take_damage(packet: Variant, _damage_type: Variant = &"") -> void:
		damage_packets.append(packet)

	func is_dead() -> bool:
		return false

var _failed: bool = false
var _recorded_dash_events: Array[StringName] = []


func _init() -> void:
	_ensure_data_manager()
	_expect(_space_dash_input_exists(), "dash input action exists and is bound to Space")

	var packed_scene: PackedScene = load("res://scenes/characters/player.tscn") as PackedScene
	_expect(packed_scene != null, "player scene loads")
	if packed_scene == null:
		quit(1)
		return

	var world: Node2D = Node2D.new()
	world.name = "DashTestWorld"
	root.add_child(world)
	var player: CharacterBody2D = packed_scene.instantiate() as CharacterBody2D
	world.add_child(player)
	await process_frame

	_expect(player.has_method("start_dash"), "Player exposes start_dash")
	_expect(player.has_method("is_dash_active"), "Player exposes is_dash_active")
	_expect(_has_property(player, "dash_speed"), "Player exposes dash_speed")
	_expect(_has_property(player, "dash_duration"), "Player exposes dash_duration")
	_expect(_has_property(player, "dash_cooldown"), "Player exposes dash_cooldown")
	_expect(is_equal_approx(float(player.get("dash_cooldown")), 2.6), "Player dash cooldown defaults to 2.6s")

	if player.has_method("start_dash"):
		player.global_position = Vector2.ZERO
		var started: bool = bool(player.call("start_dash", Vector2.RIGHT))
		_expect(started, "Player starts dash in requested direction")
		_expect(player.has_method("is_dash_active") and bool(player.call("is_dash_active")), "Player reports active dash after starting")
		player.call("_physics_process", 0.05)
		var afterimage: Node = world.find_child("DashAfterimage", true, false)
		_expect(afterimage is CanvasItem, "Player dash creates a visible afterimage")
		_expect(player.global_position.x > 0.0, "Player moves forward during dash")
		await _verify_dash_event_lifecycle(player)
		player.global_position = Vector2.ZERO
		player.set("_dash_time_remaining", 0.0)
		player.set("_dash_cooldown_remaining", 0.0)
		var blocker := Node2D.new()
		blocker.name = "DashPathEnemy"
		blocker.global_position = Vector2(70.0, 0.0)
		blocker.add_to_group(&"enemies")
		world.add_child(blocker)
		_expect(bool(player.call("start_dash", Vector2.RIGHT)), "Player starts dash toward enemy blocker")
		player.call("_physics_process", 0.12)
		_expect(player.global_position.x > blocker.global_position.x, "Player dash passes through enemies on the path")
		blocker.queue_free()
		player.global_position = Vector2.ZERO
		player.set("_dash_time_remaining", 0.0)
		player.set("_dash_cooldown_remaining", 0.0)
		var body_blocker := CharacterBody2D.new()
		body_blocker.name = "DashBodyEnemy"
		body_blocker.global_position = Vector2(70.0, 0.0)
		body_blocker.add_to_group(&"enemies")
		var body_shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 24.0
		body_shape.shape = circle
		body_blocker.add_child(body_shape)
		world.add_child(body_blocker)
		var original_enemy_position: Vector2 = body_blocker.global_position
		_expect(bool(player.call("start_dash", Vector2.RIGHT)), "Player starts dash toward physics enemy body")
		player.call("_physics_process", 0.12)
		_expect(player.global_position.x > body_blocker.global_position.x, "Player dash passes through physics enemy body")
		_expect(body_blocker.global_position.distance_to(original_enemy_position) <= 0.01, "Player dash does not push enemy body")
		player.global_position = Vector2.ZERO
		player.set("_dash_time_remaining", 0.0)
		player.set("_dash_cooldown_remaining", 0.0)
		await _verify_dash_skill_damage_is_local(world, player)

	world.queue_free()
	if _failed:
		quit(1)
		return
	print("verify_player_dash: PASS")
	quit(0)


func _verify_dash_event_lifecycle(player: CharacterBody2D) -> void:
	var event_bus: Node = player.get_node_or_null("SkillEventBus")
	_expect(event_bus != null and event_bus.has_method("subscribe"), "Player has a subscribable SkillEventBus")
	if event_bus == null or not event_bus.has_method("subscribe"):
		return
	for event_name: StringName in [&"dash_start", &"dash_tick", &"dash_end"]:
		event_bus.call("subscribe", event_name, Callable(self, "_record_dash_event").bind(event_name))

	_recorded_dash_events.clear()
	player.global_position = Vector2.ZERO
	player.set("_dash_time_remaining", 0.0)
	player.set("_dash_cooldown_remaining", 0.0)
	_expect(bool(player.call("start_dash", Vector2.RIGHT)), "Player starts dash for lifecycle event test")
	player.call("_physics_process", float(player.get("dash_duration")) + 0.1)
	_expect(_recorded_dash_events.count(&"dash_start") == 1, "dash emits one start event")
	_expect(_recorded_dash_events.count(&"dash_tick") >= 1, "dash emits tick events while active")
	_expect(_recorded_dash_events.count(&"dash_end") == 1, "dash emits one end event")
	player.call("_physics_process", 0.1)
	_expect(_recorded_dash_events.count(&"dash_end") == 1, "idle frames do not repeat dash end")


func _record_dash_event(_context: Dictionary, event_name: StringName) -> Dictionary:
	_recorded_dash_events.append(event_name)
	return {}


func _verify_dash_skill_damage_is_local(world: Node2D, player: CharacterBody2D) -> void:
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	_expect(skill_manager != null and skill_manager.has_method("add_skill"), "Player has a usable SkillManager")
	if skill_manager == null or not skill_manager.has_method("add_skill"):
		return
	var has_fire_dash: bool = bool(skill_manager.call("has_skill", &"fire_dash_blazing_run")) if skill_manager.has_method("has_skill") else false
	if not has_fire_dash:
		has_fire_dash = bool(skill_manager.call("add_skill", &"fire_dash_blazing_run"))
	_expect(has_fire_dash, "Player has fire dash skill")

	var near_enemy := _add_recording_enemy(world, Vector2(48.0, 0.0))
	var side_enemy := _add_recording_enemy(world, Vector2(20.0, 58.0))
	var far_enemy := _add_recording_enemy(world, Vector2(1200.0, 0.0))
	var registry: Node = CombatTargetRegistryScript.get_or_create(world)
	_expect(registry != null and registry.has_method("register_enemy"), "Combat target registry is available")
	if registry != null and registry.has_method("register_enemy"):
		registry.call("register_enemy", near_enemy)
		registry.call("register_enemy", side_enemy)
		registry.call("register_enemy", far_enemy)

	_expect(bool(player.call("start_dash", Vector2.RIGHT)), "Player starts fire dash for local damage test")
	await process_frame
	await process_frame

	var collision_exceptions: Array = player.get("_dash_collision_exceptions") as Array
	_expect(collision_exceptions.has(near_enemy), "Fire dash ignores collision with an enemy near the dash path")
	_expect(not collision_exceptions.has(side_enemy), "Fire dash does not add side collision exceptions outside the dash path")
	_expect(not collision_exceptions.has(far_enemy), "Fire dash does not add fullscreen collision exceptions")
	_expect(near_enemy.damage_packets.size() > 0, "Fire dash damages an enemy near the dash path")
	_expect(side_enemy.damage_packets.is_empty(), "Fire dash does not damage an enemy beside the dash path")
	_expect(far_enemy.damage_packets.is_empty(), "Fire dash does not damage an enemy outside the dash path")
	if registry != null and registry.has_method("unregister_enemy"):
		registry.call("unregister_enemy", near_enemy)
		registry.call("unregister_enemy", side_enemy)
		registry.call("unregister_enemy", far_enemy)
	near_enemy.queue_free()
	side_enemy.queue_free()
	far_enemy.queue_free()


func _add_recording_enemy(parent: Node, position: Vector2) -> RecordingEnemy:
	var enemy := RecordingEnemy.new()
	enemy.global_position = position
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	collision_shape.shape = circle
	enemy.add_child(collision_shape)
	parent.add_child(enemy)
	return enemy


func _space_dash_input_exists() -> bool:
	if not InputMap.has_action("dash"):
		return false
	for event: InputEvent in InputMap.action_get_events("dash"):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_SPACE:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true


func _ensure_data_manager() -> void:
	if root.get_node_or_null("DataManager") != null:
		return
	var data_manager: Node = DataManagerScript.new()
	data_manager.name = "DataManager"
	root.add_child(data_manager)
	data_manager.call("load_all")


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
