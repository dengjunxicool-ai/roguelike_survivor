extends RefCounted
class_name LocalizationService


const CONFIG_PATH: String = "res://data/localization/ui_text.json"
const DEFAULT_LANGUAGE_ID: String = "zh"

static var _config_loaded: bool = false
static var _config: Dictionary = {}
static var _language_id: String = ""


static func apply_language(language_id: String) -> void:
	_ensure_config_loaded()
	_language_id = _normalize_language_id(language_id)


static func get_language_id() -> String:
	if _language_id == "":
		apply_language(SaveManager.get_language_id())
	return _language_id


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


static func _get_text(language_id: String, key: String) -> String:
	var texts: Dictionary = _get_dictionary(_config.get("texts", {}))
	var language_texts: Dictionary = _get_dictionary(texts.get(language_id, {}))
	return String(language_texts.get(key, ""))


static func _normalize_language_id(language_id: String) -> String:
	for language: Dictionary in get_language_options():
		if String(language.get("id", "")) == language_id:
			return language_id
	return DEFAULT_LANGUAGE_ID


static func _ensure_config_loaded() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	_config = {}
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_config = parsed


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
