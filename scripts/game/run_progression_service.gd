## 文件用途：将终局统计转为全局计数、角色专精、地图挑战和固定挑战进度。
## 使用方式：由 UI 的单次终局记录入口调用 record_run_result，结果写入 SaveManager。

extends RefCounted
class_name RunProgressionService


const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"


## 作用：从终局快照计算并保存全局计数、角色专精、地图及固定挑战进度。
## 使用：state/run_state 来自已锁定结果；由 UIManager 保证每局只调用一次，返回摘要和新解锁项；可能写入 user:// 存档。
static func record_run_result(state: String, run_state: Dictionary) -> Dictionary:
	var summary: Dictionary = _build_summary(state, run_state)
	var unlocked_items: Array[String] = []

	SaveManager.save_last_run_summary(summary)
	_update_global_counters(summary)
	_update_character_specialization(summary)
	_update_map_challenges(summary, unlocked_items)
	_update_fixed_challenges(summary, unlocked_items)

	summary["progression_unlocks"] = unlocked_items
	return summary


## 作用：整理终局结果、角色地图、时间、击杀、灵魂、240 秒达成情况及挑战信息。
## 使用：context 为运行上下文；返回包含 main_attack_level 和 run_stats 的成长摘要。
static func _build_summary(state: String, run_state: Dictionary) -> Dictionary:
	var run_seconds: float = float(run_state.get("run_seconds", 0.0))
	var kill_count: int = maxi(int(run_state.get("kill_count", 0)), 0)
	return {
		"result_state": state,
		"victory": state == STATE_RESULT_VICTORY,
		"selected_character_id": StringName(String(run_state.get("selected_character_id", ""))),
		"selected_map_id": StringName(String(run_state.get("selected_map_id", ""))),
		"selected_map_name": String(run_state.get("selected_map_name", "")),
		"run_seconds": run_seconds,
		"kill_count": kill_count,
		"run_souls_earned": maxi(int(run_state.get("run_souls_earned", 0)), 0),
		"reached_boss": run_seconds >= 240.0,
		"challenge_id": StringName(String(run_state.get("challenge_id", ""))),
		"main_attack_level": int(run_state.get("main_attack_level", 1)),
		"run_stats": _get_dictionary(run_state.get("run_stats", {}))
	}


## 作用：更新全局计数器组。
## 使用：本文件由 record_run_result 调用；输入 summary（摘要）；可能写入 user:// 存档。
static func _update_global_counters(summary: Dictionary) -> void:
	SaveManager.increment_counter(&"total_runs", 1)
	SaveManager.increment_counter(&"total_kills", int(summary.get("kill_count", 0)))
	SaveManager.set_counter_max(&"best_run_seconds", floori(float(summary.get("run_seconds", 0.0))))

	if bool(summary.get("victory", false)):
		SaveManager.increment_counter(&"victories", 1)
		SaveManager.increment_counter(&"boss_kills", 1)
	else:
		SaveManager.increment_counter(&"defeats", 1)

	var character_id: StringName = StringName(String(summary.get("selected_character_id", "")))
	var map_id: StringName = StringName(String(summary.get("selected_map_id", "")))
	if character_id != &"":
		SaveManager.increment_counter(StringName("character:%s:runs" % String(character_id)), 1)
	if map_id != &"":
		SaveManager.increment_counter(StringName("map:%s:runs" % String(map_id)), 1)
		if bool(summary.get("victory", false)):
			SaveManager.increment_counter(StringName("map:%s:clears" % String(map_id)), 1)


