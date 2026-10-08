extends SceneTree


const EnemyDeathPipelineScript: Script = preload("res://scripts/enemies/death/enemy_death_pipeline.gd")

var _failed: bool = false


class DeathTestEnemy:
	extends Node2D

	signal died

	var _is_dead: bool = false
	var _reward_controller: RefCounted = null
	var calls: Array[String] = []
	var dead_state_violations: int = 0

	func _init() -> void:
		died.connect(_on_died)

	func _award_soul_stones() -> void:
		_record_call("award_soul")

	func _notify_enemy_killed_synergies() -> void:
		_record_call("notify_kill")

	func _apply_death_effect() -> void:
		_record_call("death_effect")

	func _drop_experience_crystal() -> void:
		_record_call("drop_experience")

	func _on_died() -> void:
		_record_call("died")

	func _record_call(call_name: String) -> void:
		if not _is_dead:
			dead_state_violations += 1
		calls.append(call_name)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_normal_death_is_ordered_and_idempotent()
	_verify_self_explosion_defaults()
	_verify_reward_policy_partial_override()
	print("[verify_enemy_death_reward_pipeline] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


func _verify_normal_death_is_ordered_and_idempotent() -> void:
	var enemy: DeathTestEnemy = _new_enemy()
	var pipeline: RefCounted = EnemyDeathPipelineScript.new()
	pipeline.call("execute", enemy, {"cause": "damage"})
	var expected_calls: Array[String] = ["award_soul", "notify_kill", "died", "death_effect", "drop_experience"]
	_expect(enemy.calls == expected_calls, "normal death preserves side-effect order", enemy.calls)
	_expect(enemy.dead_state_violations == 0, "dead state is set before normal death side effects", enemy.dead_state_violations)
	_expect(enemy._is_dead, "normal death marks the enemy dead")
	pipeline.call("execute", enemy, {"cause": "damage"})
	_expect(enemy.calls == expected_calls, "repeated death does not duplicate side effects", enemy.calls)
	enemy.free()


func _verify_self_explosion_defaults() -> void:
	var enemy: DeathTestEnemy = _new_enemy()
	var pipeline: RefCounted = EnemyDeathPipelineScript.new()
	pipeline.call("execute", enemy, {"cause": "self_explosion"})
	var expected_calls: Array[String] = ["notify_kill", "died"]
	_expect(enemy.calls == expected_calls, "self explosion suppresses reward, effect, and experience by default", enemy.calls)
	_expect(enemy.dead_state_violations == 0, "dead state is set before self-explosion side effects", enemy.dead_state_violations)
	enemy.free()


func _verify_reward_policy_partial_override() -> void:
	var enemy: DeathTestEnemy = _new_enemy()
	enemy.set_meta("reward_policy", {"award_soul": false, "drop_experience": false})
	var pipeline: RefCounted = EnemyDeathPipelineScript.new()
	pipeline.call("execute", enemy, {"cause": "damage"})
	var expected_calls: Array[String] = ["notify_kill", "died", "death_effect"]
	_expect(enemy.calls == expected_calls, "partial reward policy preserves unspecified default behaviors", enemy.calls)
	_expect(enemy.dead_state_violations == 0, "dead state is set before policy-controlled side effects", enemy.dead_state_violations)
	enemy.free()


func _new_enemy() -> DeathTestEnemy:
	var enemy := DeathTestEnemy.new()
	enemy.set_meta("enemy_rank", "normal")
	root.add_child(enemy)
	return enemy


func _expect(condition: bool, label: String, actual: Variant = null) -> void:
	if condition:
		print("[verify_enemy_death_reward_pipeline] PASS %s" % label)
		return
	_failed = true
	push_error("[verify_enemy_death_reward_pipeline] FAIL %s actual=%s" % [label, str(actual)])
