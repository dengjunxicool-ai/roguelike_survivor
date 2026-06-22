extends RefCounted
class_name EnemyBehaviorController


const EnemyBehaviorRegistryScript: Script = preload("res://scripts/enemies/behaviors/enemy_behavior_registry.gd")

var _enemy: Node
var _behavior_config: Dictionary = {}
var _behavior: EnemyBehavior
var _registry: EnemyBehaviorRegistry = EnemyBehaviorRegistryScript.new()


func setup(enemy: Node, behavior_config: Dictionary = {}) -> void:
	_enemy = enemy
	_behavior_config = behavior_config.duplicate(true)
	var behavior_type: String = String(_behavior_config.get("type", ""))
	if behavior_type == "":
		push_error("[EnemyBehaviorController] Missing behavior.type.")
		_behavior = null
		return
	_behavior = _registry.create(behavior_type)
	if _behavior != null:
		_behavior.setup(_enemy, _behavior_config)


func tick(delta: float) -> void:
	if _behavior != null:
		_behavior.tick(delta)


func get_debug_state() -> Dictionary:
	if _behavior == null:
		return {"type": String(_behavior_config.get("type", ""))}
	return _behavior.get_debug_state()
