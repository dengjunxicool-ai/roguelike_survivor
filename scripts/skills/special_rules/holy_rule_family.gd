## 文件用途：实现圣盾、圣印、战锤审判与十字领域的治疗、减伤和护盾规则。
## 使用方式：由宿主在施放、命中及玩家更新调度；盾和领域通过技能或玩家元数据保存持续效果与脉冲状态。
extends RefCounted

const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")

static var _judgment_on_strong_hit_cooldowns: Dictionary = {}

static var _warhammer_judgement_shock_cooldowns: Dictionary = {}

static var _warhammer_boss_poise_judgement_bonus_cooldowns: Dictionary = {}

static var _cross_relic_stand_shield_cooldowns: Dictionary = {}

static var _cross_relic_periodic_shield_timers: Dictionary = {}

static var _cross_relic_low_hp_rescue_cooldowns: Dictionary = {}

var _host_ref: WeakRef

## 作用：弱引用保存特殊规则宿主，供本族复用共享伤害、状态与冷却入口。
## 使用：host 为仍存活的规则宿主。
func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


## 作用：按战锤施放计数和秒数预留震地及强制震击标记。
## 使用：rules 读取 warhammer_base/warhammer_quake_slam_every_n_casts/warhammer_forced_shock_every_n_seconds；context 携带 skill_instance；写入 warhammer_quake_slam_active/warhammer_forced_shock_active/warhammer_forced_shock_next_at 元数据；需由仍存活的宿主创建并调度。
func _prepare_warhammer_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("warhammer_base"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	if rules.has("warhammer_quake_slam_every_n_casts"):
		var quake_rule: Dictionary = host._get_dictionary(rules.get("warhammer_quake_slam_every_n_casts", {}))
		var cast_interval: int = maxi(int(quake_rule.get("cast_interval", 3)), 1)
		var cast_count: int = host._advance_interval_counter(skill_instance, "warhammer_cast_count")
		skill_instance.set_meta("warhammer_quake_slam_active", cast_count % cast_interval == 0)
	if rules.has("warhammer_forced_shock_every_n_seconds"):
		var shock_rule: Dictionary = host._get_dictionary(rules.get("warhammer_forced_shock_every_n_seconds", {}))
		var now_seconds: float = host._now_seconds()
		var next_at: float = float(skill_instance.get_meta("warhammer_forced_shock_next_at", 0.0))
		var active_shock: bool = now_seconds >= next_at
		skill_instance.set_meta("warhammer_forced_shock_active", active_shock)
		if active_shock:
			skill_instance.set_meta("warhammer_forced_shock_next_at", now_seconds + maxf(float(shock_rule.get("interval", 8.0)), 0.0))


## 作用：按圣盾规则创建盾值、持续时间及脉冲元数据，并同步玩家接触减伤。
## 使用：rules 读取 holy_shield_base；context 携带 caster/skill_instance；写入 holy_shield_active/holy_shield_value/holy_shield_remaining 元数据；需由仍存活的宿主创建并调度。
func _deploy_holy_shield(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("holy_shield_base"):
		return
	var caster: Node = context.get("caster") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if caster == null or skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("holy_shield_base", {}))
	var shield_value: int = host._get_effective_skill_stat_int(skill_instance, context, "shield_value", rule.get("shield_value", 30))
	var break_damage: int = host._get_effective_skill_stat_int(skill_instance, context, "break_damage", rule.get("break_damage", 30))
	var now_seconds: float = host._now_seconds()
	var duration: float = maxf(float(rule.get("duration", rule.get("deploy_interval", 7.0))), 0.1)
	skill_instance.set_meta("holy_shield_active", true)
	skill_instance.set_meta("holy_shield_value", shield_value)
	skill_instance.set_meta("holy_shield_remaining", shield_value)
	skill_instance.set_meta("holy_shield_break_damage", break_damage)
	skill_instance.set_meta("holy_shield_started_at", now_seconds)
	skill_instance.set_meta("holy_shield_expires_at", now_seconds + duration)
	skill_instance.set_meta("holy_shield_next_pulse_at", now_seconds)
	skill_instance.set_meta("holy_shield_pulse_count", 0)
	host._apply_holy_shield_player_meta(caster, rules, now_seconds + duration)


## 作用：推进圣盾有效期与脉冲计数，按规则执行脉冲或到期处理。
## 使用：rules 读取 holy_shield_base；context 携带 caster/skill_instance；写入 holy_shield_active/holy_shield_pulse_count/holy_shield_next_pulse_at 元数据；需由仍存活的宿主创建并调度。
func _update_holy_shield(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("holy_shield_base"):
		return
	var caster: Node = context.get("caster") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if caster == null or skill_instance == null:
		return
	if not bool(skill_instance.get_meta("holy_shield_active", false)):
		return
	var now_seconds: float = host._now_seconds()
	var expires_at: float = float(skill_instance.get_meta("holy_shield_expires_at", now_seconds))
	if now_seconds >= expires_at:
		skill_instance.set_meta("holy_shield_active", false)
		SpecialDamageRuleHandlerScript.execute_holy_shield_expire(rules, context)
		host._clear_holy_shield_player_meta(caster)
		return
	host._apply_holy_shield_player_meta(caster, rules, expires_at)
	var pulse_interval: float = host._holy_shield_pulse_interval(rules)
	if now_seconds < float(skill_instance.get_meta("holy_shield_next_pulse_at", now_seconds)):
		return
	var pulse_count: int = int(skill_instance.get_meta("holy_shield_pulse_count", 0)) + 1
	skill_instance.set_meta("holy_shield_pulse_count", pulse_count)
	skill_instance.set_meta("holy_shield_next_pulse_at", now_seconds + pulse_interval)
	SpecialDamageRuleHandlerScript.execute_holy_shield_pulse(rules, context, pulse_count)


## 作用：合并基础圣盾与脉冲间隔规则，计算下一次脉冲间隔。
## 使用：rules 读取 holy_shield_base/holy_pulse_interval；需由仍存活的宿主创建并调度。
func _holy_shield_pulse_interval(rules: Dictionary) -> float:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var base: Dictionary = host._get_dictionary(rules.get("holy_shield_base", {}))
	var interval: float = maxf(float(base.get("pulse_interval", 1.0)), 0.05)
	if rules.has("holy_pulse_interval"):
		var rule: Dictionary = host._get_dictionary(rules.get("holy_pulse_interval", {}))
		interval *= maxf(float(rule.get("multiplier", 1.0)), 0.05)
	return interval


## 作用：将圣盾接触减伤及有效截止时间同步到玩家元数据。
## 使用：caster 为施法者节点；rules 读取 holy_shield_contact_damage_reduction；写入 holy_shield_contact_reduction_until/holy_shield_contact_damage_taken_multiplier_add 元数据；需由仍存活的宿主创建并调度。
func _apply_holy_shield_player_meta(caster: Node, rules: Dictionary, until_time: float) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if caster == null or not rules.has("holy_shield_contact_damage_reduction"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("holy_shield_contact_damage_reduction", {}))
	caster.set_meta("holy_shield_contact_reduction_until", until_time)
	caster.set_meta("holy_shield_contact_damage_taken_multiplier_add", float(rule.get("damage_taken_multiplier_add", -0.15)))


## 作用：清空玩家圣盾接触减伤值和有效时间。
## 使用：caster 为施法者节点；写入 holy_shield_contact_reduction_until/holy_shield_contact_damage_taken_multiplier_add 元数据；需由仍存活的宿主创建并调度。
func _clear_holy_shield_player_meta(caster: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if caster == null:
		return
	caster.set_meta("holy_shield_contact_reduction_until", 0.0)
	caster.set_meta("holy_shield_contact_damage_taken_multiplier_add", 0.0)


## 作用：按圣印调整规则补充状态层数与时长参数。
## 使用：params 读取 duration；context 为施放或命中上下文；会原地更新 params.duration；需由仍存活的宿主创建并调度。
func _get_holy_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	if rules.is_empty() or not rules.has("holy_mark_tuning"):
		return params
	var rule: Dictionary = host._get_dictionary(rules.get("holy_mark_tuning", {}))
	params["duration"] = float(params.get("duration", 4.0)) + float(rule.get("duration_add", 0.0))
	return params


## 作用：目标带圣印且伤害符合圣系条件时修改伤害包易伤。
## 使用：packet 为待修饰伤害包视图；rules 读取 holy_mark_holy_vulnerability；target 为本次命中目标；会原地更新 packet.vulnerability_total；需由仍存活的宿主创建并调度。
func _apply_holy_mark_holy_vulnerability(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("holy_mark_holy_vulnerability") or target == null or packet_object == null:
		return
	if not target.has_method("has_status") or not bool(target.call("has_status", &"holy_mark")):
		return
	if String(packet_object.call("get_value", "element", "")) != "holy":
		return
	var rule: Dictionary = host._get_dictionary(rules.get("holy_mark_holy_vulnerability", {}))
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("holy_damage_taken_multiplier_add", 0.08))


## 作用：目标处于战锤眩晕条件时应用承伤加成。
## 使用：packet 为待修饰伤害包视图；rules 读取 warhammer_stun_target_damage_taken；target 为本次命中目标；会原地更新 packet.vulnerability_total；需由仍存活的宿主创建并调度。
func _apply_warhammer_stun_target_damage_taken(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("warhammer_stun_target_damage_taken") or target == null:
		return
	if not target.has_method("has_status") or not bool(target.call("has_status", &"stun")):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("warhammer_stun_target_damage_taken", {}))
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("primary_attack_damage_taken_multiplier_add", 0.15))


## 作用：根据目标持续伤害或杂质状态应用十字领域直接伤害收益。
## 使用：packet 为待修饰伤害包视图；rules 读取 cross_relic_dot_target_damage_bonus/cross_relic_purify_impurity；target 为本次命中目标；会原地更新 packet.direct_damage_multiplier_add；需由仍存活的宿主创建并调度。
func _apply_cross_relic_dot_target_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("cross_relic_dot_target_damage_bonus") and not rules.has("cross_relic_purify_impurity"):
		return
	if target == null or packet_object == null:
		return
	if String(packet_object.call("get_value", "damage_origin", "")) != "field":
		return
	if not target.has_method("has_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("cross_relic_dot_target_damage_bonus", {}))
	if rule.is_empty():
		return
	for status_variant: Variant in host._get_array(rule.get("status_ids", ["burning", "poison", "bleed"])):
		if bool(target.call("has_status", StringName(String(status_variant)))):
			packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(rule.get("damage_multiplier_add", 0.15))
			return


## 作用：十字领域命中 tick 时转入杂质施加规则。
## 使用：rules 读取 cross_relic_base；context 携带 source_id；需由仍存活的宿主创建并调度。
func _apply_cross_relic_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("cross_relic_base"):
		return
	if String(context.get("source_id", "")) != "holy_field_area":
		return
	host._apply_cross_relic_impurity_on_field_tick(rules, context)
	SpecialDamageRuleHandlerScript.execute_cross_relic_field_tick(rules, context)


## 作用：按十字领域杂质规则给命中目标施加状态。
## 使用：rules 读取 cross_relic_impurity_on_field_tick；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_cross_relic_impurity_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("cross_relic_impurity_on_field_tick"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("cross_relic_impurity_on_field_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "impurity"))), {
		"duration": float(rule.get("duration", 4.0)),
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 3)), 1)
	})


