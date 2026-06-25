extends RefCounted
class_name SummonAttackComponent


var attack_type: String = "melee"
var attack_range: float = 48.0
var attack_cooldown: float = 1.2
var damage_type: StringName = &"neutral"
var damage_scale: float = 0.45
var on_hit_effects: Array = []
var _cooldown_remaining: float = 0.0


func setup(config: Dictionary) -> void:
	attack_type = String(config.get("attack_type", attack_type))
	attack_range = maxf(float(config.get("attack_range", attack_range)), 1.0)
	attack_cooldown = maxf(float(config.get("attack_cooldown", attack_cooldown)), 0.05)
	damage_type = StringName(String(config.get("damage_type", damage_type)))
	damage_scale = maxf(float(config.get("damage_scale", damage_scale)), 0.0)
	on_hit_effects = _array(config.get("on_hit_effects", []))
	_cooldown_remaining = 0.0


func tick(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func is_in_range(summon: Node2D, target: Node2D) -> bool:
	return summon != null and target != null and summon.global_position.distance_to(target.global_position) <= attack_range


func can_attack() -> bool:
	return _cooldown_remaining <= 0.0


func attack(summon: Node2D, target: Node2D, player_power: float, context: Dictionary) -> bool:
	if summon == null or target == null or not can_attack():
		return false
	if not is_in_range(summon, target):
		return false
	if attack_type == "projectile":
		_fire_projectile(summon, target, player_power, context)
	else:
		_apply_melee(target, player_power)
	_cooldown_remaining = attack_cooldown
	return true


func _apply_melee(target: Node2D, player_power: float) -> void:
	var amount: int = maxi(roundi(player_power * damage_scale), 0)
	if amount > 0 and target.has_method("take_damage"):
		target.call("take_damage", {
			"raw_amount": amount,
			"amount": amount,
			"damage_origin": &"special",
			"damage_type": damage_type,
			"element": damage_type,
			"source_type": "summon"
		}, damage_type)
	_apply_on_hit_effects(target)


func _fire_projectile(summon: Node2D, target: Node2D, player_power: float, context: Dictionary) -> void:
	var action_executor: RefCounted = context.get("action_executor") as RefCounted
	if action_executor == null:
		_apply_melee(target, player_power)
		return
	var projectile_context: Dictionary = context.duplicate(true)
	projectile_context["caster"] = context.get("owner")
	projectile_context["target"] = target
	projectile_context["source"] = summon
	action_executor.call("execute_action", {
		"type": "spawn_projectile",
		"params": {
			"damage": roundi(player_power * damage_scale),
			"damage_type": String(damage_type),
			"damage_origin": "special",
			"speed": 420.0,
			"range": attack_range,
			"on_hit": on_hit_effects
		}
	}, projectile_context)


func _apply_on_hit_effects(target: Node2D) -> void:
	for effect_variant: Variant in on_hit_effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if String(effect.get("type", "")) == "apply_status" and target.has_method("apply_status"):
			target.call("apply_status", StringName(String(effect.get("status", effect.get("status_id", "")))), {
				"stacks": int(effect.get("stacks", effect.get("stack", 1))),
				"duration": float(effect.get("duration", 4.0))
			})


func _array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
