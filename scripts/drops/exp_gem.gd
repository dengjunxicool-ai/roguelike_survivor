extends Area2D
class_name ExpGem

@export_range(1, 10000, 1, "or_greater") var experience_amount: int = 25
@export_range(1.0, 1000.0, 1.0, "or_greater") var magnet_radius: float = 180.0
@export_range(1.0, 200.0, 1.0, "or_greater") var pickup_radius: float = 24.0
@export_range(1.0, 2000.0, 10.0, "or_greater") var fly_speed: float = 360.0
@export var target_group: StringName = &"player"

var target: Node2D
var _is_collected: bool = false


func _ready() -> void:
	add_to_group(&"experience_crystal")
	target = _find_target()


func _physics_process(delta: float) -> void:
	if _is_collected:
		return

	if not is_instance_valid(target):
		target = _find_target()

	if target == null:
		return

	var distance_to_target: float = global_position.distance_to(target.global_position)
	var target_pickup_radius: float = _get_target_pickup_radius()
	if distance_to_target <= pickup_radius:
		_collect(target)
		return

	if distance_to_target <= target_pickup_radius:
		global_position = global_position.move_toward(
			target.global_position,
			fly_speed * delta
		)


func set_experience_amount(amount: int) -> void:
	experience_amount = maxi(amount, 1)


func collect_to_player(player: Node2D = null) -> void:
	var collector: Node2D = player
	if collector == null:
		collector = target if is_instance_valid(target) else _find_target()
	if collector != null:
		_collect(collector)


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


func _collect(player: Node2D) -> void:
	if _is_collected or not player.has_method("add_experience"):
		return

	_is_collected = true
	player.call(&"add_experience", experience_amount)
	queue_free()


func _get_target_pickup_radius() -> float:
	if target == null:
		return magnet_radius

	var configured_radius: Variant = target.get("pickup_radius")
	if target.has_method("get_effective_pickup_radius"):
		configured_radius = target.call("get_effective_pickup_radius")
	if configured_radius == null:
		return magnet_radius

	return maxf(float(configured_radius), magnet_radius)