## 作用：在战锤命中时依次处理审判、击退、眩晕或韧性及审判冲击。
## 使用：rules 读取 warhammer_base；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_warhammer_on_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("warhammer_base"):
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	host._apply_warhammer_judgment_status(rules, context, target)
	host._apply_warhammer_knockback(rules, context, target)
	host._apply_warhammer_stun_or_poise(rules, context, target)
	if host._warhammer_source_once(context, "warhammer_crack_field"):
		SpecialDamageRuleHandlerScript.execute_warhammer_crack_field(rules, context)
	host._apply_warhammer_judgement_shock(rules, context, target)
	SpecialDamageRuleHandlerScript.execute_warhammer_boss_low_hp_shockwave(rules, context)


## 作用：在强敌命中且同来源冷却允许时累积审判状态。
## 使用：rules 读取 judgment_on_strong_hit；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_warhammer_judgment_status(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("judgment_on_strong_hit") or target == null or not target.has_method("apply_status"):
		return
	if not (host._is_elite(target) or host._is_boss(target)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("judgment_on_strong_hit", {}))
	var key: String = "judgment_on_hit:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_judgment_on_strong_hit_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.0)), 0.0)):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "judgment"))), {
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 4)), 1),
		"duration": float(rule.get("duration", 5.0))
	})


