## 文件用途：为动作族提供目标、位置、伤害包、来源身份、状态及冷却元数据等共享能力。
## 使用方式：SkillActionExecutor 初始化族后 bind_executor；族调用共享方法或通过弱引用返回分派器执行嵌套动作。
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

## 作用：弱引用绑定动作分派器，并共享其特殊规则执行器。
## 使用：SkillActionExecutor 初始化族后 bind_executor；族调用共享方法或通过弱引用返回分派器执行嵌套动作。
func bind_executor(executor: RefCounted) -> void:
	_dispatch_owner = weakref(executor)
	_special_rule_executor = executor.get("_special_rule_executor")

## 作用：取得动作分派宿主，未绑定时返回当前实例。
## 使用：由本文件 execute_action/execute_actions 调用。
func _dispatcher() -> RefCounted:
	return _dispatch_owner.get_ref() if _dispatch_owner != null else self

## 作用：检查动作条件后按 type 转入对应动作族并返回执行结果。
## 使用：context 为施放或命中上下文。
func execute_action(action: Dictionary, context: Dictionary) -> Variant:
	return _dispatcher().call("execute_action", action, context)

## 作用：按动作数组顺序执行字典动作，跳过非字典项。
## 使用：actions 为依次执行的动作列表；context 为施放或命中上下文。
func execute_actions(actions: Array, context: Dictionary) -> void:
	_dispatcher().call("execute_actions", actions, context)

## 作用：优先使用显式位置或事件位置，否则按位置模式解析施法者、目标及偏移。
## 使用：params 读取 position/position_mode；context 携带 position/caster/target。
func _resolve_position(params: Dictionary, context: Dictionary) -> Vector2:
	if String(params.get("position_mode", "")) == "event": return context.get("position", Vector2.ZERO)
	if String(params.get("position_mode", "")) == "area_end":
		var area: Node2D = context.get("area") as Node2D
		return area.global_position+Vector2(area.cone_direction)*(float(area.effect_length) if area.effect_shape=="line" else float(area.radius)) if area != null else context.get("position",Vector2.ZERO)
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


## 作用：优先取显式向量偏移，否则按配置方向和距离计算偏移。
## 使用：params 读取 position_offset/position_offset_distance/position_offset_direction；context 为施放或命中上下文。
func _resolve_position_offset(params: Dictionary, context: Dictionary, base_position: Vector2) -> Vector2:
	if params.has("position_offset"):
		return _get_vector2(params["position_offset"], Vector2.ZERO)
	var distance: float = float(params.get("position_offset_distance", 0.0))
	if distance <= 0.0:
		return Vector2.ZERO
	return _resolve_named_direction(str(params.get("position_offset_direction", "towards_target")), context, base_position) * distance


## 作用：优先用配置方向，否则根据施法者到目标或区域的方向计算扇形朝向。
## 使用：params 读取 cone_direction；context 携带 caster/target。
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


## 作用：把区域 move_direction 的命名方向或向量转换为单位方向，缺字段不移动。
## 使用：params 读取 move_direction；context 为施放或命中上下文。
func _resolve_area_move_direction(params: Dictionary, context: Dictionary, area_position: Vector2) -> Vector2:
	if not params.has("move_direction"):
		return Vector2.ZERO
	var direction_value: Variant = params.get("move_direction")
	if direction_value is String:
		return _resolve_named_direction(str(direction_value), context, area_position)
	var direction: Vector2 = _get_vector2(direction_value, Vector2.ZERO)
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.ZERO


## 作用：按朝向目标、背向目标或施法者前方解析方向，无法解析时向右。
## 使用：context 携带 target/caster；origin 为世界位置或伤害来源。
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


## 作用：检查事件中的目标引用并按动作指定策略重新选择，返回可供动作使用的上下文。
## 使用：params 读取 targeting/targeting_mode；context 携带 target/enemy。
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


