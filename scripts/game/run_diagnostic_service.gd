extends RefCounted
class_name RunDiagnosticService


const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"


static func build_diagnostic(result_state: String, run_state: Dictionary) -> Dictionary:
	var stats: Dictionary = _get_dictionary(run_state.get("run_stats", {}))
	var damage_done: Dictionary = _get_dictionary(stats.get("damage_done_by_origin", {}))
	var damage_taken: Dictionary = _get_dictionary(stats.get("damage_taken_by_source", {}))
	var total_damage: float = maxf(float(stats.get("damage_done_total", _sum_dictionary(damage_done))), 1.0)
	var total_taken: float = maxf(float(stats.get("damage_taken_total", _sum_dictionary(damage_taken))), 1.0)

	var damage_share: Dictionary = _build_share(damage_done, total_damage)
	var taken_share: Dictionary = _build_share(damage_taken, total_taken)
	var primary_issue: String = _pick_primary_issue(result_state, run_state, stats, damage_share, taken_share)
	var recommendation: Dictionary = _build_recommendation(primary_issue, run_state)

	return {
		"primary_issue": primary_issue,
		"diagnosis_text": _get_diagnosis_text(primary_issue),
		"death_cause": _format_death_cause(String(stats.get("last_damage_source", ""))),
		"damage_share": damage_share,
		"damage_taken_share": taken_share,
		"boss_dps": float(stats.get("boss_dps", 0.0)),
		"boss_hp_at_30s": float(stats.get("boss_hp_at_30s", -1.0)),
		"boss_core_average_lifetime": float(stats.get("boss_core_average_lifetime", 0.0)),
		"boss_core_destroyed_count": int(stats.get("boss_core_destroyed_count", 0)),
		"build_summary": _format_build_summary(damage_share, stats),
		"upgrade_summary": _format_top_upgrades(_get_dictionary(stats.get("upgrade_counts", {}))),
		"next_run_suggestion": recommendation.get("summary", ""),
		"recommendation_reason": recommendation.get("reason", ""),
		"recommended_character_id": recommendation.get("character_id", run_state.get("selected_character_id", &"mage")),
		"recommended_weapon_id": recommendation.get("weapon_id", run_state.get("selected_weapon_id", &"fire_staff")),
		"recommended_map_id": recommendation.get("map_id", run_state.get("selected_map_id", &"abandoned_dungeon"))
	}


static func _build_share(values: Dictionary, total: float) -> Dictionary:
	var share: Dictionary = {}
	for key: Variant in values.keys():
		share[String(key)] = float(values[key]) / maxf(total, 1.0)
	return share


static func _pick_primary_issue(result_state: String, run_state: Dictionary, stats: Dictionary, damage_share: Dictionary, taken_share: Dictionary) -> String:
	if result_state == STATE_RESULT_VICTORY:
		return "victory"
	if float(stats.get("boss_core_average_lifetime", 0.0)) > 8.0:
		return "targeting"
	if float(stats.get("boss_hp_at_30s", -1.0)) > 0.60:
		return "boss_single_target"
	if float(stats.get("seconds_near_alive_cap", 0.0)) >= 18.0 or int(stats.get("highest_alive_normal_enemies", 0)) >= 110:
		return "wave_clear"
	if float(taken_share.get("contact", taken_share.get("physical", 0.0))) >= 0.55:
		return "surrounded"
	if float(taken_share.get("boss", 0.0)) >= 0.35 or float(taken_share.get("area", 0.0)) >= 0.35:
		return "survival"
	if _get_weapon_level(run_state) < 5 and float(run_state.get("run_seconds", 0.0)) >= 220.0:
		return "growth"
	if _status_share_low(damage_share, run_state):
		return "status_incomplete"
	return "survival"


static func _get_diagnosis_text(issue: String) -> String:
	match issue:
		"victory":
			return "本局构筑完成了通关目标。"
		"wave_clear":
			return "清怪效率不足，中后段普通怪长时间接近场上上限。"
		"boss_single_target":
			return "Boss 单体输出不足，Boss 战 30 秒后血量仍偏高。"
		"status_incomplete":
			return "状态或反应链未成型，DOT / 反应贡献低于当前构筑预期。"
		"survival":
			return "生存压力过高，建议补充防御、移速、护盾或治疗。"
		"surrounded":
			return "移动压力导致被包围，接触伤害占比过高。"
		"growth":
			return "成长速度不足，Boss 前主攻击没有稳定完成 Lv5。"
		"targeting":
			return "目标切换效率不足，腐化核心平均存活时间过长。"
		_:
			return "本局失败原因不明确，建议补充通用输出与生存。"


