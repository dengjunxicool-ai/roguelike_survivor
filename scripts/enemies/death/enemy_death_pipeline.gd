extends RefCounted
class_name EnemyDeathPipeline


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


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _merge_policy(target: Dictionary, override: Dictionary) -> void:
	for key: Variant in override.keys():
		target[String(key)] = override[key]


func _uses_full_death_animation(enemy: Node) -> bool:
	return String(enemy.get_meta("enemy_rank", enemy.get_meta("enemy_type", "normal"))) != "normal"


func _finish_node(enemy: Node, play_death_visual: bool) -> void:
	if play_death_visual and not _uses_full_death_animation(enemy) and enemy is CanvasItem:
		var tween: Tween = enemy.create_tween()
		tween.tween_property(enemy, "modulate:a", 0.0, 0.16)
		tween.tween_callback(Callable(enemy, "queue_free"))
		return
	enemy.queue_free()
