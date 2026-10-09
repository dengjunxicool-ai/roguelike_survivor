## 文件用途：统一应用已保存的窗口模式、音量和语言。
## 使用方式：启动调用 apply_saved_settings；设置控件通过对应静态接口更新设备状态。

extends RefCounted
class_name UISettingsService


const LocalizationServiceScript: Script = preload("res://scripts/ui/localization_service.gd")


## 作用：读取存档设置并应用窗口、音量与语言。
## 使用：启动时调用；仅读取持久化设置并更新当前设备/服务状态。
static func apply_saved_settings() -> void:
	apply_window_mode(SaveManager.get_fullscreen_enabled())
	apply_master_volume(SaveManager.get_master_volume_percent())
	apply_language(SaveManager.get_language_id())


## 作用：根据全屏请求切换窗口显示模式。
## 使用：fullscreen_enabled 为 true 时全屏；false 时从窗口态最大化、从其他状态切回窗口态。
static func apply_window_mode(fullscreen_enabled: bool) -> void:
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## 作用：把 0～100 百分比转换为主声道音量，零音量时静音。
## 使用：value 为百分比；主声道不存在时返回，本函数不保存设置。
static func apply_master_volume(value: float) -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return
	var linear_volume: float = clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(master_bus_index, linear_volume <= 0.0)
	if linear_volume > 0.0:
		AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(linear_volume))


## 作用：将语言 ID 交给本地化服务应用。
## 使用：language_id 来自已保存设置或界面选择；本函数不写入存档。
static func apply_language(language_id: String) -> void:
	LocalizationServiceScript.apply_language(language_id)