## 作用：更新角色专精。
## 使用：本文件由 record_run_result 调用；输入 summary（摘要）；可能写入 user:// 存档。
static func _update_character_specialization(summary: Dictionary) -> void:
	var character_id: StringName = StringName(String(summary.get("selected_character_id", "")))
	if character_id == &"":
		return

	SaveManager.increment_character_specialization(character_id, &"runs", 1)
	SaveManager.increment_character_specialization(character_id, &"kills", int(summary.get("kill_count", 0)))
	SaveManager.increment_character_specialization(character_id, &"survival_seconds", floori(float(summary.get("run_seconds", 0.0))))
	if bool(summary.get("victory", false)):
		SaveManager.increment_character_specialization(character_id, &"victories", 1)

	for goal_variant: Variant in _get_character_goal_ids(character_id):
		var goal_id: StringName = StringName(String(goal_variant))
		if goal_id != &"" and _character_goal_met(character_id, goal_id, summary):
			SaveManager.increment_character_specialization(character_id, goal_id, 1)


## 作用：更新地图挑战列表。
## 使用：本文件由 record_run_result 调用；输入 summary（摘要）、unlocked_items（已解锁条目）；可能写入 user:// 存档。
static func _update_map_challenges(summary: Dictionary, unlocked_items: Array[String]) -> void:
	var map_id: StringName = StringName(String(summary.get("selected_map_id", "")))
	if map_id == &"":
		return

	for objective_variant: Variant in _get_map_objectives(map_id):
		var objective_id: StringName = StringName(String(objective_variant))
		if objective_id == &"" or not _map_objective_met(objective_id, summary):
			continue
		if SaveManager.mark_map_challenge_completed(map_id, objective_id):
			unlocked_items.append("地图挑战：%s / %s" % [String(map_id), String(objective_id)])


## 作用：更新固定挑战列表。
## 使用：本文件由 record_run_result 调用；输入 summary（摘要）、unlocked_items（已解锁条目）；可能写入 user:// 存档。
static func _update_fixed_challenges(summary: Dictionary, unlocked_items: Array[String]) -> void:
	if not bool(summary.get("victory", false)):
		return

	var pools: Array = []
	pools.append_array(GameData.get_daily_challenge_pool())
	pools.append_array(GameData.get_weekly_challenge_pool())
	for challenge: Dictionary in pools:
		if StringName(String(challenge.get("character_id", ""))) != StringName(String(summary.get("selected_character_id", ""))):
			continue
		if StringName(String(challenge.get("map_id", ""))) != StringName(String(summary.get("selected_map_id", ""))):
			continue
		var challenge_id: StringName = StringName(String(challenge.get("challenge_id", "")))
		if SaveManager.mark_challenge_completed(challenge_id):
			unlocked_items.append("挑战完成：%s" % String(challenge.get("display_name", challenge_id)))


## 作用：获取角色目标ID列表，供当前模块后续逻辑使用。
## 使用：本文件由 _update_character_specialization 调用；输入 character_id（角色ID）；返回 Array 列表。
static func _get_character_goal_ids(character_id: StringName) -> Array:
	var goals_data: Dictionary = GameData.get_progression_goals()
	for entry_variant: Variant in _get_array(goals_data.get("character_specializations", [])):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if StringName(String(entry.get("character_id", ""))) == character_id:
			return _get_array(entry.get("goals", []))
	return []


## 作用：获取地图挑战目标组，供当前模块后续逻辑使用。
## 使用：本文件由 _update_map_challenges 调用；输入 map_id（地图ID）；返回 Array 列表。
static func _get_map_objectives(map_id: StringName) -> Array:
	var goals_data: Dictionary = GameData.get_progression_goals()
	for entry_variant: Variant in _get_array(goals_data.get("map_challenges", [])):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if StringName(String(entry.get("map_id", ""))) == map_id:
			return _get_array(entry.get("objectives", []))
	return []


