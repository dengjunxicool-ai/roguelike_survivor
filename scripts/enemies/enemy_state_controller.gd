## 文件用途：管理敌人的运行状态、受击反馈与开发期强制状态。
## 使用方式：setup 绑定 enemy；update 推进计时，行为/受击入口切换状态。

extends RefCounted
class_name EnemyStateController


const STATE_IDLE: String = "idle"
const STATE_CHASE: String = "chase"
const STATE_ATTACK: String = "attack"
const STATE_HURT: String = "hurt"
const STATE_WARNING: String = "warning"
const STATE_CONTROLLED: String = "controlled"
const STATE_DEAD: String = "dead"

var _owner: CharacterBody2D
var _transient_states: Dictionary = {}
var _forced_state: String = ""


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: CharacterBody2D) -> void:
	_owner = owner
	_transient_states.clear()
	_forced_state = ""


## 作用：更新。
## 使用：供本模块调用者使用；输入 delta（delta）。
func update(delta: float) -> void:
	for state: String in _transient_states.keys():
		var remaining: float = maxf(float(_transient_states[state]) - delta, 0.0)
		if remaining <= 0.0:
			_transient_states.erase(state)
		else:
			_transient_states[state] = remaining


## 作用：标记。
## 使用：供本模块调用者使用；输入 state（状态）、duration（持续时间）。
func mark(state: String, duration: float) -> void:
	if duration <= 0.0:
		return
	_transient_states[state] = maxf(float(_transient_states.get(state, 0.0)), duration)


## 作用：设置强制状态。
## 使用：供本模块调用者使用；输入 state（状态）。
func set_forced_state(state: String) -> void:
	if _is_forcible_state(state):
		_forced_state = state


## 作用：清除强制状态。
## 使用：供本模块调用者使用。
func clear_forced_state() -> void:
	_forced_state = ""


## 作用：是否包含状态，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 state（状态）。
func has_state(state: String) -> bool:
	return _get_state() == state or _transient_states.has(state)


## 作用：获取快照，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回字典包含 state/is_dead/is_hurt/is_attacking/is_warning/is_controlled/is_moving/move_direction。
func get_snapshot() -> Dictionary:
	var state: String = _get_state()
	var moving: bool = _owner != null and _owner.velocity.length_squared() > 1.0
	return {
		"state": state,
		"is_dead": state == STATE_DEAD,
		"is_hurt": state == STATE_HURT,
		"is_attacking": state == STATE_ATTACK,
		"is_warning": state == STATE_WARNING,
		"is_controlled": state == STATE_CONTROLLED,
		"is_moving": moving,
		"move_direction": _owner.velocity.normalized() if moving else Vector2.ZERO
	}


## 作用：获取状态，供当前模块后续逻辑使用。
## 使用：本文件由 has_state、get_snapshot 调用；返回 String 文本/标识。
func _get_state() -> String:
	if _owner == null:
		return STATE_IDLE
	if bool(_owner.get("_is_dead")):
		return STATE_DEAD
	if _forced_state != "":
		return _forced_state
	if _transient_states.has(STATE_HURT):
		return STATE_HURT
	if _transient_states.has(STATE_ATTACK) or float(_owner.get("_dash_timer")) > 0.0:
		return STATE_ATTACK
	if float(_owner.get("_ranged_warning_timer")) > 0.0 or float(_owner.get("_dash_warning_timer")) > 0.0:
		return STATE_WARNING
	if _owner.has_method("_is_movement_frozen") and bool(_owner.call("_is_movement_frozen")):
		return STATE_CONTROLLED
	if _owner.velocity.length_squared() > 1.0:
		return STATE_CHASE
	return STATE_IDLE


## 作用：判断强制状态，返回布尔判断结果。
## 使用：本文件由 set_forced_state 调用；输入 state（状态）。
func _is_forcible_state(state: String) -> bool:
	return state == STATE_IDLE or state == STATE_CHASE or state == STATE_ATTACK or state == STATE_HURT or state == STATE_DEAD
