## 文件用途：调度技能组件的冷却、目标查找、触发规则施放和持续环绕物创建。
## 使用方式：SkillExecutor 每帧 tick 传技能实例、delta 和上下文，冷却到期且满足目标条件后触发动作和事件。
extends RefCounted
class_name SkillComponentRunner


const TargetingServiceScript: Script = preload("res://scripts/skills/targeting_service.gd")
const ModifierResolverScript: Script = preload("res://scripts/skills/modifier_resolver.gd")
const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")
const Growth: Script = preload("res://scripts/skills/skill_growth_scaling.gd")


## 作用：在技能有效时包裹性能采样并推进组件施放调度。
## 使用：skill_instance 为技能运行实例；delta 为本帧经过的秒数；context 为施放或命中上下文。
func tick(skill_instance: RefCounted, delta: float, context: Dictionary) -> bool:
	var hot_path_start: int = HotPathProfilerScript.begin_context(context)
	var result: bool = _tick_profiled(skill_instance, delta, context)
	HotPathProfilerScript.end_context(context, &"skill_cast_tick", hot_path_start)
	return result


## 作用：扣减技能冷却，查找组件目标并在就绪后执行动作与施放事件。
## 使用：skill_instance 为技能运行实例；delta 为本帧经过的秒数；context 携带 event_bus；返回布尔判断或执行是否成功。
func _tick_profiled(skill_instance: RefCounted, delta: float, context: Dictionary) -> bool:
	if skill_instance == null:
		return false

	var components: Array = _get_components(skill_instance)
	if components.is_empty():
		return _tick_trigger_rule_cast_skill(skill_instance, delta, context)

	if _has_component(components, "persistent_orbit"):
		_ensure_persistent_orbit(skill_instance, components, context)
		return true

	var cooldown_remaining: float = maxf(float(skill_instance.get("cooldown_remaining")) - delta, 0.0)
	skill_instance.set("cooldown_remaining", cooldown_remaining)
	if cooldown_remaining > 0.0:
		return true

	var cast_context: Dictionary = context.duplicate(true)
	cast_context["scheduled_cast"] = true
	cast_context["target"] = _find_target(components, cast_context)
	if cast_context.get("target") == null and _requires_target(components):
		return true

	var event_bus: Node = context.get("event_bus") as Node
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		event_bus.call("emit_skill_event", &"on_cast", cast_context)

	skill_instance.set("cooldown_remaining", _get_cooldown(skill_instance, components, context))
	return true


## 作用：为以 cast_skill 触发规则描述的技能安排冷却与施放事件。
## 使用：skill_instance 为技能运行实例；delta 为本帧经过的秒数；context 携带 event_bus；返回布尔判断或执行是否成功。
func _tick_trigger_rule_cast_skill(skill_instance: RefCounted, delta: float, context: Dictionary) -> bool:
	if not _has_cast_skill_trigger_rule(skill_instance):
		return false

	var cooldown_remaining: float = maxf(float(skill_instance.get("cooldown_remaining")) - delta, 0.0)
	skill_instance.set("cooldown_remaining", cooldown_remaining)
	if cooldown_remaining > 0.0:
		return true

	var cast_context: Dictionary = context.duplicate(true)
	cast_context["scheduled_cast"] = true
	if cast_context.get("target") == null:
		cast_context["target"] = _find_default_target(cast_context)

	var event_bus: Node = context.get("event_bus") as Node
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		event_bus.call("emit_skill_event", &"on_cast", cast_context)

	skill_instance.set("cooldown_remaining", _get_cast_skill_trigger_cooldown(skill_instance, context))
	return true


## 作用：取得技能当前最终冷却，供外部调度和调试展示。
## 使用：skill_instance 为技能运行实例；context 为施放或命中上下文。
func get_cooldown(skill_instance: RefCounted, context: Dictionary) -> float:
	return _get_cooldown(skill_instance, _get_components(skill_instance), context)


## 作用：检查技能持续环绕组件，缺对象时创建而非每次重建。
## 使用：context 携带 event_bus。
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


## 作用：根据组件目标策略和上下文选择技能施放目标。
## 使用：context 携带 caster/skill_instance；无法解析或创建时返回 null。
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


