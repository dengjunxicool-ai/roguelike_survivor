extends RefCounted
const IDS: Array[String] = ["meteor_burning_ground","lava_rift","fire_ground","inferno_fire_ground","searing_fire_path","blazing_run_path"]
static func is_fire_ground(area: Node) -> bool:
	return area != null and String(area.get("source_id")) in IDS
static func burning_bonus(target: Node2D, player: Node) -> float:
	if target == null or player == null or target.get_tree() == null: return 0.0
	var manager: Node = player.get_node_or_null("SkillManager")
	var skill: RefCounted = manager.get_skill(&"fire_passive_scorched_ground_affinity") if manager != null else null
	if skill == null: return 0.0
	var areas: Node = target.get_tree().root.get_node_or_null("AreaEffectManager")
	if areas == null: return 0.0
	for area: Node in areas.get_active_areas():
		if not is_fire_ground(area) or area.is_queued_for_deletion(): continue
		if area is AreaEffect and (area._damage_window_finished or area._age >= area.duration or (area._dash_path_filter and not area._is_body_on_dash_path(target))): continue
		if area._body_in_effect_shape(target) if area.has_method("_body_in_effect_shape") else (area as Node2D).global_position.distance_squared_to(target.global_position) <= pow(float(area.get("radius")), 2):
			var rule: Dictionary = skill.definition.trigger_rules[0]
			return preload("res://scripts/skills/skill_growth_scaling.gd").apply_to_number(float(rule.effects[0].value), skill, "modifier")
	return 0.0
