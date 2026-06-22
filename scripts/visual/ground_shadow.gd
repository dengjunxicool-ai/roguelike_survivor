extends RefCounted
class_name GroundShadow


const SHADOW_NODE_NAME: String = "GroundShadow"


static func ensure(owner: Node2D, radius: float = 22.0, flatten: float = 0.36, offset: Vector2 = Vector2(0.0, 16.0), alpha: float = 0.42) -> Polygon2D:
	if owner == null:
		return null

	var existing_node: Node = owner.get_node_or_null(SHADOW_NODE_NAME)
	if existing_node != null:
		var existing: Polygon2D = existing_node as Polygon2D
		if existing == null:
			push_warning("GroundShadow helper found a non-Polygon2D child named GroundShadow on %s." % owner.name)
			return null
		_configure(existing, radius, flatten, offset, alpha)
		return existing

	var shadow: Polygon2D = Polygon2D.new()
	shadow.name = SHADOW_NODE_NAME
	owner.add_child(shadow)
	owner.move_child(shadow, 0)
	_configure(shadow, radius, flatten, offset, alpha)
	return shadow


static func _configure(shadow: Polygon2D, radius: float, flatten: float, offset: Vector2, alpha: float) -> void:
	var safe_radius: float = maxf(radius, 1.0)
	var safe_flatten: float = clampf(flatten, 0.08, 1.0)
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(32):
		var angle: float = TAU * float(index) / 32.0
		points.append(Vector2(cos(angle) * safe_radius, sin(angle) * safe_radius * safe_flatten))
	shadow.polygon = points
	shadow.position = offset
	shadow.color = Color(0.0, 0.0, 0.0, clampf(alpha, 0.0, 1.0))
	shadow.z_index = -4
	shadow.show_behind_parent = true
