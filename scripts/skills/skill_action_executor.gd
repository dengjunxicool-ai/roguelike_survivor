## 文件用途：验证动作条件并把动作按投射物、区域、召唤、状态和属性族分派。
## 使用方式：execute_actions 依次执行字典动作，execute_action 解析范围单位后分派；族通过 bind_executor 共享支持服务。
extends "res://scripts/skills/skill_action_support.gd"
class_name SkillActionExecutor

const ProjectileExecutor: Script = preload("res://scripts/skills/skill_action_projectile_executor.gd")
const AreaExecutor: Script = preload("res://scripts/skills/skill_action_area_executor.gd")
const SummonExecutor: Script = preload("res://scripts/skills/skill_action_summon_executor.gd")
const StatusExecutor: Script = preload("res://scripts/skills/skill_action_status_executor.gd")
const ModifierExecutor: Script = preload("res://scripts/skills/skill_action_modifier_executor.gd")

var _families: Dictionary = {}

## 作用：创建特殊规则执行器与五个动作族，再逐个绑定共享分派器。
## 使用：execute_actions 依次执行字典动作，execute_action 解析范围单位后分派；族通过 bind_executor 共享支持服务。
func _init() -> void:
	_special_rule_executor = SkillSpecialRuleExecutorScript.new()
	_families["projectile"] = ProjectileExecutor.new()
	_families["area"] = AreaExecutor.new()
	_families["summon"] = SummonExecutor.new()
	_families["status"] = StatusExecutor.new()
	_families["modifier"] = ModifierExecutor.new()
	for family: RefCounted in _families.values():
		family.call("bind_executor", self)

## 作用：按动作数组顺序执行字典动作，跳过非字典项。
## 使用：actions 为依次执行的动作列表；context 为施放或命中上下文。
func execute_actions(actions: Array, context: Dictionary) -> void:
	for action_variant: Variant in actions:
		if action_variant is Dictionary:
			var result: Variant = execute_action(action_variant, context)
			if bool(context.get("is_cast_source", false)) and context.has("_cast_result"):
				if (result is bool and result) or ((result is int or result is float) and result > 0):
					context["_cast_result"]["successful_outputs"] = int(context["_cast_result"].get("successful_outputs", 0)) + 1


## 作用：检查动作条件后按 type 转入对应动作族并返回执行结果。
## 使用：context 为施放或命中上下文。
func execute_action(action: Dictionary, context: Dictionary) -> Variant:
	var action_type: String = str(action.get("type", ""))
	var params: Dictionary = SkillRangeUnitScript.resolve_action_params(_get_dictionary(action.get("params", {})))
	var conditions: Array = _get_array(action.get("conditions", params.get("conditions", [])))
	if not conditions.is_empty() and not ConditionEvaluatorScript.evaluate_all(conditions, context):
		return null

	match action_type:
		"combustion_explosion":
			return context.event_bus.start_combustion(context,params) if context.get("event_bus") != null else false
		"deal_damage":
			return _families["status"]._deal_damage(params, context)
		"apply_status":
			return _families["status"]._apply_status(params, context)
		"spawn_projectile":
			return _families["projectile"]._spawn_projectile(params, context)
		"spawn_projectiles_at_targets":
			return _families["projectile"]._spawn_projectiles_at_targets(params, context)
		"spawn_area":
			return _families["area"]._spawn_area(params, context, "area")
		"instant_area_hit":
			return _families["area"]._instant_area_hit(params, context)
		"create_explosion":
			return _families["area"]._spawn_area(params, context, "explosion")
		"spawn_trap":
			return _families["area"]._spawn_trap(params, context)
		"spawn_orbit_object":
			return _families["area"]._spawn_orbit_object(params, context)
		"spawn_orbitals":
			return _families["area"]._spawn_orbitals(params, context)
		"spawn_particles":
			return _families["summon"]._spawn_particles(params, context)
		"spawn_summon":
			return _families["summon"]._spawn_summon(params, context)
		"chain_to_targets":
			return _families["projectile"]._chain_to_targets(params, context)
		"consume_status_stack":
			return _families["status"]._consume_status_stack(params, context)
		"damage_by_status_stack":
			return _families["status"]._damage_by_status_stack(params, context)
		"knockback":
			return _families["area"]._knockback(params, context)
		"heal_owner", "heal_caster":
			return _families["modifier"]._heal_owner(params, context)
		"destroy_enemy_projectile":
			return _families["projectile"]._destroy_enemy_projectile(params, context)
		"add_temporary_modifier":
			return _families["modifier"]._add_temporary_modifier(params, context)
		"grant_shield":
			return _families["modifier"]._grant_shield(params, context)
		"pull":
			return _families["area"]._pull(params, context)
		"repeat_skill":
			return _families["modifier"]._repeat_skill(params, context)
		"swap_targets":
			return _families["area"]._swap_targets(params, context)
		"transform_area":
			return _families["area"]._transform_area(params, context)
		"transfer_status":
			return _families["status"]._transfer_status(params, context)
		"consume_status_duration":
			return _families["status"]._consume_status_duration(params, context)
		"trigger_overload":
			return _families["status"]._trigger_overload(params, context)
		"shatter_frozen":
			return _families["status"]._shatter_frozen(params, context)
		"spawn_projectile_burst":
			return _families["projectile"]._spawn_projectile_burst(params, context)
		"repeat_area_path":
			return _families["area"]._repeat_area_path(params, context)
		"spawn_area_from_existing_area":
			return _families["area"]._spawn_area_from_existing_area(params, context)
		"mark_target":
			return _families["status"]._mark_target(params, context)
		_:
			push_warning("[SkillActionExecutor] Unsupported action type: %s" % action_type)
			return null


