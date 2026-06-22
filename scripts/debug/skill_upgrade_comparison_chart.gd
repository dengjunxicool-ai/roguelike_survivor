extends Control
class_name SkillUpgradeComparisonChart


var _rows: Array[Dictionary] = []


func set_rows(rows: Array[Dictionary]) -> void:
	_rows = rows.duplicate(true)
	custom_minimum_size = Vector2(0, maxf(96.0, 30.0 * float(_rows.size()) + 28.0))
	queue_redraw()


func _draw() -> void:
	var background: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(background, Color(0.05, 0.06, 0.07, 0.86), true)
	draw_rect(background, Color(0.32, 0.36, 0.42, 0.9), false, 1.0)

	var font: Font = get_theme_default_font()
	var font_size: int = 11
	if _rows.is_empty():
		draw_string(font, Vector2(10, 24), "No upgrade comparison yet.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.78, 0.82, 0.88))
		return

	draw_string(font, Vector2(10, 18), "Before", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.52, 0.68, 1.0))
	draw_string(font, Vector2(size.x - 64.0, 18), "After", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.40, 0.92, 0.66))

	var label_width: float = minf(132.0, maxf(92.0, size.x * 0.32))
	var bar_start: float = label_width + 10.0
	var bar_width: float = maxf(size.x - bar_start - 56.0, 24.0)
	var row_height: float = 28.0
	var y: float = 28.0
	for row: Dictionary in _rows:
		var label: String = String(row.get("label", "stat"))
		var before_value: float = float(row.get("before", 0.0))
		var after_value: float = float(row.get("after", 0.0))
		var max_value: float = maxf(maxf(absf(before_value), absf(after_value)), 1.0)
		var before_width: float = clampf(absf(before_value) / max_value, 0.0, 1.0) * bar_width
		var after_width: float = clampf(absf(after_value) / max_value, 0.0, 1.0) * bar_width
		var delta: float = after_value - before_value
		var delta_color: Color = Color(0.44, 0.92, 0.62, 1.0) if delta >= 0.0 else Color(1.0, 0.45, 0.42, 1.0)

		draw_string(font, Vector2(10.0, y + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, label_width - 14.0, font_size, Color(0.9, 0.92, 0.96))
		draw_rect(Rect2(Vector2(bar_start, y + 3.0), Vector2(bar_width, 8.0)), Color(0.18, 0.20, 0.24, 1.0), true)
		draw_rect(Rect2(Vector2(bar_start, y + 3.0), Vector2(before_width, 8.0)), Color(0.35, 0.50, 0.9, 1.0), true)
		draw_rect(Rect2(Vector2(bar_start, y + 15.0), Vector2(bar_width, 8.0)), Color(0.18, 0.20, 0.24, 1.0), true)
		draw_rect(Rect2(Vector2(bar_start, y + 15.0), Vector2(after_width, 8.0)), delta_color, true)
		draw_string(font, Vector2(bar_start + bar_width + 8.0, y + 16.0), _format_delta(delta), HORIZONTAL_ALIGNMENT_LEFT, 48.0, font_size, delta_color)
		y += row_height


func _format_delta(delta: float) -> String:
	if absf(delta) < 0.001:
		return "+0"
	return "%+.2f" % delta
