extends RefCounted
class_name UIScreenRegistry


var _screens: Dictionary = {}


func get_screens() -> Dictionary:
	return _screens


func has_screen(state: String) -> bool:
	return _screens.has(state)


func register_screen(state: String, screen: Node) -> void:
	if state == "" or screen == null:
		return
	_screens[state] = screen


func get_screen(state: String) -> Node:
	return _screens.get(state, null) as Node


func get_states() -> Array:
	return _screens.keys()


func set_screen_visible(state: String, should_show: bool) -> void:
	var screen: Node = get_screen(state)
	if screen != null:
		screen.set("visible", should_show)
