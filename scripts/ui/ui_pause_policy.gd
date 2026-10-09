## 文件用途：根据 UI 状态注册表统一应用场景树暂停规则。
## 使用方式：状态切换完成后调用 apply(tree,registry,state)。

extends RefCounted
class_name UIPausePolicy


## 作用：根据状态注册表查询结果设置 SceneTree.paused。
## 使用：tree/state_registry/state 为运行依赖；树为空则跳过，缺少有效暂停策略时默认暂停。
func apply(tree: SceneTree, state_registry: RefCounted, state: String) -> void:
	if tree == null:
		return
	if state_registry == null or not state_registry.has_method("should_pause_for_state"):
		tree.paused = true
		return
	tree.paused = bool(state_registry.call("should_pause_for_state", state))