## 作用：按战锤基础值与击退倍率对命中目标执行击退。
## 使用：rules 读取 warhammer_base/warhammer_knockback_multiplier；context 携带 source/caster；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_warhammer_knockback(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var target_2d: Node2D = target as Node2D
	if target_2d == null or host._is_boss(target):
		return
	var source: Node2D = context.get("source") as Node2D
	if source == null:
		source = context.get("caster") as Node2D
	if source == null:
		return
	var base: Dictionary = host._get_dictionary(rules.get("warhammer_base", {}))
	var force: float = float(base.get("knockback", 16.0))
	if rules.has("warhammer_knockback_multiplier"):
		var rule: Dictionary = host._get_dictionary(rules.get("warhammer_knockback_multiplier", {}))
		force *= maxf(1.0 + float(rule.get("multiplier_add", 0.25)), 0.0)
	var direction: Vector2 = source.global_position.direction_to(target_2d.global_position)
	if direction != Vector2.ZERO:
		target_2d.global_position += direction.normalized() * force


## 作用：按目标类型施加战锤眩晕或 Boss 韧性效果，并消费强制震击标记。
## 使用：rules 读取 warhammer_stun_on_hit/warhammer_forced_shock_every_n_seconds；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_warhammer_stun_or_poise(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var forced: bool = host._consume_warhammer_forced_shock(context)
	if not rules.has("warhammer_stun_on_hit") and not forced:
		return
	if host._is_boss(target):
		if forced:
			var forced_rule: Dictionary = host._get_dictionary(rules.get("warhammer_forced_shock_every_n_seconds", {}))
			for _i in range(maxi(int(forced_rule.get("boss_poise_stacks", 1)), 1)):
				ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")
		elif bool(host._get_dictionary(rules.get("warhammer_stun_on_hit", {})).get("boss_converts_to_poise", true)):
			ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")
		return
	if not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("warhammer_stun_on_hit", {}))
	var chance: float = 1.0 if forced else float(rule.get("chance", 0.25))
	if host._is_elite(target):
		chance *= float(rule.get("elite_chance_multiplier", 0.5))
	if randf() > clampf(chance, 0.0, 1.0):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "stun"))), {
		"duration": float(rule.get("duration", 0.6)),
		"stacks": 1,
		"max_stacks": 1
	})


