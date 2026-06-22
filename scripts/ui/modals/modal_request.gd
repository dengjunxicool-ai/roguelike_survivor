extends RefCounted
class_name ModalRequest


var modal_type: String = ""
var target_state: String = ""
var payload: Dictionary = {}
var priority: int = 0
var hide_hud: bool = false


static func create(request_type: String, state: String, request_payload: Dictionary = {}, request_priority: int = 0, request_hide_hud: bool = false) -> Dictionary:
	return {
		"modal_type": request_type,
		"target_state": state,
		"payload": request_payload.duplicate(true),
		"priority": request_priority,
		"hide_hud": request_hide_hud
	}


func to_dictionary() -> Dictionary:
	return {
		"modal_type": modal_type,
		"target_state": target_state,
		"payload": payload.duplicate(true),
		"priority": priority,
		"hide_hud": hide_hud
	}
