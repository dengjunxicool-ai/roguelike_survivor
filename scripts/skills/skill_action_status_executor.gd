extends "res://scripts/skills/skill_action_support.gd"
class_name SkillActionStatusExecutor


func _deal_damage(params: Dictionary, context: Dictionary) -> bool:
	context = _context_with_resolved_target(params, context)
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("take_damage"):
		return false

	var base_amount: Variant = params.get("amount", ModifierResolverScript.get_stat(context, "damage", 0))
	var amount: int = maxi(roundi(_resolve_scaled_amount(base_amount, context, "damage")), 0)
	var source_type: String = _effective_action_source_type(params, "skill")
	var damage_type: StringName = _get_damage_type(params, context, source_type, _get_damage_origin(params, context, source_type))
	var targets: Array[Node] = _resolve_damage_targets(params, context, target)
	var requires_low_hp_execute: bool = params.has("low_hp_execute_threshold") and float(params.get("low_hp_execute_threshold", 0.0)) > 0.0
	var damaged_any: bool = false
	for damage_target: Node in targets:
		damaged_any = _deal_damage_to_target(params, context, damage_target, amount, damage_type, requires_low_hp_execute) or damaged_any
	return damaged_any


func _deal_damage_to_target(params: Dictionary, context: Dictionary, damage_target: Node, amount: int, damage_type: StringName, requires_low_hp_execute: bool) -> bool:
	if damage_target == null or not damage_target.has_method("take_damage"):
		return false
	var target_context: Dictionary = context.duplicate(true)
	target_context["target"] = damage_target
	var execute_triggered: bool = _should_execute_low_hp_target(params, damage_target)
	if requires_low_hp_execute and not execute_triggered:
		return false
	var target_amount: int = _get_low_hp_execute_amount(damage_target, amount) if execute_triggered else amount
	var packet: Dictionary = _build_damage_packet(params, target_context, target_amount, "skill")
	_inherit_projectile_runtime_damage_packet(packet, target_context, damage_target)
	if execute_triggered:
		_apply_low_hp_execute_packet(packet, params, damage_target)
	packet = _special_rule_executor.call("adjust_damage_packet", packet, target_context)
	damage_target.call("take_damage", DamagePacketScript.from_dictionary(packet))
	return true


func _should_execute_low_hp_target(params: Dictionary, target: Node) -> bool:
	var threshold: float = clampf(float(params.get("low_hp_execute_threshold", 0.0)), 0.0, 1.0)
	if threshold <= 0.0 or target == null:
		return false
	var max_health: float = maxf(_get_float_property(target, "max_health", 0.0), 1.0)
	var current_health: float = clampf(_get_float_property(target, "current_health", max_health), 0.0, max_health)
	if current_health <= 0.0:
		return false
	return current_health / max_health <= threshold


func _get_low_hp_execute_amount(target: Node, fallback_amount: int) -> int:
	if target == null:
		return fallback_amount
	var max_health: float = maxf(_get_float_property(target, "max_health", 0.0), 1.0)
	var current_health: float = clampf(_get_float_property(target, "current_health", max_health), 0.0, max_health)
	return maxi(ceili(current_health + max_health), fallback_amount)


func _apply_low_hp_execute_packet(packet: Dictionary, params: Dictionary, target: Node) -> void:
	var amount: int = _get_low_hp_execute_amount(target, int(packet.get("amount", packet.get("raw_amount", 0))))
	packet["raw_amount"] = amount
	packet["amount"] = amount
	packet["damage_origin"] = &"special"
	packet["damage_type"] = &"true_damage"
	packet["low_hp_execute"] = true
	packet["low_hp_execute_threshold"] = clampf(float(params.get("low_hp_execute_threshold", 0.0)), 0.0, 1.0)


func _resolve_damage_targets(params: Dictionary, context: Dictionary, primary_target: Node) -> Array[Node]:
	var targets: Array[Node] = [primary_target]
	var radius: float = maxf(float(params.get("radius", 0.0)), 0.0)
	var center: Node2D = primary_target as Node2D
	if radius <= 0.0 or center == null:
		return targets
	var target_group: StringName = StringName(str(params.get("target_group", context.get("target_group", &"enemies"))))
	for candidate: Node2D in _find_targets_around(center.global_position, radius, target_group, primary_target):
		targets.append(candidate)
	return targets


