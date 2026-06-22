extends RefCounted
class_name ModalFlowController

const ModalRequestScript: Script = preload("res://scripts/ui/modals/modal_request.gd")

const STATE_LEVEL_UP_MODAL: String = "LEVEL_UP_MODAL"
const STATE_RUN_REWARD_MODAL: String = "RUN_REWARD_MODAL"
const STATE_CURSE_CHOICE_MODAL: String = "CURSE_CHOICE_MODAL"
const STATE_BRANCH_CHOICE_MODAL: String = "BRANCH_CHOICE_MODAL"
const STATE_RUNNING: String = "RUNNING"

var _modal_queue: Array[Dictionary] = []


func refresh_modal_for_state(choice_modal: RefCounted, state: String) -> bool:
	if choice_modal == null:
		return is_modal_state(state)
	match state:
		STATE_LEVEL_UP_MODAL:
			choice_modal.call("refresh_level_up_modal")
			return true
		STATE_RUN_REWARD_MODAL:
			choice_modal.call("refresh_reward_modal")
			return true
		STATE_CURSE_CHOICE_MODAL:
			choice_modal.call("refresh_curse_choice_modal")
			return true
		STATE_BRANCH_CHOICE_MODAL:
			return true
		_:
			return false


func get_pending_state(choice_modal: RefCounted) -> String:
	if not _modal_queue.is_empty():
		var request: Dictionary = _modal_queue[0]
		return String(request.get("target_state", ""))
	if choice_modal == null:
		return ""
	if bool(choice_modal.call("has_pending_reward")):
		return STATE_RUN_REWARD_MODAL
	if bool(choice_modal.call("has_pending_level_up")):
		return STATE_LEVEL_UP_MODAL
	return ""


func is_modal_state(state: String) -> bool:
	return [
		STATE_LEVEL_UP_MODAL,
		STATE_RUN_REWARD_MODAL,
		STATE_CURSE_CHOICE_MODAL,
		STATE_BRANCH_CHOICE_MODAL
	].has(state)


func request_modal(modal_type: String, target_state: String, payload: Dictionary = {}, priority: int = 0, hide_hud: bool = false) -> Dictionary:
	var request: Dictionary = ModalRequestScript.create(modal_type, target_state, payload, priority, hide_hud)
	_modal_queue.append(request)
	_modal_queue.sort_custom(Callable(self, "_sort_modal_requests"))
	return request


func complete_current_modal() -> void:
	if not _modal_queue.is_empty():
		_modal_queue.remove_at(0)


func has_pending_request() -> bool:
	return not _modal_queue.is_empty()


func _sort_modal_requests(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("priority", 0)) > int(right.get("priority", 0))
