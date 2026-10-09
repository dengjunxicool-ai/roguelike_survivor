## 文件用途：在通用敌人初始化基础上接入 Boss 节点。
## 使用方式：挂载 Boss 场景，复用 EnemyBase 的配置和战斗流程。

extends EnemyBase
class_name BossController


@export_range(1.0, 10.0, 0.1, "or_greater") var boss_health_multiplier: float = 1.0


## 作用：指定 dungeon_heart 配置并执行 EnemyBase 初始化，再应用 Boss 额外血量倍率。
## 使用：由 Godot 入树时调用；倍率不为 1 时同步最大和当前血量并发出 health_changed。
func _ready() -> void:
	enemy_id = &"dungeon_heart"
	super._ready()
	if boss_health_multiplier != 1.0:
		max_health = roundi(float(max_health) * boss_health_multiplier)
		current_health = max_health
		health_changed.emit(current_health, max_health)
