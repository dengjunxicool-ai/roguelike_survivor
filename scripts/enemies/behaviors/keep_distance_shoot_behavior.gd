## 文件用途：实现远程敌人在射程外追逐、进入射程后停下并预警射击的行为。
## 使用方式：registry 以 keep_distance_and_shoot 类型创建；先 setup，tick 推进预警与射击时机。

extends EnemyBehavior
class_name KeepDistanceShootBehavior


## 作用：射程外追逐，射程内停下并在预警结束后射击。
## 使用：先 setup 绑定 enemy；由控制器每物理帧调用，delta 为秒。
func tick(delta: float) -> void:
	var body: CharacterBody2D = _body()
	var target: Node2D = _target()
	if body == null or target == null:
		_set_velocity(Vector2.ZERO)
		return

	var to_target: Vector2 = target.global_position - body.global_position
	var distance: float = to_target.length()
	var direction_to_target: Vector2 = to_target.normalized() if distance > 0.0 else Vector2.RIGHT

	if not _is_target_in_attack_range(distance):
		_cancel_ranged_attack_warning()
		_apply_chase_movement()
		return

	_set_velocity(Vector2.ZERO)
	var warning_timer: float = _float_property(&"_ranged_warning_timer")
	if warning_timer > 0.0:
		warning_timer = maxf(warning_timer - delta, 0.0)
		_set_property(&"_ranged_warning_timer", warning_timer)
		_call_enemy(&"_show_ranged_attack_warning")
		if warning_timer <= 0.0:
			_fire_projectile()
		return

	if _float_property(&"_shoot_cooldown") <= 0.0:
		_call_enemy(&"_start_ranged_attack_warning", [direction_to_target])
		if _float_property(&"_ranged_warning_timer") <= 0.0:
			_fire_projectile()


## 作用：发射投射物。
## 使用：本文件由 tick 调用。
func _fire_projectile() -> void:
	var direction: Vector2 = enemy.get("_ranged_warning_direction") if enemy != null else Vector2.RIGHT
	_execute_required_action("projectile", {"direction": direction})
	_call_enemy(&"_hide_attack_telegraph")
	_set_property(&"_shoot_cooldown", float(_call_enemy(&"_get_enemy_skill_cooldown", ["projectile", float(config.get("shoot_cooldown", 2.2))])))