func _inherit_projectile_runtime_damage_packet(packet: Dictionary, context: Dictionary, target: Node) -> void:
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return
	var runtime_packet: Dictionary = _get_dictionary(projectile.get("damage_packet"))
	if runtime_packet.is_empty():
		return
	for key_variant: Variant in runtime_packet.keys():
		var key: String = str(key_variant)
		if key == "raw_amount" or key == "amount" or key == "target_id":
			continue
		if (key == "damage_origin" or key == "source_type" or key == "damage_type" or key == "element") and packet.has(key):
			continue
		packet[key] = runtime_packet[key_variant]
	if target != null:
		packet["target_id"] = str(target.get_instance_id())


func _apply_status(params: Dictionary, context: Dictionary) -> bool:
	context = _context_with_resolved_target(params, context)
	var target: Node = context.get("target") as Node
	if target == null:
		return false

	var chance: float = clampf(float(params.get("chance", 1.0)), 0.0, 1.0)
	if randf() > chance:
		return false

	var status_id: StringName = StringName(str(params.get("status_id", "")))
	if status_id == &"":
		return false

	var status_params: Dictionary = {}
	if params.has("duration"):
		status_params["duration"] = float(ModifierResolverScript.resolve_value(context, "status_duration", params["duration"]))
	if params.has("damage"):
		status_params["damage"] = int(ModifierResolverScript.resolve_value(context, "status_damage", params["damage"]))
	if params.has("tick_interval"):
		status_params["tick_interval"] = float(ModifierResolverScript.resolve_value(context, "status_tick_interval", params["tick_interval"]))
	if params.has("stack"):
		status_params["stacks"] = int(params["stack"])
	if params.has("max_stacks"):
		status_params["max_stacks"] = int(params["max_stacks"])
	if not status_params.has("power"):
		var status_power: float = _get_status_power_from_context(context)
		if status_power > 0.0:
			status_params["power"] = status_power
	status_params = DamageTraceContextScript.apply_to_status_params(status_params, context)
	status_params = _special_rule_executor.call("get_status_params", status_id, status_params, context)

	if _should_coalesce_area_status_apply(target, status_id, context):
		return true
	if target.has_method("apply_status"):
		_increment_area_tick_status_apply(context)
		return bool(target.call("apply_status", status_id, status_params))
	if target.has_method("add_status_effect"):
		_increment_area_tick_status_apply(context)
		target.call("add_status_effect", status_id)
		return true

	return false


