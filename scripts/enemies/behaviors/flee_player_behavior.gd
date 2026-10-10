## 宝石怪远离玩家，撞到地图边缘后沿切线逃跑；不请求攻击动作。
extends EnemyBehavior
const Boundary = preload("res://scripts/enemies/enemy_map_boundary.gd")
func tick(delta: float) -> void:
	var body := _body()
	var target := _target()
	if body==null or target==null:
		_set_velocity(Vector2.ZERO)
		return
	var direction := target.global_position.direction_to(body.global_position)
	if direction.is_zero_approx(): direction=Vector2.RIGHT
	var speed := float(_call_enemy(&"_get_effective_move_speed"))
	var desired := direction*speed
	var limited := Boundary.limit_velocity(body,desired,delta,float(_call_enemy(&"_get_collision_radius",[body,18.0])))
	if limited.length_squared()<desired.length_squared()*0.25:
		var tangent := direction.orthogonal()*speed
		var first := Boundary.limit_velocity(body,tangent,delta,18.0)
		var second := Boundary.limit_velocity(body,-tangent,delta,18.0)
		limited=first if first.length_squared()>=second.length_squared() else second
	_set_velocity(limited)
