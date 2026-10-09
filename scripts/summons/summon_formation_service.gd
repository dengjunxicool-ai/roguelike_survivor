## 文件用途：计算召唤初始出生位置的简单环形编队偏移。
## 使用方式：SummonManager创建时按活跃序号调用get_offset；运行跟随编队由移动组件负责。
extends RefCounted
class_name SummonFormationService


## 作用：以跟随距离和分离半径较大值为圆半径，为序号返回出生偏移。
## 使用：index<=0位于右侧，其余按六等分角度排列，返回Vector2。
static func get_offset(index: int, separation_radius: float, follow_distance: float) -> Vector2:
	var radius: float = maxf(follow_distance, separation_radius)
	if index <= 0:
		return Vector2.RIGHT * radius
	var angle: float = -PI * 0.5 + float(index) * TAU / 6.0
	return Vector2(cos(angle), sin(angle)) * radius