## 作用：按审判层数与冷却触发审判冲击，并检查 Boss 韧性追加收益。
## 使用：rules 读取 warhammer_judgement_shock；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_warhammer_judgement_shock(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("warhammer_judgement_shock") or target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("warhammer_judgement_shock", {}))
	if int(target.call("get_status_stack", &"judgment")) < maxi(int(rule.get("required_stacks", 4)), 1):
		return
	var key: String = "warhammer_judgement:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_warhammer_judgement_shock_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)):
		return
	if host._is_boss(target):
		for _i in range(maxi(int(rule.get("boss_poise_stacks", 0)), 0)):
			ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.warhammer_judgement_shock_intents(rules, context, maxi(int(rule.get("amount", 22)), 0), "warhammer_judgement_shock"))
	host._apply_warhammer_boss_poise_judgement_bonus(rules, context, target)


## 作用：仅对新的 Boss 韧性破坏计数触发审判加成，避免重复消费。
## 使用：rules 读取 warhammer_boss_poise_judgement_bonus；context 为施放或命中上下文；target 为本次命中目标；写入 warhammer_poise_judgement_consumed_count 元数据；需由仍存活的宿主创建并调度。
func _apply_warhammer_boss_poise_judgement_bonus(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("warhammer_boss_poise_judgement_bonus") or not host._is_boss(target):
		return
	var completed_at: float = float(target.get_meta("boss_poise_recently_completed_at", -9999.0))
	if host._now_seconds() - completed_at > 4.0:
		return
	var completed_count: int = int(target.get_meta("boss_poise_completed_count", 0))
	var consumed_count: int = int(target.get_meta("warhammer_poise_judgement_consumed_count", 0))
	if completed_count <= consumed_count:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("warhammer_boss_poise_judgement_bonus", {}))
	var key: String = "warhammer_boss_poise_judgement:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_warhammer_boss_poise_judgement_bonus_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 2.5)), 0.0)):
		return
	target.set_meta("warhammer_poise_judgement_consumed_count", completed_count)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.warhammer_judgement_shock_intents(rules, context, maxi(int(rule.get("amount", 34)), 0), "warhammer_boss_poise_judgement_bonus"))


