extends RefCounted
class_name SkillActionSupport


const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const DamageSourceIdentityScript: Script = preload("res://scripts/combat/damage_source_identity.gd")
const ModifierResolverScript: Script = preload("res://scripts/skills/modifier_resolver.gd")
const SkillEffectAdapterScript: Script = preload("res://scripts/skills/skill_effect_adapter.gd")
const SkillActionAreaBuilderScript: Script = preload("res://scripts/skills/skill_action_area_builder.gd")
const SkillActionProjectileBuilderScript: Script = preload("res://scripts/skills/skill_action_projectile_builder.gd")
const SkillRangeUnitScript: Script = preload("res://scripts/skills/skill_range_unit.gd")
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const SkillSpecialRuleExecutorScript: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")
const TargetingServiceScript: Script = preload("res://scripts/skills/targeting_service.gd")
const ConditionEvaluatorScript: Script = preload("res://scripts/skills/condition_evaluator.gd")
const RuntimePoolRegistryScript: Script = preload("res://scripts/runtime/runtime_pool_registry.gd")
const InstantAreaHitVisualScript: Script = preload("res://scripts/combat/instant_area_hit_visual.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const MetadataKeyScript: Script = preload("res://scripts/core/metadata_key.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/runtime/debug_combat_trace.gd")
const DamageTraceContextScript: Script = preload("res://scripts/runtime/damage_trace_context.gd")
const SummonDefinitionScript: Script = preload("res://scripts/summons/summon_definition.gd")
const SummonManagerScript: Script = preload("res://scripts/summons/summon_manager.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

const ELEMENT_ALIASES: Dictionary = {
	"frost": "ice",
	"thunder": "lightning",
	"curse": "arcane"
}

static var _projectile_burst_budget_frame_by_key: Dictionary = {}
static var _projectile_burst_budget_used_by_key: Dictionary = {}
static var _aoe_status_apply_frame: int = -1
static var _aoe_status_apply_keys: Dictionary = {}

var _special_rule_executor: RefCounted


var _dispatch_owner: WeakRef

func bind_executor(executor: RefCounted) -> void:
	_dispatch_owner = weakref(executor)
	_special_rule_executor = executor.get("_special_rule_executor")

func _dispatcher() -> RefCounted:
	return _dispatch_owner.get_ref() if _dispatch_owner != null else self

func execute_action(action: Dictionary, context: Dictionary) -> Variant:
	return _dispatcher().call("execute_action", action, context)

func execute_actions(actions: Array, context: Dictionary) -> void:
	_dispatcher().call("execute_actions", actions, context)

func _resolve_position(params: Dictionary, context: Dictionary) -> Vector2:
	if params.has("position"):
		return _get_vector2(params["position"], Vector2.ZERO)

	if context.has("position") and not params.has("position_mode"):
		return _get_vector2(context.get("position"), Vector2.ZERO)

	var position_mode: String = str(params.get("position_mode", "target"))
	if position_mode == "caster" or position_mode == "owner" or position_mode == "self":
		var caster_for_mode: Node2D = context.get("caster") as Node2D
		var base_position: Vector2 = caster_for_mode.global_position if caster_for_mode != null else Vector2.ZERO
		return base_position + _resolve_position_offset(params, context, base_position)

	var target: Node2D = context.get("target") as Node2D
	if target != null:
		return target.global_position

	var caster: Node2D = context.get("caster") as Node2D
	return caster.global_position if caster != null else Vector2.ZERO


func _resolve_position_offset(params: Dictionary, context: Dictionary, base_position: Vector2) -> Vector2:
	if params.has("position_offset"):
		return _get_vector2(params["position_offset"], Vector2.ZERO)
	var distance: float = float(params.get("position_offset_distance", 0.0))
	if distance <= 0.0:
		return Vector2.ZERO
	return _resolve_named_direction(str(params.get("position_offset_direction", "towards_target")), context, base_position) * distance


func _resolve_cone_direction(params: Dictionary, context: Dictionary, area_position: Vector2) -> Vector2:
	if params.has("cone_direction"):
		var configured: Vector2 = _get_vector2(params["cone_direction"], Vector2.RIGHT)
		return configured.normalized() if configured.length_squared() > 0.0001 else Vector2.RIGHT
	var caster: Node2D = context.get("caster") as Node2D
	var target: Node2D = context.get("target") as Node2D
	if caster != null and target != null:
		var target_direction: Vector2 = target.global_position - caster.global_position
		if target_direction.length_squared() > 0.0001:
			return target_direction.normalized()
	if caster != null:
		var forward: Vector2 = area_position - caster.global_position
		if forward.length_squared() > 0.0001:
			return forward.normalized()
	return Vector2.RIGHT


func _resolve_area_move_direction(params: Dictionary, context: Dictionary, area_position: Vector2) -> Vector2:
	if not params.has("move_direction"):
		return Vector2.ZERO
	var direction_value: Variant = params.get("move_direction")
	if direction_value is String:
		return _resolve_named_direction(str(direction_value), context, area_position)
	var direction: Vector2 = _get_vector2(direction_value, Vector2.ZERO)
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.ZERO


func _resolve_named_direction(name: String, context: Dictionary, origin: Vector2) -> Vector2:
	match name:
		"towards_target", "target":
			var target: Node2D = context.get("target") as Node2D
			if target != null:
				var target_direction: Vector2 = target.global_position - origin
				if target_direction.length_squared() > 0.0001:
					return target_direction.normalized()
				var caster_for_same_position: Node2D = context.get("caster") as Node2D
				if caster_for_same_position != null:
					var caster_to_target: Vector2 = target.global_position - caster_for_same_position.global_position
					if caster_to_target.length_squared() > 0.0001:
						return caster_to_target.normalized()
		"away_from_target":
			var target_for_away: Node2D = context.get("target") as Node2D
			if target_for_away != null:
				var away_direction: Vector2 = origin - target_for_away.global_position
				if away_direction.length_squared() > 0.0001:
					return away_direction.normalized()
		"caster_forward":
			var caster: Node2D = context.get("caster") as Node2D
			if caster != null:
				var caster_forward: Vector2 = origin - caster.global_position
				if caster_forward.length_squared() > 0.0001:
					return caster_forward.normalized()
	return Vector2.RIGHT


func _context_with_resolved_target(params: Dictionary, context: Dictionary) -> Dictionary:
	var target: Node = _valid_node_or_null(context.get("target"))
	var target_2d: Node2D = target as Node2D
	var has_invalid_target_reference: bool = context.has("target") and target == null
	var has_invalid_enemy_reference: bool = context.has("enemy") and _valid_node_or_null(context.get("enemy")) == null
	var force_configured_targeting: bool = params.has("targeting") or params.has("targeting_mode")
	if not force_configured_targeting and target != null and (target_2d == null or TargetingServiceScript.is_valid_target(target_2d)):
		return context
	var resolved_target: Node2D = _resolve_action_target(params, context)
	if resolved_target == null:
		if has_invalid_target_reference or has_invalid_enemy_reference or (not force_configured_targeting and target != null):
			var cleared_context: Dictionary = context.duplicate(true)
			cleared_context.erase("target")
			cleared_context.erase("enemy")
			return cleared_context
		return context
	var resolved_context: Dictionary = context.duplicate(true)
	resolved_context["target"] = resolved_target
	resolved_context["enemy"] = resolved_target
	return resolved_context


func _valid_node_or_null(value: Variant) -> Node:
	if value == null or typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as Node


func _valid_node2d_or_null(value: Variant) -> Node2D:
	if value == null or typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as Node2D


func _resolve_action_target(params: Dictionary, context: Dictionary) -> Node2D:
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return null
	var mode: String = str(params.get("targeting", params.get("targeting_mode", "nearest_enemy")))
	if mode == "":
		return null
	var range: float = float(params.get("range", params.get("detect_range", ModifierResolverScript.get_stat(context, "range", INF))))
	return TargetingServiceScript.find_target(caster, mode, {
		"origin": caster,
		"range": range,
		"radius": range,
		"cluster_radius": float(params.get("cluster_radius", params.get("radius", 168.0))),
		"count": 1
	})


func _resolve_area_tick_interval(area_source_id: StringName, params: Dictionary, special_rules: Dictionary) -> float:
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_tick_interval"):
		var rule: Dictionary = _get_dictionary(special_rules.get("acid_pressure_tick_interval", {}))
		return maxf(float(rule.get("tick_interval_override", params.get("tick_interval", 0.1))), 0.05)
	return maxf(float(params.get("tick_interval", 0.1)), 0.05)


func _get_damage_type(params: Dictionary, context: Dictionary, source_type: String = "skill", damage_origin: String = "") -> StringName:
	if params.has("damage_type"):
		var configured_damage_type: String = str(params["damage_type"])
		if _is_element_name(configured_damage_type):
			return _infer_damage_type(_get_element(params, context), source_type, damage_origin)
		return _normalize_configured_damage_type(configured_damage_type, _get_element(params, context), source_type, damage_origin)

	var context_damage_type: String = str(context.get("damage_type", ""))
	if context_damage_type != "":
		if _is_element_name(context_damage_type):
			return _infer_damage_type(StringName(_normalize_element_name(context_damage_type)), source_type, damage_origin)
		return _normalize_configured_damage_type(context_damage_type, _get_element(params, context), source_type, damage_origin)

	return _infer_damage_type(_get_element(params, context), source_type, damage_origin)


func _get_element(params: Dictionary, context: Dictionary) -> StringName:
	if params.has("element"):
		return StringName(_normalize_element_name(str(params["element"])))
	if params.has("damage_type") and _is_element_name(str(params["damage_type"])):
		return StringName(_normalize_element_name(str(params["damage_type"])))
	var context_element: String = str(context.get("element", ""))
	if context_element != "":
		return StringName(_normalize_element_name(context_element))
	var context_damage_type: String = str(context.get("damage_type", ""))
	if _is_element_name(context_damage_type):
		return StringName(_normalize_element_name(context_damage_type))
	return &"physical"


func _get_damage_origin(params: Dictionary, context: Dictionary, source_type: String) -> String:
	var configured: String = str(params.get("damage_origin", context.get("damage_origin", "")))
	match configured:
		"primary_attack", "status_dot", "reaction", "field", "trap", "special", "healing":
			return configured
		"status":
			return "status_dot"

	if source_type == "trap":
		return "trap"
	if source_type == "explosion":
		return "primary_attack"
	if source_type == "status":
		return "status_dot"
	var field_model: String = str(params.get("field_damage_model", ""))
	if field_model == "dot_tick":
		return "status_dot"
	if source_type == "area":
		return "field"
	if source_type == "cast":
		return "field"
	return "primary_attack"


func _normalize_configured_damage_type(value: String, element: StringName, source_type: String, damage_origin: String) -> StringName:
	return DamageRuleRegistryScript.normalize_configured_damage_type(value, element, source_type, damage_origin, "SkillActionExecutor")


func _infer_damage_type(element: StringName, source_type: String, damage_origin: String) -> StringName:
	return DamageRuleRegistryScript.infer_damage_type(element, source_type, damage_origin)


func _is_element_name(value: String) -> bool:
	return DamageRuleRegistryScript.is_element(value) or ELEMENT_ALIASES.has(value)


func _normalize_element_name(value: String) -> String:
	return str(ELEMENT_ALIASES.get(value, value))


func _build_damage_packet(params: Dictionary, context: Dictionary, amount: int, source_type: String) -> Dictionary:
	source_type = _effective_action_source_type(params, source_type)
	var damage_origin: String = _get_damage_origin(params, context, source_type)
	var damage_type: StringName = _get_damage_type(params, context, source_type, damage_origin)
	var element: StringName = _get_element(params, context)
	var caster: Node = context.get("caster") as Node
	var uses_skill_level: bool = bool(params.get("uses_skill_level_coefficient", damage_origin == "primary_attack" and context.get("skill_instance") != null))
	var packet: Dictionary = DamagePacketBuilderScript.from_skill_action({
		"params": params,
		"context": context,
		"amount": amount,
		"source_type": source_type,
		"damage_origin": damage_origin,
		"damage_type": damage_type,
		"element": element,
		"skill_level_coefficient": _get_skill_level_coefficient(context) if uses_skill_level else 1.0
	})
	_apply_damage_packet_modifiers(packet, params, context)
	_apply_shared_primary_attack_crit(packet, params, context, caster)
	return packet


func _effective_action_source_type(params: Dictionary, fallback: String) -> String:
	var configured: String = str(params.get("source_type", ""))
	return configured if configured != "" else fallback


func _apply_damage_packet_modifiers(packet: Dictionary, params: Dictionary, context: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var skill_modifiers: Dictionary = SkillStatServiceScript.get_combined_modifiers(
		skill_instance,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node
	)

	for key: String in _get_damage_packet_modifier_keys(packet):
		_add_numeric_packet_modifier(packet, key, params)
		_add_numeric_packet_modifier(packet, key, skill_modifiers)
	if str(packet.get("element", "")) == "lightning" and _target_has_status(context.get("target") as Node, &"conductive"):
		packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(skill_modifiers.get("conductive_lightning_damage_taken_multiplier", 0.0))
	if str(packet.get("element", "")) == "holy" and _target_has_status(context.get("target") as Node, &"judgment"):
		var judgment_stacks: int = maxi(_target_status_stack(context.get("target") as Node, &"judgment"), 1)
		packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(skill_modifiers.get("judgment_holy_damage_taken_multiplier", 0.0)) * float(judgment_stacks)


func _get_damage_packet_modifier_keys(packet: Dictionary) -> Array[String]:
	var keys: Array[String] = [
		"crit_chance_add",
		"crit_damage_add",
		"primary_attack_damage_multiplier_add",
		"direct_damage_multiplier_add",
		"starting_skill_damage_add",
		"dot_damage_multiplier_add",
		"reaction_damage_multiplier_add",
		"field_damage_multiplier_add",
		"area_damage_multiplier_add",
		"trap_damage_multiplier_add",
		"boss_damage_multiplier_add",
		"elite_damage_multiplier_add"
	]
	var element: String = str(packet.get("element", ""))
	if element != "" and element != "neutral":
		keys.append("%s_damage_multiplier_add" % element)
	return keys


func _add_numeric_packet_modifier(packet: Dictionary, key: String, source: Dictionary) -> void:
	if source.has(key):
		packet[key] = float(packet.get(key, 0.0)) + float(source[key])


func _apply_shared_primary_attack_crit(packet: Dictionary, params: Dictionary, context: Dictionary, caster: Node) -> void:
	var packet_object: RefCounted = DamagePacketScript.from_dictionary(packet, caster, context.get("target") as Node)
	if not bool(packet_object.call("get_value", "can_crit", false)):
		return
	if str(packet_object.call("get_value", "damage_origin", "")) != "primary_attack":
		return
	if not bool(params.get("share_primary_attack_crit", true)):
		return
	if caster == null:
		return

	var cache_key: String = "shared_primary_attack_crit"
	if not context.has(cache_key):
		var damage_modifiers: Dictionary = ModifierAggregatorScript.collect(ModifierQueryScript.for_damage(packet_object, caster))
		var crit_chance: float = clampf(_get_float_property(caster, "crit_chance", 0.0) + float(packet_object.call("get_value", "crit_chance_add", params.get("crit_chance_add", 0.0))) + float(damage_modifiers.get("crit_chance_add", 0.0)), 0.0, 1.0)
		var crit_damage: float = maxf(_get_float_property(caster, "crit_damage", 1.5) + float(packet_object.call("get_value", "crit_damage_add", params.get("crit_damage_add", 0.0))) + float(damage_modifiers.get("crit_damage_add", 0.0)), 1.0)
		context[cache_key] = {
			"is_critical": randf() < crit_chance,
			"crit_multiplier": crit_damage
		}

	var crit_result: Dictionary = context.get(cache_key, {})
	var is_critical: bool = bool(crit_result.get("is_critical", false))
	packet["critical_resolved"] = true
	packet["is_critical"] = is_critical
	packet["crit_multiplier"] = float(crit_result.get("crit_multiplier", 1.0)) if is_critical else 1.0


func _default_can_crit(damage_origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_can_crit(damage_origin, damage_type)


func _default_uses_character_damage(damage_origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_uses_character_damage(damage_origin, damage_type)


func _get_skill_level_coefficient(context: Dictionary) -> float:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		push_warning("[SkillActionExecutor] Missing skill_instance for skill_level_coefficient; defaulting to 1.0.")
		return 1.0

	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	var scaling: Dictionary = {}
	if definition != null:
		var scaling_variant: Variant = definition.get("damage_scaling")
		if scaling_variant is Dictionary:
			scaling = scaling_variant
	var coefficients: Array = _get_array(scaling.get("skill_level_coefficients", []))
	if coefficients.is_empty():
		return 1.0

	var level_index: int = maxi(int(skill_instance.get("current_level")) - 1, 0)
	if level_index >= coefficients.size():
		push_warning("[SkillActionExecutor] skill_level_coefficients out of range for %s level %d; defaulting to 1.0." % [str(skill_instance.get("skill_id")), level_index + 1])
		return 1.0
	return maxf(float(coefficients[level_index]), 0.0)


func _build_orbit_params(params: Dictionary, context: Dictionary, caster: Node2D, orbit_radius: float, area_radius: float, source_id: StringName, angle: float) -> Dictionary:
	var damage: int = 0
	if params.has("damage"):
		damage = maxi(roundi(_resolve_scaled_amount(params["damage"], context, "damage")), 0)
	var orbit_packet_params: Dictionary = params.duplicate(true)
	if not orbit_packet_params.has("source_instance_id"):
		orbit_packet_params["source_instance_id"] = DamageSourceIdentityScript.for_orbit(caster, context.get("skill_id", ""), source_id)
	return {
		"owner": caster,
		"angle": angle,
		"damage": damage,
		"damage_type": _get_damage_type(orbit_packet_params, context, "area", _get_damage_origin(orbit_packet_params, context, "area")),
		"damage_packet": _build_damage_packet(orbit_packet_params, context, damage, "area"),
		"orbit_radius": orbit_radius,
		"rotation_speed": float(ModifierResolverScript.resolve_value(context, "rotation_speed", params.get("rotation_speed", 220.0))),
		"hit_interval": maxf(float(ModifierResolverScript.resolve_value(context, "hit_interval", params.get("hit_interval", 0.45))), 0.05),
		"area_radius": area_radius,
		"target_group": context.get("target_group", &"enemies"),
		"event_bus": context.get("event_bus"),
		"skill_instance": context.get("skill_instance"),
		"caster": caster,
		"skill_manager": context.get("skill_manager"),
		"relic_manager": context.get("relic_manager"),
		"source_id": source_id,
		"object_id": source_id,
		"event_on_hit": &"on_orbit_hit"
	}


func _get_orbit_objects(parent: Node, caster: Node2D, skill_id: StringName, source_id: StringName) -> Array[Node2D]:
	var objects: Array[Node2D] = []
	if parent == null or caster == null:
		return objects

	for child: Node in parent.get_children():
		var orbit_object: Node2D = child as Node2D
		if orbit_object == null or not orbit_object.has_meta("skill_id") or not orbit_object.has_meta("owner_instance_id"):
			continue
		if StringName(str(orbit_object.get_meta("skill_id"))) != skill_id:
			continue
		if int(orbit_object.get_meta("owner_instance_id")) != int(caster.get_instance_id()):
			continue
		if source_id != &"" and StringName(str(orbit_object.get_meta("source_id", ""))) != source_id:
			continue

		objects.append(orbit_object)

	return objects


func _get_parent_node(context: Dictionary) -> Node:
	var parent: Node = context.get("parent") as Node
	if parent != null:
		return parent

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		return tree.current_scene

	var caster: Node = context.get("caster") as Node
	return caster.get_parent() if caster != null else null


func _get_root_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


func _get_debug_attack_trace_id(context: Dictionary) -> int:
	var root: Node = _get_root_node()
	return DamageTraceContextScript.get_trace_id(context, root, true)


func _next_cast_instance_id(context: Dictionary) -> String:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var skill_key: String = str(context.get("skill_id", "skill"))
	if skill_instance == null:
		return "%s:%d" % [skill_key, Time.get_ticks_msec()]
	var nonce: int = int(skill_instance.get_meta("cast_instance_nonce", 0)) + 1
	skill_instance.set_meta("cast_instance_nonce", nonce)
	return "%s:%d" % [skill_key, nonce]


func _consume_hot_rapid_fire_pending(context: Dictionary) -> bool:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("hot_rapid_fire_next_cast", false)):
		return false
	skill_instance.set_meta("hot_rapid_fire_next_cast", false)
	return true


func _mark_storm_hail_cast(context: Dictionary, cast_instance_id: String) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("storm_hail_next_cast", false)):
		return
	skill_instance.set_meta("storm_hail_next_cast", false)
	skill_instance.set_meta("storm_hail_cast_instance_id", cast_instance_id)


func _consume_arcane_double_page_pending(context: Dictionary) -> int:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("arcane_double_page_next_cast", false)):
		return 0
	var extra_count: int = maxi(int(skill_instance.get_meta("arcane_double_page_extra_projectiles", 1)), 0)
	skill_instance.set_meta("arcane_double_page_next_cast", false)
	skill_instance.set_meta("arcane_double_page_extra_projectiles", 0)
	return extra_count


func _consume_forbidden_page_pending(context: Dictionary) -> bool:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("forbidden_page_next_cast", false)):
		return false
	skill_instance.set_meta("forbidden_page_next_cast", false)
	return true


func _cast_instance_id_for_area(context: Dictionary) -> String:
	var projectile: Node = context.get("projectile") as Node
	if projectile != null:
		var projectile_cast_id: String = str(projectile.get_meta("cast_instance_id", ""))
		if projectile_cast_id != "":
			return projectile_cast_id
	return _next_cast_instance_id(context)


func _get_storm_hail_rule_for_context(context: Dictionary) -> Dictionary:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return {}
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return {}
	if str(projectile.get_meta("cast_instance_id", "")) != str(skill_instance.get_meta("storm_hail_cast_instance_id", "")):
		return {}
	var rules_variant: Variant = skill_instance.get("runtime_special_rules")
	if not (rules_variant is Dictionary):
		return {}
	var rules: Dictionary = rules_variant
	var rule_variant: Variant = rules.get("storm_hail_every_n_casts", {})
	if rule_variant is Dictionary:
		return (rule_variant as Dictionary).duplicate(true)
	return {}


func _get_hot_rapid_fire_crit_chance_add(context: Dictionary) -> float:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return 0.0
	return float(skill_instance.get_meta("hot_rapid_fire_crit_chance_add", 0.0))


func _resolve_scaled_amount(value: Variant, context: Dictionary, stat_name: String = "damage") -> float:
	if value is Dictionary:
		var data: Dictionary = value
		if str(data.get("stat", "")) == "power":
			if context.has("power"):
				return float(context.get("power", 0.0)) * float(data.get("scale", 1.0))
			var power: float = float(ModifierResolverScript.resolve_value(context, stat_name, ModifierResolverScript.get_stat(context, "power", _get_caster_attack_power(context))))
			return power * float(data.get("scale", 1.0))
	return float(ModifierResolverScript.resolve_value(context, stat_name, value))


func _build_modifier_from_params(params: Dictionary) -> Dictionary:
	return ModifierSourceScript.flatten_effects([params], ModifierSourceScript.SOURCE_SKILL)


func _get_caster_attack_power(context: Dictionary) -> float:
	var caster: Object = context.get("caster") as Object
	if caster == null:
		return 1.0
	for property_name: String in ["attack_power", "damage", "base_damage"]:
		if _has_property(caster, property_name):
			return float(caster.get(property_name))
	return 1.0


func _get_status_power_from_context(context: Dictionary) -> float:
	for packet_key: String in ["damage_packet", "source_packet", "packet"]:
		var packet_variant: Variant = context.get(packet_key)
		if packet_variant is Dictionary:
			var packet: Dictionary = packet_variant
			var amount: float = float(packet.get("raw_amount", packet.get("amount", 0.0)))
			if amount > 0.0:
				return amount
	var amount: float = float(context.get("amount", 0.0))
	if amount > 0.0:
		return amount
	return _get_caster_attack_power(context)


func _should_coalesce_area_status_apply(target: Node, status_id: StringName, context: Dictionary) -> bool:
	if target == null or status_id == &"":
		return true
	if not context.has("area") and not context.has("area_tick_stats"):
		return false
	var frame: int = int(Engine.get_physics_frames())
	if _aoe_status_apply_frame != frame:
		_aoe_status_apply_frame = frame
		_aoe_status_apply_keys.clear()
	var key: String = "%d|%s" % [int(target.get_instance_id()), String(status_id)]
	if _aoe_status_apply_keys.has(key):
		return true
	_aoe_status_apply_keys[key] = true
	return false


func _increment_area_tick_status_apply(context: Dictionary) -> void:
	var stats_variant: Variant = context.get("area_tick_stats", {})
	if not (stats_variant is Dictionary):
		return
	var stats: Dictionary = stats_variant
	stats["status_apply_count"] = int(stats.get("status_apply_count", 0)) + 1


func _apply_status_to_target(target: Node, status_id: StringName, status_params: Dictionary = {}) -> bool:
	if target == null or status_id == &"":
		return false
	if target.has_method("apply_status"):
		return bool(target.call("apply_status", status_id, status_params))
	if target.has_method("add_status_effect"):
		target.call("add_status_effect", status_id)
		return true
	var manager: Node = _get_status_manager(target)
	if manager != null and manager.has_method("apply_status"):
		return bool(manager.call("apply_status", status_id, status_params))
	return false


func _consume_status_stack_on_target(target: Node, status_id: StringName, stacks: int) -> bool:
	if target == null or status_id == &"":
		return false
	if target.has_method("consume_status_stack"):
		return bool(target.call("consume_status_stack", status_id, stacks))
	var manager: Node = _get_status_manager(target)
	if manager != null and manager.has_method("consume_status_stack"):
		return bool(manager.call("consume_status_stack", status_id, stacks))
	return false


func _get_status_manager(target: Node) -> Node:
	return target.get_node_or_null("StatusEffectManager") if target != null else null


func _effects_to_actions(effects: Array) -> Array:
	return SkillEffectAdapterScript.to_actions(effects)


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _has_property(object: Object, property: String) -> bool:
	if object == null:
		return false
	for property_info: Dictionary in object.get_property_list():
		if str(property_info.get("name", "")) == property:
			return true
	return false


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _get_runtime_special_rules(context: Dictionary) -> Dictionary:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return {}
	var special_rules_variant: Variant = skill_instance.get("runtime_special_rules")
	if special_rules_variant is Dictionary:
		return (special_rules_variant as Dictionary).duplicate(true)
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	return fallback


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_float_property(object: Object, property: String, fallback: float) -> float:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if str(property_info.get("name", "")) == property:
			return float(object.get(property))
	return fallback


func _combined_modifier_value(key: String, context: Dictionary, fallback: float = 0.0) -> float:
	if key == "":
		return fallback
	var modifiers: Dictionary = SkillStatServiceScript.get_combined_modifiers(
		context.get("skill_instance") as RefCounted,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	)
	return float(modifiers.get(key, fallback))


func _target_has_status(target: Node, status_id: StringName) -> bool:
	if target == null or status_id == &"":
		return false
	if target.has_method("has_status") and bool(target.call("has_status", status_id)):
		return true
	var manager: Node = target.get_node_or_null("StatusEffectManager")
	return manager != null and manager.has_method("has_status") and bool(manager.call("has_status", status_id))


func _target_status_stack(target: Node, status_id: StringName) -> int:
	if target == null or status_id == &"":
		return 0
	if target.has_method("get_status_stack"):
		return int(target.call("get_status_stack", status_id))
	var manager: Node = target.get_node_or_null("StatusEffectManager")
	if manager != null and manager.has_method("get_status_stack"):
		return int(manager.call("get_status_stack", status_id))
	return 1 if _target_has_status(target, status_id) else 0


func _get_status_ids(params: Dictionary) -> Array[StringName]:
	var status_ids: Array[StringName] = []
	var ids_variant: Variant = params.get("status_ids", [])
	if ids_variant is Array:
		for id_variant: Variant in ids_variant:
			var status_id: StringName = StringName(str(id_variant))
			if status_id != &"" and not status_ids.has(status_id):
				status_ids.append(status_id)

	var single_id: StringName = StringName(str(params.get("status_id", "")))
	if single_id != &"" and not status_ids.has(single_id):
		status_ids.append(single_id)

	return status_ids


func _find_targets_around(origin: Vector2, radius: float, target_group: StringName, excluded: Variant = null) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var radius_squared: float = radius * radius
	var registry: Node = CombatTargetRegistryScript.get_or_create(null)
	var candidates: Array = registry.call("get_targets_in_radius", origin, radius, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in candidates:
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target) or target == excluded:
			continue
		if target.has_method("is_dead") and bool(target.call("is_dead")):
			continue
		if origin.distance_squared_to(target.global_position) <= radius_squared:
			targets.append(target)

	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return targets


func _get_statuses_on_hit(params: Dictionary, context: Dictionary = {}) -> Array[StringName]:
	var statuses: Array[StringName] = []
	var statuses_variant: Variant = params.get("statuses_on_hit", [])
	if statuses_variant is Array:
		var status_items: Array = statuses_variant
		for status_variant: Variant in status_items:
			var status_id: StringName = StringName(str(status_variant))
			if status_id != &"" and not statuses.has(status_id):
				statuses.append(status_id)

	var single_status: StringName = StringName(str(params.get("status_id", params.get("status_on_hit", ""))))
	if single_status != &"" and not statuses.has(single_status):
		statuses.append(single_status)

	return statuses


func _get_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var status_params: Dictionary = _get_dictionary(params.get("status_params", {}))
	if params.has("status_duration") or params.has("duration"):
		status_params["duration"] = float(ModifierResolverScript.resolve_value(context, "status_duration", params.get("status_duration", params.get("duration"))))
	if params.has("status_damage"):
		status_params["damage"] = int(ModifierResolverScript.resolve_value(context, "status_damage", params["status_damage"]))
	if params.has("status_tick_interval"):
		status_params["tick_interval"] = float(ModifierResolverScript.resolve_value(context, "status_tick_interval", params["status_tick_interval"]))
	if params.has("stack"):
		status_params["stacks"] = int(params["stack"])
	if params.has("max_stacks"):
		status_params["max_stacks"] = int(params["max_stacks"])
	return DamageTraceContextScript.apply_to_status_params(status_params, context)


func _metadata_key(namespace_text: String, suffix: String) -> String:
	return MetadataKeyScript.key(namespace_text, suffix, "skill_action")


func _metadata_identifier(raw_key: String) -> String:
	return MetadataKeyScript.identifier(raw_key, "skill_action")
func _apply_status(params: Dictionary, context: Dictionary) -> bool:
	return _dispatcher().call("_dispatch_family_method", "_apply_status", [params, context])

func _deal_damage(params: Dictionary, context: Dictionary) -> bool:
	return _dispatcher().call("_dispatch_family_method", "_deal_damage", [params, context])

func _spawn_projectile_burst(params: Dictionary, context: Dictionary) -> bool:
	return _dispatcher().call("_dispatch_family_method", "_spawn_projectile_burst", [params, context])
