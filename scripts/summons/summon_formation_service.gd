extends RefCounted
class_name SummonFormationService


static func get_offset(index: int, separation_radius: float, follow_distance: float) -> Vector2:
	var radius: float = maxf(follow_distance, separation_radius)
	if index <= 0:
		return Vector2.RIGHT * radius
	var angle: float = -PI * 0.5 + float(index) * TAU / 6.0
	return Vector2(cos(angle), sin(angle)) * radius
