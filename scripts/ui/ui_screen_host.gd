## 文件用途：按状态控制主页面、运行 HUD 及子页面的可见层级。
## 使用方式：setup 注入页面与状态 registry，切换时 apply_visible_hierarchy。

extends RefCounted
class_name UIScreenHost


const STATE_RUNNING: String = "RUNNING"


var _screen_registry: RefCounted
var _state_registry: RefCounted


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(screen_registry: RefCounted, state_registry: RefCounted) -> void:
	_screen_registry = screen_registry
	_state_registry = state_registry


## 作用：先隐藏全部页面，再显示当前状态及需要保留的运行 HUD。
## 使用：state 为目标状态；运行子状态保留 HUD，全屏选择子状态隐藏 HUD。
func apply_visible_hierarchy(state: String) -> void:
	if _screen_registry == null:
		return
	for state_variant: Variant in _screen_registry.call("get_states"):
		_set_screen_visible(String(state_variant), false)

	if _is_running_child_state(state):
		_set_screen_visible(STATE_RUNNING, not _is_fullscreen_choice_state(state))
		_set_screen_visible(state, true)
		return

	_set_screen_visible(state, true)


## 作用：显式修改指定状态页面的可见性。
## 使用：公开入口，内部调用 _set_screen_visible，再委托页面注册表更新；state 为状态 ID，should_show 为显示开关。
func set_screen_visible(state: String, should_show: bool) -> void:
	_set_screen_visible(state, should_show)


## 作用：设置页面可见性；具体处理委托给 _screen_registry.set_screen_visible。
## 使用：本文件由 apply_visible_hierarchy、set_screen_visible 调用；输入 state（状态）、should_show（是否需要显示）。
func _set_screen_visible(state: String, should_show: bool) -> void:
	if _screen_registry != null:
		_screen_registry.call("set_screen_visible", state, should_show)


## 作用：判断运行子节点状态，返回布尔判断结果；具体处理委托给 _state_registry.is_running_child_state。
## 使用：本文件由 apply_visible_hierarchy 调用；输入 state（状态）。
func _is_running_child_state(state: String) -> bool:
	return _state_registry != null and bool(_state_registry.call("is_running_child_state", state))


## 作用：判断全屏选择状态，返回布尔判断结果；具体处理委托给 _state_registry.is_fullscreen_choice_state。
## 使用：本文件由 apply_visible_hierarchy 调用；输入 state（状态）。
func _is_fullscreen_choice_state(state: String) -> bool:
	return _state_registry != null and bool(_state_registry.call("is_fullscreen_choice_state", state))
