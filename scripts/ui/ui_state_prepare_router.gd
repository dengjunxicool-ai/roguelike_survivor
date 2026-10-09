## 文件用途：在进入页面前路由刷新页面与弹窗待办操作。
## 使用方式：UIManager 状态切换中调用 prepare(owner,state,context)。

extends RefCounted
class_name UIStatePrepareRouter


const STATE_TITLE: String = "TITLE"
const STATE_CHARACTER_SELECT: String = "CHARACTER_SELECT"
const STATE_MAP_SELECT: String = "MAP_SELECT"
const STATE_RUNNING: String = "RUNNING"
const STATE_RESULT_DEFEAT: String = "RESULT_DEFEAT"
const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const STATE_META_UPGRADE: String = "META_UPGRADE"
const STATE_CODEX: String = "CODEX"
const STATE_SETTINGS: String = "SETTINGS"


## 作用：准备。
## 使用：供本模块调用者使用；输入 target（目标）、state（状态）、context（上下文）。
func prepare(target: Object, state: String, context: Dictionary = {}) -> void:
	if target == null:
		return

	if state == STATE_TITLE:
		_call_if_available(target, &"_teardown_run_scene")
		_call_if_available(target, &"_reset_title_screen")
	elif state == STATE_META_UPGRADE:
		_call_if_available(target, &"_teardown_run_scene")
		_call_if_available(target, &"_refresh_meta_upgrade_screen")
	elif state == STATE_CHARACTER_SELECT:
		_call_if_available(target, &"_teardown_run_scene")
		_call_if_available(target, &"_refresh_character_select_screen")
	elif state == STATE_CODEX or state == STATE_SETTINGS:
		_call_if_available(target, &"_teardown_run_scene")
	elif state == STATE_MAP_SELECT:
		_call_if_available(target, &"_refresh_map_select_screen")
	elif _refresh_modal_for_state(state, context):
		return
	elif state == STATE_RUNNING:
		_call_if_available(target, &"_connect_runtime_sources")
		_call_if_available(target, &"_update_run_hud")
		if _has_pending_modal(context):
			target.call_deferred("_show_pending_modal_if_running")
	elif state == STATE_RESULT_DEFEAT or state == STATE_RESULT_VICTORY:
		_call_if_available(target, &"_refresh_result_screen", [state])


## 作用：刷新弹窗对应状态；具体处理委托给 modal_flow_controller.refresh_modal_for_state。
## 使用：本文件由 prepare 调用；输入 state（状态）、context（上下文）；返回是否满足条件或执行成功。
func _refresh_modal_for_state(state: String, context: Dictionary) -> bool:
	var modal_flow_controller: RefCounted = context.get("modal_flow_controller", null) as RefCounted
	if modal_flow_controller == null:
		return false
	return bool(modal_flow_controller.call("refresh_modal_for_state", context.get("choice_modal", null), state))


## 作用：是否包含待处理弹窗，返回布尔判断结果；具体处理委托给 modal_flow_controller.get_pending_state。
## 使用：本文件由 prepare 调用；输入 context（上下文）。
func _has_pending_modal(context: Dictionary) -> bool:
	var modal_flow_controller: RefCounted = context.get("modal_flow_controller", null) as RefCounted
	if modal_flow_controller == null:
		return false
	return String(modal_flow_controller.call("get_pending_state", context.get("choice_modal", null))) != ""


## 作用：调用按条件可用。
## 使用：本文件由 prepare 调用；输入 target（目标）、method_name（方法名称）、args（args）。
func _call_if_available(target: Object, method_name: StringName, args: Array = []) -> void:
	if target != null and target.has_method(method_name):
		target.callv(method_name, args)
