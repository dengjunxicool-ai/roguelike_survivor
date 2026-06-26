extends RefCounted
class_name SummonMovementComponent


var move_speed: float = 180.0
var follow_distance: float = 80.0
var min_distance: float = 40.0
var leash_distance: float = 360.0
var teleport_distance: float = 720.0
var separation_radius: float = 32.0
var formation_index: int = 0

var _has_owner_position: bool = false
var _last_owner_position: Vector2 = Vector2.ZERO
var _follow_direction: Vector2 = Vector2.LEFT


func setup(config: Dictionary, index: int) -> void:
	move_speed = maxf(float(config.get("move_speed", move_speed)), 1.0)
	follow_distance = maxf(float(config.get("follow_distance", follow_distance)), 0.0)
	min_distance = maxf(float(config.get("min_distance", min_distance)), 0.0)
	leash_distance = maxf(float(config.get("leash_distance", leash_distance)), min_distance)
	teleport_distance = maxf(float(config.get("teleport_distance", teleport_distance)), leash_distance)
	separation_radius = maxf(float(config.get("separation_radius", separation_radius)), 0.0)
	formation_index = maxi(index, 0)
	_has_owner_position = false
	_follow_direction = Vector2.LEFT


func update_owner_motion(owner: Node2D) -> void:
	if owner == null:
		return
	if _has_owner_position:
		var owner_delta: Vector2 = owner.global_position - _last_owner_position
		if owner_delta.length_squared() > 1.0:
			_follow_direction = -owner_delta.normalized()
	_last_owner_position = owner.global_position
	_has_owner_position = true


func is_beyond_leash(summon: Node2D, owner: Node2D) -> bool:
	return summon != null and owner != null and summon.global_position.distance_to(owner.global_position) > leash_distance


func is_beyond_teleport(summon: Node2D, owner: Node2D) -> bool:
	return summon != null and owner != null and summon.global_position.distance_to(owner.global_position) > teleport_distance


func teleport_near_owner(summon: Node2D, owner: Node2D) -> void:
	if summon == null or owner == null:
		return
	summon.global_position = owner.global_position + get_follow_offset()


func move_follow(summon: Node2D, owner: Node2D, delta: float) -> void:
	if summon == null or owner == null:
		return
	var desired: Vector2 = owner.global_position + get_follow_offset()
	if summon.global_position.distance_to(owner.global_position) < min_distance and summon.global_position.distance_to(desired) < min_distance:
		return
	summon.global_position = summon.global_position.move_toward(desired, move_speed * delta)


func move_chase(summon: Node2D, target: Node2D, delta: float) -> void:
	if summon == null or target == null:
		return
	summon.global_position = summon.global_position.move_toward(target.global_position, move_speed * delta)


func move_return(summon: Node2D, owner: Node2D, delta: float) -> void:
	if summon == null or owner == null:
		return
	var desired: Vector2 = owner.global_position + get_follow_offset()
	summon.global_position = summon.global_position.move_toward(desired, move_speed * delta)


func get_follow_offset() -> Vector2:
	var behind: Vector2 = _follow_direction
	if behind.length_squared() <= 0.0001:
		behind = Vector2.LEFT
	behind = behind.normalized()
	var side: Vector2 = Vector2(-behind.y, behind.x)
	var side_step: float = 0.0
	if formation_index > 0:
		var lane: int = int((formation_index + 1) / 2)
		var sign_value: float = -1.0 if formation_index % 2 == 1 else 1.0
		side_step = sign_value * float(lane) * separation_radius
	return behind * follow_distance + side * side_step
