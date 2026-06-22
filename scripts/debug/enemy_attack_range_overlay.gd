extends Node2D
class_name EnemyAttackRangeOverlay


const RING_SEGMENTS: int = 96

@export var range_color: Color = Color(1.0, 0.28, 0.18, 0.72)

var _enemy: Node2D


func setup(enemy: Node2D) -> void:
	_enemy = enemy
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1000


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var attack_range: float = _get_attack_range()
	if attack_range <= 0.0:
		return

	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, RING_SEGMENTS, range_color, 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(attack_range + 8.0, -4.0), "%s atk %.0f" % [_get_enemy_label(), attack_range], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, range_color)


func _get_attack_range() -> float:
	if _enemy == null or not is_instance_valid(_enemy):
		return 0.0
	var value: Variant = _enemy.get("attack_range")
	return 0.0 if value == null else float(value)


func _get_enemy_label() -> String:
	if _enemy == null or not is_instance_valid(_enemy):
		return "enemy"
	return String(_enemy.get("enemy_id"))
