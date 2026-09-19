extends Node2D
class_name EnemySpawnWarning


var _radius: float = 34.0
var _progress: float = 0.0


func configure(radius: float) -> void:
	_radius = maxf(radius, 8.0)
	queue_redraw()


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.82 + sin(_progress * TAU * 2.0) * 0.08
	var warning_color := Color(1.0, 0.22, 0.12, 0.9 - _progress * 0.25)
	draw_circle(Vector2.ZERO, _radius * pulse, Color(1.0, 0.08, 0.04, 0.08), true)
	draw_arc(Vector2.ZERO, _radius * pulse, 0.0, TAU, 48, warning_color, 3.0, true)
	draw_arc(Vector2.ZERO, _radius * 0.62, -PI * 0.5, -PI * 0.5 + TAU * _progress, 32, Color(1.0, 0.72, 0.18, 0.95), 4.0, true)
