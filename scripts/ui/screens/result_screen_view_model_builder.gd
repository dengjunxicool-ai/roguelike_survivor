## 文件用途：格式化胜负结算、死亡原因、进度与伤害占比文本。
## 使用方式：结果页创建实例后调用 build，不重复应用奖励或修改运行数据。

extends RefCounted
class_name ResultScreenViewModelBuilder


const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const RunDiagnosticServiceScript: Script = preload("res://scripts/game/run_diagnostic_service.gd")


## 作用：整理上下文和配置为页面展示模型。
## 使用：由页面或局内编排的构建流程调用；结果按声明类型供后续展示/执行使用；输入 state（状态）、run_state（单局状态）、unlocks（解锁组）；返回字典包含 diagnostic/labels/title/character/map/time/kill/progress 等字段。
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
			"cause": "死亡原因：%s" % _get_death_cause(state, run_state, diagnostic),
			"boss": "Boss DPS：%.1f / 核心处理：%d 个，平均 %.1fs" % [
				float(diagnostic.get("boss_dps", 0.0)),
				int(diagnostic.get("boss_core_destroyed_count", 0)),
				float(diagnostic.get("boss_core_average_lifetime", 0.0))
			],
			"summary": "构筑摘要：%s" % String(diagnostic.get("build_summary", "")),
			"upgrades": "已选升级：%s" % String(diagnostic.get("upgrade_summary", "无")),
			"damage": "伤害结构：%s" % _format_percent_dictionary(_get_dictionary(diagnostic.get("damage_share", {})), "本局未造成伤害"),
			"taken": "受伤来源：%s" % _format_percent_dictionary(_get_dictionary(diagnostic.get("damage_taken_share", {})), "本局未受到伤害"),
			"diagnosis": "诊断：%s" % String(diagnostic.get("diagnosis_text", "")),
			"suggestion": "下局建议：%s" % String(diagnostic.get("next_run_suggestion", "")),
			"soul": "本局获得：%d / 总灵魂石：%d" % [run_souls_earned, SaveManager.get_soul_stones()],
			"unlock": "解锁：%s" % ("、".join(unlocks) if not unlocks.is_empty() else "无")
		},
		"reason": "推荐原因：%s" % String(diagnostic.get("recommendation_reason", ""))
	}


## 作用：获取死亡原因，供当前模块后续逻辑使用。
## 使用：本文件由 build 调用；输入 state（状态）、run_state（单局状态）、diagnostic（诊断）；返回 String 文本/标识。
func _get_death_cause(state: String, run_state: Dictionary, diagnostic: Dictionary) -> String:
	if state == STATE_RESULT_VICTORY:
		return "未死亡"
	var player_dead: Variant = run_state.get("player_dead", null)
	if player_dead == null:
		return "未记录"
	if not bool(player_dead):
		return "主动结束 / 未死亡"
	return String(diagnostic.get("death_cause", "未记录"))


## 作用：获取进度文本，供当前模块后续逻辑使用。
## 使用：本文件由 build 调用；输入 run_state（单局状态）；返回 String 文本/标识。
func _get_progress_text(run_state: Dictionary) -> String:
	var level: int = int(run_state.get("main_attack_level", 1))
	return "主攻技能：Lv.%d" % level


## 作用：格式化百分比字典。
## 使用：本文件由 build 调用；输入 dictionary（字典）、empty_text（空值文本）；返回 String 文本/标识。
func _format_percent_dictionary(dictionary: Dictionary, empty_text: String) -> String:
	if dictionary.is_empty():
		return empty_text
	var parts: Array[String] = []
	for key: Variant in dictionary.keys():
		var value: float = float(dictionary[key])
		if value <= 0.0:
			continue
		parts.append("%s %.0f%%" % [_label_for_key(String(key)), value * 100.0])
	return "、".join(parts) if not parts.is_empty() else empty_text


## 作用：标签对应键。
## 使用：本文件由 _format_percent_dictionary 调用；输入 key（键）；返回 String 文本/标识。
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
		"special":
			return "特殊"
		"enemy":
			return "敌人"
		"contact", "physical":
			return "接触"
		"boss":
			return "Boss"
		"ranged", "projectile":
			return "远程伤害"
		"map_toxic_fog":
			return "毒雾"
		"poison":
			return "中毒"
		"fire", "lava", "map_lava":
			return "火焰/岩浆"
		_:
			return key


## 作用：格式化时间。
## 使用：本文件由 build 调用；输入 seconds（秒）；返回 String 文本/标识。
func _format_time(seconds: float) -> String:
	var total_seconds: int = maxi(int(seconds), 0)
	return "%02d:%02d" % [floori(float(total_seconds) / 60.0), total_seconds % 60]


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 build 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