## 作用：把共享辅助入口的方法名与参数数组转发给拥有该方法的动作族，未知方法报错。
## 使用：execute_actions 依次执行字典动作，execute_action 解析范围单位后分派；族通过 bind_executor 共享支持服务。
func _dispatch_family_method(method: String, arguments: Array) -> Variant:
	match method:
		"_spawn_projectile", "_spawn_projectiles_at_targets", "_spawn_direct_projectile_instance", "_spawn_targeted_projectile_instance", "_spawn_targeted_projectile_instance_after_delay", "_spawn_targeted_projectile_instance_now", "_same_target_projectile_spawn_delay", "_projectile_params_for_same_target_hit", "_damage_only_actions", "_resolve_projectile_runtime_stats", "_build_projectile_runtime_data", "_get_projectile_runtime_statuses_on_hit", "_build_targeted_projectile_launch_data", "_build_direct_projectile_launch_data", "_apply_projectile_visual_start_offset", "_build_projectile_spawn_params", "_build_projectile_target_sequence", "_resolve_projectile_visual_start_position", "_resolve_projectile_visual_target_position", "_apply_projectile_damage_sequence", "_resolve_projectile_damage_sequence", "_get_hail_same_target_decay_rule", "_chain_to_targets", "_actions_with_chain_decay", "_params_with_chain_decay", "_spawn_projectile_burst", "_spawn_projectile_burst_with_budget", "_defer_projectile_burst_to_budget", "_prepare_projectile_burst_params", "_destroy_enemy_projectile":
			return _families["projectile"].callv(method, arguments)
		"_instant_area_hit", "_play_instant_area_hit_visual", "_create_instant_area_hit_visual", "_instant_area_hit_visual_params", "_get_combat_object_definition", "_spawn_area", "_prepare_area_damage_packet", "_try_merge_fire_oil_area", "_record_area_explosion_trace", "_register_area_effect_runtime_metadata", "_prepare_area_radius_and_geometry_params", "_resolve_area_damage", "_resolve_area_max_targets", "_resolve_area_max_active", "_resolve_area_duration", "_build_area_effect_spawn_params", "_spawn_trap", "_enforce_max_active_areas", "_merge_existing_fire_oil_area", "_spawn_orbit_object", "_spawn_orbitals", "_knockback", "_pull", "_swap_targets", "_transform_area", "_repeat_area_path", "_spawn_area_from_existing_area", "_prepare_area_tick_action_params":
			return _families["area"].callv(method, arguments)
		"_spawn_particles", "_spawn_summon", "_spawn_managed_summon", "_create_summon_node", "_summon_tick", "_attach_summon_visual", "_update_summon_visual_facing", "_spawn_summon_breath_particles", "_restart_summon_particles", "_configure_gpu_particles":
			return _families["summon"].callv(method, arguments)
		"_deal_damage", "_deal_damage_to_target", "_should_execute_low_hp_target", "_get_low_hp_execute_amount", "_apply_low_hp_execute_packet", "_resolve_damage_targets", "_inherit_projectile_runtime_damage_packet", "_apply_status", "_consume_status_stack", "_damage_by_status_stack", "_transfer_status", "_consume_status_duration", "_trigger_overload", "_shatter_frozen", "_prepare_shatter_damage_params", "_mark_target":
			return _families["status"].callv(method, arguments)
		"_heal_owner", "_add_temporary_modifier", "_add_status_damage_taken_modifier", "_grant_shield", "_repeat_skill":
			return _families["modifier"].callv(method, arguments)
	push_error("Unknown skill action family method: " + method)
	return null
