extends RefCounted
class_name SummonAttackComponent


const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

var attack_type: String = "melee"
var attack_range: float = 48.0
var attack_cooldown: float = 1.2
var damage_type: StringName = &"neutral"
var damage_scale: float = 0.45
var projectile_id: StringName = &""
var pulse_radius: float = 96.0
var pulse_area_id: StringName = &""
var pulse_duration: float = 0.28
var pulse_tick_interval: float = 0.1
var on_hit_effects: Array = []
var _cooldown_remaining: float = 0.0


func setup(config: Dictionary) -> void:
	attack_type = str(config.get("attack_type", attack_type))
	attack_range = maxf(float(config.get("attack_range", attack_range)), 1.0)
	attack_cooldown = maxf(float(config.get("attack_cooldown", attack_cooldown)), 0.05)
	damage_type = StringName(str(config.get("damage_type", damage_type)))
	damage_scale = maxf(float(config.get("damage_scale", damage_scale)), 0.0)
	projectile_id = StringName(str(config.get("projectile_id", projectile_id)))
	pulse_radius = maxf(float(config.get("pulse_radius", config.get("attack_range", pulse_radius))), 1.0)
	pulse_area_id = StringName(str(config.get("pulse_area_id", "")))
	pulse_duration = maxf(float(config.get("pulse_duration", pulse_duration)), 0.05)
	pulse_tick_interval = maxf(float(config.get("pulse_tick_interval", pulse_tick_interval)), 0.05)
	on_hit_effects = _array(config.get("on_hit_effects", []))
	_cooldown_remaining = 0.0


func tick(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func is_in_range(summon: Node2D, target: Node2D) -> bool:
	var range: float = pulse_radius if attack_type == "area_pulse" else attack_range
	return summon != null and target != null and summon.global_position.distance_to(target.global_position) <= range


func can_attack() -> bool:
	return _cooldown_remaining <= 0.0


func attack(summon: Node2D, target: Node2D, player_power: float, context: Dictionary) -> bool:
	if summon == null or target == null or not can_attack():
		return false
	if attack_type != "area_pulse" and not is_in_range(summon, target):
		return false
	match attack_type:
		"projectile":
			_fire_projectile(summon, target, player_power, context)
		"area_pulse":
			if not _spawn_area_pulse(summon, player_power, context):
				_apply_area_pulse(summon, player_power, context)
		_:
			_apply_melee(summon, target, player_power, context)
	_cooldown_remaining = attack_cooldown
	return true


func _apply_melee(summon: Node2D, target: Node2D, player_power: float, context: Dictionary) -> void:
	var amount: int = maxi(roundi(player_power * damage_scale), 0)
	if amount > 0 and target.has_method("take_damage"):
		var skill_id: StringName = _source_skill_id(context)
		target.call("take_damage", {
			"raw_amount": amount,
			"amount": amount,
			"damage_origin": &"special",
			"damage_type": &"summon_damage",
			"element": damage_type,
			"source_type": "summon",
			"source_origin_id": _source_origin_id(context),
			"source_skill_id": skill_id,
			"source_instance_id": "%s:%s" % [String(skill_id), str(summon.get_instance_id()) if summon != null else "summon"]
		}, &"summon_damage")
	_apply_on_hit_effects(target)


func _apply_area_pulse(summon: Node2D, player_power: float, context: Dictionary) -> void:
	if summon == null:
		return
	var target_group: StringName = StringName(str(context.get("target_group", &"enemies")))
	var radius_squared: float = pulse_radius * pulse_radius
	var registry: Node = CombatTargetRegistryScript.get_or_create(summon)
	var targets: Array = registry.call("get_targets_in_radius", summon.global_position, pulse_radius, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in targets:
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if target.has_method("is_dead") and bool(target.call("is_dead")):
			continue
		if summon.global_position.distance_squared_to(target.global_position) > radius_squared:
			continue
		_apply_melee(summon, target, player_power, context)


func _spawn_area_pulse(summon: Node2D, player_power: float, context: Dictionary) -> bool:
	var action_executor: RefCounted = context.get("action_executor") as RefCounted
	if summon == null or action_executor == null or pulse_area_id == &"":
		return false
	var amount: int = maxi(roundi(player_power * damage_scale), 0)
	var area_context: Dictionary = context.duplicate(true)
	area_context["caster"] = summon
	area_context["source"] = summon
	area_context["parent"] = context.get("parent", summon.get_parent())
	area_context["target_group"] = context.get("target_group", &"enemies")
	area_context["power"] = player_power
	var area_params: Dictionary = {
		"area_id": pulse_area_id,
		"position_mode": "caster",
		"radius": pulse_radius,
		"duration": pulse_duration,
		"tick_interval": pulse_tick_interval,
		"damage": amount,
		"damage_type": "summon_damage",
		"element": str(damage_type),
		"damage_origin": "special",
		"source_type": "summon",
		"source_origin_id": _source_origin_id(context),
		"source_skill_id": _source_skill_id(context)
	}
	_apply_pulse_status_params(area_params)
	return bool(action_executor.call("execute_action", {"type": "spawn_area", "params": area_params}, area_context))


func _apply_pulse_status_params(area_params: Dictionary) -> void:
	for effect_variant: Variant in on_hit_effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if str(effect.get("type", "")) != "apply_status":
			continue
		area_params["status_id"] = str(effect.get("status", effect.get("status_id", "")))
		area_params["stack"] = int(effect.get("stacks", effect.get("stack", 1)))
		area_params["status_duration"] = float(effect.get("duration", 4.0))
		return


func _fire_projectile(summon: Node2D, target: Node2D, player_power: float, context: Dictionary) -> void:
	var action_executor: RefCounted = context.get("action_executor") as RefCounted
	if action_executor == null:
		_apply_melee(summon, target, player_power, context)
		return
	var projectile_context: Dictionary = context.duplicate(true)
	projectile_context["caster"] = context.get("owner")
	projectile_context["target"] = target
	projectile_context["source"] = summon
	action_executor.call("execute_action", {
		"type": "spawn_projectile",
		"params": {
			"damage": roundi(player_power * damage_scale),
			"damage_type": "summon_damage",
			"element": str(damage_type),
			"damage_origin": "special",
			"projectile_id": str(projectile_id) if projectile_id != &"" else "thunder_arc_bolt",
			"speed": 420.0,
			"range": attack_range,
			"source_origin_id": _source_origin_id(context),
			"source_skill_id": _source_skill_id(context),
			"on_hit": on_hit_effects
		}
	}, projectile_context)


func _source_origin_id(context: Dictionary) -> StringName:
	return StringName(String(context.get("source_origin_id", "")))


func _source_skill_id(context: Dictionary) -> StringName:
	return StringName(String(context.get("skill_id", context.get("source_skill_id", ""))))


func _apply_on_hit_effects(target: Node2D) -> void:
	for effect_variant: Variant in on_hit_effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if str(effect.get("type", "")) == "apply_status" and target.has_method("apply_status"):
			target.call("apply_status", StringName(str(effect.get("status", effect.get("status_id", "")))), {
				"stacks": int(effect.get("stacks", effect.get("stack", 1))),
				"duration": float(effect.get("duration", 4.0))
			})


func _array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
