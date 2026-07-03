extends Node
class_name StatusEffectManager
const DataPathsScript := preload("res://scripts/core/data_paths.gd")


const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageSourceIdentityScript: Script = preload("res://scripts/combat/damage_source_identity.gd")
const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")
const SkillEffectAdapterScript: Script = preload("res://scripts/skills/skill_effect_adapter.gd")
const StatusEffectQueryScript: Script = preload("res://scripts/combat/status_effect_query.gd")
const StatusEffectTickHelperScript: Script = preload("res://scripts/combat/status_effect_tick_helper.gd")
const DOT_STATUS_IDS: Array[StringName] = [&"burning", &"poison", &"bleed"]
const MOVEMENT_LOCK_STATUS_IDS: Array[StringName] = [&"freeze", &"frozen", &"stun", &"paralyze"]
const STATUS_VISUAL_NODE_NAME: String = "StatusVisualOverlay"

var _statuses: Dictionary = {}
var _status_visual_overlay: Node2D
var _status_visual_key: String = ""
var _status_visual_priority: float = -INF
var _status_visual_refresh_queued: bool = false


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

	var stack_data: Dictionary = _resolve_status_stack_data(id, definition, params)
	var status: Dictionary = _build_status_runtime_data(id, definition, params, stack_data)
	var current_stacks: int = int(stack_data.get("current_stacks", 0))
	var new_stacks: int = int(stack_data.get("new_stacks", 0))
	var max_stacks: int = int(stack_data.get("max_stacks", 1))

	var next_tick_interval: float = float(status["tick_interval"])
	status["tick_timer"] = minf(float(status.get("tick_timer", next_tick_interval)), next_tick_interval)
	_statuses[id] = status
	if _status_visual_refresh_needed_after_apply(id, definition):
		_queue_status_visual_refresh()

	_notify_status_applied(id, status)
	if new_stacks >= max_stacks and current_stacks < max_stacks:
		_handle_max_stack_reached(id, status)
	_apply_poison_slow_synergy()
	return true


func _resolve_status_stack_data(id: StringName, definition: Dictionary, params: Dictionary) -> Dictionary:
	var status: Dictionary = _statuses.get(id, {}).duplicate(true)
	var stacks_to_add: int = maxi(int(params.get("stacks", params.get("stack", 1))), 1)
	var max_stacks: int = maxi(int(params.get("max_stacks", definition.get("max_stacks", 1))), 1)
	var current_stacks: int = int(status.get("stacks", 0))
	return {
		"status": status,
		"current_stacks": current_stacks,
		"new_stacks": mini(current_stacks + stacks_to_add, max_stacks),
		"max_stacks": max_stacks,
		"duration": maxf(float(params.get("duration", definition.get("duration", 1.0))), 0.05)
	}


func _build_status_runtime_data(id: StringName, definition: Dictionary, params: Dictionary, stack_data: Dictionary) -> Dictionary:
	var status: Dictionary = stack_data.get("status", {}).duplicate(true)
	var max_stacks: int = int(stack_data.get("max_stacks", 1))
	status["id"] = id
	status["definition"] = definition
	status["stacks"] = int(stack_data.get("new_stacks", 0))
	status["duration_remaining"] = maxf(float(status.get("duration_remaining", 0.0)), float(stack_data.get("duration", 1.0)))
	status["tick_interval"] = maxf(float(params.get("tick_interval", definition.get("tick_interval", 0.5))), 0.05)
	var configured_tick_damage: float = maxf(float(params.get("tick_damage", params.get("damage", definition.get("damage", 0.0)))), 0.0)
	configured_tick_damage = maxf(configured_tick_damage * maxf(1.0 + float(params.get("damage_multiplier_add", 0.0)), 0.0), 0.0)
	status["tick_damage"] = configured_tick_damage
	status["damage_type"] = StringName(String(params.get("damage_type", definition.get("damage_type", id))))
	status["element"] = StringName(String(params.get("element", definition.get("element", id))))
	if params.has("power"):
		status["power"] = maxf(float(params.get("power", 0.0)), 0.0)
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
	return status


func update_status_effects(delta: float) -> void:
	if delta <= 0.0:
		return

	var expired_statuses: Array[StringName] = []
	var expired_snapshots: Dictionary = {}
	for id_variant: Variant in _statuses.keys():
		var id: StringName = StringName(String(id_variant))
		var status: Dictionary = _statuses[id]
		_advance_status_tick(status, delta)

		if _is_status_expired(status):
			expired_statuses.append(id)
			expired_snapshots[id] = status.duplicate(true)
		else:
			_statuses[id] = status

	_expire_statuses(expired_statuses, expired_snapshots)
	if not expired_statuses.is_empty():
		_queue_status_visual_refresh()
	_apply_poison_slow_synergy()


