## 跃击落点在预警开始时锁定；落地单次结算，恢复期间禁用接触伤害。
extends EnemyBehavior
const Telegraph = preload("res://scripts/enemies/combat/enemy_attack_telegraph.gd")
const MapBoundary = preload("res://scripts/enemies/enemy_map_boundary.gd")
var _phase: StringName = &"idle"
var _remaining := 0.0
var _cooldown := 0.0
var _direction := Vector2.ZERO
var _landing := Vector2.ZERO
var _warning: Node2D

func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown-delta,0.0)
	if _phase == &"warning":
		_remaining = maxf(_remaining-delta,0.0)
		_set_velocity(Vector2.ZERO)
		if is_instance_valid(_warning):
			_warning.call("set_progress",1.0-_remaining/float(config.get("leap_warning_time",1.0)))
		if _remaining <= 0.0:
			_phase = &"leap"
			_set_property(&"_special_attack_passes_target",true)
			_remaining = float(config.get("leap_duration",0.6))
		return
	if _phase == &"leap":
		if _remaining > 0.0:
			var step := minf(_remaining,delta)
			_remaining = maxf(_remaining-delta,0.0)
			_set_velocity(_direction * float(config.get("leap_speed",280.0)) * step/maxf(delta,0.000001))
			return
		_set_velocity(Vector2.ZERO)
		var actual_landing := _body().global_position
		var impact_ready := actual_landing.distance_squared_to(_landing) <= 4.0
		if is_instance_valid(_warning):
			_warning.queue_free()
		_set_property(&"_special_attack_passes_target",false)
		_call_enemy(&"_execute_enemy_skill_action",["damage_area",{"position":actual_landing,"impact_ready":impact_ready}])
		_phase = &"recovery"
		_remaining = float(config.get("recovery_time",0.8))
		return
	if _phase == &"recovery":
		_remaining = maxf(_remaining-delta,0.0)
		_set_velocity(Vector2.ZERO)
		if _remaining <= 0.0:
			_phase = &"idle"
			_set_property(&"_special_attack_contact_blocked",false)
		return
	var target := _target()
	var body := _body()
	if target == null or body == null:
		return
	if _cooldown <= 0.0 and _is_target_in_behavior_attack_range():
		_direction = body.global_position.direction_to(target.global_position)
		_landing = body.global_position + _direction * float(config.get("leap_speed",280.0)) * float(config.get("leap_duration",0.6))
		_landing = MapBoundary.clamp_position(body,_landing,float(body.call("_get_collision_radius",body,24.0)))
		_remaining = float(config.get("leap_warning_time",1.0))
		_cooldown = float(config.get("leap_cooldown",5.0))
		_phase = &"warning"
		_set_property(&"_special_attack_contact_blocked",true)
		_set_velocity(Vector2.ZERO)
		_warning = Telegraph.new()
		body.add_child(_warning)
		_warning.top_level = true
		_warning.global_position = _landing
		_warning.call("configure", &"circle", {"radius":110.0,"color":Color(1.0,0.45,0.1,0.9)})
	else:
		_apply_chase_movement()

func cancel_pending_attack() -> void:
	if is_instance_valid(_warning):
		_warning.queue_free()
	_phase = &"idle"
	_set_property(&"_special_attack_passes_target",false)
	_set_property(&"_special_attack_contact_blocked",false)
	_set_velocity(Vector2.ZERO)
