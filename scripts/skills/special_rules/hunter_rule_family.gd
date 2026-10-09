## 文件用途：实现猎手飞刀、弓箭、标记、流血、回收及陷阱特殊规则。
## 使用方式：宿主按投射物、陷阱命中或击杀调用；同目标窗口、来源冷却和 Boss 条件在族内校验。
extends RefCounted

const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")

static var _execution_burst_cooldowns: Dictionary = {}

static var _wound_on_hit_cooldowns: Dictionary = {}

static var _bleed_on_wound_cooldowns: Dictionary = {}

static var _rupture_cooldowns: Dictionary = {}

static var _marked_hit_refund_cooldowns: Dictionary = {}

static var _marked_death_explosion_cooldowns: Dictionary = {}

static var _pincer_reaction_cooldowns: Dictionary = {}

static var _boss_core_trap_bonus_cooldowns: Dictionary = {}

static var _decoy_trap_spawn_cooldowns: Dictionary = {}

var _host_ref: WeakRef

## 作用：弱引用保存特殊规则宿主，供本族复用共享伤害、状态与冷却入口。
## 使用：host 为仍存活的规则宿主。
func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


## 作用：在陷阱伤害路径应用猎手标记与 Boss 核心相关加成。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_trap_damage_packet_modifiers(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_hunter_trap_damage_bonus(packet, rules, target)


## 作用：按周期施放计数触发额外飞刀投射。
## 使用：rules 读取 extra_knife_every_n_casts；context 携带 skill_instance；需由仍存活的宿主创建并调度。
func _prepare_extra_knife_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("extra_knife_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("extra_knife_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 4)), 1)
	var cast_count: int = host._advance_interval_counter(skill_instance, "extra_knife_cast_count")
	if cast_count % interval == 0:
		SpecialDamageRuleHandlerScript.execute_extra_knife_throw(rules, context, host._get_skill_damage(context))


