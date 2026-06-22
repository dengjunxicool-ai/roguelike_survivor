extends RefCounted
class_name EnemyAttackTelegraph


var _owner: Node2D
var _line: Line2D


## Params:
## - owner: Enemy node that owns the telegraph line.
## Returns:
## - Nothing.
func setup(owner: Node2D) -> void:
	_owner = owner


## Params:
## - direction: Direction in local enemy space.
## - behavior: Enemy behavior dictionary that may override telegraph style.
## - fallback_range: Attack range used when behavior does not define a warning range.
## Returns:
## - Nothing.
func show(direction: Vector2, behavior: Dictionary, fallback_range: float) -> void:
	var line: Line2D = _ensure_line(behavior)
	var spawn_offset: float = float(behavior.get("projectile_spawn_offset", 20.0))
	var line_length: float = float(behavior.get("projectile_warning_range", fallback_range))
	var normalized_direction: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	line.width = float(behavior.get("projectile_warning_width", 4.0))
	line.default_color = _get_color(behavior)
	line.clear_points()
	line.add_point(normalized_direction * spawn_offset)
	line.add_point(normalized_direction * maxf(line_length, spawn_offset + 1.0))
	line.visible = true


## Params:
## - None.
## Returns:
## - Nothing.
func hide() -> void:
	if _line != null and is_instance_valid(_line):
		_line.visible = false


## Params:
## - behavior: Enemy behavior dictionary used to style a newly created line.
## Returns:
## - Existing or newly created Line2D.
func _ensure_line(behavior: Dictionary) -> Line2D:
	if _line != null and is_instance_valid(_line):
		return _line

	_line = Line2D.new()
	_line.name = "AttackTrajectoryLine"
	_line.z_index = 30
	_line.width = float(behavior.get("projectile_warning_width", 4.0))
	_line.default_color = _get_color(behavior)
	_line.antialiased = true
	_line.visible = false
	if _owner != null:
		_owner.add_child(_line)
	return _line


## Params:
## - behavior: Enemy behavior dictionary that may contain color overrides.
## Returns:
## - Telegraph color.
func _get_color(behavior: Dictionary) -> Color:
	var color_value: Variant = behavior.get("projectile_warning_color", [])
	if color_value is Array:
		var color_items: Array = color_value
		if color_items.size() >= 3:
			var alpha: float = float(color_items[3]) if color_items.size() > 3 else 0.75
			return Color(float(color_items[0]), float(color_items[1]), float(color_items[2]), alpha)
	if color_value is String and String(color_value) != "":
		return Color.html(String(color_value))
	return Color(1.0, 0.18, 0.08, 0.72)
