extends Node
class_name StatusEffectManager


const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")
const SkillEffectAdapterScript: Script = preload("res://scripts/skills/skill_effect_adapter.gd")
const DOT_STATUS_IDS: Array[StringName] = [&"burn", &"burning", &"poison", &"bleed"]
const MOVEMENT_LOCK_STATUS_IDS: Array[StringName] = [&"freeze", &"frozen", &"stun", &"paralyze"]
const STATUS_VISUAL_NODE_NAME: String = "StatusVisualOverlay"

var _statuses: Dictionary = {}
var _status_visual_overlay: Node2D
var _status_visual_key: String = ""


func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"":
		return false

	var definition: Dictionary = _get_status_definition(id)
	if definition.is_empty():
		push_warning("[StatusEffectManager] Unknown status_id: %s" % String(id))
		return false

	definition = _apply_enemy_tier_rules(id, definition)
	if definition.is_empty():
		return false

	var converted_status_id: StringName = StringName(String(definition.get("convert_to_status", "")))
	if converted_status_id != &"" and converted_status_id != id:
		var converted_params: Dictionary = params.duplicate(true)
		for key: Variant in definition.keys():
			if key != "convert_to_status" and not converted_params.has(key):
				converted_params[key] = definition[key]
		return apply_status(converted_status_id, converted_params)

	var status: Dictionary = _statuses.get(id, {}).duplicate(true)
	var stacks_to_add: int = maxi(int(params.get("stacks", params.get("stack", 1))), 1)
	var max_stacks: int = maxi(int(params.get("max_stacks", definition.get("max_stacks", 1))), 1)
	var current_stacks: int = int(status.get("stacks", 0))
	var new_stacks: int = mini(current_stacks + stacks_to_add, max_stacks)
	var duration: float = maxf(float(params.get("duration", definition.get("duration", 1.0))), 0.05)

	status["id"] = id
	status["definition"] = definition
	status["stacks"] = new_stacks
	status["duration_remaining"] = maxf(float(status.get("duration_remaining", 0.0)), duration)
	status["tick_interval"] = maxf(float(params.get("tick_interval", definition.get("tick_interval", 0.5))), 0.05)
	var configured_tick_damage: float = maxf(float(params.get("tick_damage", params.get("damage", definition.get("damage", 0.0)))), 0.0)
	configured_tick_damage = maxf(configured_tick_damage * maxf(1.0 + float(params.get("damage_multiplier_add", 0.0)), 0.0), 0.0)
	status["tick_damage"] = configured_tick_damage
	status["damage_type"] = StringName(String(params.get("damage_type", definition.get("damage_type", id))))
	status["element"] = StringName(String(params.get("element", definition.get("element", id))))
	status["on_tick_effects"] = _get_array(definition.get("on_tick_effects", definition.get("on_tick", [])))
	status["on_expire_effects"] = _get_array(definition.get("on_expire", definition.get("on_expire_effects", [])))
	status = DamageTraceContextScript.apply_to_status_params(status, params)
	status["slow_percent"] = clampf(float(params.get("slow_percent", definition.get("slow_percent", _get_effect_value(definition, "slow_percent", 0.0)))), 0.0, 0.95)
	if _is_boss() and params.has("boss_slow_percent"):
		status["slow_percent"] = clampf(float(params.get("boss_slow_percent", status["slow_percent"])), 0.0, 0.95)
	status["armor_break_multiplier_add"] = maxf(
		float(params.get("armor_break_multiplier_add", definition.get("armor_break_multiplier_add", _get_effect_value(definition, "physical_damage_taken_multiplier_add_per_stack", 0.0)))),
		0.0
	)
	if params.has("direct_damage_multiplier_add_per_stack"):
		status["direct_damage_multiplier_add_per_stack"] = float(params.get("direct_damage_multiplier_add_per_stack", 0.0))
	for vulnerability_key: String in [
		"all_damage_taken_multiplier_add_per_stack",
		"fire_damage_taken_multiplier_add_per_stack",
		"direct_magical_damage_taken_multiplier_add_per_stack",
		"direct_damage_taken_multiplier_add_per_stack",
	]:
		if params.has(vulnerability_key):
			status[vulnerability_key] = float(params.get(vulnerability_key, 0.0))
	if params.has("full_stack_explosion_damage_taken_multiplier_add"):
		status["full_stack_explosion_damage_taken_multiplier_add"] = float(params.get("full_stack_explosion_damage_taken_multiplier_add", 0.0))
		status["full_stack_required_stacks"] = int(params.get("full_stack_required_stacks", max_stacks))

	var next_tick_interval: float = float(status["tick_interval"])
	status["tick_timer"] = minf(float(status.get("tick_timer", next_tick_interval)), next_tick_interval)
	_statuses[id] = status
	_refresh_status_visual()

	_notify_status_applied(id, status)
	if new_stacks >= max_stacks and current_stacks < max_stacks:
		_handle_max_stack_reached(id, status)
	_apply_poison_slow_synergy()
	return true