## 作用：按战锤来源身份限制同一来源重复处理。
## 使用：context 携带 skill_instance/source_instance_id/source_key/source_id；需由仍存活的宿主创建并调度；返回布尔判断或执行是否成功。
func _warhammer_source_once(context: Dictionary, source_namespace: String) -> bool:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return true
	var source_instance_id: String = String(context.get("source_instance_id", context.get("source_key", "")))
	if source_instance_id == "":
		source_instance_id = String(context.get("source_id", "warhammer"))
	var meta_key: String = host._metadata_key(source_namespace, "sources")
	var seen: Dictionary = {}
	var seen_variant: Variant = skill_instance.get_meta(meta_key, {})
	if seen_variant is Dictionary:
		seen = (seen_variant as Dictionary).duplicate(true)
	if bool(seen.get(source_instance_id, false)):
		return false
	seen[source_instance_id] = true
	skill_instance.set_meta(meta_key, seen)
	return true


## 作用：读取并清除技能预留强制震击标记，返回本次是否强化。
## 使用：context 携带 skill_instance；写入 warhammer_forced_shock_active 元数据；需由仍存活的宿主创建并调度；返回布尔判断或执行是否成功。
func _consume_warhammer_forced_shock(context: Dictionary) -> bool:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("warhammer_forced_shock_active", false)):
		return false
	skill_instance.set_meta("warhammer_forced_shock_active", false)
	return true


