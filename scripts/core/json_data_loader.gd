## 文件用途：读取 JSON 对象或对象中的数组并提供统一错误报告。
## 使用方式：静态调用 load_dictionary/load_array，传入 res:// 路径及报告模式；失败返回空容器。

extends RefCounted
class_name JsonDataLoader


const REPORT_ERROR: String = "error"
const REPORT_WARNING: String = "warning"
const REPORT_SILENT: String = "silent"


## 作用：读取并解析 JSON 根对象，返回独立深拷贝。
## 使用：path 为文件路径；context 用于报错前缀，report_mode 控制报错/警告/静默；失败返回 {}。
static func load_dictionary(path: String, context: String = "JsonDataLoader", report_mode: String = REPORT_ERROR) -> Dictionary:
	if not FileAccess.file_exists(path):
		_report(report_mode, "[%s] Data file does not exist: %s" % [context, path])
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_report(report_mode, "[%s] Could not open data file: %s (error: %s)" % [context, path, error_string(FileAccess.get_open_error())])
		return {}

	var json := JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	if parse_error != OK:
		_report(
			report_mode,
			"[%s] Failed to parse JSON file: %s (line %d: %s)" % [
				context,
				path,
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return {}

	var data: Variant = json.data
	if not (data is Dictionary):
		_report(report_mode, "[%s] JSON root must be an object: %s" % [context, path])
		return {}

	var document: Dictionary = data
	return document.duplicate(true)


## 作用：读取 JSON 对象中 key 指定的数组并返回深拷贝。
## 使用：复用 load_dictionary；字段缺失、文件错误或字段类型错误时返回 []。
static func load_array(path: String, key: String, context: String = "JsonDataLoader", report_mode: String = REPORT_ERROR) -> Array:
	var document: Dictionary = load_dictionary(path, context, report_mode)
	if document.is_empty():
		return []

	var value: Variant = document.get(key, [])
	if not (value is Array):
		_report(report_mode, "[%s] Expected %s.%s to be an Array." % [context, path, key])
		return []

	var items: Array = value
	return items.duplicate(true)


## 作用：根据报告模式输出错误、警告或保持静默。
## 使用：加载失败分支调用；未知模式按错误处理。
static func _report(report_mode: String, message: String) -> void:
	match report_mode:
		REPORT_WARNING:
			push_warning(message)
		REPORT_SILENT:
			pass
		_:
			push_error(message)
