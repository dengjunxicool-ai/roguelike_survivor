extends RefCounted
class_name RunProgressionService


const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"


static func record_run_result(state: String, run_state: Dictionary) -> Dictionary:
	var summary: Dictionary = _build_summary(state, run_state)
	var unlocked_items: Array[String] = []

	SaveManager.save_last_run_summary(summary)
	_update_global_counters(summary)
	_update_weapon_mastery(summary, unlocked_items)
	_update_character_specialization(summary)
	_update_map_challenges(summary, unlocked_items)
	_update_fixed_challenges(summary, unlocked_items)

	summary["progression_unlocks"] = unlocked_items
	return summary


static func _build_summary(state: String, run_state: Dictionary) -> Dictionary:
	var run_seconds: float = float(run_state.get("run_seconds", 0.0))
	var kill_count: int = maxi(int(run_state.get("kill_count", 0)), 0)
	var run_stats: Dictionary = _get_dictionary(run_state.get("run_stats", {}))
	return {
		"result_state": state,
		"victory": state == STATE_RESULT_VICTORY,
		"selected_character_id": StringName(String(run_state.get("selected_character_id", ""))),
		"selected_weapon_id": StringName(String(run_state.get("selected_weapon_id", ""))),
		"selected_map_id": StringName(String(run_state.get("selected_map_id", ""))),
		"selected_map_name": String(run_state.get("selected_map_name", "")),
		"run_seconds": run_seconds,
		"kill_count": kill_count,
		"run_souls_earned": maxi(int(run_state.get("run_souls_earned", 0)), 0),
		"reached_boss": run_seconds >= 240.0,
		"challenge_id": StringName(String(run_state.get("challenge_id", ""))),
		"main_attack_level": int(run_state.get("main_attack_level", 1)),
		"current_branch_name": String(run_state.get("current_branch_name", "")),
		"run_stats": run_stats
	}


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
	var weapon_id: StringName = StringName(String(summary.get("selected_weapon_id", "")))
	var map_id: StringName = StringName(String(summary.get("selected_map_id", "")))
	if character_id != &"":
		SaveManager.increment_counter(StringName("character:%s:runs" % String(character_id)), 1)
	if weapon_id != &"":
		SaveManager.increment_counter(StringName("weapon:%s:runs" % String(weapon_id)), 1)
		SaveManager.increment_counter(StringName("weapon:%s:kills" % String(weapon_id)), int(summary.get("kill_count", 0)))
	if map_id != &"":
		SaveManager.increment_counter(StringName("map:%s:runs" % String(map_id)), 1)
		if bool(summary.get("victory", false)):
			SaveManager.increment_counter(StringName("map:%s:clears" % String(map_id)), 1)


static func _update_weapon_mastery(summary: Dictionary, unlocked_items: Array[String]) -> void:
	var weapon_id: StringName = StringName(String(summary.get("selected_weapon_id", "")))
	if weapon_id == &"":
		return

	var old_level: int = SaveManager.get_weapon_mastery_level(weapon_id)
	var earned_xp: int = int(summary.get("kill_count", 0)) + floori(float(summary.get("run_seconds", 0.0)) / 5.0)
	var stats: Dictionary = _get_dictionary(summary.get("run_stats", {}))
	var status_counts: Dictionary = _get_dictionary(stats.get("status_counts", {}))
	earned_xp += mini(floori(float(_sum_dictionary(status_counts)) / 4.0), 60)
	if bool(summary.get("victory", false)):
		earned_xp += 80

	var new_xp: int = SaveManager.add_weapon_mastery_xp(weapon_id, earned_xp)
	var new_level: int = SaveManager.get_weapon_mastery_level_from_xp(new_xp)
	if new_level > old_level:
		_apply_weapon_mastery_unlocks(weapon_id, old_level, new_level, unlocked_items)


static func _apply_weapon_mastery_unlocks(weapon_id: StringName, old_level: int, new_level: int, unlocked_items: Array[String]) -> void:
	for level in range(old_level + 1, new_level + 1):
		match level:
			1:
				SaveManager.set_unlocked("weapon_codex", weapon_id)
				unlocked_items.append("武器图鉴：%s" % String(weapon_id))
			2:
				SaveManager.set_unlocked("weapon_skin", StringName("%s_skin_1" % String(weapon_id)))
				unlocked_items.append("武器皮肤：%s" % String(weapon_id))
			3:
				SaveManager.set_unlocked("weapon_branch_records", weapon_id)
				unlocked_items.append("分支纪录：%s" % String(weapon_id))
			4:
				SaveManager.set_unlocked("weapon_exclusive_relic", weapon_id)
				unlocked_items.append("专属遗物池：%s" % String(weapon_id))
			5:
				SaveManager.set_unlocked("weapon_vfx", StringName("%s_master_vfx" % String(weapon_id)))
				unlocked_items.append("武器特效：%s" % String(weapon_id))
			6:
				SaveManager.set_unlocked("weapon_challenge_stage", weapon_id)
				unlocked_items.append("武器挑战关：%s" % String(weapon_id))
			7:
				SaveManager.set_unlocked("weapon_title", StringName("%s_golden_title" % String(weapon_id)))
				unlocked_items.append("金边称号：%s" % String(weapon_id))


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


