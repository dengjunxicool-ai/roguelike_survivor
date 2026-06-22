extends RefCounted
class_name UIPausePolicy


func apply(tree: SceneTree, state_registry: RefCounted, state: String) -> void:
	if tree == null:
		return
	if state_registry == null or not state_registry.has_method("should_pause_for_state"):
		tree.paused = true
		return
	tree.paused = bool(state_registry.call("should_pause_for_state", state))
