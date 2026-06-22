extends EnemyBehavior
class_name ExplodeNearPlayerBehavior


func tick(delta: float) -> void:
	var body: CharacterBody2D = _body()
	var target: Node2D = _target()
	if body == null or target == null:
		return

	var distance: float = body.global_position.distance_to(target.global_position)
	if _is_target_in_attack_range(distance):
		_set_property(&"_is_fusing", true)

	if bool(enemy.get("_is_fusing")):
		_set_velocity(Vector2.ZERO)
		var fuse_timer: float = _float_property(&"_fuse_timer") + delta
		_set_property(&"_fuse_timer", fuse_timer)
		_call_enemy(&"_update_fuse_visual")
		if fuse_timer >= maxf(float(config.get("fuse_time", 0.8)), 0.05):
			_execute_required_action("self_explode")
		return

	_apply_melee_chase_movement()
