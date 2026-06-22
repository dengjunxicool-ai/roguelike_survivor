extends EnemyBehavior
class_name ChasePlayerBehavior


func tick(_delta: float) -> void:
	_cancel_ranged_attack_warning()
	if _is_target_in_attack_range():
		_set_velocity(Vector2.ZERO)
		_apply_range_attack_damage()
	else:
		_apply_melee_chase_movement()