func update_status_effects(delta: float) -> void:
	if delta <= 0.0:
		return

	var expired_statuses: Array[StringName] = []
	var expired_snapshots: Dictionary = {}
	for id_variant: Variant in _statuses.keys():
		var id: StringName = StringName(String(id_variant))
		var status: Dictionary = _statuses[id]
		status["duration_remaining"] = float(status.get("duration_remaining", 0.0)) - delta

		if _is_dot_status(status):
			_update_damage_over_time(status, delta)

		if float(status.get("duration_remaining", 0.0)) <= 0.0:
			expired_statuses.append(id)
			expired_snapshots[id] = status.duplicate(true)
		else:
			_statuses[id] = status

	for id: StringName in expired_statuses:
		_statuses.erase(id)
		var expired_status: Dictionary = _get_dictionary(expired_snapshots.get(id, {}))
		_execute_status_effects(expired_status, "on_expire_effects")
		_emit_status_skill_event(&"status_expired", id, expired_status)
	if not expired_statuses.is_empty():
		_refresh_status_visual()
	_apply_poison_slow_synergy()


func has_status(status_id: Variant) -> bool:
	return _statuses.has(StringName(String(status_id)))


func get_status_stack(status_id: Variant) -> int:
	var id: StringName = StringName(String(status_id))
	if not _statuses.has(id):
		return 0

	var status: Dictionary = _statuses[id]
	return int(status.get("stacks", 0))


func consume_shock_stack() -> bool:
	return consume_status_stack(&"shock", 1)


func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"" or not _statuses.has(id):
		return false

	var status: Dictionary = _statuses[id]
	var stacks: int = int(status.get("stacks", 0)) - maxi(stack_count, 1)
	if stacks <= 0:
		_statuses.erase(id)
	else:
		status["stacks"] = stacks
		_statuses[id] = status

	_refresh_status_visual()
	return true


func consume_status_duration(status_id: Variant, seconds: float) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"" or not _statuses.has(id):
		return false

	var status: Dictionary = _statuses[id]
	status["duration_remaining"] = float(status.get("duration_remaining", 0.0)) - maxf(seconds, 0.0)
	if float(status.get("duration_remaining", 0.0)) <= 0.0:
		_statuses.erase(id)
		_execute_status_effects(status, "on_expire_effects")
		_emit_status_skill_event(&"status_expired", id, status)
	else:
		_statuses[id] = status

	_refresh_status_visual()
	_apply_poison_slow_synergy()
	return true


func get_status_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for status_variant: Variant in _statuses.values():
		if not (status_variant is Dictionary):
			continue
		var status: Dictionary = status_variant
		snapshot.append({
			"id": StringName(String(status.get("id", ""))),
			"stacks": int(status.get("stacks", 0)),
			"duration_remaining": float(status.get("duration_remaining", 0.0)),
			"tick_interval": float(status.get("tick_interval", 0.0)),
			"tick_damage": float(status.get("tick_damage", 0.0)),
			"damage_type": StringName(String(status.get("damage_type", ""))),
			"element": StringName(String(status.get("element", "")))
		})
	return snapshot


