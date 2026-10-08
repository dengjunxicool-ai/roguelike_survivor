extends "res://scripts/skills/skill_action_support.gd"
class_name SkillActionModifierExecutor


func _heal_owner(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return false

	var amount: int = maxi(int(params.get("amount", 0)), 0)
	if amount <= 0 and params.has("max_health_ratio"):
		var max_health_for_ratio: int = maxi(int(caster.get("max_health")), 1)
		amount = maxi(roundi(float(max_health_for_ratio) * float(params.get("max_health_ratio", 0.0))), 1)
	if amount <= 0:
		return false

	var max_health: int = int(caster.get("max_health"))
	var current_health: int = int(caster.get("current_health"))
	caster.set("current_health", mini(current_health + amount, max_health))
	if caster.has_signal("health_changed"):
		caster.emit_signal("health_changed", int(caster.get("current_health")), max_health)
	return true


func _add_temporary_modifier(params: Dictionary, context: Dictionary) -> bool:
	var modifier: Dictionary = _build_modifier_from_params(params)
	if modifier.is_empty():
		return false

	if str(params.get("stat", "")) == "status_dot_damage_taken_multiplier_add_per_stack" and params.get("scope", {}).get("status_id", "") == "burning":
		return _add_status_damage_taken_modifier(&"burning", modifier, params, context)

	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance != null:
		var runtime_modifiers: Dictionary = {}
		var runtime_variant: Variant = skill_instance.get("runtime_modifiers")
		if runtime_variant is Dictionary or runtime_variant is Array:
			runtime_modifiers = ModifierSourceScript.flatten(runtime_variant)
		ModifierSourceScript.merge_flat_values(runtime_modifiers, ModifierSourceScript.flatten(modifier))
		skill_instance.set("runtime_modifiers", runtime_modifiers)
		return true

	var skill_manager: Node = context.get("skill_manager") as Node
	if skill_manager != null and skill_manager.has_method("add_passive_modifier"):
		skill_manager.call("add_passive_modifier", modifier)
		return true
	return false


func _add_status_damage_taken_modifier(status_id: StringName, modifier: Dictionary, params: Dictionary, context: Dictionary) -> bool:
	var target: Node = context.get("target") as Node
	if target == null or status_id == &"":
		return false
	var manager: Node = _get_status_manager(target)
	if manager == null or not manager.has_method("apply_status"):
		return false
	var values: Dictionary = ModifierSourceScript.flatten(modifier)
	if values.is_empty():
		return false
	var duration: float = maxf(float(params.get("duration", 0.6)), 0.05)
	if manager.has_method("merge_status_fields"):
		return bool(manager.call("merge_status_fields", status_id, values, duration))
	var status_params: Dictionary = values.duplicate(true)
	status_params["stacks"] = 1
	status_params["duration"] = duration
	return bool(manager.call("apply_status", status_id, status_params))


func _grant_shield(params: Dictionary, context: Dictionary) -> bool:
	var owner: Node = context.get("owner") as Node
	if owner == null:
		owner = context.get("caster") as Node
	if owner == null:
		return false

	var max_health: float = maxf(_get_float_property(owner, "max_health", 0.0), 0.0)
	var amount: int = maxi(roundi(_resolve_scaled_amount(params.get("amount", 0.0), context, "shield")), 0)
	if amount <= 0 and params.has("max_health_ratio"):
		amount = maxi(roundi(max_health * float(params.get("max_health_ratio", 0.0))), 0)
	amount = maxi(roundi(float(amount) * maxf(1.0 + _combined_modifier_value("holy_shield_restore_multiplier", context, 0.0), 0.05)), 0)
	if amount <= 0:
		return false

	var duration: float = maxf(float(params.get("duration", 6.0)), 0.05)
	var shield_type: String = str(params.get("shield_type", "fire_skill"))
	var current: int = int(owner.get_meta("fire_passive_shield", 0))
	var expires_at: float = float(owner.get_meta("fire_passive_shield_expires_at", 0.0))
	if expires_at > 0.0 and expires_at <= _now_seconds():
		current = 0
	var final_amount: int = current + amount
	var overflow: int = 0
	if bool(params.get("respect_shield_cap", false)) and max_health > 0.0:
		var cap_ratio: float = maxf(float(params.get("shield_cap_health_ratio", 0.35)), 0.01)
		cap_ratio *= maxf(1.0 + _combined_modifier_value("holy_shield_cap_multiplier", context, 0.0), 0.05)
		var cap: int = maxi(roundi(max_health * cap_ratio), amount)
		if final_amount > cap:
			overflow = final_amount - cap
			final_amount = cap

	context["shield_overflowed"] = overflow > 0
	context["shield_overflow_amount"] = overflow
	context["shield_gained_amount"] = maxi(final_amount - current, 0)

	owner.set_meta("fire_passive_shield", final_amount)
	owner.set_meta("fire_passive_shield_expires_at", _now_seconds() + duration)
	var shield_meta_key: String = _metadata_key(shield_type, "shield")
	var shield_expires_meta_key: String = _metadata_key(shield_type, "shield_expires_at")
	owner.set_meta(shield_meta_key, int(owner.get_meta(shield_meta_key, 0)) + maxi(final_amount - current, 0))
	owner.set_meta(shield_expires_meta_key, _now_seconds() + duration)
	var event_bus: Node = context.get("event_bus") as Node
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		var shield_context: Dictionary = context.duplicate(true)
		shield_context["owner"] = owner
		shield_context["shield_type"] = shield_type
		shield_context["shield_amount"] = maxi(final_amount - current, 0)
		shield_context["shield_overflowed"] = overflow > 0
		shield_context["shield_overflow_amount"] = overflow
		event_bus.call("emit_skill_event", &"shield_gained", shield_context)
	return true


func _repeat_skill(params: Dictionary, context: Dictionary) -> bool:
	var actions: Array = _get_array(params.get("actions", []))
	if actions.is_empty():
		push_warning("[SkillActionExecutor] repeat_skill needs explicit actions in this runtime.")
		return false
	var times: int = maxi(int(params.get("times", params.get("count", 1))), 1)
	for _index in range(times):
		execute_actions(actions, context)
	return true
