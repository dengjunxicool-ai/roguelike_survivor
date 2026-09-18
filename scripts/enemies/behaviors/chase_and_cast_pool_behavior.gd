extends EnemyBehavior
class_name ChaseAndCastPoolBehavior


func tick(_delta: float) -> void:
	_cancel_ranged_attack_warning()
	var target: Node2D = _target()
	if target == null:
		return
	if not _is_target_in_behavior_attack_range():
		_apply_chase_movement()
		return

	_set_velocity(Vector2.ZERO)
	if _float_property(&"_cast_cooldown") <= 0.0:
		var pool_tick_interval: float = float(config.get("pool_tick_interval", 1.0))
		var pool_damage: int = int(config.get("pool_damage", enemy.get("contact_damage")))
		if pool_tick_interval >= 0.99:
			pool_damage *= 2
		_execute_required_action("damage_area", {
			"position": target.global_position,
			"damage": pool_damage,
			"duration": float(config.get("pool_duration", 3.0)),
			"tick_interval": pool_tick_interval,
			"radius": float(config.get("pool_radius", 72.0)),
			"visual_color": Color(0.35, 0.95, 0.2, 0.32)
		})
		_set_property(&"_cast_cooldown", float(_call_enemy(&"_get_enemy_skill_cooldown", ["damage_area", float(config.get("cast_cooldown", 4.0))])))

	if _is_target_in_attack_range():
		_apply_range_attack_damage()
