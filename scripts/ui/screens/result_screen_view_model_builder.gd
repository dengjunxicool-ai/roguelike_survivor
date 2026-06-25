extends RefCounted
class_name ResultScreenViewModelBuilder


const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const RunDiagnosticServiceScript: Script = preload("res://scripts/game/run_diagnostic_service.gd")


func build(state: String, run_state: Dictionary, unlocks: Array[String]) -> Dictionary:
	var selected_character_id: StringName = StringName(String(run_state.get("selected_character_id", "")))
	var selected_map_id: StringName = StringName(String(run_state.get("selected_map_id", "")))
	var selected_map_name: String = String(run_state.get("selected_map_name", selected_map_id))
	var run_seconds: float = float(run_state.get("run_seconds", 0.0))
	var kill_count: int = int(run_state.get("kill_count", 0))
	var run_souls_earned: int = int(run_state.get("run_souls_earned", 0))
	var diagnostic: Dictionary = RunDiagnosticServiceScript.build_diagnostic(run_state)
	var selected_character: Dictionary = GameData.get_character(selected_character_id)
	return {
		"diagnostic": diagnostic,
		"labels": {
			"title": "结果：%s" % ("胜利" if state == STATE_RESULT_VICTORY else "失败"),
			"character": "角色：%s" % String(selected_character.get("display_name", selected_character_id)),
			"map": "地图：%s" % selected_map_name,
			"time": "时间：%s" % _format_time(run_seconds),
			"kill": "击杀：%d" % kill_count,
			"progress": _get_progress_text(run_state),
			"cause": "死亡原因：%s" % String(diagnostic.get("death_cause", "未记录")),
			"boss": "Boss DPS：%.1f / 核心处理：%d 个，平均 %.1fs" % [
				float(diagnostic.get("boss_dps", 0.0)),
				int(diagnostic.get("boss_core_destroyed_count", 0)),
				float(diagnostic.get("boss_core_average_lifetime", 0.0))
			],
			"summary": "构筑摘要：%s" % String(diagnostic.get("build_summary", "")),
			"upgrades": "高贡献升级：%s" % String(diagnostic.get("upgrade_summary", "无")),
			"damage": "伤害结构：%s" % _format_percent_dictionary(_get_dictionary(diagnostic.get("damage_share", {}))),
			"taken": "受伤来源：%s" % _format_percent_dictionary(_get_dictionary(diagnostic.get("damage_taken_share", {}))),
			"diagnosis": "诊断：%s" % String(diagnostic.get("diagnosis_text", "")),
			"suggestion": "下局建议：%s" % String(diagnostic.get("next_run_suggestion", "")),
			"soul": "本局获得：%d / 总灵魂石：%d" % [run_souls_earned, SaveManager.get_soul_stones()],
			"unlock": "解锁：%s" % ("、".join(unlocks) if not unlocks.is_empty() else "无")
		},
		"reason": "推荐原因：%s" % String(diagnostic.get("recommendation_reason", ""))
	}


func _get_progress_text(run_state: Dictionary) -> String:
	var level: int = int(run_state.get("main_attack_level", 1))
	return "初始技能：Lv.%d" % level


func _format_percent_dictionary(dictionary: Dictionary) -> String:
	if dictionary.is_empty():
		return "暂无"
	var parts: Array[String] = []
	for key: Variant in dictionary.keys():
		var value: float = float(dictionary[key])
		if value <= 0.0:
			continue
		parts.append("%s %.0f%%" % [_label_for_key(String(key)), value * 100.0])
	return "、".join(parts) if not parts.is_empty() else "暂无"


func _label_for_key(key: String) -> String:
	match key:
		"main_attack", "primary_attack":
			return "初始技能"
		"dot", "status_dot":
			return "DOT"
		"reaction":
			return "反应"
		"field", "area", "area_direct":
			return "区域"
		"trap":
			return "陷阱"
		"contact", "physical":
			return "接触"
		"boss":
			return "Boss"
		"poison":
			return "中毒"
		"fire", "lava", "map_lava":
			return "火焰/岩浆"
		_:
			return key


func _format_time(seconds: float) -> String:
	var total_seconds: int = maxi(int(seconds), 0)
	return "%02d:%02d" % [floori(float(total_seconds) / 60.0), total_seconds % 60]


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
