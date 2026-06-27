extends RefCounted
class_name EnemyHealthApplicationStage


const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

var stage_name: StringName = &"enemy_health_apply"


func apply_with_host(host: Object, context: RefCounted) -> void:
	var enemy: Node = context.get("target") as Node
	var amount_or_packet: Variant = context.get("amount_or_packet")
	var damage_result: Dictionary = context.get("damage_result")
	var final_amount: int = int(context.get("final_amount"))
	var current_health: int = maxi(int(enemy.get("current_health")) - final_amount, 0)
	enemy.set("current_health", current_health)
	enemy.set_meta("last_damage_was_critical", bool(damage_result.get("is_critical", false)))
	enemy.set_meta("last_damage_element", String(damage_result.get("element", "")))
	enemy.set_meta("last_damage_type", String(damage_result.get("damage_type", "")))
	enemy.set_meta("last_damage_source_key", String(enemy.call("_get_damage_source_key", amount_or_packet, damage_result)))
	DamageTraceContextScript.persist_last_damage_trace(enemy, amount_or_packet, damage_result)
	enemy.call("_record_damage_done", final_amount, damage_result, amount_or_packet)
	DebugCombatTraceScript.record_damage(_get_root_node(), enemy, amount_or_packet, damage_result, final_amount)
	enemy.emit_signal("health_changed", current_health, int(enemy.get("max_health")))
	enemy.call("_show_debug_damage_number", final_amount, damage_result)
	enemy.call("_update_debug_health_display")
	if enemy.has_method("_show_hurt_visual"):
		enemy.call("_show_hurt_visual")
	_emit_post_damage_hit(enemy, amount_or_packet, damage_result, final_amount, current_health)
	if current_health == 0:
		enemy.call("_die")
	context.call("set_result", host.call("make_result", true, final_amount, damage_result, &"applied"))


func _emit_post_damage_hit(enemy: Node, amount_or_packet: Variant, damage_result: Dictionary, final_amount: int, current_health: int) -> void:
	if enemy == null or final_amount <= 0:
		return
	var player: Node = _resolve_player(enemy, amount_or_packet)
	if player == null:
		return
	var event_bus: Node = player.get_node_or_null("SkillEventBus")
	if event_bus == null or not event_bus.has_method("emit_skill_event"):
		return
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	var source_skill_id: StringName = StringName(str(_packet_value(amount_or_packet, "source_skill_id", damage_result.get("source_skill_id", ""))))
	var skill_instance: RefCounted = _resolve_skill_instance(skill_manager, source_skill_id)
	var event: Dictionary = {
		"caster": player,
		"owner": player,
		"player": player,
		"target": enemy,
		"enemy": enemy,
		"position": enemy.global_position if enemy is Node2D else Vector2.ZERO,
		"parent": enemy.get_parent(),
		"target_group": &"enemies",
		"damage_amount": final_amount,
		"damage_result": damage_result.duplicate(true),
		"damage_packet": amount_or_packet,
		"damage_origin": str(_packet_value(amount_or_packet, "damage_origin", damage_result.get("damage_origin", ""))),
		"damage_type": StringName(str(_packet_value(amount_or_packet, "damage_type", damage_result.get("damage_type", "")))),
		"element": StringName(str(_packet_value(amount_or_packet, "element", damage_result.get("element", "")))),
		"source_id": StringName(str(_packet_value(amount_or_packet, "source_id", damage_result.get("source_id", "")))),
		"source_skill_id": source_skill_id,
		"skill_id": source_skill_id,
		"skill_instance": skill_instance,
		"skill_manager": skill_manager,
		"relic_manager": player.get_node_or_null("RelicManager"),
		"event_bus": event_bus,
		"target_current_health": current_health,
		"target_max_health": int(enemy.get("max_health")),
		"debug_attack_trace_id": DamageTraceContextScript.get_last_damage_trace_id(enemy)
	}
	event_bus.call("emit_skill_event", &"post_damage_hit", event)


func _resolve_player(enemy: Node, amount_or_packet: Variant) -> Node:
	var attacker: Node = _packet_value(amount_or_packet, "attacker", null) as Node
	if attacker != null:
		if attacker.is_in_group(&"player"):
			return attacker
		var summon_owner: Node = _get_node_property(attacker, "summon_owner")
		if summon_owner != null and summon_owner.is_in_group(&"player"):
			return summon_owner
	var tree: SceneTree = enemy.get_tree() if enemy != null and enemy.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var players: Array = tree.get_nodes_in_group(&"player")
	return players[0] as Node if not players.is_empty() else null


func _resolve_skill_instance(skill_manager: Node, source_skill_id: StringName) -> RefCounted:
	if skill_manager == null or source_skill_id == &"" or not skill_manager.has_method("get_skill"):
		return null
	return skill_manager.call("get_skill", source_skill_id) as RefCounted


func _packet_value(packet: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet is Dictionary:
		return (packet as Dictionary).get(key, fallback)
	if packet is RefCounted and packet.has_method("get_value"):
		return packet.call("get_value", key, fallback)
	return fallback


func _get_node_property(node: Node, property: String) -> Node:
	if node == null:
		return null
	for property_info: Dictionary in node.get_property_list():
		if str(property_info.get("name", "")) == property:
			return node.get(property) as Node
	return null


func _get_root_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null
