## 文件用途：为二维角色复用或创建32边椭圆地面阴影。
## 使用方式：静态ensure传owner与半径/压扁/偏移/透明度；阴影作为GroundShadow子节点置于角色后方。
extends RefCounted
class_name GroundShadow


const SHADOW_NODE_NAME: String = "GroundShadow"


## 作用：复用同名Polygon2D或创建阴影并配置；同名异类型节点警告并拒绝。
## 使用：owner不能为空，返回阴影节点或null。
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


## 作用：生成椭圆顶点并设置位置、黑色透明度和背后层级。
## 使用：radius至少1，flatten限制0.08至1，alpha限制0至1。
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