func clear_statuses() -> void:
	_statuses.clear()
	_refresh_status_visual()


func is_movement_frozen() -> bool:
	for status_id: StringName in MOVEMENT_LOCK_STATUS_IDS:
		if has_status(status_id):
			return true
	return false


func get_move_speed_multiplier() -> float:
	var slow_percent: float = 0.0
	for id_variant: Variant in _statuses.keys():
		var status: Dictionary = _statuses[id_variant]
		var definition: Dictionary = _get_dictionary(status.get("definition", {}))
		var stacks: int = maxi(int(status.get("stacks", 1)), 1)
		if _get_effect_bool(definition, "locks_movement", false) and not MOVEMENT_LOCK_STATUS_IDS.has(StringName(String(id_variant))):
			return 0.0
		slow_percent += float(status.get("slow_percent", 0.0))
		slow_percent += _get_effect_value(definition, "move_slow_per_stack", 0.0) * float(stacks)

	var max_slow: float = 0.60
	if _is_boss():
		max_slow = 0.35
	elif _is_elite():
		max_slow = 0.35

	return maxf(1.0 - clampf(slow_percent, 0.0, max_slow), 0.05)


func get_damage_taken_multiplier(damage_type: Variant = &"", category: Variant = &"") -> float:
	return 1.0 + get_vulnerability_total(damage_type, category, {})


func get_vulnerability_total(damage_type: Variant = &"", category: Variant = &"", packet: Variant = {}) -> float:
	var type_name: String = String(damage_type)
	var category_name: String = String(category)
	var multiplier_add: float = 0.0
	for status_variant: Variant in _statuses.values():
		var status: Dictionary = status_variant
		var definition: Dictionary = _get_dictionary(status.get("definition", {}))
		var stacks: float = float(maxi(int(status.get("stacks", 1)), 1))
		var effect: Dictionary = _get_dictionary(definition.get("effect", {}))

		multiplier_add += float(effect.get("all_damage_taken_multiplier_add_per_stack", 0.0)) * stacks
		multiplier_add += float(effect.get("%s_damage_taken_multiplier_add_per_stack" % type_name, 0.0)) * stacks
		multiplier_add += float(status.get("all_damage_taken_multiplier_add_per_stack", 0.0)) * stacks
		multiplier_add += float(status.get("%s_damage_taken_multiplier_add_per_stack" % type_name, 0.0)) * stacks
		if category_name != "":
			multiplier_add += float(effect.get("%s_damage_taken_multiplier_add_per_stack" % category_name, 0.0)) * stacks
			multiplier_add += float(status.get("%s_damage_taken_multiplier_add_per_stack" % category_name, 0.0)) * stacks
		if type_name == "physical" or category_name == "direct_physical":
			multiplier_add += float(status.get("armor_break_multiplier_add", 0.0)) * stacks
		if effect.has("next_damage_taken_multiplier_add") and _can_consume_next_damage_taken(packet):
			multiplier_add += float(effect.get("next_damage_taken_multiplier_add", 0.0))
		if _is_full_stack_explosion_vulnerability_active(status, packet):
			multiplier_add += float(status.get("full_stack_explosion_damage_taken_multiplier_add", 0.0))

	var cap_add: float = 0.30
	var floor_value: float = -0.60
	if _is_boss():
		cap_add = 0.15
		floor_value = -0.50
	elif _is_elite():
		cap_add = 0.20
	return clampf(multiplier_add, floor_value, cap_add)


