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


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
