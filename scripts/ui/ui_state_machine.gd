extends RefCounted
class_name UIStateMachine


var current_state: String = ""
var _registry: RefCounted


func setup(initial_state: String, registry: RefCounted) -> void:
	current_state = initial_state
	_registry = registry


func can_transition(to_state: String) -> bool:
	if _registry == null or not _registry.has_method("can_transition"):
		return true
	return bool(_registry.call("can_transition", current_state, to_state))


func transition_to(to_state: String) -> bool:
	if not can_transition(to_state):
		return false
	current_state = to_state
	return true


func force_transition_to(to_state: String) -> void:
	current_state = to_state


func get_current_state() -> String:
	return current_state
