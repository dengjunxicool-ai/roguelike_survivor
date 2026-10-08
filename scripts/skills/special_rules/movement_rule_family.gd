extends RefCounted


var _host_ref: WeakRef

func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


func _update_windstep_state(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("windstep_state") and not rules.has("windstep_projectile_speed"):
		return
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return
	var now_seconds: float = host._now_seconds()
	var moving: bool = host._is_target_moving(caster)
	if moving:
		if not caster.has_meta("hunter_bow_windstep_moving_started_at"):
			caster.set_meta("hunter_bow_windstep_moving_started_at", now_seconds)
	else:
		caster.set_meta("hunter_bow_windstep_moving_started_at", -1.0)
	var state_rule: Dictionary = host._get_dictionary(rules.get("windstep_state", {}))
	if state_rule.is_empty():
		caster.set_meta("hunter_bow_windstep_active_until", now_seconds if moving else -1.0)
		return
	var started_at: float = float(caster.get_meta("hunter_bow_windstep_moving_started_at", -1.0))
	var required: float = maxf(float(state_rule.get("required_moving_seconds", 2.5)), 0.0)
	if moving and started_at >= 0.0 and now_seconds - started_at >= required:
		caster.set_meta("hunter_bow_windstep_active_until", now_seconds + maxf(float(state_rule.get("keep_after_stop", 0.0)), 0.0))
	elif not moving:
		var active_until: float = float(caster.get_meta("hunter_bow_windstep_active_until", -1.0))
		if now_seconds > active_until:
			caster.set_meta("hunter_bow_windstep_active_until", -1.0)


func _apply_windstep_runtime_modifiers(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var moving: bool = host._is_target_moving(context.get("caster") as Node)
	var speed_rule: Dictionary = host._get_dictionary(rules.get("windstep_projectile_speed", {}))
	var projectile_speed_add: Variant = float(speed_rule.get("projectile_speed_multiplier_add", 0.2)) if moving and not speed_rule.is_empty() else null
	host._set_dynamic_runtime_modifier(skill_instance, "hunter_windstep", "projectile_speed_multiplier_add", projectile_speed_add)
	var state_rule: Dictionary = host._get_dictionary(rules.get("windstep_state", {}))
	var attack_speed_add: Variant = float(state_rule.get("attack_speed_multiplier_add", 0.1364)) if host._is_windstep_active(context) and not state_rule.is_empty() else null
	host._set_dynamic_runtime_modifier(skill_instance, "hunter_windstep", "attack_speed_multiplier_add", attack_speed_add)


func _is_windstep_active(context: Dictionary) -> bool:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return false
	return host._now_seconds() <= float(caster.get_meta("hunter_bow_windstep_active_until", -1.0))


func _set_dynamic_runtime_modifier(skill_instance: RefCounted, modifier_namespace: String, key: String, value: Variant) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if skill_instance == null or key == "":
		return
	var modifiers: Dictionary = {}
	var modifiers_variant: Variant = skill_instance.get("runtime_modifiers")
	if modifiers_variant is Dictionary:
		modifiers = (modifiers_variant as Dictionary).duplicate(true)
	var originals_key: String = host._metadata_key(modifier_namespace, "runtime_originals")
	var originals: Dictionary = {}
	var originals_variant: Variant = skill_instance.get_meta(originals_key, {})
	if originals_variant is Dictionary:
		originals = (originals_variant as Dictionary).duplicate(true)
	if not originals.has(key):
		originals[key] = modifiers[key] if modifiers.has(key) else null
	if value == null:
		if originals.has(key):
			if originals[key] == null:
				modifiers.erase(key)
			else:
				modifiers[key] = originals[key]
			originals.erase(key)
	else:
		var base_value: float = float(originals.get(key, 0.0)) if originals.get(key, null) != null else 0.0
		modifiers[key] = base_value + float(value)
	skill_instance.set("runtime_modifiers", modifiers)
	skill_instance.set_meta(originals_key, originals)
