## 文件用途：绘制敌方区域边界、冲锋通道或环形弹幕安全扇区；不结算伤害。
## 使用方式：configure 设置几何，set_progress 更新预警，set_active 显示生效状态。
extends Node2D

var _shape: StringName = &"circle"
var _params: Dictionary = {}
var _progress := 0.0
var _active := false

func configure(shape: StringName, params: Dictionary) -> void:
	_shape = shape
	_params = params.duplicate(true)
	_progress = 0.0
	_active = false
	queue_redraw()

func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func set_active(value: bool) -> void:
	_active = value
	queue_redraw()

func _draw() -> void:
	var radius: float = float(_params.get("radius", 76.0))
	var color: Color = _params.get("color", Color(1.0, 0.25, 0.08, 0.9))
	if _shape == &"ring":
		var count: int = maxi(int(_params.get("projectile_count", 12)), 1)
		var gap: int = clampi(int(_params.get("safe_gap_count", 2)), 0, count)
		var start: int = posmod(int(_params.get("safe_gap_start", 0)), count)
		for index in range(count):
			var safe: bool = posmod(index - start, count) < gap
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(count))
			draw_line(direction * 30.0, direction * radius, Color(0.2, 1.0, 0.45, 0.8) if safe else color, 5.0 if safe else 2.0, true)
			draw_circle(direction * radius, 5.0, Color.GREEN if safe else color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, 2.0, true)
	elif _shape == &"dash":
		var end: Vector2 = _params.get("direction", Vector2.RIGHT) * radius
		draw_line(Vector2.ZERO, end, Color(color, 0.15), float(_params.get("width", 40.0)), true)
		draw_line(Vector2.ZERO, end, color, 3.0, true)
	else:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.26 if _active else 0.07))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 80, color, 3.0, true)
		if not _active:
			draw_arc(Vector2.ZERO, radius * 0.86, -PI / 2.0, -PI / 2.0 + TAU * _progress, 64, color, 4.0, true)
