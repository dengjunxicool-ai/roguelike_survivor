## 文件用途：封装弹窗类型、目标状态、内容、优先级和 HUD 隐藏请求。
## 使用方式：静态 create 创建请求字典，to_dictionary 输出独立视图。

extends RefCounted
class_name ModalRequest


var modal_type: String = ""
var target_state: String = ""
var payload: Dictionary = {}
var priority: int = 0
var hide_hud: bool = false


## 作用：构建含类型、状态、payload、优先级及 HUD 隐藏标记的请求字典。
## 使用：request_payload 深拷贝；供 ModalFlowController 入队，不直接切换页面；返回字典包含 modal_type/target_state/payload/priority/hide_hud。
static func create(request_type: String, state: String, request_payload: Dictionary = {}, request_priority: int = 0, request_hide_hud: bool = false) -> Dictionary:
	return {
		"modal_type": request_type,
		"target_state": state,
		"payload": request_payload.duplicate(true),
		"priority": request_priority,
		"hide_hud": request_hide_hud
	}


## 作用：把当前请求实例转为字典并深拷贝 payload。
## 使用：返回独立展示/排队视图，不改变请求优先级或队列。
func to_dictionary() -> Dictionary:
	return {
		"modal_type": modal_type,
		"target_state": target_state,
		"payload": payload.duplicate(true),
		"priority": priority,
		"hide_hud": hide_hud
	}
