## 文件用途：统一排队与选择局内升级、奖励和诅咒弹窗。
## 使用方式：请求按优先级排序；get_pending_state 解析下个状态，完成后移除队首。

extends RefCounted
class_name ModalFlowController

const ModalRequestScript: Script = preload("res://scripts/ui/modals/modal_request.gd")

const STATE_LEVEL_UP_MODAL: String = "LEVEL_UP_MODAL"
const STATE_RUN_REWARD_MODAL: String = "RUN_REWARD_MODAL"
const STATE_CURSE_CHOICE_MODAL: String = "CURSE_CHOICE_MODAL"
const STATE_RUNNING: String = "RUNNING"

var _modal_queue: Array[Dictionary] = []


## 作用：刷新弹窗对应状态。
## 使用：供本模块调用者使用；输入 choice_modal（选择弹窗）、state（状态）；返回是否满足条件或执行成功。
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
		_:
			return false


## 作用：优先读取显式弹窗队列，否则按奖励、升级顺序查询待办。
## 使用：choice_modal 可为空；返回下个 STATE_* 字符串，无待办返回空字符串。
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


## 作用：判断弹窗状态，返回布尔判断结果。
## 使用：本文件由 refresh_modal_for_state 调用；输入 state（状态）。
func is_modal_state(state: String) -> bool:
	return [
		STATE_LEVEL_UP_MODAL,
		STATE_RUN_REWARD_MODAL,
		STATE_CURSE_CHOICE_MODAL
	].has(state)


## 作用：创建请求、加入队列并按 priority 降序排序。
## 使用：返回请求字典；hide_hud 与 payload 随请求保留，实际页面切换由编排负责。
func request_modal(modal_type: String, target_state: String, payload: Dictionary = {}, priority: int = 0, hide_hud: bool = false) -> Dictionary:
	var request: Dictionary = ModalRequestScript.create(modal_type, target_state, payload, priority, hide_hud)
	_modal_queue.append(request)
	_modal_queue.sort_custom(Callable(self, "_sort_modal_requests"))
	return request


## 作用：移除已完成的队首显式弹窗请求。
## 使用：选择处理结束后调用；空队列时无操作。
func complete_current_modal() -> void:
	if not _modal_queue.is_empty():
		_modal_queue.remove_at(0)


## 作用：是否包含待处理请求，返回布尔判断结果。
## 使用：供本模块调用者使用。
func has_pending_request() -> bool:
	return not _modal_queue.is_empty()


## 作用：排序弹窗请求组。
## 使用：本文件由 request_modal 调用；输入 left（left）、right（right）；返回是否满足条件或执行成功。
func _sort_modal_requests(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("priority", 0)) > int(right.get("priority", 0))
