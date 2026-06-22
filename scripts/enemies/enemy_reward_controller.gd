extends RefCounted
class_name EnemyRewardController


const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

var _owner: Node2D


## Params:
## - owner: Enemy node that owns reward and kill-side effects.
## Returns:
## - Nothing.
func setup(owner: Node2D) -> void:
	_owner = owner


## Params:
## - None.
## Returns:
## - Nothing.
func award_soul_stones() -> void:
	if _owner == null:
		return

	var soul_drop: int = int(_owner.get("soul_drop"))
	if soul_drop <= 0:
		return

	var multiplier: float = 1.0
	var target: Node = _owner.get("target") as Node
	if target == null:
		target = _find_target_in_group()
	if target != null:
		var multiplier_variant: Variant = target.get("soul_gain_multiplier")
		if multiplier_variant != null:
			multiplier = float(multiplier_variant)

	var final_amount: int = maxi(roundi(float(soul_drop) * multiplier), 0)
	if final_amount > 0:
		SaveManager.add_soul_stones(final_amount)


## Params:
## - amount: Raw incoming damage after normal damage calculation.
## - damage_type: Damage type or element for synergy systems.
## Returns:
## - Damage amount after synergy adjustments.
func apply_damage_synergies(amount: int, damage_type: Variant) -> int:
	var synergy_manager: Node = _get_synergy_manager()
	if synergy_manager == null or not synergy_manager.has_method("on_damage_dealt"):
		return amount

	var event_variant: Variant = synergy_manager.call("on_damage_dealt", {
		"target": _owner,
		"amount": amount,
		"damage_type": StringName(String(damage_type))
	})
	if event_variant is Dictionary:
		var event: Dictionary = event_variant
		return maxi(int(event.get("amount", amount)), 0)

	return amount


## Params:
## - amount: Damage after normal synergy adjustments.
## Returns:
## - Damage after boss-core protection reduction.
func apply_boss_core_damage_reduction(amount: int) -> int:
	if _owner == null or amount <= 0 or String(_owner.get_meta("enemy_rank", _owner.get_meta("enemy_type", ""))) != "boss":
		return amount
	var tree: SceneTree = _owner.get_tree()
	if tree == null:
		return amount
	var core_count: int = tree.get_nodes_in_group(&"boss_cores").size()
	if core_count <= 0:
		return amount
	var reduction: float = minf(float(core_count) * 0.10, 0.20)
	return maxi(roundi(float(amount) * (1.0 - reduction)), 1)


## Params:
## - amount: Final damage amount applied to the owner.
## - damage_result: Full damage calculation result.
## - source_packet: Original damage packet or amount.
## Returns:
## - Nothing.
func record_damage_done(amount: int, damage_result: Dictionary, source_packet: Variant) -> void:
	if _owner == null:
		return
	var tracker: Node = RunStatsTrackerScript.get_active(_owner.get_tree())
	if tracker != null and tracker.has_method("record_damage_done"):
		tracker.call("record_damage_done", _owner, amount, damage_result, source_packet)


## Params:
## - None.
## Returns:
## - Nothing.
func record_boss_core_destroyed() -> void:
	if _owner == null or String(_owner.get_meta("enemy_rank", _owner.get_meta("enemy_type", ""))) != "boss_core":
		return
	var tracker: Node = RunStatsTrackerScript.get_active(_owner.get_tree())
	if tracker != null and tracker.has_method("record_boss_core_destroyed"):
		tracker.call("record_boss_core_destroyed", _owner)


## Params:
## - None.
## Returns:
## - Nothing.
func notify_enemy_killed_synergies() -> void:
	if _owner == null:
		return

	var event: Dictionary = {
		"enemy": _owner,
		"position": _owner.global_position,
		"parent": _owner.get_parent(),
		"target_group": &"enemies",
		"enemy_rank": String(_owner.get_meta("enemy_rank", _owner.get_meta("enemy_type", "normal"))),
		"enemy_type": String(_owner.get_meta("enemy_type", "normal")),
		"source_key": String(_owner.get_meta("last_damage_source_key", "unknown")),
		"debug_attack_trace_id": DamageTraceContextScript.get_last_damage_trace_id(_owner)
	}

	var synergy_manager: Node = _get_synergy_manager()
	if synergy_manager != null and synergy_manager.has_method("on_enemy_killed"):
		synergy_manager.call("on_enemy_killed", event)

	var player: Node = _get_player()
	var trait_system: Node = player.get_node_or_null("CharacterTraitSystem") if player != null else null
	if trait_system != null and trait_system.has_method("handle_enemy_killed"):
		trait_system.call("handle_enemy_killed", event)
	_emit_skill_enemy_killed(player, event)


func _emit_skill_enemy_killed(player: Node, event: Dictionary) -> void:
	if player == null:
		return
	var event_bus: Node = player.get_node_or_null("SkillEventBus")
	if event_bus == null or not event_bus.has_method("emit_skill_event"):
		return
	var runtime: Node = player.get_node_or_null("CharacterRuntime")
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if runtime == null or skill_manager == null or not skill_manager.has_method("get_skill"):
		return
	var skill_id: StringName = StringName(String(runtime.call("get_equipped_weapon_skill_id")))
	var skill_instance: RefCounted = skill_manager.call("get_skill", skill_id) as RefCounted
	if skill_instance == null:
		return
	var skill_event: Dictionary = event.duplicate(true)
	skill_event["caster"] = player
	skill_event["owner"] = player
	skill_event["skill_id"] = skill_id
	skill_event["skill_instance"] = skill_instance
	skill_event["skill_manager"] = skill_manager
	skill_event["relic_manager"] = player.get_node_or_null("RelicManager")
	skill_event["event_bus"] = event_bus
	event_bus.call("emit_skill_event", &"on_enemy_killed", skill_event)


## Params:
## - None.
## Returns:
## - Player synergy manager node when available.
func _get_synergy_manager() -> Node:
	var player: Node = _get_player()
	if player == null:
		return null
	return player.get_node_or_null("SynergyManager")


## Params:
## - None.
## Returns:
## - Current target node resolved from the owner target group.
func _find_target_in_group() -> Node:
	if _owner == null or _owner.get_tree() == null:
		return null
	return _owner.get_tree().get_first_node_in_group(_owner.get("target_group"))


## Params:
## - None.
## Returns:
## - Player node when available.
func _get_player() -> Node:
	if _owner == null or _owner.get_tree() == null:
		return null
	return _owner.get_tree().get_first_node_in_group(&"player")
