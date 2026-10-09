## 文件用途：规范化敌人生成时的生命、伤害、速度和经验倍率及护甲加值。
## 使用方式：静态 normalize 接收字典，生成服务用结果设置敌人初始属性；defense_add 为整数加值。

extends RefCounted
class_name EnemySpawnMultipliers


## 作用：把任意生成倍率配置规范化为完整倍率和护甲加值字典。
## 使用：生命/伤害/速度至少 0.01，经验至少 0；move_speed 优先于 speed 别名，defense_add 转为整数，缺项使用默认值；返回字典包含 hp/damage/move_speed/exp/defense_add。
static func normalize(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	return {
		"hp": maxf(float(source.get("hp", 1.0)), 0.01),
		"damage": maxf(float(source.get("damage", 1.0)), 0.01),
		"move_speed": maxf(float(source.get("move_speed", source.get("speed", 1.0))), 0.01),
		"exp": maxf(float(source.get("exp", 1.0)), 0.0),
		"defense_add": int(source.get("defense_add", 0))
	}