func _update_damage_over_time(status: Dictionary, delta: float) -> void:
	var tick_interval: float = maxf(
		float(status.get("tick_interval", 0.5)) * float(status.get("tick_interval_multiplier", 1.0)),
		0.05
	)
	var tick_timer: float = float(status.get("tick_timer", tick_interval)) - delta
	var tick_damage: float = float(status.get("tick_damage", 0.0))
	var stacks: int = int(status.get("stacks", 1))

	while tick_timer <= 0.0 and _has_status_tick_work(status) and float(status.get("duration_remaining", 0.0)) > 0.0:
		if tick_damage > 0:
			_apply_tick_damage(_get_tier_scaled_dot_damage(status, tick_damage * stacks), status)
		_execute_status_effects(status, "on_tick_effects")
		_emit_status_skill_event(&"status_tick", StringName(String(status.get("id", ""))), status)
		tick_timer += tick_interval

	status["tick_timer"] = tick_timer


func _apply_tick_damage(amount: float, status: Dictionary = {}) -> void:
	var owning_node: Node = get_parent()
	if owning_node == null or amount <= 0:
		return

	var tick_packet_args: Dictionary = {
		"target": owning_node,
		"status": status,
		"amount": amount,
		"element": StringName(String(status.get("element", status.get("id", "status")))),
		"damage_type": StringName(String(status.get("damage_type", &"status_dot"))),
		"ignore_target_class_origin_modifier": _is_boss() or _is_elite()
	}
	if owning_node.has_method("take_damage"):
		owning_node.call(&"take_damage", DamagePacketBuilderScript.from_status_dot(tick_packet_args))


func _has_status_tick_work(status: Dictionary) -> bool:
	return float(status.get("tick_damage", 0.0)) > 0.0 or not _get_array(status.get("on_tick_effects", [])).is_empty()


func _handle_max_stack_reached(status_id: StringName, status: Dictionary) -> void:
	_emit_status_skill_event(&"status_max_stack_reached", status_id, status)
	var definition: Dictionary = _get_dictionary(status.get("definition", {}))
	var max_stack_status: StringName = StringName(String(definition.get("max_stack_status", "")))
	if max_stack_status != &"" and max_stack_status != status_id:
		apply_status(max_stack_status, {})
	var max_stack_event: StringName = StringName(String(definition.get("max_stack_event", "")))
	if max_stack_event != &"":
		var event_context: Dictionary = _build_status_event_context(status_id, status)
		event_context["max_stack_event"] = max_stack_event
		var event_bus: Node = _get_skill_event_bus()
		if event_bus != null and event_bus.has_method("emit_skill_event"):
			event_bus.call("emit_skill_event", max_stack_event, event_context)


func _execute_status_effects(status: Dictionary, effects_key: String) -> void:
	var effects: Array = _get_array(status.get(effects_key, []))
	if effects.is_empty():
		return
	var event_bus: Node = _get_skill_event_bus()
	if event_bus == null or not event_bus.has_method("execute_adapted_actions"):
		return
	var status_id: StringName = StringName(String(status.get("id", "")))
	var actions: Array = SkillEffectAdapterScript.to_actions(_prepare_status_effects(effects, status))
	event_bus.call("execute_adapted_actions", actions, _build_status_event_context(status_id, status))


func _prepare_status_effects(effects: Array, status: Dictionary) -> Array:
	var prepared: Array = []
	var stacks: float = float(maxi(int(status.get("stacks", 1)), 1))
	for effect_variant: Variant in effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = (effect_variant as Dictionary).duplicate(true)
		if effect.has("power_scale_per_stack") and not effect.has("power_scale"):
			effect["power_scale"] = float(effect.get("power_scale_per_stack", 0.0)) * stacks
		prepared.append(effect)
	return prepared


func _emit_status_skill_event(event_name: StringName, status_id: StringName, status: Dictionary) -> void:
	var event_bus: Node = _get_skill_event_bus()
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		event_bus.call("emit_skill_event", event_name, _build_status_event_context(status_id, status))


func _build_status_event_context(status_id: StringName, status: Dictionary) -> Dictionary:
	var target: Node = get_parent()
	var position: Vector2 = (target as Node2D).global_position if target is Node2D else Vector2.ZERO
	var player: Node = _get_player()
	return {
		"target": target,
		"enemy": target,
		"caster": player,
		"owner": player,
		"status_id": status_id,
		"status": status.duplicate(true),
		"position": position,
		"parent": target.get_parent() if target != null else null,
		"event_bus": _get_skill_event_bus(),
		"skill_manager": player.get_node_or_null("SkillManager") if player != null else null,
		"relic_manager": player.get_node_or_null("RelicManager") if player != null else null,
		"target_group": &"enemies"
	}


