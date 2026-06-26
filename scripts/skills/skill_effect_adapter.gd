extends RefCounted
class_name SkillEffectAdapter


static func to_actions(effects: Array) -> Array:
	var actions: Array = []
	for effect_variant: Variant in effects:
		if effect_variant is Dictionary:
			var action: Dictionary = to_action(effect_variant as Dictionary)
			if not action.is_empty():
				actions.append(action)
	return actions


static func to_action(effect: Dictionary) -> Dictionary:
	var effect_type: String = str(effect.get("type", ""))
	var params: Dictionary = effect.duplicate(true)
	params.erase("type")
	match effect_type:
		"damage":
			return {"type": "deal_damage", "params": _normalize_damage_params(params)}
		"apply_status":
			return {"type": "apply_status", "params": _normalize_status_params(params)}
		"spawn_area":
			return {"type": "spawn_area", "params": _normalize_area_params(params)}
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
	return params


static func _normalize_status_params(params: Dictionary) -> Dictionary:
	if params.has("status") and not params.has("status_id"):
		params["status_id"] = params["status"]
	if params.has("stacks") and not params.has("stack"):
		params["stack"] = params["stacks"]
	return params


static func _normalize_area_params(params: Dictionary) -> Dictionary:
	if params.has("effects_on_tick"):
		params["actions_on_tick"] = to_actions(_get_array(params.get("effects_on_tick", [])))
	if params.has("effects_on_apply"):
		params["actions_on_apply"] = to_actions(_get_array(params.get("effects_on_apply", [])))
	if params.has("effects_on_expire"):
		params["actions_on_expire"] = to_actions(_get_array(params.get("effects_on_expire", [])))
	if params.has("effects_on_death"):
		params["actions_on_death"] = to_actions(_get_array(params.get("effects_on_death", [])))
	return params


static func _normalize_projectile_params(params: Dictionary) -> Dictionary:
	if params.has("on_hit"):
		params["actions_on_hit"] = to_actions(_get_array(params.get("on_hit", [])))
	if params.has("effects_on_hit"):
		params["actions_on_hit"] = to_actions(_get_array(params.get("effects_on_hit", [])))
	if params.has("damage") and params.get("damage") is Dictionary:
		var damage: Dictionary = params.get("damage")
		if damage.has("power_scale"):
			params["damage"] = {"stat": "power", "scale": float(damage.get("power_scale", 0.0))}
		for key_variant: Variant in damage.keys():
			var key: String = str(key_variant)
			if not params.has(key):
				params[key] = damage[key_variant]
	return params


static func _normalize_chain_params(params: Dictionary) -> Dictionary:
	if params.has("actions"):
		params["actions"] = to_actions(_get_array(params.get("actions", [])))
	return params


static func _normalize_status_stack_damage_params(params: Dictionary) -> Dictionary:
	if params.has("status") and not params.has("status_id"):
		params["status_id"] = params["status"]
	if params.has("power_scale_per_stack") and not params.has("amount_per_stack"):
		params["amount_per_stack"] = {"stat": "power", "scale": float(params.get("power_scale_per_stack", 0.0))}
	return params


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