static func _build_recommendation(issue: String, run_state: Dictionary) -> Dictionary:
	var map_id: StringName = StringName(String(run_state.get("selected_map_id", "abandoned_dungeon")))
	match issue:
		"wave_clear":
			return _recommend(&"mage", &"fire_staff", map_id, "推荐 Mage + Fire Staff，优先爆炸、弹射、领域类清场路线。", "当前波次压力偏高，需要更强范围清怪。")
		"boss_single_target", "targeting":
			return _recommend(&"ranger", &"hunter_bow", map_id, "推荐 Ranger + Hunter's Bow，优先标记、强敌伤害或过载单体路线。", "Boss 或腐化核心处理偏慢，需要更稳定的单体/穿透输出。")
		"status_incomplete":
			return _recommend(&"alchemist", &"toxic_vial", map_id, "推荐 Alchemist + Toxic Vial，优先 DOT、反应和持续时间升级。", "状态链贡献不足，需要更明确的 DOT / 反应构筑。")
		"surrounded":
			return _recommend(&"paladin", &"holy_shield", map_id, "推荐 Paladin + Holy Shield，优先击退、减速、护盾或防御路线。", "接触伤害占比过高，需要自保和控场。")
		"growth":
			return _recommend(StringName(String(run_state.get("selected_character_id", "mage"))), StringName(String(run_state.get("selected_weapon_id", "fire_staff"))), map_id, "沿用当前配装，优先 Stable Growth、拾取范围和主攻击进度。", "Boss 前成长不足，先保证主攻击 Lv5。")
		_:
			return _recommend(&"mage", &"lightning_whip", map_id, "推荐 Mage + Lightning Whip，优先过载、弹射和 Boss 补强。", "需要兼顾清怪、反应和 Boss 单体。")


static func _recommend(character_id: StringName, weapon_id: StringName, map_id: StringName, summary: String, reason: String) -> Dictionary:
	return {
		"character_id": character_id,
		"weapon_id": weapon_id,
		"map_id": map_id,
		"summary": summary,
		"reason": reason
	}


static func _format_build_summary(damage_share: Dictionary, stats: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in ["main_attack", "dot", "reaction", "field", "trap"]:
		if damage_share.has(key):
			parts.append("%s %.0f%%" % [_origin_label(key), float(damage_share[key]) * 100.0])
	if parts.is_empty():
		parts.append("暂无有效伤害统计")
	var status_counts: Dictionary = _get_dictionary(stats.get("status_counts", {}))
	var top_status: String = _top_key(status_counts)
	if top_status != "":
		parts.append("主要状态：%s x%d" % [top_status, int(status_counts[top_status])])
	return "；".join(parts)


static func _format_top_upgrades(upgrade_counts: Dictionary) -> String:
	var entries: Array[Dictionary] = []
	for key: Variant in upgrade_counts.keys():
		entries.append({"id": String(key), "count": int(upgrade_counts[key])})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	var parts: Array[String] = []
	for index: int in range(mini(entries.size(), 3)):
		var entry: Dictionary = entries[index]
		parts.append("%s x%d" % [_format_upgrade_name(String(entry.get("id", ""))), int(entry.get("count", 0))])
	return "、".join(parts) if not parts.is_empty() else "无"


static func _format_upgrade_name(option_id: String) -> String:
	var raw_id: String = option_id
	if raw_id.begins_with("level_up_upgrade:"):
		raw_id = raw_id.trim_prefix("level_up_upgrade:")
	elif raw_id.begins_with("skill_level_up:"):
		var skill_parts: PackedStringArray = raw_id.split(":")
		return "主攻击 Lv.%s" % (skill_parts[2] if skill_parts.size() > 2 else "?")
	elif raw_id.begins_with("branch_choice:"):
		var branch_parts: PackedStringArray = raw_id.split(":")
		return "分支：%s" % (branch_parts[2] if branch_parts.size() > 2 else raw_id)
	var upgrade: Dictionary = GameData.get_upgrade(StringName(raw_id))
	return String(upgrade.get("display_name", raw_id)) if not upgrade.is_empty() else raw_id


static func _format_death_cause(source: String) -> String:
	match source:
		"", "unknown":
			return "未记录"
		"boss":
			return "Boss 技能或接触"
		"contact":
			return "怪物接触伤害"
		"ranged", "projectile":
			return "远程怪物投射物"
		"map_lava", "lava":
			return "地图岩浆"
		"map_toxic_fog", "poison":
			return "毒雾/中毒"
		"area":
			return "范围预警技能"
		_:
			return source


static func _origin_label(origin: String) -> String:
	match origin:
		"main_attack":
			return "主攻击"
		"dot":
			return "DOT"
		"reaction":
			return "反应"
		"field":
			return "领域"
		"trap":
			return "陷阱"
		_:
			return origin


static func _status_share_low(damage_share: Dictionary, run_state: Dictionary) -> bool:
	var weapon_id: String = String(run_state.get("selected_weapon_id", ""))
	if not ["toxic_vial", "acid_sprayer", "lightning_whip", "frost_staff"].has(weapon_id):
		return false
	return float(damage_share.get("dot", 0.0)) + float(damage_share.get("reaction", 0.0)) < 0.22


static func _get_weapon_level(run_state: Dictionary) -> int:
	var player: Node = _get_player()
	if player == null:
		return int(run_state.get("main_attack_level", 1))
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return int(run_state.get("main_attack_level", 1))
	var weapon: Dictionary = GameData.get_weapon(StringName(String(run_state.get("selected_weapon_id", ""))))
	var skill_id: StringName = StringName(String(weapon.get("starting_skill_id", "")))
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill: RefCounted = skill_variant as RefCounted
		if skill != null and StringName(String(skill.get("skill_id"))) == skill_id:
			return int(skill.get("current_level"))
	return int(run_state.get("main_attack_level", 1))


static func _get_player() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"player")


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


static func _top_key(dictionary: Dictionary) -> String:
	var best_key: String = ""
	var best_value: int = 0
	for key: Variant in dictionary.keys():
		var value: int = int(dictionary[key])
		if value > best_value:
			best_key = String(key)
			best_value = value
	return best_key
