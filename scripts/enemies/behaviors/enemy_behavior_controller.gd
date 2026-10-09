## 文件用途：持有并驱动敌人的具体行为策略。
## 使用方式：setup 根据配置向 registry 创建策略；每次 tick 转发给当前行为。

extends RefCounted
class_name EnemyBehaviorController


const EnemyBehaviorRegistryScript: Script = preload("res://scripts/enemies/behaviors/enemy_behavior_registry.gd")

var _enemy: Node
var _behavior_config: Dictionary = {}
var _behavior: EnemyBehavior
var _registry: EnemyBehaviorRegistry = EnemyBehaviorRegistryScript.new()


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
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


## 作用：推进当前敌方行为或技能的周期更新。
## 使用：先 setup 绑定 enemy；由控制器每物理帧调用，delta 为秒。
func tick(delta: float) -> void:
	if _behavior != null:
		_behavior.tick(delta)


## 作用：获取调试状态，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回结果字典。
func get_debug_state() -> Dictionary:
	if _behavior == null:
		return {"type": String(_behavior_config.get("type", ""))}
	return _behavior.get_debug_state()
