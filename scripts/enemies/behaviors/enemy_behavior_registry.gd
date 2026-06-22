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


func create(behavior_type: String) -> EnemyBehavior:
	if not _types.has(behavior_type):
		push_error("[EnemyBehaviorRegistry] Unknown behavior '%s'." % behavior_type)
		return null
	var script: Script = _types[behavior_type] as Script
	return script.new() as EnemyBehavior


func has_behavior(behavior_type: String) -> bool:
	return _types.has(behavior_type)


func get_registered_types() -> Array:
	return _types.keys()