func _get_skill_event_bus() -> Node:
	var owner: Node = get_parent()
	if owner != null:
		var local_bus: Node = owner.get_node_or_null("SkillEventBus")
		if local_bus != null:
			return local_bus
	var player: Node = _get_player()
	return player.get_node_or_null("SkillEventBus") if player != null else null


func _get_player() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var player: Node = tree.get_first_node_in_group(&"player")
	if player != null:
		return player
	var owner: Node = get_parent()
	if owner != null and owner.has_node("SkillEventBus"):
		return owner
	return null


func _refresh_status_visual() -> void:
	var visual: Dictionary = _get_active_status_visual()
	if visual.is_empty():
		_hide_status_visual()
		return

	var overlay: Node2D = _get_or_create_status_visual_overlay()
	if overlay == null:
		return

	var state: String = String(visual.get("state", visual.get("animation", visual.get("status_id", "idle"))))
	var visual_key: String = _status_visual_identity(visual, state)
	if overlay.visible and visual_key == _status_visual_key:
		return

	overlay.visible = true
	overlay.z_index = int(visual.get("overlay_z_index", 20))
	_status_visual_key = visual_key
	VisualConfigApplierScript.play_state(overlay, visual, state, "idle")


func _get_active_status_visual() -> Dictionary:
	var best_visual: Dictionary = {}
	var best_priority: float = -INF
	for status_variant: Variant in _statuses.values():
		if not (status_variant is Dictionary):
			continue
		var status: Dictionary = status_variant
		var definition: Dictionary = _get_dictionary(status.get("definition", {}))
		var visual: Dictionary = _get_dictionary(definition.get("visual", {}))
		if not _has_visual_resource(visual):
			continue
		var priority: float = float(visual.get("priority", 0.0))
		if priority <= best_priority:
			continue
		best_priority = priority
		best_visual = visual.duplicate(true)
		best_visual["status_id"] = StringName(String(status.get("id", "")))
	return best_visual


func _has_visual_resource(visual: Dictionary) -> bool:
	return String(visual.get("texture", "")) != "" or String(visual.get("sprite_frames", "")) != "" or visual.has("sprite_sheet")


func _get_or_create_status_visual_overlay() -> Node2D:
	if _status_visual_overlay != null and is_instance_valid(_status_visual_overlay):
		return _status_visual_overlay

	var owning_node: Node2D = get_parent() as Node2D
	if owning_node == null:
		return null

	var existing_overlay: Node2D = owning_node.get_node_or_null(STATUS_VISUAL_NODE_NAME) as Node2D
	if existing_overlay != null and not existing_overlay.is_queued_for_deletion():
		_status_visual_overlay = existing_overlay
		return _status_visual_overlay

	_status_visual_overlay = Node2D.new()
	_status_visual_overlay.name = STATUS_VISUAL_NODE_NAME
	_status_visual_overlay.visible = false
	owning_node.add_child(_status_visual_overlay)
	return _status_visual_overlay


func _hide_status_visual() -> void:
	if _status_visual_overlay == null or not is_instance_valid(_status_visual_overlay):
		return
	var parent_node: Node = _status_visual_overlay.get_parent()
	if parent_node != null:
		parent_node.remove_child(_status_visual_overlay)
	_status_visual_overlay.queue_free()
	_status_visual_overlay = null
	_status_visual_key = ""


func _status_visual_identity(visual: Dictionary, state: String) -> String:
	return "%s|%s|%s|%s" % [
		String(visual.get("status_id", "")),
		String(visual.get("texture", "")),
		String(visual.get("sprite_frames", "")),
		state
	]


