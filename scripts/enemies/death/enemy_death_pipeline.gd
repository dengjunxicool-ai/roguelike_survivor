## 文件用途：按既定顺序执行死亡标记、奖励、事件、特效、经验掉落和节点清理。
## 使用方式：EnemyBase 统一通过 execute 死亡；先置死亡标记保证幂等，自爆默认抑制部分奖励。

extends RefCounted
class_name EnemyDeathPipeline


## 作用：先设置死亡标记，再按策略执行奖励、事件、特效、经验与节点清理。
## 使用：enemy/context 为敌人与死亡上下文；重复死亡直接返回，自爆默认抑制奖励，可用 reward_policy 覆盖。
func execute(enemy: Node, context: Dictionary) -> void:
	if enemy == null or bool(enemy.get("_is_dead")):
		return

	var cause: String = String(context.get("cause", "damage"))
	var policy: Dictionary = _get_dictionary(context.get("policy", {}))
	_merge_policy(policy, _get_dictionary(enemy.get_meta("reward_policy", {})))
	enemy.set("_is_dead", true)

	var play_death_visual: bool = bool(policy.get("play_death_visual", cause != "self_explosion"))
	if play_death_visual and _uses_full_death_animation(enemy):
		var visual_controller: RefCounted = enemy.get("_visual_controller") as RefCounted
		if visual_controller != null:
			visual_controller.call("play_state", "death", true)
	if bool(policy.get("record_boss_core", cause != "self_explosion")):
		var reward_controller: RefCounted = enemy.get("_reward_controller") as RefCounted
		if reward_controller != null:
			reward_controller.call("record_boss_core_destroyed")
	if bool(policy.get("award_soul", cause != "self_explosion")) and enemy.has_method("_award_soul_stones"):
		enemy.call("_award_soul_stones")
	if bool(policy.get("notify_kill_events", true)) and enemy.has_method("_notify_enemy_killed_synergies"):
		enemy.call("_notify_enemy_killed_synergies")
	if bool(policy.get("emit_died_signal", true)) and enemy.has_signal(&"died"):
		enemy.emit_signal(&"died")
	if bool(policy.get("run_death_effect", cause != "self_explosion")) and enemy.has_method("_apply_death_effect"):
		enemy.call("_apply_death_effect")
	if bool(policy.get("drop_experience", cause != "self_explosion")) and enemy.has_method("_drop_experience_crystal"):
		enemy.call("_drop_experience_crystal")
	_finish_node(enemy, play_death_visual)


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 execute 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：把 override 的各项策略写入 target。
## 使用：就地覆盖 target；用于合并敌人元数据中的局部奖励策略。
func _merge_policy(target: Dictionary, override: Dictionary) -> void:
	for key: Variant in override.keys():
		target[String(key)] = override[key]


## 作用：判断非 normal 等阶敌人或 boss_minion 来源敌人是否需要完整死亡表现。
## 使用：由死亡表现与节点清理步骤查询；包含精英、Boss 和 Boss 核心等非普通分类；返回是否满足条件或执行成功。
func _uses_full_death_animation(enemy: Node) -> bool:
	return String(enemy.get_meta("enemy_rank", "normal")) != "normal" or String(enemy.get_meta("spawn_source_type", "")) == "boss_minion"


## 作用：普通敌人可先淡出再释放，其余分支直接请求释放。
## 使用：execute 最后调用；play_death_visual 控制是否走视觉结束流程。
func _finish_node(enemy: Node, play_death_visual: bool) -> void:
	if play_death_visual and not _uses_full_death_animation(enemy) and enemy is CanvasItem:
		var tween: Tween = enemy.create_tween()
		tween.tween_property(enemy, "modulate:a", 0.0, 0.16)
		tween.tween_callback(Callable(enemy, "queue_free"))
		return
	enemy.queue_free()
