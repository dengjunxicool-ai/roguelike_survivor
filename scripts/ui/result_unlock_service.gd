extends RefCounted
class_name ResultUnlockService


const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const MapRuntimeScript: Script = preload("res://scripts/maps/map_runtime.gd")


var _unlocks_by_result_key: Dictionary = {}


func reset_for_new_run() -> void:
	_unlocks_by_result_key.clear()


func apply_result_unlocks(state: String, run_seconds: float, selected_map_id: StringName, selected_map_name: String) -> Array[String]:
	var result_key: String = _get_result_key(state, run_seconds, selected_map_id)
	if _unlocks_by_result_key.has(result_key):
		return _get_string_array(_unlocks_by_result_key[result_key])

	var unlocked_items: Array[String] = []
	if run_seconds >= 300.0 and not SaveManager.is_unlocked("achievement", &"survive_5_minutes"):
		SaveManager.set_unlocked("achievement", &"survive_5_minutes")
		SaveManager.set_unlocked("character", &"ranger")
		unlocked_items.append("角色：游侠")

	if state == STATE_RESULT_VICTORY:
		if SaveManager.mark_map_cleared(selected_map_id):
			unlocked_items.append("通关记录：%s" % selected_map_name)

		for map_data: Dictionary in GameData.get_map_pool():
			var map_id: StringName = StringName(String(map_data.get("id", "")))
			if MapRuntimeScript.is_map_unlocked(map_data) and not SaveManager.is_map_cleared(map_id):
				var unlock: Dictionary = _get_dictionary(map_data.get("unlock", {}))
				if StringName(String(unlock.get("map_id", ""))) == selected_map_id:
					unlocked_items.append("地图：%s" % String(map_data.get("display_name", map_id)))


	_unlocks_by_result_key[result_key] = unlocked_items.duplicate()
	return unlocked_items


func _get_result_key(state: String, run_seconds: float, selected_map_id: StringName) -> String:
	return "%s:%s:%d" % [state, String(selected_map_id), floori(run_seconds)]


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
