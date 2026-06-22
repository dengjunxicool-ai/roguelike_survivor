extends RefCounted
class_name RunResultStateBuilder


## Params: tracker RunStatsTracker 节点。
## Returns: 单局统计摘要；不存在统计器时返回空字典。
static func get_run_stats_summary(tracker: Node) -> Dictionary:
	if tracker != null and tracker.has_method("get_summary"):
		var summary_variant: Variant = tracker.call("get_summary")
		if summary_variant is Dictionary:
			var summary: Dictionary = summary_variant
			return summary
	return {}


## Params: tree 当前场景树；player_group 玩家分组名；selected_weapon_id 当前武器 ID。
## Returns: 当前主攻击等级。
static func get_main_attack_level(tree: SceneTree, player_group: StringName, selected_weapon_id: StringName) -> int:
	var player: Node = tree.get_first_node_in_group(player_group) if tree != null else null
	if player == null:
		return 1
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return int(player.get("level"))
	var weapon: Dictionary = GameData.get_weapon(selected_weapon_id)
	var skill_id: StringName = StringName(String(weapon.get("starting_skill_id", "")))
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill: RefCounted = skill_variant as RefCounted
		if skill != null and StringName(String(skill.get("skill_id"))) == skill_id:
			return int(skill.get("current_level"))
	return 1


## Params: tree 当前场景树；player_group 玩家分组名。
## Returns: 当前武器分支名称；未选择时返回“未选择”。
static func get_current_branch_name(tree: SceneTree, player_group: StringName) -> String:
	var player: Node = tree.get_first_node_in_group(player_group) if tree != null else null
	var branch_system: Node = player.get_node_or_null("WeaponBranchSystem") if player != null else null
	if branch_system != null and branch_system.has_method("get_selected_branch"):
		var branch_variant: Variant = branch_system.call("get_selected_branch", player)
		if branch_variant is Dictionary:
			var branch: Dictionary = branch_variant
			if not branch.is_empty():
				return String(branch.get("display_name", branch.get("id", "未选择")))
	return "未选择"


## Params: context 结算上下文，包含角色、武器、地图、时间、击杀、魂石和统计器等字段。
## Returns: ResultScreenController 可直接消费的结算状态字典。
static func build_result_state(context: Dictionary) -> Dictionary:
	var tree: SceneTree = context.get("tree", null) as SceneTree
	var player_group: StringName = StringName(String(context.get("player_group", &"player")))
	var selected_weapon_id: StringName = StringName(String(context.get("selected_weapon_id", &"")))
	var tracker: Node = context.get("run_stats_tracker", null) as Node
	return {
		"selected_character_id": context.get("selected_character_id", &""),
		"selected_weapon_id": selected_weapon_id,
		"selected_map_id": context.get("selected_map_id", &""),
		"selected_map_name": String(context.get("selected_map_name", "")),
		"run_seconds": float(context.get("run_seconds", 0.0)),
		"kill_count": int(context.get("kill_count", 0)),
		"run_souls_earned": int(context.get("run_souls_earned", 0)),
		"main_attack_level": get_main_attack_level(tree, player_group, selected_weapon_id),
		"current_branch_name": get_current_branch_name(tree, player_group),
		"run_stats": get_run_stats_summary(tracker),
		"progression_summary": context.get("progression_summary", {})
	}
