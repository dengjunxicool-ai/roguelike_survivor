## 文件用途：实现追逐接近玩家后引信倒计时与自爆行为。
## 使用方式：从行为 registry 创建并绑定敌人；tick 检查距离与引信状态。

extends EnemyBehavior
class_name ExplodeNearPlayerBehavior


## 作用：追逐目标，进入距离阈值后推进引信并自爆。
## 使用：先 setup 绑定 enemy；由控制器每物理帧调用，delta 为秒。
func tick(delta: float) -> void:
	var body: CharacterBody2D = _body()
	var target: Node2D = _target()
	if body == null or bool(enemy.get("_is_dead")):
		return

	if is_instance_valid(target) and _is_target_in_attack_range(body.global_position.distance_to(target.global_position)):
		_set_property(&"_is_fusing", true)

	if bool(enemy.get("_is_fusing")):
		_set_velocity(Vector2.ZERO)
		var fuse_timer: float = _float_property(&"_fuse_timer") + delta
		_set_property(&"_fuse_timer", fuse_timer)
		_call_enemy(&"_update_fuse_visual")
		if fuse_timer >= maxf(float(config.get("fuse_time", 0.8)), 0.05):
			_execute_required_action("self_explode")
		return

	if is_instance_valid(target):
		_apply_melee_chase_movement()
