## 文件用途：规范化单个 UI 状态的构建、准备、暂停和转移配置。
## 使用方式：registry 注册状态时静态 from_dictionary，将字段统一成描述字典。

extends RefCounted
class_name UIStateDescriptor


const PAUSE_MODE_PAUSE: String = "pause"
const PAUSE_MODE_RUNNING: String = "running"


var id: String = ""
var allowed_to: Array[String] = []
var is_running_child: bool = false
var is_fullscreen_choice: bool = false
var pause_mode: String = PAUSE_MODE_PAUSE
var build_method: StringName = &""
var prepare_method: StringName = &""


## 作用：来源字典。
## 使用：供本模块调用者使用；输入 data（数据）；返回字典包含 id/allowed_to/is_running_child/is_fullscreen_choice/pause_mode/build_method/prepare_method。
static func from_dictionary(data: Dictionary) -> Dictionary:
	return {
		"id": String(data.get("id", "")),
		"allowed_to": _string_array(data.get("allowed_to", [])),
		"is_running_child": bool(data.get("is_running_child", false)),
		"is_fullscreen_choice": bool(data.get("is_fullscreen_choice", false)),
		"pause_mode": String(data.get("pause_mode", PAUSE_MODE_PAUSE)),
		"build_method": StringName(String(data.get("build_method", ""))),
		"prepare_method": StringName(String(data.get("prepare_method", "")))
	}


## 作用：字符串数组，为界面/配置读取提供类型和回退处理。
## 使用：本文件由 from_dictionary 调用；输入 value（值）；返回 Array[String] 列表。
static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
