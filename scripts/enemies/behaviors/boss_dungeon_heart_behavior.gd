## 文件用途：驱动地牢之心 Boss 的待机与技能动作行为。
## 使用方式：由 EnemyBehaviorRegistry 创建并 setup；EnemyBehaviorController 每次 tick 驱动。

extends EnemyBehavior
class_name BossDungeonHeartBehavior


## 作用：更新 Boss 技能冷却，追逐或停下并执行血量阶段技能。
## 使用：先 setup 绑定 enemy；由控制器每物理帧调用，delta 为秒。
func tick(delta: float) -> void:
	_cancel_ranged_attack_warning()
	_call_enemy(&"_update_boss_skill_cooldowns", [delta])
	if not _is_target_in_behavior_attack_range():
		_apply_chase_movement()
		return

	_set_velocity(Vector2.ZERO)
	_call_enemy(&"_process_boss_phase_skills")