func _is_dot_status(status: Dictionary) -> bool:
	var definition: Dictionary = _get_dictionary(status.get("definition", {}))
	if _get_effect_bool(definition, "dot", false):
		return true
	return DOT_STATUS_IDS.has(StringName(String(status.get("id", ""))))


func _get_tier_scaled_dot_damage(status: Dictionary, amount: float) -> float:
	var definition: Dictionary = _get_dictionary(status.get("definition", {}))
	var multiplier: float = 1.0
	if _is_boss():
		multiplier = float(_get_dictionary(definition.get("boss_modifiers", {})).get("dot_damage_multiplier", 0.65))
	elif _is_elite():
		multiplier = float(_get_dictionary(definition.get("elite_modifiers", {})).get("dot_damage_multiplier", 0.8))
	if StringName(String(status.get("id", ""))) == &"burn":
		var owner: Node = get_parent()
		if owner != null and float(owner.get_meta("fire_oil_burn_damage_until", 0.0)) > float(Time.get_ticks_msec()) / 1000.0:
			if _is_boss():
				multiplier *= maxf(float(owner.get_meta("fire_oil_boss_burn_damage_multiplier", 0.7)), 0.0)
			else:
				multiplier *= maxf(1.0 + float(owner.get_meta("fire_oil_burn_damage_multiplier_add", 0.0)), 0.0)
	return maxf(float(amount) * multiplier, 0.0)


func _apply_enemy_tier_rules(_status_id: StringName, definition: Dictionary) -> Dictionary:
	var result: Dictionary = definition.duplicate(true)
	var boss_control_conversion: Dictionary = ReactionLimiterScript.apply_boss_control_conversion(get_parent(), _status_id)
	if not boss_control_conversion.is_empty():
		for key: Variant in boss_control_conversion.keys():
			result[key] = boss_control_conversion[key]

	var modifiers: Dictionary = {}
	if _is_boss():
		modifiers = _get_dictionary(definition.get("boss_modifiers", {}))
	elif _is_elite():
		modifiers = _get_dictionary(definition.get("elite_modifiers", {}))

	if modifiers.is_empty():
		return result

	if float(modifiers.get("duration_multiplier", 1.0)) <= 0.0:
		return {}
	if modifiers.has("convert_to_status"):
		result["convert_to_status"] = modifiers["convert_to_status"]
	if modifiers.has("duration"):
		result["duration"] = modifiers["duration"]
	elif modifiers.has("duration_multiplier"):
		result["duration"] = float(result.get("duration", 1.0)) * float(modifiers["duration_multiplier"])
	if modifiers.has("max_stacks"):
		result["max_stacks"] = modifiers["max_stacks"]
	if modifiers.has("slow_percent"):
		result["slow_percent"] = modifiers["slow_percent"]
	if modifiers.has("next_damage_taken_multiplier_add"):
		var effect: Dictionary = _get_dictionary(result.get("effect", {}))
		effect["next_damage_taken_multiplier_add"] = modifiers["next_damage_taken_multiplier_add"]
		result["effect"] = effect
	return result


func _can_consume_next_damage_taken(packet: Variant) -> bool:
	if packet is Dictionary and (packet as Dictionary).is_empty():
		return true
	var damage_type: String = String(_damage_packet_value(packet, "damage_type", ""))
	var damage_origin: String = String(_damage_packet_value(packet, "damage_origin", ""))
	if damage_type == "status_dot" or damage_origin == "field":
		return false
	if damage_origin == "reaction" and String(_damage_packet_value(packet, "reaction_tier", "minor")) == "minor":
		return false
	return true


func _is_full_stack_explosion_vulnerability_active(status: Dictionary, packet: Variant) -> bool:
	if not status.has("full_stack_explosion_damage_taken_multiplier_add"):
		return false
	var required_stacks: int = maxi(int(status.get("full_stack_required_stacks", status.get("stacks", 1))), 1)
	if int(status.get("stacks", 0)) < required_stacks:
		return false
	var damage_origin: String = String(_damage_packet_value(packet, "damage_origin", ""))
	var damage_type: String = String(_damage_packet_value(packet, "damage_type", ""))
	var source_type: String = String(_damage_packet_value(packet, "source_type", ""))
	return damage_origin == "reaction" or damage_type == "reaction_damage" or source_type == "explosion"


