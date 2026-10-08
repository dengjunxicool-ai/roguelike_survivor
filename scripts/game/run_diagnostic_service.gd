extends RefCounted
class_name RunDiagnosticService


const SkillLearnDefinitionRepositoryScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")


static func build_diagnostic(run_state: Dictionary) -> Dictionary:
	var map_id: StringName = StringName(String(run_state.get("selected_map_id", "abandoned_dungeon")))
	var character_id: StringName = StringName(String(run_state.get("selected_character_id", "mage")))
	var run_seconds: float = float(run_state.get("run_seconds", 0.0))
	var kill_count: int = int(run_state.get("kill_count", 0))
	var run_stats: Dictionary = _get_dictionary(run_state.get("run_stats", {}))
	var damage_taken: int = int(run_stats.get("damage_taken_total", 0))
	var damage_done: int = int(run_stats.get("damage_done_total", 0))
	var recommendation: Dictionary

	if damage_taken > damage_done and damage_taken > 0:
		recommendation = _recommend(character_id, map_id, "优先生存和拾取范围。", "本局承伤高于输出，先补稳定性。")
	elif damage_done == 0 and damage_taken == 0:
		recommendation = _recommend(character_id, map_id, "优先学习技能并保持攻击覆盖。", "本局未记录伤害，暂无法判断输出和承伤表现。")
	elif run_seconds >= 220.0 and kill_count < 120:
		recommendation = _recommend(character_id, map_id, "优先选择伤害、范围和 Boss 压制。", "后期清场效率偏低。")
	else:
		recommendation = _recommend(character_id, map_id, "沿用当前角色，优先补强已拥有技能和神系技能。", "当前数据没有明显短板。")
	var last_source: String = String(run_stats.get("last_damage_source", ""))
	recommendation.merge({
		"death_cause": _source_label(last_source) if last_source != "" else "未记录",
		"boss_dps": float(run_stats.get("boss_dps", 0.0)),
		"boss_core_destroyed_count": int(run_stats.get("boss_core_destroyed_count", 0)),
		"boss_core_average_lifetime": float(run_stats.get("boss_core_average_lifetime", 0.0)),
		"build_summary": _build_summary(run_state),
		"upgrade_summary": _upgrade_summary(_get_dictionary(run_stats.get("upgrade_counts", {}))),
		"damage_share": _damage_shares(_get_dictionary(run_stats.get("damage_done_by_origin", {}))),
		"damage_taken_share": _damage_shares(_get_dictionary(run_stats.get("damage_taken_by_source", {}))),
		"diagnosis_text": String(recommendation.get("reason", "")),
		"next_run_suggestion": String(recommendation.get("summary", "")),
		"recommendation_reason": String(recommendation.get("reason", ""))
	})
	return recommendation


static func _damage_shares(amounts: Dictionary) -> Dictionary:
	var total: float = 0.0
	for amount: Variant in amounts.values():
		total += maxf(float(amount), 0.0)
	var shares: Dictionary = {}
	if total <= 0.0:
		return shares
	for key: Variant in amounts.keys():
		var amount: float = float(amounts[key])
		if amount > 0.0:
			shares[key] = amount / total
	return shares


static func _build_summary(run_state: Dictionary) -> String:
	var parts: Array[String] = []
	var snapshot: Variant = run_state.get("skills_snapshot", [])
	if snapshot is Array:
		for item: Variant in snapshot:
			if not item is Dictionary:
				continue
			var skill: Dictionary = item
			var name: String = String(skill.get("display_name", skill.get("skill_id", "")))
			if name != "":
				parts.append("%s Lv.%d" % [name, int(skill.get("level", 1))])
	return "、".join(parts) if not parts.is_empty() else "未记录技能构筑"


static func _upgrade_summary(upgrade_counts: Dictionary) -> String:
	var counts_by_name: Dictionary = {}
	for key: Variant in upgrade_counts.keys():
		var count: int = int(upgrade_counts[key])
		if count <= 0:
			continue
		var name: String = _upgrade_name(String(key))
		counts_by_name[name] = int(counts_by_name.get(name, 0)) + count
	var names: Array = counts_by_name.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_count: int = int(counts_by_name[a])
		var b_count: int = int(counts_by_name[b])
		return a_count > b_count if a_count != b_count else String(a) < String(b)
	)
	var parts: Array[String] = []
	for name: Variant in names:
		parts.append("%s ×%d" % [String(name), int(counts_by_name[name])])
	return "、".join(parts) if not parts.is_empty() else "本局未选择升级"


static func _upgrade_name(option_id: String) -> String:
	var parts: PackedStringArray = option_id.split(":")
	if parts.size() > 1 and parts[0] == "skill_level_up":
		var skill: Dictionary = GameData.get_skill(StringName(parts[1]))
		return "%s升级" % String(skill.get("display_name", parts[1]))
	var upgrade_id: String = parts[1] if parts.size() > 1 and parts[0] == "level_up_upgrade" else option_id
	var upgrade: Dictionary = SkillLearnDefinitionRepositoryScript.resolve_upgrade(StringName(upgrade_id))
	if upgrade.is_empty():
		for candidate: Dictionary in GameData.get_level_up_upgrade_pool():
			if String(candidate.get("id", "")) == upgrade_id:
				upgrade = candidate
				break
	return String(upgrade.get("display_name", upgrade_id))


static func _source_label(source: String) -> String:
	match source:
		"boss":
			return "Boss"
		"enemy":
			return "敌人"
		"contact", "physical":
			return "接触伤害"
		"poison":
			return "中毒"
		"ranged", "projectile":
			return "远程伤害"
		"map_toxic_fog":
			return "毒雾"
		"area":
			return "区域伤害"
		"fire", "lava", "map_lava":
			return "火焰/岩浆"
		_:
			return source


static func _recommend(character_id: StringName, map_id: StringName, summary: String, reason: String) -> Dictionary:
	return {
		"recommended_character_id": character_id,
		"recommended_map_id": map_id,
		"summary": summary,
		"reason": reason
	}


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