## 作用：确定玩家是否站在十字领域内，更新治疗、减伤、补盾及低血救援。
## 使用：rules 读取 cross_relic_base；context 携带 player/caster；写入 cross_relic_field_reduction_until/cross_relic_inside_field_since 元数据；需由仍存活的宿主创建并调度。
func _update_cross_relic_field(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("cross_relic_base"):
		return
	var player: Node2D = context.get("player", context.get("caster")) as Node2D
	if player == null:
		return
	var field: Node2D = host._find_cross_relic_field_containing_player(player)
	var now_seconds: float = host._now_seconds()
	if field == null:
		player.set_meta("cross_relic_field_reduction_until", 0.0)
		player.set_meta("cross_relic_inside_field_since", -1.0)
		return
	if float(player.get_meta("cross_relic_inside_field_since", -1.0)) < 0.0:
		player.set_meta("cross_relic_inside_field_since", now_seconds)
	var base: Dictionary = host._get_dictionary(rules.get("cross_relic_base", {}))
	host._apply_cross_relic_field_heal(rules, context, player, now_seconds, base)
	host._apply_cross_relic_field_damage_reduction(rules, player, now_seconds)
	host._apply_cross_relic_periodic_shield(rules, player, now_seconds)
	host._apply_cross_relic_stand_shield(rules, player, now_seconds)
	host._apply_cross_relic_low_hp_rescue(rules, player, now_seconds)


## 作用：按领域治疗与庇护规则的间隔恢复玩家生命。
## 使用：rules 读取 cross_relic_field_heal_upgrade/cross_relic_shelter_upgrade；context 携带 skill_instance；player 为玩家节点；写入 cross_relic_next_heal_at 元数据；需由仍存活的宿主创建并调度。
func _apply_cross_relic_field_heal(rules: Dictionary, context: Dictionary, player: Node, now_seconds: float, base: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var heal_interval: float = float(base.get("heal_interval", 0.5))
	var heal_amount: int = int(base.get("heal", 1))
	if rules.has("cross_relic_field_heal_upgrade"):
		var heal_rule: Dictionary = host._get_dictionary(rules.get("cross_relic_field_heal_upgrade", {}))
		heal_amount += int(heal_rule.get("heal_add", 0))
		heal_interval = float(heal_rule.get("heal_interval", heal_interval))
	if rules.has("cross_relic_shelter_upgrade"):
		var shelter_rule: Dictionary = host._get_dictionary(rules.get("cross_relic_shelter_upgrade", {}))
		heal_amount = maxi(roundi(float(heal_amount) * maxf(1.0 + float(shelter_rule.get("heal_multiplier_add", 0.0)), 0.0)), 0)
	if heal_amount <= 0:
		return
	var next_at: float = float(skill_instance.get_meta("cross_relic_next_heal_at", 0.0))
	if now_seconds < next_at:
		return
	skill_instance.set_meta("cross_relic_next_heal_at", now_seconds + maxf(heal_interval, 0.05))
	host._heal_player(player, heal_amount)


## 作用：刷新玩家领域承伤修正及其短时有效截止时间。
## 使用：rules 读取 cross_relic_field_damage_reduction；player 为玩家节点；now_seconds 为当前单调计时秒数；写入 cross_relic_field_reduction_until/cross_relic_field_damage_taken_multiplier_add 元数据；需由仍存活的宿主创建并调度。
func _apply_cross_relic_field_damage_reduction(rules: Dictionary, player: Node, now_seconds: float) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("cross_relic_field_damage_reduction"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("cross_relic_field_damage_reduction", {}))
	player.set_meta("cross_relic_field_reduction_until", now_seconds + 0.25)
	player.set_meta("cross_relic_field_damage_taken_multiplier_add", float(rule.get("damage_taken_multiplier_add", -0.08)))


## 作用：在领域内按规则冷却补充十字护盾。
## 使用：rules 读取 cross_relic_periodic_shield；player 为玩家节点；now_seconds 为当前单调计时秒数；需由仍存活的宿主创建并调度。
func _apply_cross_relic_periodic_shield(rules: Dictionary, player: Node, now_seconds: float) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("cross_relic_periodic_shield"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("cross_relic_periodic_shield", {}))
	var key: String = "periodic:%s" % str(player.get_instance_id())
	if not host._reserve_cooldown(_cross_relic_periodic_shield_timers, key, now_seconds, maxf(float(rule.get("interval", 2.0)), 0.05)):
		return
	host._grant_cross_relic_shield(player, int(rule.get("shield_value", 5)), rules)


## 作用：玩家在领域内持续站立达门槛后，按冷却授予十字护盾。
## 使用：rules 读取 cross_relic_stand_shield；player 为玩家节点；now_seconds 为当前单调计时秒数；需由仍存活的宿主创建并调度。
func _apply_cross_relic_stand_shield(rules: Dictionary, player: Node, now_seconds: float) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("cross_relic_stand_shield"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("cross_relic_stand_shield", {}))
	var inside_since: float = float(player.get_meta("cross_relic_inside_field_since", now_seconds))
	if now_seconds - inside_since < float(rule.get("required_stand_time", 2.0)):
		return
	var key: String = "stand:%s" % str(player.get_instance_id())
	if not host._reserve_cooldown(_cross_relic_stand_shield_cooldowns, key, now_seconds, maxf(float(rule.get("same_source_cooldown", 12.0)), 0.0)):
		return
	host._grant_cross_relic_shield(player, int(rule.get("shield_value", 12)), rules)


## 作用：领域内玩家满足低血条件且冷却允许时恢复生命并授予护盾。
## 使用：rules 读取 cross_relic_low_hp_rescue；player 为玩家节点；now_seconds 为当前单调计时秒数；需由仍存活的宿主创建并调度。
func _apply_cross_relic_low_hp_rescue(rules: Dictionary, player: Node, now_seconds: float) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("cross_relic_low_hp_rescue"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("cross_relic_low_hp_rescue", {}))
	if host._player_health_ratio(player) > float(rule.get("hp_threshold", 0.35)):
		return
	var key: String = "rescue:%s" % str(player.get_instance_id())
	if not host._reserve_cooldown(_cross_relic_low_hp_rescue_cooldowns, key, now_seconds, maxf(float(rule.get("same_source_cooldown", 20.0)), 0.0)):
		return
	host._heal_player(player, int(rule.get("heal", 8)))
	host._grant_cross_relic_shield(player, int(rule.get("shield_value", 12)), rules)


## 作用：查找当前包含玩家位置的有效十字领域对象。
## 使用：player 为玩家节点；需由仍存活的宿主创建并调度；无法解析或创建时返回 null。
func _find_cross_relic_field_containing_player(player: Node2D) -> Node2D:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var tree: SceneTree = player.get_tree()
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(&"areas"):
		var area: Node2D = node as Node2D
		if area == null or not bool(area.get_meta("cross_relic_field", false)):
			continue
		var radius: float = float(area.get("radius"))
		if player.global_position.distance_squared_to(area.global_position) <= radius * radius:
			return area
	return null


## 作用：结合基础领域和庇护规则增加玩家十字护盾点数。
## 使用：player 为玩家节点；amount 为本次伤害或动作数值；rules 读取 cross_relic_base/cross_relic_shelter_upgrade；写入 cross_relic_shield_points 元数据；需由仍存活的宿主创建并调度。
func _grant_cross_relic_shield(player: Node, amount: int, rules: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if player == null or amount <= 0:
		return
	var base: Dictionary = host._get_dictionary(rules.get("cross_relic_base", {}))
	var cap: int = int(base.get("shield_cap", 12))
	if rules.has("cross_relic_shelter_upgrade"):
		var rule: Dictionary = host._get_dictionary(rules.get("cross_relic_shelter_upgrade", {}))
		cap += int(rule.get("shield_cap_add", 0))
	var current: int = int(player.get_meta("cross_relic_shield_points", 0))
	player.set_meta("cross_relic_shield_points", mini(current + amount, maxi(cap, amount)))


## 作用：在玩家治疗接口存在时恢复指定正数生命。
## 使用：player 为玩家节点；amount 为本次伤害或动作数值；会发出对应变更信号；需由仍存活的宿主创建并调度。
func _heal_player(player: Node, amount: int) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if player == null or amount <= 0:
		return
	var max_health: int = int(player.get("max_health"))
	var current_health: int = int(player.get("current_health"))
	player.set("current_health", mini(current_health + amount, max_health))
	if player.has_signal("health_changed"):
		player.emit_signal("health_changed", int(player.get("current_health")), max_health)


## 作用：读取玩家当前生命比例并夹紧到零至一，缺玩家视作满血。
## 使用：player 为玩家节点；需由仍存活的宿主创建并调度。
func _player_health_ratio(player: Node) -> float:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if player == null:
		return 1.0
	var max_health: float = maxf(float(player.get("max_health")), 1.0)
	return clampf(float(player.get("current_health")) / max_health, 0.0, 1.0)