## 作用：只保留有效且未排队删除的 Node 引用。
## 使用：由本文件 _context_with_resolved_target 调用；无法解析或创建时返回 null。
func _valid_node_or_null(value: Variant) -> Node:
	if value == null or typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as Node


## 作用：在有效节点检查后要求 Node2D，供位置计算使用。
## 使用：SkillActionExecutor 初始化族后 bind_executor；族调用共享方法或通过弱引用返回分派器执行嵌套动作；无法解析或创建时返回 null。
func _valid_node2d_or_null(value: Variant) -> Node2D:
	if value == null or typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as Node2D


## 作用：依据动作目标选择设置和事件上下文确定当前执行目标。
## 使用：params 读取 targeting/targeting_mode/range/detect_range；context 携带 caster；无法解析或创建时返回 null。
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


## 作用：酸液锥形区域存在压力间隔规则时取覆盖值，其余取动作 tick_interval，均至少零点零五秒。
## 使用：params 读取 tick_interval。
func _resolve_area_tick_interval(area_source_id: StringName, params: Dictionary, special_rules: Dictionary) -> float:
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_tick_interval"):
		var rule: Dictionary = _get_dictionary(special_rules.get("acid_pressure_tick_interval", {}))
		return maxf(float(rule.get("tick_interval_override", params.get("tick_interval", 0.1))), 0.05)
	return maxf(float(params.get("tick_interval", 0.1)), 0.05)


## 作用：确定动作伤害分类，优先配置并按来源语义推断缺省类型。
## 使用：params 读取 damage_type；context 携带 damage_type。
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


## 作用：从动作参数及技能上下文解析伤害元素并归一别名。
## 使用：params 读取 element/damage_type；context 携带 element/damage_type。
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


## 作用：从动作参数与上下文确定主攻击、区域、陷阱等伤害来源分类。
## 使用：params 读取 damage_origin/field_damage_model；context 携带 damage_origin。
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


## 作用：把配置伤害类型转换为执行器认可的伤害分类。
## 使用：由本文件 _get_damage_type 调用。
func _normalize_configured_damage_type(value: String, element: StringName, source_type: String, damage_origin: String) -> StringName:
	return DamageRuleRegistryScript.normalize_configured_damage_type(value, element, source_type, damage_origin, "SkillActionExecutor")


## 作用：依据元素和伤害来源推断物理、魔法或持续伤害分类。
## 使用：由本文件 _get_damage_type 调用。
func _infer_damage_type(element: StringName, source_type: String, damage_origin: String) -> StringName:
	return DamageRuleRegistryScript.infer_damage_type(element, source_type, damage_origin)


## 作用：检查字符串是否属于支持的元素名称或别名。
## 使用：由本文件 _get_damage_type/_get_element 调用。
func _is_element_name(value: String) -> bool:
	return DamageRuleRegistryScript.is_element(value) or ELEMENT_ALIASES.has(value)


## 作用：将 frost、thunder、curse 等别名归一为标准元素。
## 使用：由本文件 _get_damage_type/_get_element 调用。
func _normalize_element_name(value: String) -> String:
	return str(ELEMENT_ALIASES.get(value, value))


## 作用：汇总技能来源、数值、暴击、元素及规则修正，构建严格伤害包。
## 使用：params 读取 uses_skill_level_coefficient；context 携带 caster/skill_instance；amount 为本次伤害或动作数值。
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


## 作用：解析当前动作的实际战斗对象来源类型。
## 使用：params 读取 source_type；fallback 为缺值备用结果。
func _effective_action_source_type(params: Dictionary, fallback: String) -> String:
	var configured: String = str(params.get("source_type", ""))
	return configured if configured != "" else fallback


## 作用：把作用于伤害包的查询属性和动作参数合并到包字段。
## 使用：packet 为待修饰伤害包视图；params 为动作或状态参数；context 携带 skill_instance/skill_manager/relic_manager/target；会原地更新 packet.vulnerability_total。
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


## 作用：枚举当前伤害对象需要从聚合属性读取的伤害包修正键。
## 使用：packet 为待修饰伤害包视图。
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


