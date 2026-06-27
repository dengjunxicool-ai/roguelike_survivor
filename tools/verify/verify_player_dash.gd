extends SceneTree

const DataManagerScript: Script = preload("res://scripts/core/data_manager.gd")

var _failed: bool = false


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

	world.queue_free()
	if _failed:
		quit(1)
		return
	print("verify_player_dash: PASS")
	quit(0)


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
