extends RefCounted
class_name UIThemeService
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


const CONFIG_PATH: String = DataPathsScript.UI_THEME_PATH

static var _config_loaded: bool = false
static var _config: Dictionary = {}


static func get_config() -> Dictionary:
	_ensure_config_loaded()
	return _config


static func get_section(path: Array) -> Dictionary:
	var value: Variant = get_config()
	for key_variant: Variant in path:
		var key: String = String(key_variant)
		if not value is Dictionary:
			return {}
		value = (value as Dictionary).get(key, {})
	return get_dictionary(value)


static func get_string(path: Array, fallback: String = "") -> String:
	var value: Variant = get_config()
	for key_variant: Variant in path:
		var key: String = String(key_variant)
		if not value is Dictionary:
			return fallback
		value = (value as Dictionary).get(key, null)
	if value == null:
		return fallback
	return String(value)


static func get_token(path: Array, fallback: Variant = null) -> Variant:
	var value: Variant = get_config()
	for key_variant: Variant in path:
		var key: String = String(key_variant)
		if not value is Dictionary:
			return fallback
		value = (value as Dictionary).get(key, null)
		if value == null:
			return fallback
	return value


static func get_color_token(path: Array, fallback: Color) -> Color:
	var parent_path: Array = path.duplicate()
	if parent_path.is_empty():
		return fallback
	var key: String = String(parent_path.pop_back())
	return get_color(get_section(parent_path), key, fallback)


static func get_number_token(path: Array, fallback: float) -> float:
	var value: Variant = get_token(path, fallback)
	return float(value) if (value is float or value is int) else fallback


static func get_color(config: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = config.get(key, null)
	if value is String:
		return Color.from_string(String(value), fallback)
	if value is Array:
		var parts: Array = value
		if parts.size() >= 3:
			return Color(
				float(parts[0]),
				float(parts[1]),
				float(parts[2]),
				float(parts[3]) if parts.size() > 3 else 1.0
			)
	return fallback


static func load_texture(resource_path: String) -> Texture2D:
	if resource_path == "":
		return null
	if ResourceLoader.exists(resource_path, "Texture2D"):
		return load(resource_path) as Texture2D
	var image: Image = Image.new()
	if image.load(resource_path) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _ensure_config_loaded() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	_config = JsonDataLoaderScript.load_dictionary(CONFIG_PATH, "UIThemeService", JsonDataLoaderScript.REPORT_SILENT)
