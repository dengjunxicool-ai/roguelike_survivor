extends RefCounted
class_name EnemyBehavior


var enemy: Node
var config: Dictionary = {}
var _reported_required_action_failures: Dictionary = {}


func setup(owner: Node, behavior_config: Dictionary = {}) -> void:
	enemy = owner
	config = behavior_config.duplicate(true)


func tick(_delta: float) -> void:
	pass


func get_debug_state() -> Dictionary:
	return {
		"type": String(config.get("type", ""))
	}


func _call_enemy(method_name: StringName, args: Array = []) -> Variant:
	if enemy == null or not enemy.has_method(method_name):
		return null
	return enemy.callv(method_name, args)


func _body() -> CharacterBody2D:
	return enemy as CharacterBody2D


func _target() -> Node2D:
	if enemy == null:
		return null
	return enemy.get("target") as Node2D


func _set_velocity(value: Vector2) -> void:
	var body: CharacterBody2D = _body()
	if body != null:
		body.velocity = value


func _apply_chase_movement(extra_direction: Vector2 = Vector2.ZERO) -> void:
	var body: CharacterBody2D = _body()
	var target: Node2D = _target()
	if body == null or target == null:
		_set_velocity(Vector2.ZERO)
		return

	var direction: Vector2 = (body.global_position.direction_to(target.global_position) + extra_direction).normalized()
	if bool(config.get("zigzag", false)) and direction != Vector2.ZERO:
		var sway_strength: float = float(config.get("zigzag_strength", 0.45))
		var sway_speed: float = float(config.get("zigzag_speed", 6.0))
		var behavior_time: float = float(enemy.get("_behavior_time")) if enemy != null else 0.0
		var perpendicular: Vector2 = direction.orthogonal()
		direction = (direction + perpendicular * sin(behavior_time * sway_speed) * sway_strength).normalized()

	_set_velocity(direction * float(_call_enemy(&"_get_effective_move_speed")))


func _apply_melee_chase_movement() -> void:
	if _idle_if_melee_space_blocked():
		return
	_apply_chase_movement(_get_separation_direction() * float(config.get("separation_strength", 0.25)))


func _idle_if_melee_space_blocked() -> bool:
	var body: CharacterBody2D = _body()
	var target: Node2D = _target()
	if body == null or target == null or _is_target_in_attack_range():
		return false

	var radius: float = float(config.get("melee_crowd_radius", 88.0))
	if body.global_position.distance_squared_to(target.global_position) <= radius * radius:
		return false

	var max_nearby: int = int(config.get("melee_crowd_limit", 10))
	var count: int = 0
	for node: Node in body.get_tree().get_nodes_in_group(&"enemy"):
		var other: Node2D = node as Node2D
		if other == null or other == body or other.is_queued_for_deletion():
			continue
		if other.has_method("get_behavior_type") and not _is_melee_behavior(String(other.call("get_behavior_type"))):
			continue
		if other.global_position.distance_squared_to(target.global_position) <= radius * radius:
			count += 1
			if count >= max_nearby:
				_set_velocity(Vector2.ZERO)
				return true
	return false


func _get_separation_direction() -> Vector2:
	var body: CharacterBody2D = _body()
	if body == null:
		return Vector2.ZERO
	var radius: float = float(config.get("separation_radius", 30.0))
	var separation: Vector2 = Vector2.ZERO
	var checked: int = 0
	for node: Node in body.get_tree().get_nodes_in_group(&"enemy"):
		var other: Node2D = node as Node2D
		if other == null or other == body or other.is_queued_for_deletion():
			continue
		var offset: Vector2 = body.global_position - other.global_position
		var distance_squared: float = offset.length_squared()
		if distance_squared <= 0.01 or distance_squared > radius * radius:
			continue
		separation += offset.normalized() * (1.0 - sqrt(distance_squared) / radius)
		checked += 1
		if checked >= 8:
			break
	return separation.normalized() if separation.length_squared() > 0.01 else Vector2.ZERO


func _is_melee_behavior(behavior_type: String) -> bool:
	return behavior_type == "chase_player" or behavior_type == "explode_near_player" or behavior_type == "dash_attack"


func _is_target_in_attack_range(distance: float = -1.0) -> bool:
	return bool(_call_enemy(&"_is_target_in_attack_range", [distance]))


func _is_target_in_behavior_attack_range(distance: float = -1.0) -> bool:
	return bool(_call_enemy(&"_is_target_in_behavior_attack_range", [distance]))


func _cancel_ranged_attack_warning() -> void:
	_call_enemy(&"_cancel_ranged_attack_warning")


func _apply_range_attack_damage() -> void:
	_call_enemy(&"_apply_range_attack_damage")


func _execute_required_action(action_type: String, runtime_params: Dictionary = {}) -> bool:
	if bool(_call_enemy(&"_execute_enemy_skill_action", [action_type, runtime_params])):
		return true
	if not _reported_required_action_failures.has(action_type):
		_reported_required_action_failures[action_type] = true
		var enemy_id: String = String(enemy.get("enemy_id")) if enemy != null else ""
		push_error("[%s] Required enemy skill action '%s' failed for enemy '%s'." % [get_script().resource_path.get_file(), action_type, enemy_id])
	return false


func _float_property(property_name: StringName, fallback: float = 0.0) -> float:
	if enemy == null:
		return fallback
	var value: Variant = enemy.get(property_name)
	return fallback if value == null else float(value)


func _set_property(property_name: StringName, value: Variant) -> void:
	if enemy != null:
		enemy.set(property_name, value)
