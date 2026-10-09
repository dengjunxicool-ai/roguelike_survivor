## 文件用途：实现近战敌人追逐玩家的移动策略。
## 使用方式：行为 registry 根据配置创建；tick 使用基类的近战追逐和邻居避让入口。

extends EnemyBehavior
class_name ChasePlayerBehavior


## 作用：使用近战追逐策略更新速度。
## 使用：先 setup 绑定 enemy；由控制器每物理帧调用，delta 为秒。
func tick(_delta: float) -> void:
	_cancel_ranged_attack_warning()
	if _is_target_in_attack_range():
		_set_velocity(Vector2.ZERO)
		_apply_range_attack_damage()
	else:
		_apply_melee_chase_movement()
