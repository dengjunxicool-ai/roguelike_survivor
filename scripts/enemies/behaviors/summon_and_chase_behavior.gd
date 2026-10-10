## 文件用途：实现行为射程外追逐、射程内停下召唤并处理近身攻击。
## 使用方式：registry 创建后 setup；tick 检查召唤时机并重置冷却，冷却递减由 EnemyBase 执行。

extends EnemyBehavior
class_name SummonAndChaseBehavior
const Telegraph = preload("res://scripts/enemies/combat/enemy_attack_telegraph.gd")
var _warning_elapsed := -1.0
var _warning: Node2D


## 作用：范围外追逐，范围内停下；召唤冷却到期请求召唤并重置冷却，近身时可攻击。
## 使用：_delta 未用于递减冷却，冷却由 EnemyBase._update_enemy_action_cooldowns 推进；先 setup 绑定敌人。
func tick(delta: float) -> void:
	if enemy == null or enemy.get("_is_dead") == true:
		cancel_pending_attack()
		return
	_cancel_ranged_attack_warning()
	if not _is_target_in_behavior_attack_range():
		cancel_pending_attack()
		_apply_chase_movement()
		return

	var body: CharacterBody2D = _body()
	_set_velocity(Vector2.ZERO)
	if _warning_elapsed >= 0.0:
		_warning_elapsed += delta
		var warning_time: float = float(config.get("summon_warning_time", 0.8))
		_warning.call("set_progress", _warning_elapsed / warning_time)
		if _warning_elapsed + 0.000001 < warning_time:
			return
		var center: Vector2 = body.global_position if body != null else Vector2.ZERO
		var executed: bool = bool(_call_enemy(&"_execute_enemy_skill_action", ["summon", {
			"enemy_id": String(config.get("summon_enemy_id", "small_slime")),
			"count": int(config.get("summon_count", 1)),
			"center": center,
			"radius": float(config.get("summon_radius", 72.0))
		}]))
		cancel_pending_attack()
		if executed:
			_set_property(&"_summon_cooldown", float(_call_enemy(&"_get_enemy_skill_cooldown", ["summon", float(config.get("summon_cooldown", 5.0))])))
	elif _float_property(&"_summon_cooldown") <= 0.0 and int(_call_enemy(&"_get_owned_summon_count")) < int(config.get("summon_limit", 4)):
		_warning_elapsed = 0.0
		_warning = Telegraph.new()
		body.add_child(_warning)
		_warning.call("configure", &"circle", {"radius": float(config.get("summon_radius", 72.0)), "color": Color(0.75, 0.5, 1.0, 0.9)})

	if _is_target_in_attack_range():
		_apply_range_attack_damage()

func cancel_pending_attack() -> void:
	_warning_elapsed = -1.0
	if is_instance_valid(_warning):
		_warning.queue_free()
	_warning = null
