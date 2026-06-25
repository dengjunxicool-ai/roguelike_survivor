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
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return int(player.get("level"))
	var character: Dictionary = GameData.get_character(StringName(String(player.get("selected_character_id"))))
	var skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill: RefCounted = skill_variant as RefCounted
		if skill != null and StringName(String(skill.get("skill_id"))) == skill_id:
			return int(skill.get("current_level"))
	return 1


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
		"run_stats": get_run_stats_summary(tracker),
		"progression_summary": context.get("progression_summary", {})
	}
