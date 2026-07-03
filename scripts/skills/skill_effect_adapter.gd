extends RefCounted
class_name SkillEffectAdapter

const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")

static func to_actions(effects: Array, skill_instance: RefCounted = null, effect_context: String = "") -> Array:
	var actions: Array = []
	for effect_variant: Variant in effects:
		if effect_variant is Dictionary:
			var action: Dictionary = to_action(effect_variant as Dictionary, skill_instance, effect_context)
			if not action.is_empty():
				actions.append(action)
	return actions


static func to_action(effect: Dictionary, skill_instance: RefCounted = null, effect_context: String = "") -> Dictionary:
	var effect_type: String = str(effect.get("type", ""))
	var params: Dictionary = effect.duplicate(true)
	params.erase("type")
	_apply_growth_to_params(params, effect_type, skill_instance, effect_context)
	match effect_type:
		"damage":
			return {"type": "deal_damage", "params": _normalize_damage_params(params)}
		"apply_status":
			return {"type": "apply_status", "params": _normalize_status_params(params)}
		"spawn_area":
			return {"type": "spawn_area", "params": _normalize_area_params(params)}
		"instant_area_hit":
			return {"type": "instant_area_hit", "params": _normalize_area_params(params)}
		"spawn_projectile":
			return {"type": "spawn_projectile", "params": _normalize_projectile_params(params)}
		"spawn_projectiles_at_targets":
			return {"type": "spawn_projectiles_at_targets", "params": _normalize_projectile_params(params)}
		"spawn_summon":
			return {"type": "spawn_summon", "params": params}
		"chain_to_targets":
			return {"type": "chain_to_targets", "params": _normalize_chain_params(params)}
		"consume_status_stack":
			return {"type": "consume_status_stack", "params": _normalize_status_params(params)}
		"damage_by_status_stack":
			return {"type": "damage_by_status_stack", "params": _normalize_status_stack_damage_params(params)}
		"mark_target":
			return {"type": "mark_target", "params": params}
		"add_modifier":
			return {"type": "add_temporary_modifier", "params": params}
		"grant_shield":
			return {"type": "grant_shield", "params": params}
		"heal":
			return {"type": "heal_owner", "params": params}
		"pull":
			return {"type": "pull", "params": params}
		"knockback":
			return {"type": "knockback", "params": params}
		"repeat_skill":
			return {"type": "repeat_skill", "params": params}
		"swap_targets":
			return {"type": "swap_targets", "params": params}
		"transform_area":
			return {"type": "transform_area", "params": params}
		"transfer_status":
			return {"type": "transfer_status", "params": params}
		"consume_status_duration":
			return {"type": "consume_status_duration", "params": params}
		"trigger_overload":
			return {"type": "trigger_overload", "params": params}
		"shatter_frozen":
			return {"type": "shatter_frozen", "params": params}
		"spawn_projectile_burst":
			return {"type": "spawn_projectile_burst", "params": params}
		"repeat_area_path":
			return {"type": "repeat_area_path", "params": params}
		"spawn_area_from_existing_area":
			return {"type": "spawn_area_from_existing_area", "params": params}
		_:
			push_warning("[SkillEffectAdapter] Unsupported effect type: %s" % effect_type)
			return {}


static func _normalize_damage_params(params: Dictionary) -> Dictionary:
	if params.has("power_scale") and not params.has("amount"):
		params["amount"] = {"stat": "power", "scale": float(params.get("power_scale", 0.0))}
	if params.has("source_type") and not params.has("damage_origin"):
		params["damage_origin"] = str(params.get("source_type"))
	params.erase("_skill_instance")
	return params


static func _normalize_status_params(params: Dictionary) -> Dictionary:
	if params.has("status") and not params.has("status_id"):
		params["status_id"] = params["status"]
	if params.has("stacks") and not params.has("stack"):
		params["stack"] = params["stacks"]
	params.erase("_skill_instance")
	return params


static func _normalize_area_params(params: Dictionary) -> Dictionary:
	if params.has("effects_on_tick"):
		params["actions_on_tick"] = to_actions(_get_array(params.get("effects_on_tick", [])), params.get("_skill_instance", null) as RefCounted, "tick")
	if params.has("effects_on_apply"):
		params["actions_on_apply"] = to_actions(_get_array(params.get("effects_on_apply", [])), params.get("_skill_instance", null) as RefCounted, "apply")
	if params.has("effects_on_expire"):
		params["actions_on_expire"] = to_actions(_get_array(params.get("effects_on_expire", [])), params.get("_skill_instance", null) as RefCounted, "expire")
	if params.has("effects_on_death"):
		params["actions_on_death"] = to_actions(_get_array(params.get("effects_on_death", [])), params.get("_skill_instance", null) as RefCounted, "death")
	params.erase("_skill_instance")
	return params


