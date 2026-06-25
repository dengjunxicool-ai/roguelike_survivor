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
	var runtime := player.get_node_or_null("CharacterRuntime")
	if runtime != null:
		state["character_id"] = String(runtime.call("get_character_id"))
		state["main_attack"] = String(runtime.call("get_starting_skill_id"))
	var skill_level: int = _get_starting_skill_level(player)
	if skill_level > 0:
		state["main_attack_level"] = skill_level
	state["skills"] = _build_skill_slots(player)


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


func _get_starting_skill_level(player: Node) -> int:
	if not is_instance_valid(player):
		return 0
	var runtime := player.get_node_or_null("CharacterRuntime")
	var skill_manager := player.get_node_or_null("SkillManager")
	if runtime == null or skill_manager == null or not skill_manager.has_method("get_skill"):
		return 0
	var skill_instance := skill_manager.call("get_skill", StringName(String(runtime.call("get_starting_skill_id")))) as RefCounted
	if skill_instance == null:
		return 0
	return int(skill_instance.get("current_level"))


func _build_skill_slots(player: Node) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if not is_instance_valid(player):
		return slots
	var skill_manager := player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return slots
	var skill_instances_variant: Variant = skill_manager.call("get_all_skills")
	if not (skill_instances_variant is Array):
		return slots
	for skill_variant: Variant in skill_instances_variant:
		var skill_instance := skill_variant as RefCounted
		if skill_instance == null:
			continue
		var skill_id: String = _string_from_value(skill_instance.get("skill_id"))
		if skill_id == "":
			continue
		var definition := skill_instance.get("definition") as RefCounted
		var cooldown_remaining: float = maxf(float(skill_instance.get("cooldown_remaining")), 0.0)
		var cooldown_total: float = _resolve_skill_cooldown_total(definition)
		if _is_dash_skill(skill_instance, definition):
			cooldown_remaining = _get_player_float(player, "_dash_cooldown_remaining", cooldown_remaining)
			cooldown_total = _get_player_float(player, "dash_cooldown", cooldown_total)
		if cooldown_remaining > cooldown_total:
			cooldown_total = cooldown_remaining
		slots.append({
			"id": skill_id,
			"display_name": _resolve_skill_display_name(skill_id, definition),
			"level": int(skill_instance.get("current_level")),
			"cooldown_remaining": cooldown_remaining,
			"cooldown_total": cooldown_total,
			"icon": _resolve_skill_icon_path(skill_id, definition)
		})
	return slots


func _resolve_skill_display_name(skill_id: String, definition: RefCounted) -> String:
	if definition != null:
		var display_name: String = _string_from_value(definition.get("display_name"))
		if display_name != "":
			return display_name
		var name: String = _string_from_value(definition.get("name"))
		if name != "":
			return name
	var skill_data: Dictionary = GameData.get_skill(StringName(skill_id))
	return String(skill_data.get("display_name", skill_id))


func _resolve_skill_icon_path(skill_id: String, definition: RefCounted) -> String:
	if definition != null:
		for key: String in ["icon", "texture", "background_texture"]:
			var value: String = _string_from_value(definition.get(key))
			if value != "":
				return value
		var visual: Dictionary = _get_dictionary_from_value(definition.get("visual"))
		for key: String in ["icon", "texture", "background_texture"]:
			var value: String = String(visual.get(key, ""))
			if value != "":
				return value
	var skill_data: Dictionary = GameData.get_skill(StringName(skill_id))
	for key: String in ["icon", "texture", "background_texture"]:
		var data_value: String = String(skill_data.get(key, ""))
		if data_value != "":
			return data_value
	var data_visual: Dictionary = _get_dictionary_from_value(skill_data.get("visual", {}))
	for key: String in ["icon", "texture", "background_texture"]:
		var visual_value: String = String(data_visual.get(key, ""))
		if visual_value != "":
			return visual_value
	return ""


func _resolve_skill_cooldown_total(definition: RefCounted) -> float:
	if definition == null:
		return 0.0
	for rule_variant: Variant in _get_array_from_value(definition.get("trigger_rules")):
		if not (rule_variant is Dictionary):
			continue
		var rule: Dictionary = rule_variant
		if String(rule.get("trigger", "")) == "cast_skill" and rule.has("cooldown"):
			return maxf(float(rule.get("cooldown", 0.0)), 0.0)
	for component_variant: Variant in _get_array_from_value(definition.get("components")):
		if not (component_variant is Dictionary):
			continue
		var component: Dictionary = component_variant
		if String(component.get("type", "")) != "cooldown":
			continue
		var params: Dictionary = _get_dictionary_from_value(component.get("params", {}))
		return maxf(float(params.get("seconds", 0.0)), 0.0)
	if definition.has_method("get_base_stat"):
		return maxf(float(definition.call("get_base_stat", "cooldown", 0.0)), 0.0)
	var base: Dictionary = _get_dictionary_from_value(definition.get("base"))
	return maxf(float(base.get("cooldown", 0.0)), 0.0)


func _is_dash_skill(skill_instance: RefCounted, definition: RefCounted) -> bool:
	if skill_instance != null and _string_from_value(skill_instance.get("skill_type")) == "dash":
		return true
	return definition != null and _string_from_value(definition.get("skill_type")) == "dash"


func _get_player_float(player: Node, property_name: String, fallback: float = 0.0) -> float:
	if not is_instance_valid(player):
		return fallback
	var value: Variant = player.get(property_name)
	return fallback if value == null else maxf(float(value), 0.0)


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


func _get_dictionary_from_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_array_from_value(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _string_from_value(value: Variant) -> String:
	return "" if value == null else String(value)


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
