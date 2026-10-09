## 文件用途：执行严格伤害、低血斩杀、状态施加消耗转移和冻结粉碎等命中动作。
## 使用方式：context 提供目标与技能来源；伤害通过 DamagePacket 和目标受击入口，状态经目标公开方法操作。
extends "res://scripts/skills/skill_action_support.gd"
class_name SkillActionStatusExecutor


## 作用：解析单体或范围目标，为每个目标执行标准伤害动作。
## 使用：params 读取 amount/low_hp_execute_threshold；context 携带 target；返回布尔判断或执行是否成功。
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


## 作用：继承弹体伤害来源并应用斩杀与规则修正后调用目标 take_damage。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；amount 为本次伤害或动作数值；返回布尔判断或执行是否成功。
func _deal_damage_to_target(params: Dictionary, context: Dictionary, damage_target: Node, amount: int, damage_type: StringName, requires_low_hp_execute: bool) -> bool:
	if damage_target == null or not damage_target.has_method("take_damage"):
		return false
	var target_context: Dictionary = context.duplicate(true)
	target_context["target"] = damage_target
	var policy: Dictionary = _execute_policy(damage_target, params, target_context)
	var execute_triggered: bool = requires_low_hp_execute and policy.mode == "execute" and policy.eligible
	if requires_low_hp_execute and not policy.eligible: return false
	var target_amount: int = _get_low_hp_execute_amount(damage_target, amount) if execute_triggered else amount
	if requires_low_hp_execute and policy.mode == "bonus":
		target_amount = roundi(policy.bonus_amount)
		damage_target.set_meta("frost_execute_ready_at", float(target_context.get("event_bus").combat_seconds())+float(policy.cooldown) if target_context.get("event_bus") != null else float(policy.cooldown))
	var packet: Dictionary = _build_damage_packet(params, target_context, target_amount, "skill")
	_inherit_projectile_runtime_damage_packet(packet, target_context, damage_target)
	if execute_triggered:
		_apply_low_hp_execute_packet(packet, params, damage_target)
	packet = _special_rule_executor.call("adjust_damage_packet", packet, target_context)
	damage_target.call("take_damage", DamagePacketScript.from_dictionary(packet))
	return true


func _execute_policy(target: Node, params: Dictionary, context: Dictionary) -> Dictionary:
	var rank: String = String(preload("res://scripts/combat/target_damage_profile_resolver.gd").resolve(target).target_type)
	var maximum: float = maxf(_get_float_property(target, "max_health", 1.0), 1.0)
	var current: float = _get_float_property(target, "current_health", maximum)
	var threshold: float = float(params.get("low_hp_execute_threshold", 0.0))
	if rank == "elite": threshold = minf(threshold, 0.04)
	var now: float = float(context.get("event_bus").combat_seconds()) if context.get("event_bus") != null else 0.0
	var eligible: bool = threshold > 0.0 and current > 0.0 and current / maximum <= threshold
	if rank == "boss":
		var power: float = _resolve_scaled_amount({"stat":"power", "scale":1.0}, context, "damage")
		return {"mode":"bonus", "eligible":eligible and now >= float(target.get_meta("frost_execute_ready_at",0.0)), "threshold":threshold, "bonus_amount":minf(0.8*power,0.01*maximum), "cooldown":5.0}
	return {"mode":"execute", "eligible":eligible, "threshold":threshold, "bonus_amount":0.0, "cooldown":0.0}


## 作用：检查有效存活目标生命比例是否不高于 low_hp_execute_threshold，零门槛不触发。
## 使用：params 读取 low_hp_execute_threshold；target 为本次命中目标；返回布尔判断或执行是否成功。
func _should_execute_low_hp_target(params: Dictionary, target: Node) -> bool:
	var threshold: float = clampf(float(params.get("low_hp_execute_threshold", 0.0)), 0.0, 1.0)
	if threshold <= 0.0 or target == null:
		return false
	var max_health: float = maxf(_get_float_property(target, "max_health", 0.0), 1.0)
	var current_health: float = clampf(_get_float_property(target, "current_health", max_health), 0.0, max_health)
	if current_health <= 0.0:
		return false
	return current_health / max_health <= threshold


## 作用：取当前生命加最大生命的向上取整值与备用伤害较大者，作为斩杀伤害量。
## 使用：target 为本次命中目标。
func _get_low_hp_execute_amount(target: Node, fallback_amount: int) -> int:
	if target == null:
		return fallback_amount
	var max_health: float = maxf(_get_float_property(target, "max_health", 0.0), 1.0)
	var current_health: float = clampf(_get_float_property(target, "current_health", max_health), 0.0, max_health)
	return maxi(ceili(current_health + max_health), fallback_amount)


