## 文件用途：实现预警、突进和突进冷却组成的敌人攻击流程。
## 使用方式：通过 behavior 配置绑定到敌人；在物理更新 tick 中推进各阶段计时。

extends EnemyBehavior
class_name DashAttackBehavior


## 作用：推进突进持续时间与预警，冷却到期可启动突进，空闲时追逐或近身攻击。
## 使用：delta 用于突进/预警计时；突进冷却递减由 EnemyBase 处理，本方法仅在启动时重置冷却。
func tick(delta: float) -> void:
	var target: Node2D = _target()
	if target == null:
		return

	var dash_timer: float = _float_property(&"_dash_timer")
	if dash_timer > 0.0:
		_call_enemy(&"_hide_attack_telegraph")
		var body: CharacterBody2D = _body()
		var stop_distance: float = float(config.get("dash_stop_distance", 0.0))
		if body != null and stop_distance > 0.0 and body.global_position.distance_squared_to(target.global_position) <= stop_distance * stop_distance:
			_set_property(&"_dash_timer", 0.0)
			_set_velocity(Vector2.ZERO)
			return
		dash_timer = maxf(dash_timer - delta, 0.0)
		_set_property(&"_dash_timer", dash_timer)
		var direction: Vector2 = enemy.get("_dash_direction")
		_set_velocity(direction * float(config.get("dash_speed", 360.0)))
		return

	var warning_timer: float = _float_property(&"_dash_warning_timer")
	if warning_timer > 0.0:
		warning_timer = maxf(warning_timer - delta, 0.0)
		_set_property(&"_dash_warning_timer", warning_timer)
		_call_enemy(&"_show_dash_attack_warning")
		_set_velocity(Vector2.ZERO)
		if warning_timer <= 0.0:
			_call_enemy(&"_hide_attack_telegraph")
			_set_property(&"_dash_timer", maxf(float(config.get("dash_duration", 0.35)), 0.05))
			_set_property(&"_damage_cooldown", 0.0)
		return

	var body: CharacterBody2D = _body()
	if body == null:
		return
	var to_target: Vector2 = target.global_position - body.global_position
	var distance: float = to_target.length()
	if _float_property(&"_dash_cooldown") <= 0.0 and _is_target_in_behavior_attack_range(distance):
		var dash_direction: Vector2 = to_target.normalized() if distance > 0.0 else Vector2.RIGHT
		_set_property(&"_dash_direction", dash_direction)
		var dash_warning_time: float = maxf(float(config.get("dash_warning_time", 0.8)), 0.0)
		_set_property(&"_dash_warning_timer", dash_warning_time)
		_call_enemy(&"notify_preparing_attack", [])
		_set_property(&"_dash_cooldown", maxf(float(config.get("dash_cooldown", 4.5)), 0.1))
		if dash_warning_time <= 0.0:
			_set_property(&"_dash_timer", maxf(float(config.get("dash_duration", 0.35)), 0.05))
		else:
			_call_enemy(&"_show_dash_attack_warning")
		return

	if _is_target_in_attack_range(distance):
		_set_velocity(Vector2.ZERO)
		_apply_range_attack_damage()
	else:
		_apply_chase_movement()
