extends RefCounted
class_name UISettingsService


const LocalizationServiceScript: Script = preload("res://scripts/ui/localization_service.gd")


static func apply_saved_settings() -> void:
	apply_window_mode(SaveManager.get_fullscreen_enabled())
	apply_master_volume(SaveManager.get_master_volume_percent())
	apply_language(SaveManager.get_language_id())


static func apply_window_mode(fullscreen_enabled: bool) -> void:
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


static func apply_master_volume(value: float) -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return
	var linear_volume: float = clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(master_bus_index, linear_volume <= 0.0)
	if linear_volume > 0.0:
		AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(linear_volume))


static func apply_language(language_id: String) -> void:
	LocalizationServiceScript.apply_language(language_id)