static func _normalize_projectile_params(params: Dictionary) -> Dictionary:
	if params.has("on_hit"):
		params["actions_on_hit"] = to_actions(_get_array(params.get("on_hit", [])), params.get("_skill_instance", null) as RefCounted, "hit")
	if params.has("effects_on_hit"):
		params["actions_on_hit"] = to_actions(_get_array(params.get("effects_on_hit", [])), params.get("_skill_instance", null) as RefCounted, "hit")
	if params.has("damage") and params.get("damage") is Dictionary:
		var damage: Dictionary = params.get("damage")
		if damage.has("power_scale"):
			params["damage"] = {"stat": "power", "scale": float(damage.get("power_scale", 0.0))}
		for key_variant: Variant in damage.keys():
			var key: String = str(key_variant)
			if not params.has(key):
				params[key] = damage[key_variant]
	params.erase("_skill_instance")
	return params


static func _normalize_chain_params(params: Dictionary) -> Dictionary:
	if params.has("actions"):
		params["actions"] = to_actions(_get_array(params.get("actions", [])), params.get("_skill_instance", null) as RefCounted, "chain")
	params.erase("_skill_instance")
	return params


static func _normalize_status_stack_damage_params(params: Dictionary) -> Dictionary:
	if params.has("status") and not params.has("status_id"):
		params["status_id"] = params["status"]
	if params.has("power_scale_per_stack") and not params.has("amount_per_stack"):
		params["amount_per_stack"] = {"stat": "power", "scale": float(params.get("power_scale_per_stack", 0.0))}
	params.erase("_skill_instance")
	return params


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _apply_growth_to_params(params: Dictionary, effect_type: String, skill_instance: RefCounted, effect_context: String) -> void:
	if skill_instance == null:
		return
	params["_skill_instance"] = skill_instance
	match effect_type:
		"damage":
			if effect_context != "tick":
				_scale_damage_params(params, skill_instance)
		"spawn_area", "create_explosion", "spawn_trap", "spawn_area_from_existing_area":
			_scale_numeric_keys(params, skill_instance, ["radius", "radius_r", "collision_radius", "collision_radius_r", "area_radius", "area_radius_r", "pull_radius", "pull_radius_r"], "radius")
			_scale_numeric_keys(params, skill_instance, ["duration"], "duration")
			_scale_damage_params(params, skill_instance)
		"spawn_projectile", "spawn_projectile_burst", "spawn_projectiles_at_targets":
			_scale_numeric_keys(params, skill_instance, ["radius", "radius_r", "collision_radius", "collision_radius_r", "range", "range_r"], "radius")
			_scale_numeric_keys(params, skill_instance, ["lifetime"], "duration")
			_scale_damage_params(params, skill_instance)
		"spawn_orbit_object", "spawn_orbitals":
			_scale_numeric_keys(params, skill_instance, ["orbit_radius", "orbit_radius_r", "collision_radius", "collision_radius_r"], "radius")
			_scale_numeric_keys(params, skill_instance, ["duration"], "duration")
			_scale_damage_params(params, skill_instance)


static func _scale_damage_params(params: Dictionary, skill_instance: RefCounted) -> void:
	if params.has("power_scale"):
		params["power_scale"] = SkillGrowthScalingScript.apply_to_number(float(params.get("power_scale", 0.0)), skill_instance, "damage")
	if params.has("scale"):
		params["scale"] = SkillGrowthScalingScript.apply_to_number(float(params.get("scale", 0.0)), skill_instance, "damage")
	if params.has("amount"):
		params["amount"] = _scale_amount_value(params.get("amount"), skill_instance)
	if params.has("damage") and params.get("damage") is Dictionary:
		var damage: Dictionary = params.get("damage")
		if damage.has("power_scale"):
			damage["power_scale"] = SkillGrowthScalingScript.apply_to_number(float(damage.get("power_scale", 0.0)), skill_instance, "damage")
		if damage.has("scale"):
			damage["scale"] = SkillGrowthScalingScript.apply_to_number(float(damage.get("scale", 0.0)), skill_instance, "damage")


static func _scale_amount_value(value: Variant, skill_instance: RefCounted) -> Variant:
	if value is Dictionary:
		var amount: Dictionary = (value as Dictionary).duplicate(true)
		if amount.has("scale"):
			amount["scale"] = SkillGrowthScalingScript.apply_to_number(float(amount.get("scale", 0.0)), skill_instance, "damage")
		return amount
	if _is_number(value):
		var scaled: float = SkillGrowthScalingScript.apply_to_number(float(value), skill_instance, "damage")
		return roundi(scaled) if typeof(value) == TYPE_INT else scaled
	return value


static func _scale_numeric_keys(params: Dictionary, skill_instance: RefCounted, keys: Array[String], stat_kind: String) -> void:
	for key: String in keys:
		if not params.has(key) or not _is_number(params[key]):
			continue
		var scaled: float = SkillGrowthScalingScript.apply_to_number(float(params[key]), skill_instance, stat_kind)
		params[key] = roundi(scaled) if typeof(params[key]) == TYPE_INT else scaled


static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT
