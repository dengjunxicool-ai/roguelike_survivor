## 文件用途：缓存同一局结果解锁处理以避免重复领取。
## 使用方式：每局 reset_for_new_run；结果刷新调用 apply_result_unlocks，按结果键复用本局结果。

extends RefCounted
class_name ResultUnlockService


const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const MapRuntimeScript: Script = preload("res://scripts/maps/map_runtime.gd")


var _unlocks_by_result_key: Dictionary = {}


## 作用：清空仅属于上一局的结果解锁缓存。
## 使用：新一局开始时调用；不清除已持久化的角色、成就或地图进度。
func reset_for_new_run() -> void:
	_unlocks_by_result_key.clear()


## 作用：首次为该结果记录存活成就、角色解锁与地图通关，并缓存解锁文字。
## 使用：state/run_seconds/map_id 构成结果键；重复刷新返回缓存，不再次落盘领取；可能写入 user:// 存档。
func apply_result_unlocks(state: String, run_seconds: float, selected_map_id: StringName, selected_map_name: String) -> Array[String]:
	var result_key: String = _get_result_key(state, run_seconds, selected_map_id)
	if _unlocks_by_result_key.has(result_key):
		return _get_string_array(_unlocks_by_result_key[result_key])
	var config := ConfigFile.new()
	if not SaveManager._load_for_write(config):
		return []
	var unlocked_items: Array[String] = populate_config(config, state, run_seconds, selected_map_id, selected_map_name)
	if not SaveManager._commit_config(config):
		return []
	cache_result(state, run_seconds, selected_map_id, unlocked_items)
	return unlocked_items


func cache_result(state: String, run_seconds: float, map_id: StringName, items: Array[String]) -> void:
	_unlocks_by_result_key[_get_result_key(state, run_seconds, map_id)] = items.duplicate()


## 纯修改同一个 ConfigFile，由调用者一次提交；独立解锁服务与终局事务共用。
static func populate_config(config: ConfigFile, state: String, run_seconds: float, selected_map_id: StringName, selected_map_name: String) -> Array[String]:
	var items: Array[String] = []
	if run_seconds >= 300.0 and not bool(config.get_value(SaveManager.SECTION_UNLOCKS, "achievement:survive_5_minutes", false)):
		config.set_value(SaveManager.SECTION_UNLOCKS, "achievement:survive_5_minutes", true)
		config.set_value(SaveManager.SECTION_UNLOCKS, "character:ranger", true)
		items.append("角色：游侠")
	if state == STATE_RESULT_VICTORY:
		if not bool(config.get_value(SaveManager.SECTION_MAP_CLEAR_RECORDS, String(selected_map_id), false)):
			config.set_value(SaveManager.SECTION_MAP_CLEAR_RECORDS, String(selected_map_id), true)
			items.append("通关记录：%s" % selected_map_name)
		for map_data: Dictionary in GameData.get_map_pool():
			var unlock: Dictionary = map_data.get("unlock", {})
			var map_id: String = String(map_data.get("id", ""))
			if String(unlock.get("map_id", "")) == String(selected_map_id) and not bool(config.get_value(SaveManager.SECTION_MAP_CLEAR_RECORDS, map_id, false)):
				items.append("地图：%s" % String(map_data.get("display_name", map_id)))
	return items

## 作用：获取结果键，供当前模块后续逻辑使用。
## 使用：本文件由 apply_result_unlocks 调用；输入 state（状态）、run_seconds（单局秒）、selected_map_id（当前选择地图ID）；返回 String 文本/标识。
func _get_result_key(state: String, run_seconds: float, selected_map_id: StringName) -> String:
	return "%s:%s:%d" % [state, String(selected_map_id), floori(run_seconds)]


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 apply_result_unlocks 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：获取字符串数组，为界面/配置读取提供类型和回退处理。
## 使用：本文件由 apply_result_unlocks 调用；输入 value（值）；返回 Array[String] 列表。
func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