## 作用：使用技能默认策略查询施放目标。
## 使用：context 携带 caster。
func _find_default_target(context: Dictionary) -> Node2D:
	var caster: Node = context.get("caster") as Node
	return TargetingServiceScript.find_target(caster, "nearest_enemy", {
		"origin": caster,
		"range": ModifierResolverScript.get_stat(context, "range", INF)
	})


## 作用：通过属性服务和组件配置求得施放间隔。
## 使用：context 为施放或命中上下文。
func _get_cooldown(_skill_instance: RefCounted, components: Array, context: Dictionary) -> float:
	for component_variant: Variant in components:
		if not (component_variant is Dictionary):
			continue
		var component: Dictionary = component_variant
		if String(component.get("type", "")) != "cooldown":
			continue

		var params: Dictionary = _get_dictionary(component.get("params", {}))
		return _scaled_cooldown(float(params.get("seconds", 1.0)), _skill_instance, context)

	if _has_cast_skill_trigger_rule(_skill_instance):
		return _get_cast_skill_trigger_cooldown(_skill_instance, context)
	return _scaled_cooldown(float(ModifierResolverScript.get_stat(context, "cooldown", 1.0)), _skill_instance, context, true)


## 作用：从施放触发规则计算冷却间隔。
## 使用：skill_instance 为技能运行实例；context 为施放或命中上下文。
func _get_cast_skill_trigger_cooldown(skill_instance: RefCounted, context: Dictionary) -> float:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return maxf(float(ModifierResolverScript.get_stat(context, "cooldown", 1.0)), 0.05)
	var fallback: float = float(ModifierResolverScript.get_stat(context, "cooldown", 1.0))
	for rule_variant: Variant in _get_array(definition.get("trigger_rules")):
		if not (rule_variant is Dictionary):
			continue
		var rule: Dictionary = rule_variant
		if String(rule.get("trigger", "")) == "cast_skill" and rule.has("cooldown"):
			return _scaled_cooldown(float(rule.get("cooldown")), skill_instance, context)
	return maxf(fallback, 0.05)

func _scaled_cooldown(base: float, skill: RefCounted, context: Dictionary, already_resolved: bool = false) -> float:
	var adjusted: float = base if already_resolved else float(ModifierResolverScript.resolve_value(context, "cooldown", base))
	return maxf(maxf(adjusted * Growth.stat_multiplier(skill, "cooldown"), base * 0.35), 0.05)


## 作用：判断技能组件施放是否必须有有效目标。
## 使用：由本文件 _tick_profiled 调用。
func _requires_target(components: Array) -> bool:
	return _has_component(components, "targeting")


## 作用：检查技能配置是否包含指定组件类型。
## 使用：由本文件 _tick_profiled/_requires_target 调用；返回布尔判断或执行是否成功。
func _has_component(components: Array, component_type: String) -> bool:
	for component_variant: Variant in components:
		if component_variant is Dictionary and String(component_variant.get("type", "")) == component_type:
			return true
	return false


## 作用：判断定义是否具备 cast_skill 触发规则入口。
## 使用：skill_instance 为技能运行实例；返回布尔判断或执行是否成功。
func _has_cast_skill_trigger_rule(skill_instance: RefCounted) -> bool:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return false
	for rule_variant: Variant in _get_array(definition.get("trigger_rules")):
		if rule_variant is Dictionary and String((rule_variant as Dictionary).get("trigger", "")) == "cast_skill":
			return true
	return false


## 作用：读取技能定义 components 并返回可用于调度的数组。
## 使用：skill_instance 为技能运行实例；无匹配项时返回空数组。
func _get_components(skill_instance: RefCounted) -> Array:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return []

	var components_variant: Variant = definition.get("components")
	return components_variant if components_variant is Array else []


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 _get_cast_skill_trigger_cooldown/_has_cast_skill_trigger_rule 调用；无匹配项时返回空数组。
func _get_array(value: Variant) -> Array:
	if value is Array:
		var items: Array = value
		return items
	return []


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 _find_target/_get_cooldown 调用；无适用数据时返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
