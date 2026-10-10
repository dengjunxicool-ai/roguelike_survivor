## 文件用途：绘制友军支援标记或鼓点，不结算伤害。
extends Node2D
var aura := false
var radius := 220.0
var _pulse := 0.0
func pulse() -> void:
	_pulse = 0.5
	queue_redraw()
func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta, 0.0)
		queue_redraw()
func _draw() -> void:
	var color := Color(0.25, 1.0, 0.65, 0.8)
	if aura:
		if _pulse > 0.0:
			draw_arc(Vector2.ZERO, radius * (1.0 - _pulse), 0, TAU, 64, Color(color, _pulse), 2, true)
		draw_arc(Vector2.ZERO, 26, 0, TAU, 32, color, 3, true)
	else:
		draw_arc(Vector2.ZERO, 18, 0, TAU, 24, color, 2, true)
		for x in [-7, 7]:
			draw_polyline(PackedVector2Array([Vector2(x-4, 3), Vector2(x, -2), Vector2(x+4, 3)]),color,2,true)