## 作用：原地把伤害包改为足额 true_damage 特殊来源，并标记斩杀与阈值；本函数不应用伤害。
## 使用：packet 为待修饰伤害包视图；params 读取 low_hp_execute_threshold；target 为本次命中目标；会原地更新 packet.raw_amount/amount/damage_origin。
func _apply_low_hp_execute_packet(packet: Dictionary, params: Dictionary, target: Node) -> void:
	var amount: int = _get_low_hp_execute_amount(target, int(packet.get("amount", packet.get("raw_amount", 0))))
	packet["raw_amount"] = amount
	packet["amount"] = amount
	packet["damage_origin"] = &"special"
	packet["damage_type"] = &"true_damage"
	packet["low_hp_execute"] = true
	packet["low_hp_execute_threshold"] = clampf(float(params.get("low_hp_execute_threshold", 0.0)), 0.0, 1.0)


## 作用：优先动作指定目标集合，否则用上下文目标或范围查询解析伤害目标。
## 使用：params 读取 radius/target_group；context 携带 target_group。
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


## 作用：从命中弹体继承运行伤害包的来源和规则字段。
## 使用：packet 为待修饰伤害包视图；context 携带 projectile；target 为本次命中目标；会原地更新 packet.target_id。
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
		if key in ["origin_skill_id", "listener_skill_id", "event_id", "parent_event_id", "proc_depth", "is_copy", "can_generate_secondary_proc", "combat_seconds", "cast_damage_multiplier"] and packet.has(key):
			continue
		if (key == "damage_origin" or key == "source_type" or key == "damage_type" or key == "element") and packet.has(key):
			continue
		packet[key] = runtime_packet[key_variant]
	if target != null:
		packet["target_id"] = str(target.get_instance_id())


## 作用：解析目标与状态参数并执行施加，支持区域同帧合并语义。
## 使用：params 读取 chance/status_id/duration/damage；context 携带 target；返回布尔判断或执行是否成功。
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


## 作用：对动作目标消耗指定状态层数。
## 使用：params 读取 status_id/stacks/stack/retain_stacks_modifier；context 携带 target；返回布尔判断或执行是否成功。
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


## 作用：按目标状态当前层数计算伤害，并按规则消费状态。
## 使用：params 读取 amount_per_stack/damage_per_stack/amount/consume；context 携带 target；返回布尔判断或执行是否成功。
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


## 作用：把指定状态从来源目标转移到动作选择的目标集合。
## 使用：params 读取 status_id/status/stacks/stack；context 携带 source/target/caster；返回布尔判断或执行是否成功。
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


## 作用：按动作数值减少目标状态剩余持续时间。
## 使用：params 读取 status_id/status/duration/seconds；context 携带 target；返回布尔判断或执行是否成功。
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


## 作用：根据电压、感电和动作参数触发过载伤害与状态变化。
## 使用：params 读取 status_id/duration；context 携带 target；返回布尔判断或执行是否成功。
func _trigger_overload(params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null:
		return false
	var overload_id: StringName = StringName(str(params.get("status_id", "overload")))
	return _apply_status_to_target(target, overload_id, {"stacks": 1, "duration": float(params.get("duration", 0.1))})


## 作用：检查冻结目标并执行粉碎伤害及派生效果。
## 使用：params 读取 projectile_count/projectile_id；context 携带 target；返回布尔判断或执行是否成功。
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


## 作用：将粉碎规则与事件来源整理为标准伤害动作参数。
## 使用：params 读取 amount/damage。
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


## 作用：在命中目标写入动作指定标记元数据。
## 使用：params 读取 mark/key/duration；context 为施放或命中上下文；返回布尔判断或执行是否成功。
func _mark_target(params: Dictionary, context: Dictionary) -> bool:
	var resolved_context: Dictionary = _context_with_resolved_target(params, context)
	var target: Node = resolved_context.get("target") as Node
	if target == null:
		return false

	var mark: String = str(params.get("mark", params.get("key", ""))).strip_edges()
	if mark == "":
		return false

	if mark == "death_pact" and context.get("event_bus") != null:
		context.event_bus.register_death_pact(target, resolved_context, float(params.get("duration", 5.0)))
	var mark_key: String = _metadata_identifier(mark)
	target.set_meta(mark_key, true)
	if params.has("duration"):
		target.set_meta(_metadata_key(mark, "expires_at"), float(context.get("combat_seconds", 0.0)) + maxf(float(params.get("duration", 0.0)), 0.0))
	return true