## 作用：更新风步属性并预备风步双箭与周期云箭标记。
## 使用：rules 读取 windstep_double_arrow/cloud_arrow_every_n_casts；context 携带 skill_instance；写入 hunter_cloud_arrow_active 元数据；需由仍存活的宿主创建并调度。
func _prepare_hunter_bow_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	host._apply_windstep_runtime_modifiers(rules, context)
	if rules.has("windstep_double_arrow") and host._is_windstep_active(context):
		var wind_rule: Dictionary = host._get_dictionary(rules.get("windstep_double_arrow", {}))
		var wind_interval: int = maxi(int(wind_rule.get("cast_interval", 4)), 1)
		var wind_count: int = host._advance_interval_counter(skill_instance, "windstep_arrow_cast_count")
		if wind_count % wind_interval == 0:
			SpecialDamageRuleHandlerScript.execute_windstep_double_arrow(rules, context, host._get_skill_damage(context))
	if not rules.has("cloud_arrow_every_n_casts"):
		host._set_dynamic_runtime_modifier(skill_instance, "hunter_cloud_arrow", "pierce_override", null)
		return
	var rule: Dictionary = host._get_dictionary(rules.get("cloud_arrow_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 3)), 1)
	var cast_count: int = host._advance_interval_counter(skill_instance, "cloud_arrow_cast_count")
	var active: bool = cast_count % interval == 0
	skill_instance.set_meta("hunter_cloud_arrow_active", active)
	var pierce_override_value: Variant = null
	if active:
		pierce_override_value = int(rule.get("pierce_override", 7))
	host._set_dynamic_runtime_modifier(skill_instance, "hunter_cloud_arrow", "pierce_override", pierce_override_value)


## 作用：按既定顺序执行飞刀标记、创伤回收与弓箭爆炸分裂等命中规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_hunter_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_execution_mark_on_strong_target(rules, context)
	host._apply_boss_low_hp_execution_burst(rules, context)
	host._apply_wound_on_throwing_knife_hit(rules, context)
	host._apply_bleed_on_crit_wound(rules, context)
	host._apply_rupture_on_full_wound_crit(rules, context)
	host._apply_recycle_boss_hit(rules, context)
	host._apply_eagle_mark_on_strong_hit(rules, context)
	host._apply_hunter_arrow_hit_explosion(rules, context)
	host._apply_hunter_arrow_shards(rules, context)
	host._apply_marked_hit_cooldown_refund(rules, context)
	host._apply_eagle_shot_on_boss_mark_hits(rules, context)


## 作用：依次执行猎手陷阱标记、伤害和控制规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _on_trap_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_hunter_trap_hit_rules(rules, context)
	host._apply_trap_damage_hit_rules(rules, context)
	host._apply_trap_control_hit_rules(rules, context)


## 作用：在陷阱命中时处理强敌猎物标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_hunter_trap_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_prey_mark_on_strong_trap_hit(rules, context)


## 作用：在陷阱命中时顺序处理 Boss 核心增伤、爆炸及小陷阱。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_trap_damage_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_boss_core_trap_bonus_damage(rules, context)
	host._apply_trap_hit_explosion(rules, context)
	host._apply_small_trap_on_trigger(rules, context)


## 作用：在陷阱命中时处理锁链定身及钳击反应。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_trap_control_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_chain_trap_root_on_hit(rules, context)
	host._apply_pincer_reaction_on_root(rules, context)


## 作用：陷阱到期时处理火油烟云和诱饵陷阱爆炸。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _on_trap_expired(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_smoke_cloud_on_oil_expire(rules, context)
	host._execute_decoy_trap_expired(rules, context)


## 作用：依据诱饵到期爆炸规则转入特殊伤害服务。
## 使用：rules 读取 decoy_trap_explosion；context 携带 area；需由仍存活的宿主创建并调度。
func _execute_decoy_trap_expired(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("decoy_trap_explosion"):
		return
	var area: Node = context.get("area") as Node
	if area == null or not bool(area.get_meta("decoy_trap", false)):
		return
	SpecialDamageRuleHandlerScript.execute_decoy_trap_explosion(rules, context)


## 作用：击杀时更新下一刀增伤、普通怪飞刀回收、标记爆炸及陷阱碎片领域。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_hunter_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_next_knife_kill_bonus(rules, context)
	host._apply_recycle_knife_on_normal_kill(rules, context)
	host._apply_marked_target_death_explosion(rules, context)
	host._apply_trap_kill_fragment_field(rules, context)


## 作用：对强敌命中写入飞刀处决标记供暴击收益使用。
## 使用：rules 读取 execution_mark_on_strong_target；context 携带 target；写入 throwing_knife_execution_mark 元数据；需由仍存活的宿主创建并调度。
func _apply_execution_mark_on_strong_target(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("execution_mark_on_strong_target"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not (host._is_elite(target) or host._is_boss(target)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("execution_mark_on_strong_target", {}))
	var key: String = "execution_hits_%s" % host._target_key(target)
	var hit_count: int = int(target.get_meta(key, 0)) + 1
	target.set_meta(key, hit_count)
	if hit_count >= maxi(int(rule.get("required_consecutive_hits", 5)), 1):
		target.set_meta("throwing_knife_execution_mark", true)


## 作用：Boss 血量低于规则门槛且冷却允许时触发处决爆发。
## 使用：rules 读取 boss_low_hp_execution_burst；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_boss_low_hp_execution_burst(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("boss_low_hp_execution_burst"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("boss_low_hp_execution_burst", {}))
	if host._health_ratio(target) > float(rule.get("hp_threshold", 0.2)):
		return
	var key: String = "execution_burst:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_execution_burst_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.execution_burst_intents(rules, context, maxi(int(rule.get("amount", 22)), 0)))


## 作用：飞刀命中在冷却允许时按创伤调整规则施加 wound。
## 使用：rules 读取 wound_on_throwing_knife_hit/wound_tuning；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_wound_on_throwing_knife_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("wound_on_throwing_knife_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("wound_on_throwing_knife_hit", {}))
	var key: String = "wound_on_hit:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_wound_on_hit_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 0.3)), 0.0)):
		return
	var duration: float = float(rule.get("duration", 4.0))
	var tuning: Dictionary = host._get_dictionary(rules.get("wound_tuning", {}))
	duration += float(tuning.get("duration_add", 0.0))
	target.call("apply_status", StringName(String(rule.get("status_id", "wound"))), {
		"duration": duration,
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 5)), 1)
	})


## 作用：暴击命中带创伤目标时按冷却施加流血。
## 使用：rules 读取 bleed_on_crit_wound；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_bleed_on_crit_wound(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("bleed_on_crit_wound") or not host._is_critical_hit_context(context):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("has_status") or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("bleed_on_crit_wound", {}))
	if not bool(target.call("has_status", StringName(String(rule.get("required_status_id", "wound"))))):
		return
	var key: String = "bleed_on_wound:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_bleed_on_wound_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.0)), 0.0)):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "bleed"))), {
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1),
		"boss_damage_multiplier": float(rule.get("boss_damage_multiplier", 0.65))
	})


## 作用：目标满创伤暴击命中在冷却允许时触发撕裂伤害。
## 使用：rules 读取 rupture_on_full_wound_crit；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_rupture_on_full_wound_crit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("rupture_on_full_wound_crit") or not host._is_critical_hit_context(context):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("rupture_on_full_wound_crit", {}))
	if int(target.call("get_status_stack", StringName(String(rule.get("required_status_id", "wound"))))) < maxi(int(rule.get("required_wound_stacks", 5)), 1):
		return
	var key: String = "rupture:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_rupture_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.rupture_on_full_wound_crit_intents(rules, context, maxi(int(rule.get("amount", 18)), 0)))


## 作用：累计 Boss 飞刀命中计数，达到门槛后授予回收冲刺增益。
## 使用：rules 读取 recycle_dash_buff；context 携带 target/skill_instance；写入 recycle_boss_hit_count 元数据；需由仍存活的宿主创建并调度。
func _apply_recycle_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("recycle_dash_buff"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not host._is_boss(target):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("recycle_dash_buff", {}))
	var interval: int = maxi(int(rule.get("boss_hit_interval", 6)), 1)
	var hit_count: int = int(skill_instance.get_meta("recycle_boss_hit_count", 0)) + 1
	skill_instance.set_meta("recycle_boss_hit_count", hit_count)
	if hit_count % interval == 0:
		SpecialDamageRuleHandlerScript.apply_recycle_dash_buff(rules, context)


