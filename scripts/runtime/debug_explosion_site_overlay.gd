extends Node2D
class_name DebugExplosionSiteOverlay


const RING_SEGMENTS: int = 96

@export var radius: float = 1.0
@export var label_text: String = ""
@export var ring_color: Color = Color(1.0, 0.46, 0.08, 0.82)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1200
	add_to_group(&"debug_explosion_site_overlays")
	queue_redraw()


func setup(new_radius: float, new_label_text: String = "") -> void:
	radius = maxf(new_radius, 1.0)
	label_text = new_label_text
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, RING_SEGMENTS, ring_color, 2.5, true)
	if label_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(radius + 8.0, 4.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, ring_color)
