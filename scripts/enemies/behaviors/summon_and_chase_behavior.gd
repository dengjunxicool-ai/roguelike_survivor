extends EnemyBehavior
class_name SummonAndChaseBehavior


func tick(_delta: float) -> void:
	_cancel_ranged_attack_warning()
	if not _is_target_in_behavior_attack_range():
		_apply_chase_movement()
		return

	var body: CharacterBody2D = _body()
	_set_velocity(Vector2.ZERO)
	if _float_property(&"_summon_cooldown") <= 0.0:
		var center: Vector2 = body.global_position if body != null else Vector2.ZERO
		_execute_required_action("summon", {
			"enemy_id": String(config.get("summon_enemy_id", "small_slime")),
			"count": int(config.get("summon_count", 1)),
			"center": center,
			"radius": float(config.get("summon_radius", 72.0))
		})
		_set_property(&"_summon_cooldown", float(_call_enemy(&"_get_enemy_skill_cooldown", ["summon", float(config.get("summon_cooldown", 5.0))])))

	if _is_target_in_attack_range():
		_apply_range_attack_damage()