static func _update_fixed_challenges(summary: Dictionary, unlocked_items: Array[String]) -> void:
	if not bool(summary.get("victory", false)):
		return

	var pools: Array = []
	pools.append_array(GameData.get_daily_challenge_pool())
	pools.append_array(GameData.get_weekly_challenge_pool())
	for challenge: Dictionary in pools:
		if StringName(String(challenge.get("character_id", ""))) != StringName(String(summary.get("selected_character_id", ""))):
			continue
		if StringName(String(challenge.get("weapon_id", ""))) != StringName(String(summary.get("selected_weapon_id", ""))):
			continue
		if StringName(String(challenge.get("map_id", ""))) != StringName(String(summary.get("selected_map_id", ""))):
			continue
		var challenge_id: StringName = StringName(String(challenge.get("challenge_id", "")))
		if SaveManager.mark_challenge_completed(challenge_id):
			unlocked_items.append("挑战完成：%s" % String(challenge.get("display_name", challenge_id)))


static func _get_character_goal_ids(character_id: StringName) -> Array:
	var goals_data: Dictionary = GameData.get_progression_goals()
	for entry_variant: Variant in _get_array(goals_data.get("character_specializations", [])):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if StringName(String(entry.get("character_id", ""))) == character_id:
			return _get_array(entry.get("goals", []))
	return []


static func _get_map_objectives(map_id: StringName) -> Array:
	var goals_data: Dictionary = GameData.get_progression_goals()
	for entry_variant: Variant in _get_array(goals_data.get("map_challenges", [])):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if StringName(String(entry.get("map_id", ""))) == map_id:
			return _get_array(entry.get("objectives", []))
	return []


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
		"avoid_toxic_fog_overdamage":
			return victory and int(stats.get("poison_instances_taken", 0)) < 5
		"clear_with_dot_branch":
			return victory and (_has_weapon_tag(summary, "dot") or _damage_origin_share_at_least(stats, "dot", 0.35))
		"clear_all_toxic_fog_events":
			return victory and int(stats.get("poison_instances_taken", 0)) < 5
		"survive_lava_fissures":
			return victory and int(stats.get("lava_hits_taken", 0)) <= 0
		"clear_with_control_branch":
			return victory and (_has_weapon_tag(summary, "control") or _has_status_count(stats, ["freeze", "slow", "stun", "paralyze"], 30))
		"survive_encirclement":
			return victory and int(stats.get("highest_alive_normal_enemies", 0)) < 120
		"clear_with_pierce_or_bounce":
			return victory and (_has_weapon_tag(summary, "pierce") or _has_weapon_tag(summary, "chain") or _has_status_count(stats, ["shock", "overload"], 20))
		"defeat_toxic_matriarch", "defeat_lava_golem", "defeat_shadow_hunter":
			return victory and int(stats.get("elite_kill_count", 0)) > 0
		_:
			return false


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


static func _has_weapon_tag(summary: Dictionary, tag: String) -> bool:
	var weapon: Dictionary = GameData.get_weapon(StringName(String(summary.get("selected_weapon_id", ""))))
	for value: Variant in _get_array(weapon.get("tags", [])):
		if String(value) == tag:
			return true
	for value: Variant in _get_array(weapon.get("upgrade_tag_pool", [])):
		if String(value) == tag:
			return true
	return false


static func _damage_origin_share_at_least(stats: Dictionary, origin: String, threshold: float) -> bool:
	var damage_by_origin: Dictionary = _get_dictionary(stats.get("damage_done_by_origin", {}))
	var total: float = maxf(float(stats.get("damage_done_total", _sum_dictionary(damage_by_origin))), 1.0)
	return float(damage_by_origin.get(origin, 0)) / total >= threshold


static func _has_status_count(stats: Dictionary, status_ids: Array[String], min_count: int) -> bool:
	var counts: Dictionary = _get_dictionary(stats.get("status_counts", {}))
	var total: int = 0
	for status_id: String in status_ids:
		total += int(counts.get(status_id, 0))
	return total >= min_count


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


static func _sum_dictionary(dictionary: Dictionary) -> int:
	var total: int = 0
	for value: Variant in dictionary.values():
		total += int(value)
	return total
