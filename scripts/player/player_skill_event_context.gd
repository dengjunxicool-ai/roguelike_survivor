extends RefCounted
class_name PlayerSkillEventContext


static func build_dash_context(player: Node2D, dash_direction: Vector2, skill_manager: Node, relic_manager: Node, event_bus: Node) -> Dictionary:
	var dash_start: Vector2 = player.global_position if player != null else Vector2.ZERO
	var dash_end: Vector2 = dash_start + dash_direction.normalized() * _dash_remaining_distance(player)
	return {
		"player": player,
		"caster": player,
		"owner": player,
		"position": player.global_position,
		"dash_direction": dash_direction,
		"dash_path_start": dash_start,
		"dash_path_end": dash_end,
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": _resolve_parent(player),
		"target_group": &"enemies"
	}


static func _dash_remaining_distance(player: Node) -> float:
	if player == null:
		return 0.0
	return maxf(float(player.get("dash_speed")) * float(player.get("_dash_time_remaining")), 0.0)


static func build_damage_taken_context(player: Node2D, source_packet: Variant, damage_result: Dictionary, amount: int, skill_manager: Node, relic_manager: Node, event_bus: Node) -> Dictionary:
	return {
		"player": player,
		"caster": player,
		"owner": player,
		"target": player,
		"parent": _resolve_parent(player),
		"source_packet": source_packet,
		"damage_result": damage_result,
		"amount": amount,
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"target_group": &"enemies"
	}


static func build_skill_instance_damage_context(player: Node2D, source_packet: Variant, damage_result: Dictionary, amount: int, skill_instance: RefCounted, skill_manager: Node, relic_manager: Node) -> Dictionary:
	return {
		"player": player,
		"caster": player,
		"parent": _resolve_parent(player),
		"source_packet": source_packet,
		"damage_result": damage_result,
		"amount": amount,
		"skill_instance": skill_instance,
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"target_group": &"enemies"
	}


static func build_damage_rule_context(player: Node2D, source_packet: Variant, damage_result: Dictionary, skill_instance: RefCounted) -> Dictionary:
	return {
		"player": player,
		"caster": player,
		"parent": _resolve_parent(player),
		"source_packet": source_packet,
		"damage_result": damage_result,
		"skill_instance": skill_instance,
		"target_group": &"enemies"
	}


static func _resolve_parent(player: Node) -> Node:
	if player == null:
		return null
	var tree: SceneTree = player.get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	return player.get_parent()