func _damage_packet_value(packet: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet is Dictionary:
		return (packet as Dictionary).get(key, fallback)
	if packet is RefCounted:
		if packet.has_method("packet_value"):
			return packet.call("packet_value", key, fallback)
		if packet.has_method("get_value"):
			return packet.call("get_value", key, fallback)
	return fallback


func _get_status_definition(status_id: StringName) -> Dictionary:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_status_definition"):
		var data: Variant = data_manager.call("get_status_definition", status_id)
		if data is Dictionary:
			return data
	var status_data: Dictionary = _get_status_definition_from_game_data(status_id)
	if not status_data.is_empty():
		return status_data
	return {}


func _get_status_definition_from_game_data(status_id: StringName) -> Dictionary:
	var document: Dictionary = GameData._load_document("res://data/status_effects.json")
	var status_items: Variant = document.get("statuses", [])
	if not (status_items is Array):
		return {}

	for status_variant: Variant in status_items:
		if not (status_variant is Dictionary):
			continue
		var status: Dictionary = status_variant
		if StringName(String(status.get("id", ""))) == status_id:
			return status.duplicate(true)
	return {}


func _get_effect_value(definition: Dictionary, key: String, fallback: float) -> float:
	var effect: Dictionary = _get_dictionary(definition.get("effect", {}))
	return float(effect.get(key, fallback))


func _get_effect_bool(definition: Dictionary, key: String, fallback: bool) -> bool:
	var effect: Dictionary = _get_dictionary(definition.get("effect", {}))
	return bool(effect.get(key, fallback))


func _notify_status_applied(status_id: StringName, status: Dictionary) -> void:
	_emit_status_skill_event(&"status_applied", status_id, status)

	var tracker: Node = RunStatsTrackerScript.get_active(get_tree())
	if tracker != null and tracker.has_method("record_status_applied"):
		tracker.call("record_status_applied", status_id, get_parent())

	var synergy_manager: Node = _get_synergy_manager()
	if synergy_manager == null or not synergy_manager.has_method("on_status_applied"):
		return

	synergy_manager.call("on_status_applied", {
		"target": get_parent(),
		"status_id": status_id,
		"status": status.duplicate(true)
	})


func _apply_poison_slow_synergy() -> void:
	if not _statuses.has(&"poison"):
		return

	var synergy_manager: Node = _get_synergy_manager()
	var multiplier: float = 1.0
	if synergy_manager != null and synergy_manager.has_method("get_status_tick_interval_multiplier"):
		multiplier = float(synergy_manager.call("get_status_tick_interval_multiplier", get_parent(), &"poison"))

	var poison: Dictionary = _statuses[&"poison"]
	poison["tick_interval_multiplier"] = multiplier
	var adjusted_interval: float = maxf(float(poison.get("tick_interval", 0.5)) * multiplier, 0.05)
	poison["tick_timer"] = minf(float(poison.get("tick_timer", adjusted_interval)), adjusted_interval)
	_statuses[&"poison"] = poison


func _is_boss() -> bool:
	var owning_node: Node = get_parent()
	return owning_node != null and (owning_node.is_in_group(&"bosses") or bool(owning_node.get_meta("is_boss", false)) or String(owning_node.get_meta("enemy_rank", "")) == "boss")


func _is_elite() -> bool:
	var owning_node: Node = get_parent()
	return owning_node != null and (owning_node.is_in_group(&"elites") or bool(owning_node.get_meta("is_elite", false)) or String(owning_node.get_meta("enemy_rank", "")) == "elite")


func _get_synergy_manager() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	var player: Node = tree.get_first_node_in_group(&"player")
	if player == null:
		return null

	return player.get_node_or_null("SynergyManager")


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		var array: Array = value
		return array.duplicate(true)
	return []
