## 文件用途：依据注册表管理当前 UI 状态与允许的转移。
## 使用方式：先 setup(initial_state,registry)，再 transition_to；开发入口可显式 force_transition_to。

extends RefCounted
class_name UIStateMachine


var current_state: String = ""
var _registry: RefCounted


## 作用：设置初始状态并绑定用于转移校验的注册表。
## 使用：initial_state 为状态 ID；setup 本身不刷新页面或应用暂停。
func setup(initial_state: String, registry: RefCounted) -> void:
	current_state = initial_state
	_registry = registry


## 作用：查询注册表是否允许从当前状态进入目标状态。
## 使用：to_state 为目标 ID；缺注册表或缺方法时按当前实现返回 true。
func can_transition(to_state: String) -> bool:
	if _registry == null or not _registry.has_method("can_transition"):
		return true
	return bool(_registry.call("can_transition", current_state, to_state))


## 作用：检查允许转移后更新 current_state。
## 使用：返回是否成功；只更新状态数据，页面准备/显隐/暂停由 UIManager 接续执行。
func transition_to(to_state: String) -> bool:
	if not can_transition(to_state):
		return false
	current_state = to_state
	return true


## 作用：跳过注册表检查直接改写 current_state。
## 使用：仅用于明确允许直达状态的开发流程；不刷新控件或更改暂停。
func force_transition_to(to_state: String) -> void:
	current_state = to_state


## 作用：获取当前状态，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 String 文本/标识。
func get_current_state() -> String:
	return current_state
