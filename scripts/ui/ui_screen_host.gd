extends RefCounted
class_name UIScreenHost


const STATE_RUNNING: String = "RUNNING"


var _screen_registry: RefCounted
var _state_registry: RefCounted


func setup(screen_registry: RefCounted, state_registry: RefCounted) -> void:
	_screen_registry = screen_registry
	_state_registry = state_registry


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


func set_screen_visible(state: String, should_show: bool) -> void:
	_set_screen_visible(state, should_show)


func _set_screen_visible(state: String, should_show: bool) -> void:
	if _screen_registry != null:
		_screen_registry.call("set_screen_visible", state, should_show)


func _is_running_child_state(state: String) -> bool:
	return _state_registry != null and bool(_state_registry.call("is_running_child_state", state))


func _is_fullscreen_choice_state(state: String) -> bool:
	return _state_registry != null and bool(_state_registry.call("is_fullscreen_choice_state", state))