## 作用：地图挑战目标达成。
## 使用：本文件由 _update_map_challenges 调用；输入 objective_id（挑战目标ID）、summary（摘要）；返回是否满足条件或执行成功。
static func _map_objective_met(objective_id: StringName, summary: Dictionary) -> bool:
	var victory: bool = bool(summary.get("victory", false))
	var run_seconds: float = float(summary.get("run_seconds", 0.0))
	var stats: Dictionary = _get_dictionary(summary.get("run_stats", {}))
	match String(objective_id):
		"clear_once", "clear_without_death":
			return victory
		"defeat_boss_before_285s":
			return victory and run_seconds <= 285.0
		"clear_without_healing":
			return victory and int(stats.get("healing_used", 0)) <= 0
		"avoid_toxic_fog_overdamage", "clear_all_toxic_fog_events":
			return victory and int(stats.get("poison_instances_taken", 0)) < 5
		"clear_with_dot_damage":
			return victory and _damage_origin_share_at_least(stats, "dot", 0.35)
		"survive_lava_fissures":
			return victory and int(stats.get("lava_hits_taken", 0)) <= 0
		"clear_with_control_status":
			return victory and _has_status_count(stats, ["freeze", "slow", "stun", "paralyze"], 30)
		"survive_encirclement":
			return victory and int(stats.get("highest_alive_normal_enemies", 0)) < 120
		"clear_with_pierce_or_bounce":
			return victory and _has_status_count(stats, ["shock", "overload"], 20)
		"defeat_toxic_matriarch", "defeat_lava_golem", "defeat_shadow_hunter":
			return victory and int(stats.get("elite_kill_count", 0)) > 0
		_:
			return false


## 作用：按角色类型与终局统计判断专精目标的固定条件。
## 使用：character_id 为角色标识，summary 为结果摘要；当前忽略 _goal_id，该角色的目标使用同一判定条件；返回是否满足条件或执行成功。
static func _character_goal_met(character_id: StringName, _goal_id: StringName, summary: Dictionary) -> bool:
	var stats: Dictionary = _get_dictionary(summary.get("run_stats", {}))
	var status_counts: Dictionary = _get_dictionary(stats.get("status_counts", {}))
	match String(character_id):
		"mage":
			return bool(summary.get("victory", false)) and (bool(stats.get("overload_full_stack_boss_kill", false)) or int(status_counts.get("overload", 0)) >= 30)
		"ranger":
			return float(stats.get("hunter_rhythm_seconds", 0.0)) >= 180.0 or int(stats.get("critical_kills", 0)) >= 120
		"paladin":
			return int(stats.get("shield_break_kills", 0)) >= 300
		"alchemist":
			return int(stats.get("potion_zone_triggers", 0)) >= 50 or int(status_counts.get("poison", 0)) >= 80
		_:
			return bool(summary.get("victory", false))


## 作用：伤害来源类别占比指定位置至少。
## 使用：本文件由 _map_objective_met 调用；输入 stats（属性统计）、origin（来源）、threshold（threshold）；返回是否满足条件或执行成功。
static func _damage_origin_share_at_least(stats: Dictionary, origin: String, threshold: float) -> bool:
	var damage_by_origin: Dictionary = _get_dictionary(stats.get("damage_done_by_origin", {}))
	var total: float = maxf(float(stats.get("damage_done_total", _sum_dictionary(damage_by_origin))), 1.0)
	return float(damage_by_origin.get(origin, 0)) / total >= threshold


## 作用：是否包含状态效果数量，返回布尔判断结果。
## 使用：本文件由 _map_objective_met 调用；输入 stats（属性统计）、status_ids（状态效果ID列表）、min_count（下限数量）。
static func _has_status_count(stats: Dictionary, status_ids: Array[String], min_count: int) -> bool:
	var counts: Dictionary = _get_dictionary(stats.get("status_counts", {}))
	var total: int = 0
	for status_id: String in status_ids:
		total += int(counts.get(status_id, 0))
	return total >= min_count


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 _get_character_goal_ids、_get_map_objectives 调用；输入 value（值）。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _build_summary、_map_objective_met、_character_goal_met 调用；输入 value（值）。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：求和字典。
## 使用：本文件由 _damage_origin_share_at_least 调用；输入 dictionary（字典）；返回计算或读取的数值。
static func _sum_dictionary(dictionary: Dictionary) -> int:
	var total: int = 0
	for value: Variant in dictionary.values():
		total += int(value)
	return total
