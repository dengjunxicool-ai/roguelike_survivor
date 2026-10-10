## 锁定方向的预警、突进和恢复；按实际移动时间截断末帧。
extends EnemyBehavior
class_name DashAttackBehavior
var _phase: StringName = &"idle"
var _remaining := 0.0

func tick(delta: float) -> void:
	if _phase == &"dash":
		if _remaining <= 0.0:
			_set_property(&"_dash_timer", 0.0)
			_phase = &"recovery"
			_set_property(&"_special_attack_passes_target",false)
			_remaining = float(config.get("recovery_time", 0.0))
			_set_property(&"_special_attack_contact_blocked", true)
			_set_velocity(Vector2.ZERO)
			return
		var step := minf(delta, _remaining)
		_remaining = maxf(_remaining - delta, 0.0)
		var direction: Vector2 = enemy.get("_dash_direction")
		_set_velocity(direction * float(config.get("dash_speed", 360.0)) * step / maxf(delta, 0.000001))
		return
	if _phase == &"recovery":
		_remaining = maxf(_remaining - delta, 0.0)
		_set_velocity(Vector2.ZERO)
		if _remaining <= 0.0:
			_phase = &"idle"
			_set_property(&"_special_attack_contact_blocked", false)
		return
	if _phase == &"warning":
		_remaining = maxf(_remaining - delta, 0.0)
		_set_property(&"_dash_warning_timer", _remaining)
		_set_velocity(Vector2.ZERO)
		if _remaining <= 0.0:
			_call_enemy(&"_hide_attack_telegraph")
			_phase = &"dash"
			_call_enemy(&"_record_attack_metric",[&"charge",&"start"])
			_set_property(&"_special_attack_passes_target",true)
			_remaining = float(config.get("dash_duration", 0.4))
			_set_property(&"_dash_timer", _remaining)
			_set_property(&"_special_attack_contact_blocked", false)
			_set_property(&"_damage_cooldown", 0.0)
		return
	var target := _target()
	var body := _body()
	if target == null or body == null:
		return
	if _float_property(&"_dash_cooldown") <= 0.0 and _is_target_in_behavior_attack_range():
		var direction := body.global_position.direction_to(target.global_position)
		_set_property(&"_dash_direction", direction if direction != Vector2.ZERO else Vector2.RIGHT)
		_set_property(&"_attack_generation", int(enemy.get("_attack_generation")) + 1)
		_set_property(&"_dash_hit_targets", {})
		_remaining = float(config.get("dash_warning_time", 0.6))
		_phase = &"warning"
		_set_property(&"_dash_warning_timer", _remaining)
		_set_property(&"_dash_cooldown", float(config.get("dash_cooldown", 4.5)))
		_set_property(&"_special_attack_contact_blocked", true)
		_set_velocity(Vector2.ZERO)
		_call_enemy(&"_show_dash_attack_warning")
	else:
		_apply_chase_movement()

func cancel_pending_attack() -> void:
	_phase = &"idle"
	_set_property(&"_special_attack_passes_target",false)
	_remaining = 0.0
	_set_property(&"_dash_timer", 0.0)
	_set_property(&"_dash_warning_timer", 0.0)
	_set_property(&"_special_attack_contact_blocked", false)
	_set_velocity(Vector2.ZERO)
	_call_enemy(&"_hide_attack_telegraph")
