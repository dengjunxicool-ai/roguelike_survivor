## 文件用途：执行治疗、临时属性、状态易伤、护盾和技能重复施放动作。
## 使用方式：由动作分派器传 params/context；需要的玩家能力通过 has_method 检查，临时属性入口当前只合并属性，不安排到期回收。
extends "res://scripts/skills/skill_action_support.gd"
class_name SkillActionModifierExecutor


## 作用：按 amount 或最大生命比例直接增加施法者 current_health，限制到上限并发血量信号。
## 使用：params 读取 amount/max_health_ratio；context 携带 caster；会发出对应变更信号；返回布尔判断或执行是否成功。
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


## 作用：把动作属性合入技能运行快照或管理器被动列表；燃烧每层易伤使用单独状态字段路径。
## 使用：params 读取 stat/scope；context 携带 skill_instance/skill_manager；返回布尔判断或执行是否成功。
func _add_temporary_modifier(params: Dictionary, context: Dictionary) -> bool:
	if String(params.get("stat", "")) == "burning_damage_taken":
		var target: Node = context.get("target") as Node
		var statuses: Node = target.get_node_or_null("StatusEffectManager") if target != null else null
		if statuses == null: return false
		return statuses.merge_status_fields(&"burning", {"ground_bonus": float(params.get("value", 0.0)), "ground_bonus_until": float(context.get("combat_seconds", 0.0))+float(params.get("duration", 0.6))})
	var modifier: Dictionary = _build_modifier_from_params(params)
	if modifier.is_empty():
		return false

	if str(params.get("stat", "")) == "status_dot_damage_taken_multiplier_add_per_stack" and params.get("scope", {}).get("status_id", "") == "burning":
		return _add_status_damage_taken_modifier(&"burning", modifier, params, context)

	var caster: Node = context.get("caster", context.get("owner")) as Node
	var store: Node = caster.get_node_or_null("ModifierStore") if caster != null else null
	if store == null:
		return false
	var skill: RefCounted = context.get("skill_instance") as RefCounted
	var skill_id: String = String(skill.get("skill_id")) if skill != null else String(context.get("listener_skill_id", context.get("skill_id", "")))
	var effect_id: String = String(params.get("effect_id", "%s_%s" % [params.get("stat", ""), params.get("op", "")]))
	var source_id: String = "skill:%s:%s" % [skill_id, effect_id]
	if bool(params.get("next_cast_only", false)):
		store.call("set_cast_charge", source_id, float(params.get("value", 0.0)))
		return true
	var effect: Dictionary = params.duplicate(true)
	for key: String in ["duration", "effect_id", "refresh_rule", "next_cast_only", "_skill_instance"]:
		effect.erase(key)
	store.call("set_timed_source", source_id, [effect], [&"skill", &"player", &"movement"], maxf(float(params.get("duration", 0.0)), 0.0), StringName(String(params.get("refresh_rule", "replace"))))
	return true


## 作用：把目标状态相关承伤增量写入对应临时属性语义。
## 使用：status_id 为标准状态 ID；params 读取 duration；context 携带 target；返回布尔判断或执行是否成功。
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


## 作用：根据动作数值和目标拥有者授予配置护盾。
## 使用：params 读取 amount/max_health_ratio/duration/shield_type；context 携带 owner/caster/event_bus；会原地更新 context.shield_overflowed/shield_overflow_amount/shield_gained_amount；写入 fire_passive_shield/fire_passive_shield_expires_at 元数据；返回布尔判断或执行是否成功。
func _grant_shield(params: Dictionary, context: Dictionary) -> bool:
	var owner: Node = context.get("owner") as Node
	if owner == null:
		owner = context.get("caster") as Node
	if owner == null:
		return false

	var bus: Node = context.get("event_bus") as Node
	var now: float = float(bus.combat_seconds()) if bus != null else _now_seconds()
	var max_health: float = maxf(_get_float_property(owner, "max_health", 0.0), 0.0)
	var amount: int = maxi(roundi(_resolve_scaled_amount(params.get("amount", 0.0), context, "shield")), 0)
	if amount <= 0 and params.has("max_health_ratio"):
		amount = maxi(roundi(max_health * float(params.get("max_health_ratio", 0.0))), 0)
	amount = maxi(roundi(float(amount) * maxf(1.0 + _combined_modifier_value("holy_shield_restore_multiplier_add", context, 0.0), 0.05)), 0)
	if amount <= 0:
		return false

	var duration: float = maxf(float(params.get("duration", 6.0)), 0.05)
	var shield_type: String = str(params.get("shield_type", "fire_skill"))
	var current: int = int(owner.get_meta("fire_passive_shield", 0))
	var expires_at: float = float(owner.get_meta("fire_passive_shield_expires_at", 0.0))
	if expires_at > 0.0 and expires_at <= now:
		current = 0
	var final_amount: int = current + amount
	var overflow: int = 0
	if bool(params.get("respect_shield_cap", false)) and max_health > 0.0:
		var cap_ratio: float = maxf(float(params.get("shield_cap_health_ratio", 0.35)), 0.01)
		cap_ratio *= maxf(1.0 + _combined_modifier_value("holy_shield_cap_multiplier_add", context, 0.0), 0.05)
		var cap: int = maxi(roundi(max_health * cap_ratio), 1)
		if final_amount > cap:
			overflow = final_amount - cap
			final_amount = cap

	context["shield_overflowed"] = overflow > 0
	context["shield_overflow_amount"] = overflow
	context["shield_gained_amount"] = maxi(final_amount - current, 0)

	preload("res://scripts/runtime/skill_balance_metrics.gd").observe(owner,{"kind":"shield_generated","amount":maxi(final_amount-current,0)})
	owner.set_meta("fire_passive_shield", final_amount)
	owner.set_meta("fire_passive_shield_expires_at", now + duration)
	var shield_meta_key: String = _metadata_key(shield_type, "shield")
	var shield_expires_meta_key: String = _metadata_key(shield_type, "shield_expires_at")
	owner.set_meta(shield_meta_key, int(owner.get_meta(shield_meta_key, 0)) + maxi(final_amount - current, 0))
	owner.set_meta(shield_expires_meta_key, now + duration)
	var event_bus: Node = context.get("event_bus") as Node
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		var shield_context: Dictionary = context.duplicate(true)
		shield_context["owner"] = owner
		shield_context["shield_type"] = shield_type
		shield_context["shield_source_skill_id"] = context.get("listener_skill_id", context.get("skill_id", &""))
		shield_context["shield_amount"] = maxi(final_amount - current, 0)
		shield_context["shield_overflowed"] = overflow > 0
		shield_context["shield_overflow_amount"] = overflow
		event_bus.call("emit_skill_event", &"shield_gained", shield_context)
	return true


## 作用：要求显式 actions 列表，按 times 或 count 至少执行一次，缺动作返回 false 并警告。
## 使用：params 读取 actions/times/count；context 为施放或命中上下文；返回布尔判断或执行是否成功。
func _repeat_skill(params: Dictionary, context: Dictionary) -> bool:
	var actions: Array = _get_array(params.get("actions", []))
	if bool(params.get("use_snapshot",false)):
		var bus: Node = context.get("event_bus") as Node
		return bus.replay_cast(bus.get_cast_snapshot(params.get("filter",{})),context,float(params.get("damage_multiplier",0.4))) if bus != null else false
	if actions.is_empty():
		push_warning("[SkillActionExecutor] repeat_skill needs explicit actions in this runtime.")
		return false
	var times: int = maxi(int(params.get("times", params.get("count", 1))), 1)
	for _index in range(times):
		execute_actions(actions, context)
	return true