## 作用：把数值型修正累加到伤害包指定字段。
## 使用：packet 为待修饰伤害包视图；source 为来源数据或对象。
func _add_numeric_packet_modifier(packet: Dictionary, key: String, source: Dictionary) -> void:
	if source.has(key):
		packet[key] = float(packet.get(key, 0.0)) + float(source[key])


## 作用：为主攻击包补充玩家共享暴击属性。
## 使用：packet 为待修饰伤害包视图；params 读取 share_primary_attack_crit/crit_chance_add/crit_damage_add；context 携带 target；会原地更新 packet.critical_resolved/is_critical/crit_multiplier。
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


## 作用：按伤害来源分类判定未配置时是否允许暴击。
## 使用：SkillActionExecutor 初始化族后 bind_executor；族调用共享方法或通过弱引用返回分派器执行嵌套动作。
func _default_can_crit(damage_origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_can_crit(damage_origin, damage_type)


## 作用：按动作和伤害来源判定默认是否应用角色伤害缩放。
## 使用：SkillActionExecutor 初始化族后 bind_executor；族调用共享方法或通过弱引用返回分派器执行嵌套动作。
func _default_uses_character_damage(damage_origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_uses_character_damage(damage_origin, damage_type)


## 作用：读取并计算来源技能等级系数。
## 使用：context 携带 skill_instance。
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


## 作用：为环绕对象补充施法者、目标组及伤害与轨道参数。
## 使用：params 读取 damage/rotation_speed/hit_interval；context 携带 skill_id/target_group/event_bus/skill_instance；caster 为施法者节点。
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


## 作用：从上下文读取并筛出当前仍有效的环绕对象引用。
## 使用：parent 为生成对象父节点；caster 为施法者节点；skill_id 为标准技能 ID。
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


## 作用：解析战斗对象应该挂载的父节点。
## 使用：context 携带 parent/caster。
func _get_parent_node(context: Dictionary) -> Node:
	var parent: Node = context.get("parent") as Node
	if parent != null:
		return parent

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		return tree.current_scene

	var caster: Node = context.get("caster") as Node
	return caster.get_parent() if caster != null else null


## 作用：从事件上下文或施法者获取当前场景树根节点。
## 使用：由本文件 _get_debug_attack_trace_id 调用。
func _get_root_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


## 作用：取得本次调试攻击追踪 ID，供衍生对象保留诊断关联。
## 使用：context 为施放或命中上下文。
func _get_debug_attack_trace_id(context: Dictionary) -> int:
	var root: Node = _get_root_node()
	return DamageTraceContextScript.get_trace_id(context, root, true)


## 作用：生成新的施放实例身份以区分同一技能不同次施放。
## 使用：context 携带 skill_instance/skill_id；写入 cast_instance_nonce 元数据。
func _next_cast_instance_id(context: Dictionary) -> String:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var skill_key: String = str(context.get("skill_id", "skill"))
	if skill_instance == null:
		return "%s:%d" % [skill_key, Time.get_ticks_msec()]
	var nonce: int = int(skill_instance.get_meta("cast_instance_nonce", 0)) + 1
	skill_instance.set_meta("cast_instance_nonce", nonce)
	return "%s:%d" % [skill_key, nonce]


## 作用：消费技能预留的热连发标记，将本次额外弹体与暴击信息写入施放上下文。
## 使用：context 携带 skill_instance；写入 hot_rapid_fire_next_cast 元数据；返回布尔判断或执行是否成功。
func _consume_hot_rapid_fire_pending(context: Dictionary) -> bool:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("hot_rapid_fire_next_cast", false)):
		return false
	skill_instance.set_meta("hot_rapid_fire_next_cast", false)
	return true


## 作用：把技能预留冰雹强化标记转为本次施放标识。
## 使用：context 携带 skill_instance；写入 storm_hail_next_cast/storm_hail_cast_instance_id 元数据。
func _mark_storm_hail_cast(context: Dictionary, cast_instance_id: String) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("storm_hail_next_cast", false)):
		return
	skill_instance.set_meta("storm_hail_next_cast", false)
	skill_instance.set_meta("storm_hail_cast_instance_id", cast_instance_id)


## 作用：消费预留的奥术双页标记并增加本次投射物数量。
## 使用：context 携带 skill_instance；写入 arcane_double_page_next_cast/arcane_double_page_extra_projectiles 元数据。
func _consume_arcane_double_page_pending(context: Dictionary) -> int:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("arcane_double_page_next_cast", false)):
		return 0
	var extra_count: int = maxi(int(skill_instance.get_meta("arcane_double_page_extra_projectiles", 1)), 0)
	skill_instance.set_meta("arcane_double_page_next_cast", false)
	skill_instance.set_meta("arcane_double_page_extra_projectiles", 0)
	return extra_count


## 作用：消费禁页施放标记，给本次上下文附加禁页命中语义。
## 使用：context 携带 skill_instance；写入 forbidden_page_next_cast 元数据；返回布尔判断或执行是否成功。
func _consume_forbidden_page_pending(context: Dictionary) -> bool:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("forbidden_page_next_cast", false)):
		return false
	skill_instance.set_meta("forbidden_page_next_cast", false)
	return true


## 作用：取得区域所属的施放身份，保证同次区域与投射物关联。
## 使用：context 携带 projectile。
func _cast_instance_id_for_area(context: Dictionary) -> String:
	var projectile: Node = context.get("projectile") as Node
	if projectile != null:
		var projectile_cast_id: String = str(projectile.get_meta("cast_instance_id", ""))
		if projectile_cast_id != "":
			return projectile_cast_id
	return _next_cast_instance_id(context)


## 作用：从当前技能有效规则读取冰雹周期强化配置。
## 使用：context 携带 skill_instance/projectile；无适用数据时返回空字典。
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


## 作用：读取本次热连发施放对应的暴击概率增量。
## 使用：context 携带 skill_instance。
func _get_hot_rapid_fire_crit_chance_add(context: Dictionary) -> float:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return 0.0
	return float(skill_instance.get_meta("hot_rapid_fire_crit_chance_add", 0.0))


## 作用：把数值或配置表达式转换为应用技能缩放后的动作数值。
## 使用：context 携带 power；stat_name 为待查询属性键。
func _resolve_scaled_amount(value: Variant, context: Dictionary, stat_name: String = "damage") -> float:
	if value is Dictionary:
		var data: Dictionary = value
		if str(data.get("stat", "")) == "power":
			if context.has("power"):
				var explicit_power: float = float(context.get("power", 0.0))
				if not bool(context.get("status_power_snapshot", false)):
					explicit_power = float(ModifierResolverScript.resolve_value(context, stat_name, explicit_power))
				return explicit_power * float(data.get("scale", 1.0)) * float(context.get("cast_damage_multiplier", 1.0))
			var power: float = float(ModifierResolverScript.resolve_value(context, stat_name, ModifierResolverScript.get_stat(context, "power", _get_caster_attack_power(context))))
			return power * float(data.get("scale", 1.0)) * float(context.get("cast_damage_multiplier", 1.0))
	return float(ModifierResolverScript.resolve_value(context, stat_name, value))


## 作用：将动作参数整理为临时属性效果或聚合快照。
## 使用：params 为动作或状态参数。
func _build_modifier_from_params(params: Dictionary) -> Dictionary:
	return ModifierSourceScript.flatten_effects([params], ModifierSourceScript.SOURCE_SKILL)


## 作用：从施法者属性读取伤害缩放需要的攻击强度。
## 使用：context 携带 caster。
func _get_caster_attack_power(context: Dictionary) -> float:
	var caster: Object = context.get("caster") as Object
	if caster == null:
		return 1.0
	for property_name: String in ["attack_power", "damage", "base_damage"]:
		if _has_property(caster, property_name):
			return float(caster.get(property_name))
	return 1.0


## 作用：从伤害包或技能上下文推导状态施加强度。
## 使用：context 携带 amount。
func _get_status_power_from_context(context: Dictionary) -> float:
	if context.has("power"):
		return maxf(float(context.power), 0.0)
	var caster: Node = context.get("caster") as Node
	return _get_caster_attack_power(context) * maxf(_get_float_property(caster, "damage_multiplier", 1.0), 0.0)


## 作用：判断同帧同区域来源对同目标的状态施加是否应合并以避免重复。
## 使用：target 为本次命中目标；status_id 为标准状态 ID；context 携带 area/area_tick_stats；返回布尔判断或执行是否成功。
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


## 作用：记录当前帧区域状态施加身份并更新重复施加计数。
## 使用：context 携带 area_tick_stats。
func _increment_area_tick_status_apply(context: Dictionary) -> void:
	var stats_variant: Variant = context.get("area_tick_stats", {})
	if not (stats_variant is Dictionary):
		return
	var stats: Dictionary = stats_variant
	stats["status_apply_count"] = int(stats.get("status_apply_count", 0)) + 1


## 作用：为目标补齐状态规则与来源参数后调用公开状态施加入口。
## 使用：target 为本次命中目标；status_id 为标准状态 ID；返回布尔判断或执行是否成功。
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


## 作用：在目标支持状态消耗接口时扣除指定层数。
## 使用：target 为本次命中目标；status_id 为标准状态 ID；返回布尔判断或执行是否成功。
func _consume_status_stack_on_target(target: Node, status_id: StringName, stacks: int) -> bool:
	if target == null or status_id == &"":
		return false
	if target.has_method("consume_status_stack"):
		return bool(target.call("consume_status_stack", status_id, stacks))
	var manager: Node = _get_status_manager(target)
	if manager != null and manager.has_method("consume_status_stack"):
		return bool(manager.call("consume_status_stack", status_id, stacks))
	return false


## 作用：取得目标的 StatusEffectManager 子节点。
## 使用：target 为本次命中目标。
func _get_status_manager(target: Node) -> Node:
	return target.get_node_or_null("StatusEffectManager") if target != null else null


## 作用：将配置 effects 交给技能效果适配器生成动作列表。
## 使用：effects 为配置效果列表。
func _effects_to_actions(effects: Array) -> Array:
	return SkillEffectAdapterScript.to_actions(effects)


## 作用：把引擎单调毫秒计时转换为冷却使用的秒数。
## 使用：SkillActionExecutor 初始化族后 bind_executor；族调用共享方法或通过弱引用返回分派器执行嵌套动作。
func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## 作用：遍历对象属性列表确认字段存在，供动态节点契约检查。
## 使用：由本文件 _get_caster_attack_power 调用；返回布尔判断或执行是否成功。
func _has_property(object: Object, property: String) -> bool:
	if object == null:
		return false
	for property_info: Dictionary in object.get_property_list():
		if str(property_info.get("name", "")) == property:
			return true
	return false


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 _resolve_area_tick_interval/_get_status_params 调用；无适用数据时返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：读取实例当前运行特殊规则字典。
## 使用：context 携带 skill_instance；无适用数据时返回空字典。
func _get_runtime_special_rules(context: Dictionary) -> Dictionary:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return {}
	var special_rules_variant: Variant = skill_instance.get("runtime_special_rules")
	if special_rules_variant is Dictionary:
		return (special_rules_variant as Dictionary).duplicate(true)
	return {}


## 作用：把向量或配置坐标转换为 Vector2，无法解析时使用备用向量。
## 使用：fallback 为缺值备用结果。
func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	return fallback


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 _get_skill_level_coefficient 调用；无匹配项时返回空数组。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：读取对象浮点属性，空对象或缺值时使用默认值。
## 使用：fallback 为缺值备用结果。
func _get_float_property(object: Object, property: String, fallback: float) -> float:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if str(property_info.get("name", "")) == property:
			return float(object.get(property))
	return fallback


## 作用：从当前技能、被动、角色与遗物聚合快照读取指定属性。
## 使用：context 携带 skill_instance/skill_manager/relic_manager/caster；fallback 为缺值备用结果。
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


## 作用：通过目标状态公开方法或 StatusEffectManager 检查指定状态。
## 使用：target 为本次命中目标；status_id 为标准状态 ID；返回布尔判断或执行是否成功。
func _target_has_status(target: Node, status_id: StringName) -> bool:
	if target == null or status_id == &"":
		return false
	if target.has_method("has_status") and bool(target.call("has_status", status_id)):
		return true
	var manager: Node = target.get_node_or_null("StatusEffectManager")
	return manager != null and manager.has_method("has_status") and bool(manager.call("has_status", status_id))


## 作用：取得目标指定状态的当前层数。
## 使用：target 为本次命中目标；status_id 为标准状态 ID。
func _target_status_stack(target: Node, status_id: StringName) -> int:
	if target == null or status_id == &"":
		return 0
	if target.has_method("get_status_stack"):
		return int(target.call("get_status_stack", status_id))
	var manager: Node = target.get_node_or_null("StatusEffectManager")
	if manager != null and manager.has_method("get_status_stack"):
		return int(manager.call("get_status_stack", status_id))
	return 1 if _target_has_status(target, status_id) else 0


## 作用：把状态配置转换为非空状态 ID 集合。
## 使用：params 读取 status_ids/status_id。
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


## 作用：从目标服务查询给定圆心与半径内的有效敌人。
## 使用：origin 为世界位置或伤害来源；radius 为世界坐标半径；target_group 为目标注册分组。
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

	## 作用：范围目标比较器：按候选到 origin 的距离升序排序。
	## 使用：由 sort_custom 调用；a、b 为有效目标，返回前者是否更近。
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return targets


## 作用：从投射物或动作配置提取命中施加的状态列表。
## 使用：params 读取 statuses_on_hit/status_id/status_on_hit；context 为施放或命中上下文。
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


## 作用：合并状态基础参数、技能属性及神系特殊规则参数。
## 使用：params 读取 status_params/status_duration/duration/status_damage；context 为施放或命中上下文。
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


## 作用：通过项目 MetadataKey 规范组合规则命名空间与后缀。
## 使用：SkillActionExecutor 初始化族后 bind_executor；族调用共享方法或通过弱引用返回分派器执行嵌套动作。
func _metadata_key(namespace_text: String, suffix: String) -> String:
	return MetadataKeyScript.key(namespace_text, suffix, "skill_action")


## 作用：将规则键转换为项目允许的统一元数据标识。
## 使用：SkillActionExecutor 初始化族后 bind_executor；族调用共享方法或通过弱引用返回分派器执行嵌套动作。
func _metadata_identifier(raw_key: String) -> String:
	return MetadataKeyScript.identifier(raw_key, "skill_action")
## 作用：解析目标与状态参数并执行施加，支持区域同帧合并语义。
## 使用：params 为动作或状态参数；context 为施放或命中上下文。
func _apply_status(params: Dictionary, context: Dictionary) -> bool:
	return _dispatcher().call("_dispatch_family_method", "_apply_status", [params, context])

## 作用：解析单体或范围目标，为每个目标执行标准伤害动作。
## 使用：params 为动作或状态参数；context 为施放或命中上下文。
func _deal_damage(params: Dictionary, context: Dictionary) -> bool:
	return _dispatcher().call("_dispatch_family_method", "_deal_damage", [params, context])

## 作用：为弹幕动作准备参数，并进入每帧预算控制的生成路径。
## 使用：params 为动作或状态参数；context 为施放或命中上下文。
func _spawn_projectile_burst(params: Dictionary, context: Dictionary) -> bool:
	return _dispatcher().call("_dispatch_family_method", "_spawn_projectile_burst", [params, context])
