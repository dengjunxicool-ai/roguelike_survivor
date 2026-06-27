extends RefCounted
class_name PlayerSkillEventContext


static func build_dash_context(player: Node2D, dash_direction: Vector2, skill_manager: Node, relic_manager: Node, event_bus: Node) -> Dictionary:
	return {
		"player": player,
		"caster": player,
		"owner": player,
		"position": player.global_position,
		"dash_direction": dash_direction,
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": _resolve_parent(player),
		"target_group": &"enemies"
	}


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
