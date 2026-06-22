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
	if current_health == 0:
		enemy.call("_die")
	context.call("set_result", host.call("make_result", true, final_amount, damage_result, &"applied"))


func _get_root_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null