func _consume_status_stack(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false

	var status_id: StringName = StringName(str(params.get("status_id", "")))
	if status_id == &"":
		return false

	var stacks: int = maxi(int(params.get("stacks", params.get("stack", 1))), 1)
	if params.has("retain_stacks_modifier"):
		var retain_stacks: int = maxi(int(_combined_modifier_value(str(params.get("retain_stacks_modifier", "")), context, 0.0)), 0)
		if retain_stacks > 0 and target.has_method("get_status_stack"):
			var current_stacks: int = int(target.call("get_status_stack", status_id))
			stacks = maxi(current_stacks - retain_stacks, 0)
			if stacks <= 0:
				return true
	if target.has_method("consume_status_stack"):
		return bool(target.call("consume_status_stack", status_id, stacks))

	var manager: Node = target.get_node_or_null("StatusEffectManager")
	if manager != null and manager.has_method("consume_status_stack"):
		return bool(manager.call("consume_status_stack", status_id, stacks))

	if status_id == &"shock" and target.has_method("consume_shock_stack"):
		var consumed_any: bool = false
		for _stack_index in range(stacks):
			consumed_any = bool(target.call("consume_shock_stack")) or consumed_any
		return consumed_any

	return false


func _damage_by_status_stack(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("take_damage"):
		return false

	var status_ids: Array[StringName] = _get_status_ids(params)
	if status_ids.is_empty():
		return false

	var stack_count: int = 0
	for status_id: StringName in status_ids:
		if target.has_method("get_status_stack"):
			stack_count += int(target.call("get_status_stack", status_id))

	if stack_count <= 0:
		return false

	var amount_per_stack: float = _resolve_scaled_amount(params.get("amount_per_stack", params.get("damage_per_stack", 1.0)), context, "damage")
	var base_amount: float = _resolve_scaled_amount(params.get("amount", 0.0), context, "damage")
	var amount: int = maxi(roundi(base_amount + amount_per_stack * float(stack_count)), 1)
	var origin: String = _get_damage_origin(params, context, "skill")
	target.call("take_damage", DamagePacketScript.from_dictionary(_build_damage_packet(params, context, amount, "skill")))

	if bool(params.get("consume", false)):
		for status_id: StringName in status_ids:
			_consume_status_stack({"status_id": status_id, "stacks": int(params.get("consume_stacks", 1))}, context)

	return true


func _transfer_status(params: Dictionary, context: Dictionary) -> bool:
	var source: Node = context.get("source") as Node
	var target: Node = context.get("target") as Node
	if source == null:
		source = target
		target = context.get("caster") as Node
	if source == null or target == null:
		return false

	var status_id: StringName = StringName(str(params.get("status_id", params.get("status", ""))))
	if status_id == &"":
		return false
	var stacks: int = maxi(int(params.get("stacks", params.get("stack", 1))), 1)
	if source.has_method("get_status_stack"):
		stacks = mini(stacks, maxi(int(source.call("get_status_stack", status_id)), 0))
	if stacks <= 0:
		return false
	if not _apply_status_to_target(target, status_id, {"stacks": stacks}):
		return false
	_consume_status_stack_on_target(source, status_id, stacks)
	return true


func _consume_status_duration(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false
	var status_id: StringName = StringName(str(params.get("status_id", params.get("status", ""))))
	if status_id == &"":
		return false
	var seconds: float = maxf(float(params.get("duration", params.get("seconds", 0.0))), 0.0)
	var manager: Node = _get_status_manager(target)
	if manager != null and manager.has_method("consume_status_duration"):
		return bool(manager.call("consume_status_duration", status_id, seconds))
	if target.has_method("consume_status_duration"):
		return bool(target.call("consume_status_duration", status_id, seconds))
	push_warning("[SkillActionExecutor] consume_status_duration requires StatusEffectManager.consume_status_duration.")
	return false


func _trigger_overload(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false
	var overload_id: StringName = StringName(str(params.get("status_id", "overload")))
	return _apply_status_to_target(target, overload_id, {"stacks": 1, "duration": float(params.get("duration", 0.1))})


func _shatter_frozen(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false
	if target.has_method("get_status_stack") and int(target.call("get_status_stack", &"frozen")) <= 0:
		return false
	_consume_status_stack_on_target(target, &"frozen", 1)

	_deal_damage(_prepare_shatter_damage_params(params), context)
	if int(params.get("projectile_count", 0)) > 0:
		var burst_params: Dictionary = params.duplicate(true)
		burst_params["count"] = int(params.get("projectile_count", 0))
		burst_params["projectile_id"] = str(params.get("projectile_id", "shattered_ember"))
		_spawn_projectile_burst(burst_params, context)
	return true


func _prepare_shatter_damage_params(params: Dictionary) -> Dictionary:
	var damage_value: Variant = params.get("amount", params.get("damage", {"stat": "power", "scale": 0.25}))
	var damage_params: Dictionary = params.duplicate(true)
	damage_params["amount"] = damage_value
	if damage_value is Dictionary:
		var damage_dictionary: Dictionary = damage_value
		if damage_dictionary.has("power_scale"):
			damage_params["amount"] = {"stat": "power", "scale": float(damage_dictionary.get("power_scale", 0.0))}
		for key_variant: Variant in damage_dictionary.keys():
			if not damage_params.has(key_variant):
				damage_params[key_variant] = damage_dictionary[key_variant]
	return damage_params


func _mark_target(params: Dictionary, context: Dictionary) -> bool:
	var resolved_context: Dictionary = _context_with_resolved_target(params, context)
	var target: Node = resolved_context.get("target") as Node
	if target == null:
		return false

	var mark: String = str(params.get("mark", params.get("key", ""))).strip_edges()
	if mark == "":
		return false

	var mark_key: String = _metadata_identifier(mark)
	target.set_meta(mark_key, true)
	if params.has("duration"):
		target.set_meta(_metadata_key(mark, "expires_at"), float(Time.get_ticks_msec()) / 1000.0 + maxf(float(params.get("duration", 0.0)), 0.0))
	return true