## 作用：击杀后记录下一次飞刀额外伤害的待消费数值。
## 使用：rules 读取 next_knife_damage_after_kill；context 携带 skill_instance；写入 next_knife_damage_after_kill_bonus 元数据；需由仍存活的宿主创建并调度。
func _apply_next_knife_kill_bonus(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("next_knife_damage_after_kill"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("next_knife_damage_after_kill", {}))
	skill_instance.set_meta("next_knife_damage_after_kill_bonus", float(rule.get("damage_multiplier_add", 0.2)))


## 作用：普通怪击杀满足回收规则时生成回收飞刀。
## 使用：rules 读取 recycle_knife_on_normal_kill；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_recycle_knife_on_normal_kill(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("recycle_knife_on_normal_kill"):
		return
	SpecialDamageRuleHandlerScript.execute_recycle_knife(rules, context, host._get_skill_damage(context))


## 作用：强敌箭命中时按规则清理或累积鹰眼标记。
## 使用：rules 读取 eagle_mark_on_strong_hit；context 携带 target/skill_instance；需由仍存活的宿主创建并调度。
func _apply_eagle_mark_on_strong_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("eagle_mark_on_strong_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not (host._is_elite(target) or host._is_boss(target)) or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("eagle_mark_on_strong_hit", {}))
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var marked_ids: Array = []
	var meta_key: String = "eagle_mark_target_ids"
	var existing: Variant = skill_instance.get_meta(meta_key, []) if skill_instance != null else []
	if existing is Array:
		marked_ids = existing
	var target_id: int = int(target.get_instance_id())
	marked_ids.erase(target_id)
	marked_ids.append(target_id)
	var status_id: StringName = StringName(String(rule.get("status_id", "eagle_mark")))
	while marked_ids.size() > maxi(int(rule.get("max_active_targets", 2)), 1):
		var removed_id: int = int(marked_ids.pop_front())
		var removed_target: Object = instance_from_id(removed_id)
		if removed_target is Node and (removed_target as Node).has_method("consume_status_stack"):
			(removed_target as Node).call("consume_status_stack", status_id, 99)
	if skill_instance != null:
		skill_instance.set_meta(meta_key, marked_ids)
	target.call("apply_status", status_id, {
		"duration": float(rule.get("duration", 6.0)),
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1)
	})


## 作用：弓箭命中时按规则生成命中爆炸。
## 使用：rules 读取 hunter_arrow_hit_explosion；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_hunter_arrow_hit_explosion(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("hunter_arrow_hit_explosion"):
		return
	SpecialDamageRuleHandlerScript.execute_hunter_arrow_hit_explosion(rules, context, host._get_skill_damage(context))


## 作用：穿透命中次数满足条件且未生成过时，生成弓箭碎片。
## 使用：rules 读取 hunter_arrow_shards_after_pierce_hits；context 携带 projectile；写入 hunter_arrow_shards_spawned 元数据；需由仍存活的宿主创建并调度。
func _apply_hunter_arrow_shards(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("hunter_arrow_shards_after_pierce_hits"):
		return
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("hunter_arrow_shards_after_pierce_hits", {}))
	var hit_count: int = int(projectile.get_meta("hunter_arrow_hit_count", 0))
	if hit_count < maxi(int(rule.get("required_hits", 3)), 1):
		return
	if bool(projectile.get_meta("hunter_arrow_shards_spawned", false)):
		return
	projectile.set_meta("hunter_arrow_shards_spawned", true)
	SpecialDamageRuleHandlerScript.execute_hunter_arrow_shards(rules, context)


## 作用：箭命中带标记目标且冷却允许时返还技能冷却。
## 使用：rules 读取 eagle_marked_hit_cooldown_refund/marked_hit_cooldown_refund；context 携带 target/skill_instance/skill_id；需由仍存活的宿主创建并调度。
func _apply_marked_hit_cooldown_refund(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("eagle_marked_hit_cooldown_refund") and not rules.has("marked_hit_cooldown_refund"):
		return
	var target: Node = context.get("target") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if target == null or skill_instance == null or not target.has_method("has_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("eagle_marked_hit_cooldown_refund", rules.get("marked_hit_cooldown_refund", {})))
	if not bool(target.call("has_status", StringName(String(rule.get("status_id", "eagle_mark"))))):
		return
	if randf() > clampf(float(rule.get("chance", 0.25)), 0.0, 1.0):
		return
	var key: String = "marked_refund:%s:%s" % [String(context.get("skill_id", "piercing_arrow")), str(skill_instance.get_instance_id())]
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_marked_hit_refund_cooldowns, key, now_seconds, maxf(float(rule.get("same_source_cooldown", 2.0)), 0.0)):
		return
	skill_instance.set("cooldown_remaining", 0.0)


## 作用：累计 Boss 标记命中条件并触发鹰击额外伤害。
## 使用：rules 读取 eagle_shot_on_boss_eagle_mark_hits/eagle_shot_on_boss_mark_hits；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_eagle_shot_on_boss_mark_hits(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("eagle_shot_on_boss_eagle_mark_hits") and not rules.has("eagle_shot_on_boss_mark_hits"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not host._is_boss(target) or not target.has_method("has_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("eagle_shot_on_boss_eagle_mark_hits", rules.get("eagle_shot_on_boss_mark_hits", {})))
	if not bool(target.call("has_status", StringName(String(rule.get("status_id", "eagle_mark"))))):
		return
	var key: String = host._metadata_key("eagle_shot_hits", host._target_key(target))
	var hit_count: int = int(target.get_meta(key, 0)) + 1
	target.set_meta(key, hit_count)
	if hit_count % maxi(int(rule.get("required_hits", 6)), 1) == 0:
		SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.eagle_shot_intents(rules, context, maxi(int(rule.get("amount", 36)), 0)))


## 作用：带指定标记目标死亡在来源冷却允许时触发死亡爆炸。
## 使用：rules 读取 burst_mark_death_explosion/marked_target_death_explosion；context 携带 enemy/source_key；需由仍存活的宿主创建并调度。
func _apply_marked_target_death_explosion(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("burst_mark_death_explosion") and not rules.has("marked_target_death_explosion"):
		return
	var enemy: Node = context.get("enemy") as Node
	if enemy == null or not enemy.has_method("has_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("burst_mark_death_explosion", rules.get("marked_target_death_explosion", {})))
	if not bool(enemy.call("has_status", StringName(String(rule.get("required_status_id", "burst_mark"))))):
		return
	if String(context.get("source_key", "")).find("hunter_burst_mark_death_explosion") >= 0 and not bool(rule.get("can_trigger_self", false)):
		return
	var key: String = "marked_death:%s" % String(context.get("source_key", str(enemy.get_instance_id())))
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_marked_death_explosion_cooldowns, key, now_seconds, maxf(float(rule.get("same_source_cooldown", 0.25)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.execute_burst_mark_death_explosion(rules, context, host._get_skill_damage(context))


## 作用：陷阱触发后按规则生成小型派生陷阱。
## 使用：rules 读取 small_trap_on_trigger；context 携带 area；需由仍存活的宿主创建并调度。
func _apply_small_trap_on_trigger(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("small_trap_on_trigger"):
		return
	var area: Node = context.get("area") as Node
	if area != null and bool(area.get_meta("small_trap", false)):
		return
	SpecialDamageRuleHandlerScript.execute_small_trap_on_trigger(rules, context, host._get_skill_damage(context))


## 作用：锁链陷阱命中时施加定身状态。
## 使用：rules 读取 chain_trap_root_on_hit；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_chain_trap_root_on_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("chain_trap_root_on_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("chain_trap_root_on_hit", {}))
	if host._is_boss(target):
		target.call("apply_status", StringName(String(rule.get("boss_status_id", "slow"))), {
			"duration": float(rule.get("elite_duration", 0.25)),
			"slow_percent": float(rule.get("boss_slow_percent", 0.35))
		})
		if bool(rule.get("boss_converts_to_poise", true)):
			ReactionLimiterScript.apply_boss_control_conversion(target, StringName(String(rule.get("status_id", "root"))))
		return
	var duration: float = float(rule.get("elite_duration", 0.25)) if host._is_elite(target) else float(rule.get("normal_duration", 0.5))
	target.call("apply_status", StringName(String(rule.get("status_id", "root"))), {
		"duration": duration,
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1)
	})


## 作用：命中带定身目标且冷却允许时触发钳击反应。
## 使用：rules 读取 pincer_reaction_on_root；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_pincer_reaction_on_root(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("pincer_reaction_on_root"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("has_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("pincer_reaction_on_root", {}))
	if not bool(target.call("has_status", StringName(String(rule.get("required_status_id", "root"))))):
		return
	var key: String = "trap_pincer:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_pincer_reaction_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.pincer_reaction_intents(rules, context, maxi(int(rule.get("amount", 16)), 0)))


## 作用：陷阱命中强敌时施加猎物标记。
## 使用：rules 读取 prey_mark_on_strong_trap_hit；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_prey_mark_on_strong_trap_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("prey_mark_on_strong_trap_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not (host._is_elite(target) or host._is_boss(target)) or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("prey_mark_on_strong_trap_hit", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "prey_mark"))), {
		"duration": float(rule.get("duration", 5.0)),
		"stacks": 1,
		"max_stacks": 1
	})


## 作用：Boss 核心陷阱命中在冷却允许时触发额外伤害。
## 使用：rules 读取 boss_core_trap_bonus_damage；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_boss_core_trap_bonus_damage(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("boss_core_trap_bonus_damage"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not (host._is_boss(target) or host._is_boss_core(target)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("boss_core_trap_bonus_damage", {}))
	var key: String = "boss_core_trap_bonus:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_boss_core_trap_bonus_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 3.0)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.boss_core_trap_bonus_intents(rules, context, maxi(int(rule.get("amount", 28)), 0)))


## 作用：陷阱命中时按规则生成爆炸区域。
## 使用：rules 读取 trap_hit_explosion；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_trap_hit_explosion(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("trap_hit_explosion"):
		return
	SpecialDamageRuleHandlerScript.execute_trap_hit_explosion(rules, context, host._get_skill_damage(context))


## 作用：陷阱击杀时生成碎片伤害领域。
## 使用：rules 读取 trap_kill_fragment_field；context 携带 enemy；需由仍存活的宿主创建并调度。
func _apply_trap_kill_fragment_field(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("trap_kill_fragment_field"):
		return
	var enemy: Node = context.get("enemy") as Node
	if enemy == null or host._is_elite(enemy) or host._is_boss(enemy):
		return
	SpecialDamageRuleHandlerScript.execute_trap_kill_fragment_field(rules, context)


## 作用：规则冷却允许时创建诱饵陷阱。
## 使用：rules 读取 decoy_trap_spawn；context 携带 caster；需由仍存活的宿主创建并调度。
func _apply_decoy_trap_spawn(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("decoy_trap_spawn"):
		return
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("decoy_trap_spawn", {}))
	var key: String = "decoy_trap:%s" % str(caster.get_instance_id())
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_decoy_trap_spawn_cooldowns, key, now_seconds, maxf(float(rule.get("spawn_interval", 10.0)), 0.05)):
		return
	SpecialDamageRuleHandlerScript.execute_decoy_trap_spawn(rules, context)


## 作用：按猎手标记调整规则修饰状态参数。
## 使用：params 读取 duration/max_stacks；context 为施放或命中上下文；会原地更新 params.duration/max_stacks；需由仍存活的宿主创建并调度。
func _get_hunter_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	if rules.is_empty():
		return params
	var rule: Dictionary = host._get_dictionary(rules.get("hunter_mark_tuning", {}))
	if rule.is_empty():
		return params
	params["duration"] = float(params.get("duration", 5.0)) + float(rule.get("duration_add", 0.0))
	params["max_stacks"] = maxi(int(params.get("max_stacks", 1)) + int(rule.get("max_stacks_add", 0)), 1)
	return params


## 作用：按创伤调整规则修饰状态参数。
## 使用：params 读取 duration；context 为施放或命中上下文；会原地更新 params.duration；需由仍存活的宿主创建并调度。
func _get_wound_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	if rules.is_empty():
		return params
	var rule: Dictionary = host._get_dictionary(rules.get("wound_tuning", {}))
	if rule.is_empty():
		return params
	params["duration"] = float(params.get("duration", 5.0)) + float(rule.get("duration_add", 0.0))
	return params


## 作用：根据目标移动状态和流血规则修饰流血参数。
## 使用：params 读取 damage/tick_damage/boss_damage_multiplier；context 携带 target；会原地更新 params.damage；需由仍存活的宿主创建并调度。
func _get_bleed_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	if rules.is_empty():
		return params
	var rule: Dictionary = host._get_dictionary(rules.get("bleed_moving_target_bonus", {}))
	var target: Node = context.get("target") as Node
	if not rule.is_empty() and host._is_target_moving(target):
		var base_damage: int = int(params.get("damage", params.get("tick_damage", 0)))
		if base_damage > 0:
			params["damage"] = maxi(roundi(float(base_damage) * maxf(1.0 + float(rule.get("damage_multiplier_add", 0.2)), 0.0)), 0)
	if host._is_boss(target):
		var boss_multiplier: float = float(params.get("boss_damage_multiplier", 0.65))
		var base_boss_damage: int = int(params.get("damage", params.get("tick_damage", 0)))
		if base_boss_damage > 0:
			params["damage"] = maxi(roundi(float(base_boss_damage) * maxf(boss_multiplier, 0.0)), 0)
	return params


## 作用：按目标血量条件给伤害包追加低血伤害收益。
## 使用：packet 为待修饰伤害包视图；rules 读取 low_hp_damage_bonus；target 为本次命中目标；会原地更新 packet.direct_damage_multiplier_add；需由仍存活的宿主创建并调度。
func _apply_low_hp_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("low_hp_damage_bonus") or target == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("low_hp_damage_bonus", {}))
	if host._health_ratio(target) <= float(rule.get("hp_threshold", 0.35)):
		packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(rule.get("damage_multiplier_add", 0.15))


## 作用：按来源和目标维护短时间命中记录，对重复命中应用衰减。
## 使用：packet 为待修饰伤害包视图；rules 读取 same_target_short_window_decay；context 为施放或命中上下文；会原地更新 packet.special_final_modifier/special_final_modifier_source；需由仍存活的宿主创建并调度。
func _apply_same_target_short_window_decay(packet: Dictionary, rules: Dictionary, context: Dictionary, packet_object: RefCounted, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("same_target_short_window_decay") or target == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("same_target_short_window_decay", {}))
	var now_seconds: float = host._now_seconds()
	var window: float = maxf(float(rule.get("window", 0.25)), 0.0)
	var key: String = "throwing_knife_short_window_%s" % host._target_key(target)
	var last_hit_at: float = float(target.get_meta(key, -9999.0))
	target.set_meta(key, now_seconds)
	if now_seconds - last_hit_at <= window:
		packet["special_final_modifier"] = float(packet_object.call("get_value", "special_final_modifier", 1.0)) * maxf(float(rule.get("second_hit_multiplier", 0.6)), 0.0)
		packet["special_final_modifier_source"] = "target_passive"


## 作用：目标具有处决标记时修改暴击伤害相关字段。
## 使用：packet 为待修饰伤害包视图；rules 读取 execution_mark_crit_damage_taken；target 为本次命中目标；会原地更新 packet.crit_damage_add；需由仍存活的宿主创建并调度。
func _apply_execution_mark_crit_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("execution_mark_crit_damage_taken") or target == null:
		return
	if not bool(target.get_meta("throwing_knife_execution_mark", false)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("execution_mark_crit_damage_taken", {}))
	packet["crit_damage_add"] = float(packet.get("crit_damage_add", 0.0)) + float(rule.get("crit_damage_taken_add", 0.25))


## 作用：将击杀预留的下一刀增量加入伤害包并消费预留标记。
## 使用：packet 为待修饰伤害包视图；rules 读取 next_knife_damage_after_kill；context 携带 skill_instance；会原地更新 packet.direct_damage_multiplier_add；写入 next_knife_damage_after_kill_bonus 元数据；需由仍存活的宿主创建并调度。
func _apply_next_knife_damage_after_kill(packet: Dictionary, rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("next_knife_damage_after_kill"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var bonus: float = float(skill_instance.get_meta("next_knife_damage_after_kill_bonus", 0.0))
	if bonus == 0.0:
		return
	packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + bonus
	skill_instance.set_meta("next_knife_damage_after_kill_bonus", 0.0)


## 作用：按箭命中序号与云箭标记修改本次穿透伤害系数。
## 使用：packet 为待修饰伤害包视图；rules 读取 hunter_arrow_pierce_tuning/cloud_arrow_every_n_casts；context 携带 projectile/skill_instance；会原地更新 packet.special_final_modifier/special_final_modifier_source；写入 hunter_arrow_hit_count 元数据；需由仍存活的宿主创建并调度。
func _apply_hunter_arrow_pierce_damage(packet: Dictionary, rules: Dictionary, context: Dictionary, packet_object: RefCounted) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("hunter_arrow_pierce_tuning") and not rules.has("cloud_arrow_every_n_casts"):
		return
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return
	var hit_count: int = int(projectile.get_meta("hunter_arrow_hit_count", 0)) + 1
	projectile.set_meta("hunter_arrow_hit_count", hit_count)
	var multiplier_per_extra_hit: float = 0.85
	if rules.has("hunter_arrow_pierce_tuning"):
		var rule: Dictionary = host._get_dictionary(rules.get("hunter_arrow_pierce_tuning", {}))
		multiplier_per_extra_hit = float(rule.get("pierce_damage_multiplier_per_extra_hit", multiplier_per_extra_hit))
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance != null and bool(skill_instance.get_meta("hunter_cloud_arrow_active", false)):
		var cloud_rule: Dictionary = host._get_dictionary(rules.get("cloud_arrow_every_n_casts", {}))
		multiplier_per_extra_hit = float(cloud_rule.get("pierce_damage_multiplier_per_extra_hit", 0.82))
	var extra_hits: int = maxi(hit_count - 1, 0)
	if extra_hits <= 0:
		return
	var final_multiplier: float = pow(maxf(multiplier_per_extra_hit, 0.0), extra_hits)
	packet["special_final_modifier"] = float(packet_object.call("get_value", "special_final_modifier", 1.0)) * final_multiplier
	packet["special_final_modifier_source"] = "target_passive"


## 作用：带猎手或鹰眼标记的目标受到主攻击时应用规则易伤。
## 使用：packet 为待修饰伤害包视图；rules 读取 eagle_mark_primary_damage_taken/hunter_mark_primary_damage_taken；target 为本次命中目标；会原地更新 packet.vulnerability_total；需由仍存活的宿主创建并调度。
func _apply_hunter_mark_damage_taken(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("eagle_mark_primary_damage_taken") and not rules.has("hunter_mark_primary_damage_taken"):
		return
	if target == null or not target.has_method("has_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("eagle_mark_primary_damage_taken", rules.get("hunter_mark_primary_damage_taken", {})))
	if not bool(target.call("has_status", StringName(String(rule.get("status_id", "eagle_mark"))))):
		return
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("primary_attack_damage_taken_multiplier_add", 0.15))


## 作用：按目标低血门槛修改战锤直接伤害。
## 使用：packet 为待修饰伤害包视图；rules 读取 warhammer_low_hp_damage_bonus；target 为本次命中目标；会原地更新 packet.direct_damage_multiplier_add；需由仍存活的宿主创建并调度。
func _apply_warhammer_low_hp_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("warhammer_low_hp_damage_bonus") or target == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("warhammer_low_hp_damage_bonus", {}))
	if host._health_ratio(target) <= float(rule.get("hp_threshold", 0.4)):
		packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(rule.get("damage_multiplier_add", 0.25))


## 作用：根据猎物标记、强敌类型及 Boss 核心规则修改陷阱伤害。
## 使用：packet 为待修饰伤害包视图；rules 读取 prey_mark_on_strong_trap_hit/boss_core_focus；target 为本次命中目标；会原地更新 packet.trap_damage_multiplier_add；需由仍存活的宿主创建并调度。
func _apply_hunter_trap_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if target == null:
		return
	if rules.has("prey_mark_on_strong_trap_hit"):
		var prey_rule: Dictionary = host._get_dictionary(rules.get("prey_mark_on_strong_trap_hit", {}))
		if (host._is_elite(target) or host._is_boss(target)) or (target.has_method("has_status") and bool(target.call("has_status", StringName(String(prey_rule.get("status_id", "prey_mark")))))):
			packet["trap_damage_multiplier_add"] = float(packet.get("trap_damage_multiplier_add", 0.0)) + float(prey_rule.get("trap_damage_multiplier_add", 0.15))
	if rules.has("boss_core_focus") and host._is_boss_core(target):
		var core_rule: Dictionary = host._get_dictionary(rules.get("boss_core_focus", {}))
		packet["trap_damage_multiplier_add"] = float(packet.get("trap_damage_multiplier_add", 0.0)) + float(core_rule.get("boss_core_damage_multiplier_add", 0.25))
