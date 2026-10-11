## 文件用途：主角进入技能范围时每 0.5 秒支援友军；范围外靠近主角，不敲鼓。
extends EnemyBehavior
const Marker = preload("res://scripts/enemies/combat/enemy_support_marker.gd")
var _refresh_timer := 0.0
var _marker: Node2D
var _scan_count := 0
func tick(delta: float) -> void:
	if enemy.get("_is_dead") == true:
		return
	_refresh_timer -= delta
	if not _is_target_in_behavior_attack_range():
		if is_instance_valid(_marker):
			_marker.visible = false
		if _target() != null:
			_apply_chase_movement()
		else:
			_set_velocity(Vector2.ZERO)
		return
	_set_velocity(Vector2.ZERO)
	if _refresh_timer <= 0.000001:
		_refresh_timer = float(config.get("refresh_interval", 0.5))
		_scan_count += 1
		_execute_required_action("ally_buff")
		if not is_instance_valid(_marker):
			_marker = Marker.new()
			_marker.set("aura", true)
			_marker.set("radius", float(config.get("aura_radius", 220.0)))
			enemy.add_child(_marker)
		_marker.visible = true
		_marker.call("pulse")

func cancel_pending_attack() -> void:
	if is_instance_valid(_marker):
		_marker.visible = false
