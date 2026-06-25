extends RefCounted
class_name SummonMovementComponent


const SummonFormationServiceScript: Script = preload("res://scripts/summons/summon_formation_service.gd")

var move_speed: float = 180.0
var follow_distance: float = 80.0
var min_distance: float = 40.0
var leash_distance: float = 360.0
var teleport_distance: float = 720.0
var separation_radius: float = 32.0
var formation_index: int = 0


func setup(config: Dictionary, index: int) -> void:
	move_speed = maxf(float(config.get("move_speed", move_speed)), 1.0)
	follow_distance = maxf(float(config.get("follow_distance", follow_distance)), 0.0)
	min_distance = maxf(float(config.get("min_distance", min_distance)), 0.0)
	leash_distance = maxf(float(config.get("leash_distance", leash_distance)), min_distance)
	teleport_distance = maxf(float(config.get("teleport_distance", teleport_distance)), leash_distance)
	separation_radius = maxf(float(config.get("separation_radius", separation_radius)), 0.0)
	formation_index = maxi(index, 0)


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
	if summon.global_position.distance_to(owner.global_position) < min_distance:
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
	return SummonFormationServiceScript.get_offset(formation_index, separation_radius, follow_distance)
