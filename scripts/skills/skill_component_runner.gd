extends RefCounted
class_name SkillComponentRunner


const TargetingServiceScript: Script = preload("res://scripts/skills/targeting_service.gd")
const ModifierResolverScript: Script = preload("res://scripts/skills/modifier_resolver.gd")


func tick(skill_instance: RefCounted, delta: float, context: Dictionary) -> bool:
	if skill_instance == null:
		return false

	var components: Array = _get_components(skill_instance)
	if components.is_empty():
		return false

	if _has_component(components, "persistent_orbit"):
		_ensure_persistent_orbit(skill_instance, components, context)
		return true

	var cooldown_remaining: float = maxf(float(skill_instance.get("cooldown_remaining")) - delta, 0.0)
	skill_instance.set("cooldown_remaining", cooldown_remaining)
	if cooldown_remaining > 0.0:
		return true

	var cast_context: Dictionary = context.duplicate(true)
	cast_context["target"] = _find_target(components, cast_context)
	if cast_context.get("target") == null and _requires_target(components):
		return true

	var event_bus: Node = context.get("event_bus") as Node
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		event_bus.call("emit_skill_event", &"on_cast", cast_context)

	skill_instance.set("cooldown_remaining", _get_cooldown(skill_instance, components, context))
	return true


func get_cooldown(skill_instance: RefCounted, context: Dictionary) -> float:
	return _get_cooldown(skill_instance, _get_components(skill_instance), context)


func _ensure_persistent_orbit(_skill_instance: RefCounted, components: Array, context: Dictionary) -> void:
	var event_bus: Node = context.get("event_bus") as Node
	if event_bus == null or not event_bus.has_method("emit_skill_event"):
		return

	for component_variant: Variant in components:
		if not (component_variant is Dictionary):
			continue
		var component: Dictionary = component_variant
		if String(component.get("type", "")) != "persistent_orbit":
			continue

		var orbit_context: Dictionary = context.duplicate(true)
		orbit_context["component"] = component
		event_bus.call("emit_skill_event", &"on_cast", orbit_context)


func _find_target(components: Array, context: Dictionary) -> Node2D:
	var caster: Node = context.get("caster") as Node
	for component_variant: Variant in components:
		if not (component_variant is Dictionary):
			continue
		var component: Dictionary = component_variant
		if String(component.get("type", "")) != "targeting":
			continue

		var params: Dictionary = _get_dictionary(component.get("params", {})).duplicate(true)
		params["origin"] = caster
		var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
		var special_rules_variant: Variant = skill_instance.get("runtime_special_rules") if skill_instance != null else {}
		if special_rules_variant is Dictionary:
			var special_rules: Dictionary = special_rules_variant
			var hunter_trap_targeting: Dictionary = _get_dictionary(special_rules.get("hunter_trap_targeting", {}))
			if bool(hunter_trap_targeting.get("prefer_strong_targets", false)):
				params["mode"] = String(hunter_trap_targeting.get("targeting_mode", "highest_hp_enemy"))
		if params.has("range"):
			params["range"] = ModifierResolverScript.resolve_value(context, "range", params["range"])
		return TargetingServiceScript.find_target(caster, String(params.get("mode", "nearest_enemy")), params)

	return null


func _get_cooldown(_skill_instance: RefCounted, components: Array, context: Dictionary) -> float:
	for component_variant: Variant in components:
		if not (component_variant is Dictionary):
			continue
		var component: Dictionary = component_variant
		if String(component.get("type", "")) != "cooldown":
			continue

		var params: Dictionary = _get_dictionary(component.get("params", {}))
		return maxf(float(ModifierResolverScript.resolve_value(context, "cooldown", params.get("seconds", 1.0))), 0.05)

	return maxf(float(ModifierResolverScript.get_stat(context, "cooldown", 1.0)), 0.05)


func _requires_target(components: Array) -> bool:
	return _has_component(components, "targeting")


func _has_component(components: Array, component_type: String) -> bool:
	for component_variant: Variant in components:
		if component_variant is Dictionary and String(component_variant.get("type", "")) == component_type:
			return true
	return false


func _get_components(skill_instance: RefCounted) -> Array:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return []

	var components_variant: Variant = definition.get("components")
	return components_variant if components_variant is Array else []


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
