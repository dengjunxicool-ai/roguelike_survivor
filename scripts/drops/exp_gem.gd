extends Area2D
class_name ExpGem

const HotPathProfilerScript: Script = preload("res://scripts/debug/hot_path_profiler.gd")
const PickupManagerScript: Script = preload("res://scripts/drops/pickup_manager.gd")
const PICKUP_STATE_IDLE: StringName = &"idle"
const PICKUP_STATE_MAGNETIZED: StringName = &"magnetized"
const PICKUP_STATE_COLLECTING: StringName = &"collecting"

@export_range(1, 10000, 1, "or_greater") var experience_amount: int = 25
@export_range(1.0, 1000.0, 1.0, "or_greater") var magnet_radius: float = 180.0
@export_range(1.0, 200.0, 1.0, "or_greater") var pickup_radius: float = 24.0
@export_range(1.0, 2000.0, 10.0, "or_greater") var fly_speed: float = 360.0
@export var target_group: StringName = &"player"

var target: Node2D
var _is_collected: bool = false
var _pickup_state: StringName = PICKUP_STATE_IDLE


func _ready() -> void:
	_prepare_active_state()


func _exit_tree() -> void:
	_unregister_pickup_manager()


func _physics_process(delta: float) -> void:
	pass


func _physics_process_profiled(delta: float) -> void:
	manager_active_update(delta, target, target.global_position if target != null else global_position, _get_target_pickup_radius())


func set_experience_amount(amount: int) -> void:
	experience_amount = maxi(amount, 1)


func prepare_for_pool_spawn(amount: Variant = null) -> void:
	if amount != null:
		set_experience_amount(int(amount))
	_prepare_active_state()


func prepare_for_pool_despawn() -> void:
	_is_collected = true
	_unregister_pickup_manager()
	target = null
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	remove_from_group(&"experience_crystal")
	visible = false


func despawn_or_free() -> void:
	if has_meta(&"runtime_pool_owner") and has_meta(&"runtime_pool_key"):
		var pool_variant: Variant = get_meta(&"runtime_pool_owner")
		var key: StringName = StringName(String(get_meta(&"runtime_pool_key")))
		if pool_variant is Node and is_instance_valid(pool_variant) and (pool_variant as Node).has_method("despawn"):
			prepare_for_pool_despawn()
			(pool_variant as Node).call("despawn", key, self)
			return
	queue_free()


func collect_to_player(player: Node2D = null) -> void:
	var collector: Node2D = player
	if collector == null:
		collector = target if is_instance_valid(target) else _find_target()
	if collector != null:
		_collect(collector)


func get_pickup_state() -> StringName:
	return _pickup_state


func manager_idle_check(player: Node2D, player_position: Vector2, target_pickup_radius: float) -> void:
	if _is_collected:
		return
	target = player
	if target == null:
		return
	var distance_to_target: float = global_position.distance_to(player_position)
	if distance_to_target <= pickup_radius:
		_collect(target)
		return
	if distance_to_target <= maxf(target_pickup_radius, magnet_radius):
		_set_pickup_state(PICKUP_STATE_MAGNETIZED)


func manager_active_update(delta: float, player: Node2D, player_position: Vector2, target_pickup_radius: float) -> void:
	if _is_collected:
		return
	target = player
	if target == null:
		_set_pickup_state(PICKUP_STATE_IDLE)
		return
	var distance_to_target: float = global_position.distance_to(player_position)
	if distance_to_target <= pickup_radius:
		_collect(target)
		return
	var effective_pickup_radius: float = maxf(target_pickup_radius, magnet_radius)
	if distance_to_target > effective_pickup_radius and _pickup_state == PICKUP_STATE_MAGNETIZED:
		_set_pickup_state(PICKUP_STATE_IDLE)
		return
	global_position = global_position.move_toward(
		player_position,
		fly_speed * delta
	)


func _find_target() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(target_group) as Node2D


func _collect(player: Node2D) -> void:
	if _is_collected or not player.has_method("add_experience"):
		return

	_is_collected = true
	_set_pickup_state(PICKUP_STATE_COLLECTING)
	var manager: Node = PickupManagerScript.get_or_create(self)
	if manager != null and manager.has_method("queue_experience_reward"):
		manager.call("queue_experience_reward", player, experience_amount)
	else:
		player.call(&"add_experience", experience_amount)
	despawn_or_free()


func _prepare_active_state() -> void:
	_is_collected = false
	_pickup_state = PICKUP_STATE_IDLE
	visible = true
	set_process(true)
	set_physics_process(false)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if not is_in_group(&"experience_crystal"):
		add_to_group(&"experience_crystal")
	target = _find_target()
	_register_pickup_manager()


func _get_target_pickup_radius() -> float:
	if target == null:
		return magnet_radius

	var configured_radius: Variant = target.get("pickup_radius")
	if target.has_method("get_effective_pickup_radius"):
		configured_radius = target.call("get_effective_pickup_radius")
	if configured_radius == null:
		return magnet_radius

	return maxf(float(configured_radius), magnet_radius)


func _set_pickup_state(new_state: StringName) -> void:
	if _pickup_state == new_state:
		return
	var old_state: StringName = _pickup_state
	_pickup_state = new_state
	var manager: Node = PickupManagerScript.get_or_create(self)
	if manager != null and manager.has_method("notify_state_changed"):
		manager.call("notify_state_changed", self, old_state, new_state)


func _register_pickup_manager() -> void:
	var manager: Node = PickupManagerScript.get_or_create(self)
	if manager != null and manager.has_method("register_pickup"):
		manager.call("register_pickup", self)


func _unregister_pickup_manager() -> void:
	var manager: Node = PickupManagerScript.get_or_create(self)
	if manager != null and manager.has_method("unregister_pickup"):
		manager.call("unregister_pickup", self)
