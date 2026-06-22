extends EnemyBehavior
class_name BossDungeonHeartBehavior


func tick(delta: float) -> void:
	_cancel_ranged_attack_warning()
	_call_enemy(&"_update_boss_skill_cooldowns", [delta])
	if not _is_target_in_behavior_attack_range():
		_apply_chase_movement()
		return

	_set_velocity(Vector2.ZERO)
	_call_enemy(&"_process_boss_phase_skills")
	if _is_target_in_attack_range():
		_set_velocity(Vector2.ZERO)
		_apply_range_attack_damage()