func _advance_status_tick(status: Dictionary, delta: float) -> void:
	StatusEffectTickHelperScript.advance_duration(status, delta)
	if _is_dot_status(status):
		_update_damage_over_time(status, delta)


func _is_status_expired(status: Dictionary) -> bool:
	return StatusEffectTickHelperScript.is_status_expired(status)


func _expire_statuses(expired_statuses: Array[StringName], expired_snapshots: Dictionary) -> void:
	for id: StringName in expired_statuses:
		_statuses.erase(id)
		var expired_status: Dictionary = _get_dictionary(expired_snapshots.get(id, {}))
		_execute_status_effects(expired_status, "on_expire_effects")
		_emit_status_skill_event(&"status_expired", id, expired_status)
		_emit_profiler_status_event(&"status_expired", id, expired_status)


func has_status(status_id: Variant) -> bool:
	return StatusEffectQueryScript.has_status(_statuses, status_id)


func get_status_stack(status_id: Variant) -> int:
	return StatusEffectQueryScript.get_status_stack(_statuses, status_id)


func merge_status_fields(status_id: Variant, fields: Dictionary, duration: float = 0.0) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"" or not _statuses.has(id):
		return false

	var status: Dictionary = _statuses[id]
	for key_variant: Variant in fields.keys():
		var key: String = String(key_variant)
		if key == "" or key == "id" or key == "definition" or key == "stacks":
			continue
		status[key] = fields[key_variant]
	if duration > 0.0:
		status["duration_remaining"] = maxf(float(status.get("duration_remaining", 0.0)), duration)
	_statuses[id] = status
	return true


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

	_queue_status_visual_refresh()
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
		_emit_profiler_status_event(&"status_expired", id, status)
	else:
		_statuses[id] = status

	_queue_status_visual_refresh()
	_apply_poison_slow_synergy()
	return true


func get_status_snapshot() -> Array[Dictionary]:
	return StatusEffectQueryScript.get_status_snapshot(_statuses)


func clear_statuses() -> void:
	_statuses.clear()
	_status_visual_refresh_queued = false
	_refresh_status_visual()


func is_movement_frozen() -> bool:
	for status_id: StringName in MOVEMENT_LOCK_STATUS_IDS:
		if has_status(status_id):
			return true
	return false


func get_move_speed_multiplier() -> float:
	return StatusEffectQueryScript.movement_speed_multiplier(_statuses, MOVEMENT_LOCK_STATUS_IDS, _is_boss(), _is_elite())


func get_damage_taken_multiplier(damage_type: Variant = &"", category: Variant = &"") -> float:
	return 1.0 + get_vulnerability_total(damage_type, category, {})


func get_vulnerability_total(damage_type: Variant = &"", category: Variant = &"", packet: Variant = {}) -> float:
	return StatusEffectQueryScript.vulnerability_total(_statuses, damage_type, category, packet, _is_boss(), _is_elite())


func _update_damage_over_time(status: Dictionary, delta: float) -> void:
	var tick_interval: float = maxf(
		float(status.get("tick_interval", 0.5)) * float(status.get("tick_interval_multiplier", 1.0)),
		0.05
	)
	var tick_timer: float = float(status.get("tick_timer", tick_interval)) - delta
	var tick_damage: float = float(status.get("tick_damage", 0.0))
	var stacks: int = int(status.get("stacks", 1))
	var status_id: StringName = StringName(String(status.get("id", "")))

	while tick_timer <= 0.0 and _has_status_tick_work(status) and float(status.get("duration_remaining", 0.0)) > 0.0:
		_emit_profiler_status_event(&"status_tick_due", status_id, status, {"tick_interval": tick_interval})
		if tick_damage > 0:
			_apply_tick_damage(_get_tier_scaled_dot_damage(status, tick_damage * stacks), status)
		_execute_status_effects(status, "on_tick_effects")
		_emit_status_skill_event(&"status_tick", status_id, status)
		_emit_profiler_status_event(&"status_tick_applied", status_id, status, {
			"tick_damage": tick_damage,
			"tick_interval": tick_interval
		})
		if _should_consume_stack_on_tick(status):
			stacks = maxi(stacks - 1, 0)
			status["stacks"] = stacks
			if stacks <= 0:
				break
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
	return StatusEffectTickHelperScript.has_status_tick_work(status)


func _should_consume_stack_on_tick(status: Dictionary) -> bool:
	return StatusEffectTickHelperScript.should_consume_stack_on_tick(status)


func _get_status_tick_damage_total(status: Dictionary) -> float:
	return StatusEffectTickHelperScript.tick_damage_total(status)


