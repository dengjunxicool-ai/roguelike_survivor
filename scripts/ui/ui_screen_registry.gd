## 文件用途：保存状态到实际页面节点的映射。
## 使用方式：创建页面后 register_screen，编排用 get_screen/has_screen 查询。

extends RefCounted
class_name UIScreenRegistry


var _screens: Dictionary = {}


## 作用：返回状态到页面节点的内部映射。
## 使用：返回原字典引用；调用者写入会改变注册表，页面创建器使用这一共享映射。
func get_screens() -> Dictionary:
	return _screens


## 作用：是否包含页面，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 state（状态）。
func has_screen(state: String) -> bool:
	return _screens.has(state)


## 作用：将非空状态 ID 关联到有效页面节点。
## 使用：state/screen 来自页面构建；同状态重复登记覆盖已有引用。
func register_screen(state: String, screen: Node) -> void:
	if state == "" or screen == null:
		return
	_screens[state] = screen


## 作用：获取页面，供当前模块后续逻辑使用。
## 使用：本文件由 set_screen_visible 调用；输入 state（状态）；返回 Node 对象/值。
func get_screen(state: String) -> Node:
	return _screens.get(state, null) as Node


## 作用：返回当前登记的状态键列表。
## 使用：keys() 生成新的数组；更改数组不会改变页面映射。
func get_states() -> Array:
	return _screens.keys()


## 作用：设置页面可见性。
## 使用：供本模块调用者使用；输入 state（状态）、should_show（是否需要显示）。
func set_screen_visible(state: String, should_show: bool) -> void:
	var screen: Node = get_screen(state)
	if screen != null:
		screen.set("visible", should_show)
