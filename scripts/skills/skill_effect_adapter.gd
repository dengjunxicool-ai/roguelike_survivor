## 文件用途：把技能 effects 配置转换为执行器动作，并应用属性类别对应的等级稀有度成长。
## 使用方式：事件与触发适配器调用 to_actions；每项 effect 的 damage/status/area/projectile 等字段被整理到动作参数。
extends RefCounted
class_name SkillEffectAdapter

const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")

## 作用：按配置 effects 顺序转换有效项为动作列表并应用技能成长。
## 使用：effects 为配置效果列表；skill_instance 为技能运行实例。
static func to_actions(effects: Array, skill_instance: RefCounted = null, effect_context: String = "") -> Array:
	var actions: Array = []
	for effect_variant: Variant in effects:
		if effect_variant is Dictionary:
			var action: Dictionary = to_action(effect_variant as Dictionary, skill_instance, effect_context)
			if not action.is_empty():
				actions.append(action)
	return actions


## 作用：按 effect.type 整理单个动作参数与条件，未知效果无动作。
## 使用：skill_instance 为技能运行实例；无适用数据时返回空字典。
static func to_action(effect: Dictionary, skill_instance: RefCounted = null, effect_context: String = "") -> Dictionary:
	var effect_type: String = str(effect.get("type", ""))
	var params: Dictionary = effect.duplicate(true)
	params.erase("type")
	_apply_growth_to_params(params, effect_type, skill_instance, effect_context)
	match effect_type:
		"combustion_explosion":
			return {"type": "combustion_explosion", "params": params}
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
			return {"type": "spawn_projectile_burst", "params": _normalize_projectile_params(params)}
		"repeat_area_path":
			return {"type": "repeat_area_path", "params": params}
		"spawn_area_from_existing_area":
			return {"type": "spawn_area_from_existing_area", "params": params}
		_:
			push_warning("[SkillEffectAdapter] Unsupported effect type: %s" % effect_type)
			return {}


## 作用：把伤害效果字段整理为伤害动作 amount、类型与元素参数。
## 使用：params 读取 power_scale/amount/source_type/damage_origin；会原地更新 params.amount/damage_origin。
static func _normalize_damage_params(params: Dictionary) -> Dictionary:
	if params.has("power_scale") and not params.has("amount"):
		params["amount"] = {"stat": "power", "scale": float(params.get("power_scale", 0.0))}
	if params.has("source_type") and not params.has("damage_origin"):
		params["damage_origin"] = str(params.get("source_type"))
	params.erase("_skill_instance")
	return params


## 作用：把状态效果字段整理为状态 ID、层数、时长和来源参数。
## 使用：params 读取 status/status_id/stacks/stack；会原地更新 params.status_id/stack。
static func _normalize_status_params(params: Dictionary) -> Dictionary:
	if params.has("status") and not params.has("status_id"):
		params["status_id"] = params["status"]
	if params.has("stacks") and not params.has("stack"):
		params["stack"] = params["stacks"]
	params.erase("_skill_instance")
	return params


## 作用：整理区域效果的伤害、几何、持续时间及 tick 动作参数。
## 使用：params 读取 effects_on_tick/_skill_instance/effects_on_apply/effects_on_expire；会原地更新 params.actions_on_tick/actions_on_apply/actions_on_expire。
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


## 作用：整理投射物效果的发射、数值与命中动作参数。
## 使用：params 读取 on_hit/_skill_instance/effects_on_hit/damage；会原地更新 params.actions_on_hit/damage。
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


## 作用：整理连锁命中的目标、跳数和伤害衰减参数。
## 使用：params 读取 actions/_skill_instance；会原地更新 params.actions。
static func _normalize_chain_params(params: Dictionary) -> Dictionary:
	if params.has("actions"):
		params["actions"] = to_actions(_get_array(params.get("actions", [])), params.get("_skill_instance", null) as RefCounted, "chain")
	params.erase("_skill_instance")
	return params


## 作用：整理按状态层数造成伤害或消耗状态的动作参数。
## 使用：params 读取 status/status_id/power_scale_per_stack/amount_per_stack；会原地更新 params.status_id/amount_per_stack。
static func _normalize_status_stack_damage_params(params: Dictionary) -> Dictionary:
	if params.has("status") and not params.has("status_id"):
		params["status_id"] = params["status"]
	if params.has("power_scale_per_stack") and not params.has("amount_per_stack"):
		params["amount_per_stack"] = {"stat": "power", "scale": float(params.get("power_scale_per_stack", 0.0))}
	params.erase("_skill_instance")
	return params


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 _normalize_area_params/_normalize_projectile_params 调用；无匹配项时返回空数组。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：按效果类型给伤害、范围、时长或冷却字段应用等级稀有度成长。
## 使用：params 为动作或状态参数；skill_instance 为技能运行实例；会原地更新 params._skill_instance。
static func _apply_growth_to_params(params: Dictionary, effect_type: String, skill_instance: RefCounted, effect_context: String) -> void:
	if skill_instance == null:
		return
	params["_skill_instance"] = skill_instance
	match effect_type:
		"damage":
			_scale_damage_params(params, skill_instance)
		"instant_area_hit", "damage_by_status_stack":
			_scale_damage_params(params, skill_instance)
			_scale_numeric_keys(params, skill_instance, ["power_scale_per_stack"], "damage")
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


## 作用：对伤害动作的 amount 或 damage 配置施加伤害成长。
## 使用：params 读取 power_scale/scale/amount/damage；skill_instance 为技能运行实例；会原地更新 params.power_scale/scale/amount。
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


## 作用：缩放数值或数值表达式中的伤害量并保留配置结构。
## 使用：skill_instance 为技能运行实例。
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


## 作用：只对列出的数值字段应用指定成长类别。
## 使用：params 为动作或状态参数；skill_instance 为技能运行实例。
static func _scale_numeric_keys(params: Dictionary, skill_instance: RefCounted, keys: Array[String], stat_kind: String) -> void:
	for key: String in keys:
		if not params.has(key) or not _is_number(params[key]):
			continue
		var scaled: float = SkillGrowthScalingScript.apply_to_number(float(params[key]), skill_instance, stat_kind)
		params[key] = roundi(scaled) if typeof(params[key]) == TYPE_INT else scaled


## 作用：严格判断 Variant 是否为 int 或 float，不把布尔或字符串当数值。
## 使用：由本文件 _scale_amount_value/_scale_numeric_keys 调用。
static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT
