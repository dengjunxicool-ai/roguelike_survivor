## 文件用途：加载 UI 文案并按语言替换文本参数。
## 使用方式：apply_language 选择语言，translate 接收文本键、参数与回退文字。

extends RefCounted
class_name LocalizationService
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


const CONFIG_PATH: String = DataPathsScript.LOCALIZATION_UI_TEXT_PATH
const DEFAULT_LANGUAGE_ID: String = "zh"

static var _config_loaded: bool = false
static var _config: Dictionary = {}
static var _language_id: String = ""


## 作用：延迟加载文案配置，并设置经过合法性校验的当前语言 ID。
## 使用：language_id 来自语言选项；未知语言回退 zh，本函数不保存设置或自动重绘现有控件。
static func apply_language(language_id: String) -> void:
	_ensure_config_loaded()
	_language_id = _normalize_language_id(language_id)


## 作用：返回当前语言，首次查询时从 SaveManager 读取并规范化。
## 使用：静态查询；尚未显式选择语言时使用存档值。
static func get_language_id() -> String:
	if _language_id == "":
		apply_language(SaveManager.get_language_id())
	return _language_id


## 作用：返回配置语言列表的深拷贝，缺少配置时提供中英两项。
## 使用：设置界面静态调用；返回包含 id/label 的独立字典数组。
static func get_language_options() -> Array[Dictionary]:
	_ensure_config_loaded()
	var options: Array[Dictionary] = []
	var languages: Variant = _config.get("languages", [])
	if languages is Array:
		for language_variant: Variant in languages:
			if language_variant is Dictionary:
				var language: Dictionary = language_variant
				options.append(language.duplicate(true))
	if options.is_empty():
		options.append({"id": "zh", "label": "中文"})
		options.append({"id": "en", "label": "English"})
	return options


## 作用：查找当前语言文案，依次回退中文、fallback 或键名，并替换参数占位符。
## 使用：key 为文案键，params 将 {参数名} 替换为字符串值，fallback 为缺失文案的默认文字；返回 String 文本/标识。
static func translate(key: String, params: Dictionary = {}, fallback: String = "") -> String:
	_ensure_config_loaded()
	var language_id: String = get_language_id()
	var text: String = _get_text(language_id, key)
	if text == "":
		text = _get_text(DEFAULT_LANGUAGE_ID, key)
	if text == "":
		text = fallback if fallback != "" else key
	for param_key_variant: Variant in params.keys():
		var param_key: String = String(param_key_variant)
		text = text.replace("{%s}" % param_key, String(params[param_key_variant]))
	return text


## 作用：读取指定语言分区中的单条文案。
## 使用：language_id/key 定位配置项；缺少分区或键时返回空字符串。
static func _get_text(language_id: String, key: String) -> String:
	var texts: Dictionary = _get_dictionary(_config.get("texts", {}))
	var language_texts: Dictionary = _get_dictionary(texts.get(language_id, {}))
	return String(language_texts.get(key, ""))


## 作用：检查语言 ID 是否在已配置选项中。
## 使用：有效值原样返回，其余返回默认 zh。
static func _normalize_language_id(language_id: String) -> String:
	for language: Dictionary in get_language_options():
		if String(language.get("id", "")) == language_id:
			return language_id
	return DEFAULT_LANGUAGE_ID


## 作用：首次使用时从 UI 本地化 JSON 加载共享文案缓存。
## 使用：后续调用跳过；读取失败静默保留空配置，由语言和文本回退处理。
static func _ensure_config_loaded() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	_config = JsonDataLoaderScript.load_dictionary(CONFIG_PATH, "LocalizationService", JsonDataLoaderScript.REPORT_SILENT)


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _get_text 调用；输入 value（值）。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