func _handle_max_stack_reached(status_id: StringName, status: Dictionary) -> void:
	_emit_status_skill_event(&"status_max_stack_reached", status_id, status)
	_emit_profiler_status_event(&"status_reaction_triggered", status_id, status, {"trigger": &"status_max_stack_reached"})
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
	var source_skill_id: StringName = StringName(String(status.get("source_skill_id", status_id)))
	if source_skill_id == &"":
		source_skill_id = status_id
	var source_instance_id: String = String(status.get("source_instance_id", ""))
	if source_instance_id == "":
		source_instance_id = DamageSourceIdentityScript.for_status_dot(target, status_id, status.get("attacker_id", ""))
	return {
		"target": target,
		"enemy": target,
		"caster": player,
		"owner": player,
		"status_id": status_id,
		"status": status.duplicate(true),
		"skill_id": source_skill_id,
		"source_id": source_skill_id,
		"source_origin_id": StringName(String(status.get("source_origin_id", ""))),
		"source_skill_id": source_skill_id,
		"source_instance_id": source_instance_id,
		"power": float(status.get("power", status.get("tick_damage", 0.0))),
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
	_status_visual_priority = float(visual.get("priority", 0.0))
	VisualConfigApplierScript.play_state(overlay, visual, state, "idle")
	_emit_profiler_status_event(&"status_visual_update", StringName(String(visual.get("status_id", ""))), {}, {
		"visual_key": visual_key,
		"state": state
	})


func _queue_status_visual_refresh() -> void:
	if _status_visual_refresh_queued:
		return
	_status_visual_refresh_queued = true
	call_deferred("_flush_status_visual_refresh")


func _flush_status_visual_refresh() -> void:
	if not _status_visual_refresh_queued:
		return
	_status_visual_refresh_queued = false
	_refresh_status_visual()


func _status_visual_refresh_needed_after_apply(status_id: StringName, definition: Dictionary) -> bool:
	var visual: Dictionary = _get_dictionary(definition.get("visual", {}))
	if not _has_visual_resource(visual):
		return false

	visual = visual.duplicate(true)
	visual["status_id"] = status_id
	var state: String = String(visual.get("state", visual.get("animation", visual.get("status_id", "idle"))))
	var visual_key: String = _status_visual_identity(visual, state)
	if _status_visual_overlay == null or not is_instance_valid(_status_visual_overlay) or not _status_visual_overlay.visible:
		return true
	if visual_key == _status_visual_key:
		return false
	return float(visual.get("priority", 0.0)) >= _status_visual_priority


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
	_emit_profiler_status_event(&"status_visual_spawn", &"", {}, {"owner": owning_node})
	return _status_visual_overlay


func _hide_status_visual() -> void:
	if _status_visual_overlay == null or not is_instance_valid(_status_visual_overlay):
		return
	_status_visual_overlay.visible = false
	_status_visual_key = ""
	_status_visual_priority = -INF


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
	if StringName(String(status.get("id", ""))) == &"burning":
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
	return StatusEffectQueryScript.can_consume_next_damage_taken(packet)


func _is_full_stack_explosion_vulnerability_active(status: Dictionary, packet: Variant) -> bool:
	return StatusEffectQueryScript.is_full_stack_explosion_vulnerability_active(status, packet)


func _damage_packet_value(packet: Variant, key: Variant, fallback: Variant = null) -> Variant:
	return StatusEffectQueryScript.damage_packet_value(packet, key, fallback)


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
	var document: Dictionary = GameData._load_document(DataPathsScript.STATUS_EFFECTS_PATH)
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


func _emit_profiler_status_event(event_name: StringName, status_id: StringName, status: Dictionary, extra: Dictionary = {}) -> void:
	var profiler_callback: Callable = _real_full_run_profiler_status_callback()
	if not profiler_callback.is_valid():
		return
	var payload: Dictionary = {
		"status_id": status_id,
		"source_id": StringName(String(status.get("source_id", status.get("source_skill_id", status_id)))),
		"source_skill_id": StringName(String(status.get("source_skill_id", status_id))),
		"source_instance_id": String(status.get("source_instance_id", "")),
		"target": get_parent(),
		"stacks": int(status.get("stacks", 0)),
		"duration_remaining": float(status.get("duration_remaining", 0.0))
	}
	for key_variant: Variant in extra.keys():
		payload[key_variant] = extra[key_variant]
	profiler_callback.call(event_name, payload)


func _real_full_run_profiler_status_callback() -> Callable:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return Callable()
	if not tree.root.has_meta(&"real_full_run_profiler_enabled") or not bool(tree.root.get_meta(&"real_full_run_profiler_enabled")):
		return Callable()
	if not tree.root.has_meta(&"real_full_run_profiler_status_event"):
		return Callable()
	var callback: Variant = tree.root.get_meta(&"real_full_run_profiler_status_event")
	return callback if callback is Callable else Callable()


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
