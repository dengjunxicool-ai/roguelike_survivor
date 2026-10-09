## 文件用途：登记行为类型到脚本的映射并构建策略实例。
## 使用方式：create 接收 behavior_type 字符串；新行为登记到映射，未知类型报错并返回 null。

extends RefCounted
class_name EnemyBehaviorRegistry


const ChasePlayerBehaviorScript: Script = preload("res://scripts/enemies/behaviors/chase_player_behavior.gd")
const KeepDistanceShootBehaviorScript: Script = preload("res://scripts/enemies/behaviors/keep_distance_shoot_behavior.gd")
const ExplodeNearPlayerBehaviorScript: Script = preload("res://scripts/enemies/behaviors/explode_near_player_behavior.gd")
const SummonAndChaseBehaviorScript: Script = preload("res://scripts/enemies/behaviors/summon_and_chase_behavior.gd")
const ChaseAndCastPoolBehaviorScript: Script = preload("res://scripts/enemies/behaviors/chase_and_cast_pool_behavior.gd")
const DashAttackBehaviorScript: Script = preload("res://scripts/enemies/behaviors/dash_attack_behavior.gd")
const BossDungeonHeartBehaviorScript: Script = preload("res://scripts/enemies/behaviors/boss_dungeon_heart_behavior.gd")

var _types: Dictionary = {
	"chase_player": ChasePlayerBehaviorScript,
	"keep_distance_and_shoot": KeepDistanceShootBehaviorScript,
	"explode_near_player": ExplodeNearPlayerBehaviorScript,
	"summon_and_chase": SummonAndChaseBehaviorScript,
	"chase_and_cast_pool": ChaseAndCastPoolBehaviorScript,
	"dash_attack": DashAttackBehaviorScript,
	"boss_dungeon_heart": BossDungeonHeartBehaviorScript
}


## 作用：按 behavior_type 从已登记映射创建行为实例。
## 使用：参数为类型字符串而非配置字典；未知类型报错并返回 null，成功后由 controller.setup 绑定 enemy。
func create(behavior_type: String) -> EnemyBehavior:
	if not _types.has(behavior_type):
		push_error("[EnemyBehaviorRegistry] Unknown behavior '%s'." % behavior_type)
		return null
	var script: Script = _types[behavior_type] as Script
	return script.new() as EnemyBehavior


## 作用：是否包含行为，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 behavior_type（行为类型）。
func has_behavior(behavior_type: String) -> bool:
	return _types.has(behavior_type)


## 作用：获取已登记类型，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 Array 列表。
func get_registered_types() -> Array:
	return _types.keys()
