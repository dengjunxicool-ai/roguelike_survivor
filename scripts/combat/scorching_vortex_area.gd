extends AreaEffect
class_name ScorchingVortexArea


@export_range(0.0, 2.0, 0.01, "or_greater") var hit_stop_duration: float = 0.35
@export_range(1.0, 1200.0, 1.0, "or_greater") var density_seek_radius: float = 320.0
@export_range(1.0, 600.0, 1.0, "or_greater") var density_cluster_radius: float = 96.0

var _hit_stop_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _swept_body_ids: Dictionary = {}


func setup(params: Dictionary) -> void:
	hit_stop_duration = maxf(float(params.get("hit_stop_duration", hit_stop_duration)), 0.0)
	density_seek_radius = maxf(float(params.get("density_seek_radius", density_seek_radius)), 1.0)
	density_cluster_radius = maxf(float(params.get("density_cluster_radius", density_cluster_radius)), 1.0)
	super.setup(params)
	_last_position = global_position
	_apply_tick_damage()


func _physics_process(delta: float) -> void:
	if _damage_window_finished:
		return
	var previous_position: Vector2 = global_position
	if _hit_stop_timer > 0.0:
		_hit_stop_timer = maxf(_hit_stop_timer - delta, 0.0)
		var saved_speed: float = move_speed
		move_speed = 0.0
		super._physics_process(delta)
		move_speed = saved_speed
	else:
		_redirect_towards_dense_cluster(global_position)
		super._physics_process(delta)
	_damage_swept_targets(previous_position, global_position)
	_last_position = global_position


func _damage_body(body: Node) -> bool:
	var damaged: bool = super._damage_body(body)
	if damaged and body is Node2D:
		_hit_stop_timer = maxf(_hit_stop_timer, hit_stop_duration)
		_redirect_towards_dense_cluster((body as Node2D).global_position)
	return damaged


func _damage_swept_targets(from_position: Vector2, to_position: Vector2) -> void:
	if from_position.distance_squared_to(to_position) <= 0.0001:
		return
	var midpoint: Vector2 = (from_position + to_position) * 0.5
	var sweep_radius: float = radius + from_position.distance_to(to_position) * 0.5
	for body: Node2D in query_target_candidates(midpoint, sweep_radius):
		if body == null or not _can_damage_body(body):
			continue
		if _swept_body_ids.has(body.get_instance_id()):
			continue
		if _distance_to_segment(body.global_position, from_position, to_position) <= radius:
			if _damage_body(body):
				_swept_body_ids[body.get_instance_id()] = true


func _redirect_towards_dense_cluster(origin: Vector2) -> void:
	var center: Vector2 = _find_dense_cluster_center(origin)
	if center == Vector2.INF:
		return
	var direction: Vector2 = center - global_position
	if direction.length_squared() > 0.0001:
		move_direction = direction.normalized()


func _find_dense_cluster_center(origin: Vector2) -> Vector2:
	var candidates: Array[Node2D] = []
	var seek_radius_squared: float = density_seek_radius * density_seek_radius
	for body: Node2D in query_target_candidates(origin, density_seek_radius):
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		if body.has_method("is_dead") and bool(body.call("is_dead")):
			continue
		if origin.distance_squared_to(body.global_position) <= seek_radius_squared:
			candidates.append(body)
	if candidates.is_empty():
		return Vector2.INF

	var best_center: Vector2 = candidates[0].global_position
	var best_count: int = -1
	var best_distance: float = INF
	var cluster_radius_squared: float = density_cluster_radius * density_cluster_radius
	for candidate: Node2D in candidates:
		var count: int = 0
		var center: Vector2 = Vector2.ZERO
		for neighbor: Node2D in candidates:
			if candidate.global_position.distance_squared_to(neighbor.global_position) <= cluster_radius_squared:
				count += 1
				center += neighbor.global_position
		if count > 0:
			center /= float(count)
		var distance: float = global_position.distance_squared_to(center)
		if count > best_count or (count == best_count and distance < best_distance):
			best_count = count
			best_center = center
			best_distance = distance
	return best_center


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)
