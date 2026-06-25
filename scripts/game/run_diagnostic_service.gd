extends RefCounted
class_name RunDiagnosticService


static func build_diagnostic(run_state: Dictionary) -> Dictionary:
	var map_id: StringName = StringName(String(run_state.get("selected_map_id", "abandoned_dungeon")))
	var character_id: StringName = StringName(String(run_state.get("selected_character_id", "mage")))
	var run_seconds: float = float(run_state.get("run_seconds", 0.0))
	var kill_count: int = int(run_state.get("kill_count", 0))
	var run_stats: Dictionary = _get_dictionary(run_state.get("run_stats", {}))
	var damage_taken: int = int(run_stats.get("damage_taken_total", 0))
	var damage_done: int = int(run_stats.get("damage_done_total", 0))

	if damage_taken > damage_done and damage_taken > 0:
		return _recommend(character_id, map_id, "优先生存和拾取范围。", "本局承伤高于输出，先补稳定性。")
	if run_seconds >= 220.0 and kill_count < 120:
		return _recommend(character_id, map_id, "优先选择伤害、范围和 Boss 压制。", "后期清场效率偏低。")
	return _recommend(character_id, map_id, "沿用当前角色，优先补强已拥有技能和神系技能。", "当前数据没有明显短板。")


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
