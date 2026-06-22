extends RefCounted
class_name RunHudStateProvider


const RunResultStateBuilderScript: Script = preload("res://scripts/ui/run_result_state_builder.gd")


func build(context: Dictionary) -> Dictionary:
	var tree: SceneTree = context.get("tree", null) as SceneTree
	var state: Dictionary = {
		"run_seconds": float(context.get("run_seconds", 0.0)),
		"run_duration": float(context.get("run_duration", 0.0)),
		"wave_index": int(context.get("wave_index", 0)),
		"wave_id": String(context.get("wave_id", "")),
		"wave_remaining_seconds": float(context.get("wave_remaining_seconds", 0.0)),
		"wave_duration_seconds": float(context.get("wave_duration_seconds", 0.0)),
		"wave_spawned_count": int(context.get("wave_spawned_count", 0)),
		"wave_total_count": int(context.get("wave_total_count", 0)),
		"kill_count": int(context.get("kill_count", 0)),
		"run_stats": RunResultStateBuilderScript.get_run_stats_summary(context.get("run_stats_tracker", null) as Node)
	}
	state["kills"] = int(state.get("kill_count", 0))
	state["souls"] = SaveManager.get_soul_stones()

	var player: Node = tree.get_first_node_in_group(&"player") if is_instance_valid(tree) else null
	_enrich_from_player(state, player)
	state["boss"] = _build_boss_state(tree)
	state["status_summary"] = _get_status_summary(tree)
	state["debug_stats"] = _build_debug_stats(tree)
	return state


func _enrich_from_player(state: Dictionary, player: Node) -> void:
	if not is_instance_valid(player):
		return
	var max_health: float = maxf(1.0, float(player.get("max_health") if player.get("max_health") != null else 100.0))
	var health: float = clampf(float(player.get("current_health") if player.get("current_health") != null else max_health), 0.0, max_health)
	state["max_health"] = max_health
	state["health"] = health
	state["level"] = int(player.get("level") if player.get("level") != null else state.get("level", 1))
	state["exp"] = int(player.get("current_experience") if player.get("current_experience") != null else state.get("exp", 0))
	state["exp_required"] = int(player.get("experience_to_next_level") if player.get("experience_to_next_level") != null else state.get("exp_required", 1))
	state["character_id"] = String(player.get("selected_character_id") if player.get("selected_character_id") != null else state.get("character_id", ""))
	state["current_weapon"] = String(player.get("selected_weapon_id") if player.get("selected_weapon_id") != null else state.get("current_weapon", ""))
	var runtime := player.get_node_or_null("CharacterRuntime")
	if runtime != null:
		state["character_id"] = String(runtime.call("get_character_id"))
		state["current_weapon"] = String(runtime.call("get_equipped_weapon_id"))
		state["main_attack"] = String(runtime.call("get_equipped_weapon_skill_id"))
		state["selected_branch"] = String(runtime.call("get_selected_weapon_branch_id"))
	var skill_level: int = _get_equipped_weapon_skill_level(player)
	if skill_level > 0:
		state["main_attack_level"] = skill_level


func _build_boss_state(tree: SceneTree) -> Dictionary:
	var boss: Node = _find_boss_enemy(tree)
	if not is_instance_valid(boss):
		return {"visible": false}
	var max_health: float = maxf(1.0, float(boss.get("max_health") if boss.get("max_health") != null else 1.0))
	var health: float = clampf(float(boss.get("current_health") if boss.get("current_health") != null else 0.0), 0.0, max_health)
	var enemy_data: Variant = boss.get("enemy_data")
	return {
		"visible": true,
		"max_health": max_health,
		"health": health,
		"name": str(enemy_data.get("name", "Boss")) if enemy_data is Dictionary else "Boss"
	}


func _build_debug_stats(tree: SceneTree) -> Dictionary:
	if not OS.is_debug_build() or not is_instance_valid(tree):
		return {}
	return {
		"fps": Engine.get_frames_per_second(),
		"enemy_count": tree.get_nodes_in_group("enemy").size(),
		"projectile_count": tree.get_nodes_in_group("projectile").size(),
		"pickup_count": tree.get_nodes_in_group("pickup").size()
	}


func _get_equipped_weapon_skill_level(player: Node) -> int:
	if not is_instance_valid(player):
		return 0
	var runtime := player.get_node_or_null("CharacterRuntime")
	var skill_manager := player.get_node_or_null("SkillManager")
	if runtime == null or skill_manager == null or not skill_manager.has_method("get_skill"):
		return 0
	var skill_instance := skill_manager.call("get_skill", StringName(String(runtime.call("get_equipped_weapon_skill_id")))) as RefCounted
	if skill_instance == null:
		return 0
	return int(skill_instance.get("current_level"))


func _get_status_summary(tree: SceneTree) -> String:
	var enemy := _find_priority_enemy(tree)
	if not is_instance_valid(enemy):
		return "-"
	var statuses := _get_dictionary(enemy, ["status_stacks", "_status_stacks", "active_statuses"])
	if statuses.is_empty():
		return "-"
	return _format_count_dictionary(statuses)


func _find_boss_enemy(tree: SceneTree) -> Node:
	if not is_instance_valid(tree):
		return null
	for enemy: Node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var enemy_data := _get_dictionary(enemy, ["enemy_data"])
		var enemy_id := str(enemy_data.get("id", enemy_data.get("type", ""))).to_lower()
		if enemy_id.contains("boss") or bool(enemy_data.get("is_boss", false)):
			return enemy
	return null


func _find_priority_enemy(tree: SceneTree) -> Node:
	if not is_instance_valid(tree):
		return null
	var fallback: Node = null
	for enemy: Node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if fallback == null:
			fallback = enemy
		var statuses := _get_dictionary(enemy, ["status_stacks", "_status_stacks", "active_statuses"])
		if not statuses.is_empty():
			return enemy
	return fallback


func _get_dictionary(object: Object, keys: Array[String]) -> Dictionary:
	for key: String in keys:
		var value: Variant = object.get(key)
		if value is Dictionary:
			return value
	return {}


func _format_count_dictionary(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key: Variant in values.keys():
		var value: Variant = values[key]
		if value is int or value is float:
			if int(value) <= 0:
				continue
			parts.append("%s %d" % [str(key), int(value)])
		elif value:
			parts.append(str(key))
		if parts.size() >= 3:
			break
	return " / ".join(parts) if not parts.is_empty() else "-"
