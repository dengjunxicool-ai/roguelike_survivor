## 文件用途：加载并提供 UI 主题、颜色、数值和纹理资源。
## 使用方式：UI 构建阶段调用静态 get_*；首次查询延迟加载 data/ui/ui_theme.json。

extends RefCounted
class_name UIThemeService
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


const CONFIG_PATH: String = DataPathsScript.UI_THEME_PATH

static var _config_loaded: bool = false
static var _config: Dictionary = {}


## 作用：首次读取时延迟加载主题配置，并返回内部缓存。
## 使用：返回原字典引用；仅用于读取，修改结果会改变后续主题查询。
static func get_config() -> Dictionary:
	_ensure_config_loaded()
	return _config


## 作用：按路径数组逐级查找主题配置的对象段。
## 使用：path 如 ["buttons", "primary"]；中途类型不符返回 {}，有效段保持原引用。
static func get_section(path: Array) -> Dictionary:
	var value: Variant = get_config()
	for key_variant: Variant in path:
		var key: String = String(key_variant)
		if not value is Dictionary:
			return {}
		value = (value as Dictionary).get(key, {})
	return get_dictionary(value)


## 作用：获取字符串，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 path（路径）、fallback（回退）；返回 String 文本/标识。
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


## 作用：按路径数组查找任意主题值。
## 使用：path 为键序列；任一步缺失或无法继续查找返回 fallback，不深拷贝容器值。
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


## 作用：获取颜色主题项，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 path（路径）、fallback（回退）；返回 Color 对象/值。
static func get_color_token(path: Array, fallback: Color) -> Color:
	var parent_path: Array = path.duplicate()
	if parent_path.is_empty():
		return fallback
	var key: String = String(parent_path.pop_back())
	return get_color(get_section(parent_path), key, fallback)


## 作用：获取数值主题项，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 path（路径）、fallback（回退）；返回计算或读取的数值。
static func get_number_token(path: Array, fallback: float) -> float:
	var value: Variant = get_token(path, fallback)
	return float(value) if (value is float or value is int) else fallback


## 作用：将颜色字符串或 RGB/RGBA 数组解析为 Color。
## 使用：config/key 指定来源；格式不支持时返回 fallback。
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


## 作用：加载纹理。
## 使用：供本模块调用者使用；输入 resource_path（resource路径）；返回 Texture2D 对象/值。
static func load_texture(resource_path: String) -> Texture2D:
	if resource_path == "":
		return null
	if ResourceLoader.exists(resource_path, "Texture2D"):
		return load(resource_path) as Texture2D
	var image: Image = Image.new()
	if image.load(resource_path) != OK:
		return null
	return ImageTexture.create_from_image(image)


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 get_section 调用；输入 value（值）。
static func get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## 作用：首次查询时加载 UI 主题 JSON 并设置已加载标记。
## 使用：读取失败静默保留空字典；已加载后不会再次读盘。
static func _ensure_config_loaded() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	_config = JsonDataLoaderScript.load_dictionary(CONFIG_PATH, "UIThemeService", JsonDataLoaderScript.REPORT_SILENT)
