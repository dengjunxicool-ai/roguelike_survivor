## 文件用途：每 0.5 秒请求友军支援动作，鼓点只提示增益，不生成伤害池。
extends EnemyBehavior
const Marker = preload("res://scripts/enemies/combat/enemy_support_marker.gd")
var _refresh_timer := 0.0
var _marker: Node2D
var _scan_count := 0
func tick(delta: float) -> void:
	if enemy.get("_is_dead") == true:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.000001:
		_refresh_timer = float(config.get("refresh_interval", 0.5))
		_scan_count += 1
		_execute_required_action("ally_buff")
		if not is_instance_valid(_marker):
			_marker = Marker.new()
			_marker.set("aura", true)
			_marker.set("radius", float(config.get("aura_radius", 220.0)))
			enemy.add_child(_marker)
		_marker.call("pulse")
	var target := _target()
	if target != null and _body().global_position.distance_to(target.global_position) > float(config.get("preferred_distance",320.0)):
		_apply_chase_movement()
	else:
		_set_velocity(Vector2.ZERO)
