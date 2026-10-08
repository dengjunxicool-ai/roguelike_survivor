extends RefCounted
class_name RunResultStateBuilder


static func get_run_stats_summary(tracker: Node) -> Dictionary:
	if tracker != null and tracker.has_method("get_summary"):
		var summary_variant: Variant = tracker.call("get_summary")
		if summary_variant is Dictionary:
			return summary_variant
	return {}


static func get_main_attack_level(tree: SceneTree, player_group: StringName) -> int:
	var player: Node = tree.get_first_node_in_group(player_group) if tree != null else null
	if player == null:
		return 1
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null:
		return int(player.get("level"))
	if skill_manager.has_method("get_primary_attack_method"):
		var primary: RefCounted = skill_manager.call("get_primary_attack_method") as RefCounted
		if primary != null:
			return int(primary.get("current_level"))
	if not skill_manager.has_method("get_all_skills"):
		return 1
	var character: Dictionary = GameData.get_character(StringName(String(player.get("selected_character_id"))))
	var skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill: RefCounted = skill_variant as RefCounted
		if skill != null and StringName(String(skill.get("skill_id"))) == skill_id:
			return int(skill.get("current_level"))
		if skill != null and String(skill.get("skill_type")) == "attack":
			return int(skill.get("current_level"))
	return 1


static func get_skills_snapshot(tree: SceneTree, player_group: StringName) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	var player: Node = tree.get_first_node_in_group(player_group) if tree != null else null
	var manager: Node = player.get_node_or_null("SkillManager") if player != null else null
	if manager == null:
		return snapshot
	var skills: Array = []
	if manager.has_method("get_active_skills"):
		skills.append_array(manager.call("get_active_skills"))
	if manager.has_method("get_passive_skills"):
		skills.append_array(manager.call("get_passive_skills"))
	for skill_variant: Variant in skills:
		var skill: RefCounted = skill_variant as RefCounted
		if skill == null:
			continue
		var skill_id: StringName = StringName(String(skill.get("skill_id")))
		var definition: Dictionary = GameData.get_skill(skill_id)
		snapshot.append({
			"skill_id": skill_id,
			"display_name": String(definition.get("display_name", skill_id)),
			"level": int(skill.get("current_level")),
			"rarity": String(skill.get("current_rarity")),
			"skill_type": String(skill.get("skill_type"))
		})
	return snapshot


static func get_player_dead(tree: SceneTree, player_group: StringName) -> Variant:
	var player: Node = tree.get_first_node_in_group(player_group) if tree != null else null
	if player == null:
		return null
	if player.has_method("is_dead"):
		return bool(player.call("is_dead"))
	var property_names: Array[String] = []
	for property: Dictionary in player.get_property_list():
		property_names.append(String(property.get("name", "")))
	if property_names.has("_is_dead"):
		return bool(player.get("_is_dead"))
	if property_names.has("current_health"):
		return int(player.get("current_health")) <= 0
	return null


static func build_result_state(context: Dictionary) -> Dictionary:
	var tree: SceneTree = context.get("tree", null) as SceneTree
	var player_group: StringName = StringName(String(context.get("player_group", &"player")))
	var tracker: Node = context.get("run_stats_tracker", null) as Node
	return {
		"selected_character_id": context.get("selected_character_id", &""),
		"selected_map_id": context.get("selected_map_id", &""),
		"selected_map_name": String(context.get("selected_map_name", "")),
		"run_seconds": float(context.get("run_seconds", 0.0)),
		"kill_count": int(context.get("kill_count", 0)),
		"run_souls_earned": int(context.get("run_souls_earned", 0)),
		"main_attack_level": get_main_attack_level(tree, player_group),
		"player_dead": get_player_dead(tree, player_group),
		"skills_snapshot": get_skills_snapshot(tree, player_group),
		"run_stats": get_run_stats_summary(tracker),
		"progression_summary": context.get("progression_summary", {})
	}
