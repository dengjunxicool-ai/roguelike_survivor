## 文件用途：实现奥术双页、禁页、封印叠层与爆发及纸灵生成。
## 使用方式：由宿主提供施放和命中 context；施放预留元数据，命中再消费或叠加对应规则状态。
extends RefCounted

const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")

static var _arcane_seal_burst_cooldowns: Dictionary = {}

var _host_ref: WeakRef

## 作用：弱引用保存特殊规则宿主，供本族复用共享伤害、状态与冷却入口。
## 使用：host 为仍存活的规则宿主。
func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


## 作用：按施法计数预留奥术双页强化及额外弹体数量。
## 使用：rules 读取 arcane_double_page_every_n_casts；context 携带 skill_instance；写入 arcane_double_page_next_cast/arcane_double_page_extra_projectiles 元数据；需由仍存活的宿主创建并调度。
func _prepare_arcane_double_page_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("arcane_double_page_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("arcane_double_page_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 5)), 1)
	var cast_count: int = host._advance_interval_counter(skill_instance, "arcane_page_cast_count")
	if cast_count % interval == 0:
		skill_instance.set_meta("arcane_double_page_next_cast", true)
		skill_instance.set_meta("arcane_double_page_extra_projectiles", maxi(int(rule.get("extra_projectile_count", 1)), 0))


## 作用：按施法计数预留下一次禁页标记。
## 使用：rules 读取 forbidden_page_every_n_casts；context 携带 skill_instance；写入 forbidden_page_next_cast 元数据；需由仍存活的宿主创建并调度。
func _prepare_forbidden_page_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("forbidden_page_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("forbidden_page_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 4)), 1)
	var cast_count: int = host._advance_interval_counter(skill_instance, "forbidden_page_cast_count")
	skill_instance.set_meta("forbidden_page_next_cast", cast_count % interval == 0)


## 作用：顺序处理奥术复制、强敌封印、封印爆发和禁页命中规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_arcane_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_arcane_page_copy(rules, context)
	host._apply_arcane_seal_on_elite_boss_hit(rules, context)
	host._apply_arcane_seal_burst(rules, context)
	host._apply_forbidden_page_hit(rules, context)


## 作用：按奥术页命中配置创建复制弹体。
## 使用：rules 读取 arcane_page_copy_on_hit；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_arcane_page_copy(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("arcane_page_copy_on_hit"):
		return
	SpecialDamageRuleHandlerScript.execute_arcane_page_copy(rules, context, host._get_skill_damage(context))


## 作用：在强敌命中与来源冷却允许时施加奥术封印。
## 使用：rules 读取 arcane_seal_on_elite_boss_hit/arcane_seal_duration_add；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_arcane_seal_on_elite_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("arcane_seal_on_elite_boss_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	if not host._is_elite(target) and not host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("arcane_seal_on_elite_boss_hit", {}))
	var key: String = "arcane_seal:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_arcane_seal_burst_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 0.4)), 0.0)):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "arcane_seal"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 5)),
		"duration": float(rule.get("duration", 5.0)) + float(rules.get("arcane_seal_duration_add", 0.0))
	})


## 作用：达到封印门槛后消耗封印并造成爆发，可登记限时主攻击易伤。
## 使用：rules 读取 arcane_seal_burst/arcane_seal_burst_elite_boss_bonus/arcane_seal_burst_vulnerability；context 携带 target；写入 arcane_seal_burst_vulnerability_until/arcane_seal_burst_primary_attack_damage_taken_multiplier_add 元数据；需由仍存活的宿主创建并调度。
func _apply_arcane_seal_burst(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("arcane_seal_burst"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("arcane_seal_burst", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "arcane_seal")))
	var required_stacks: int = maxi(int(rule.get("required_stacks", 5)), 1)
	if int(target.call("get_status_stack", status_id)) < required_stacks:
		return
	var key: String = "arcane_seal_burst:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_arcane_seal_burst_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 0.0)), 0.0)):
		return
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, maxi(int(rule.get("consume_stacks", 3)), 0))
	var amount: int = maxi(int(rule.get("amount", 20)), 0)
	var bonus_rule: Dictionary = host._get_dictionary(rules.get("arcane_seal_burst_elite_boss_bonus", {}))
	if (host._is_elite(target) or host._is_boss(target)) and not bonus_rule.is_empty():
		amount = maxi(roundi(float(amount) * maxf(1.0 + float(bonus_rule.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.arcane_seal_burst_intents(rules, context, amount))
	var vulnerability_rule: Dictionary = host._get_dictionary(rules.get("arcane_seal_burst_vulnerability", {}))
	if not vulnerability_rule.is_empty():
		target.set_meta("arcane_seal_burst_vulnerability_until", now_seconds + maxf(float(vulnerability_rule.get("duration", 2.0)), 0.0))
		target.set_meta("arcane_seal_burst_primary_attack_damage_taken_multiplier_add", float(vulnerability_rule.get("primary_attack_damage_taken_multiplier_add", 0.12)))


## 作用：处理禁页命中收益与风险，并累积 Boss 禁页叠层。
## 使用：rules 读取 forbidden_page_every_n_casts/forbidden_page_upgrade/forbidden_boss_stack；context 携带 projectile/caster/target；写入 forbidden_boss_stacks 元数据；需由仍存活的宿主创建并调度。
func _apply_forbidden_page_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var projectile: Node = context.get("projectile") as Node
	if projectile == null or not bool(projectile.get_meta("forbidden_page", false)):
		return
	var caster: Node = context.get("caster") as Node
	var damage_rule: Dictionary = host._get_dictionary(rules.get("forbidden_page_every_n_casts", {}))
	var upgrade_rule: Dictionary = host._get_dictionary(rules.get("forbidden_page_upgrade", {}))
	var self_damage: int = int(damage_rule.get("self_damage", 0))
	if not upgrade_rule.is_empty():
		self_damage = int(upgrade_rule.get("self_damage", self_damage))
	SpecialDamageRuleHandlerScript.apply_forbidden_page_self_damage(caster, context, maxi(self_damage, 0))
	var target: Node = context.get("target") as Node
	if target == null or not host._is_boss(target) or not rules.has("forbidden_boss_stack"):
		return
	var boss_rule: Dictionary = host._get_dictionary(rules.get("forbidden_boss_stack", {}))
	var current_stacks: int = int(target.get_meta("forbidden_boss_stacks", 0))
	target.set_meta("forbidden_boss_stacks", mini(current_stacks + 1, maxi(int(boss_rule.get("max_stacks", 5)), 1)))


## 作用：按规则创建纸灵并接入周期效果。
## 使用：rules 读取 page_spirit_spawn；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_page_spirit_spawn(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("page_spirit_spawn"):
		return
	SpecialDamageRuleHandlerScript.execute_page_spirit_tick(rules, context)


## 作用：根据奥术封印时长规则修饰状态参数。
## 使用：params 读取 duration；context 为施放或命中上下文；会原地更新 params.duration；需由仍存活的宿主创建并调度。
func _get_arcane_seal_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	if rules.is_empty():
		return params
	params["duration"] = float(params.get("duration", 5.0)) + float(rules.get("arcane_seal_duration_add", 0.0))
	return params


## 作用：将目标尚未过期的封印爆发易伤应用到伤害包。
## 使用：packet 为待修饰伤害包视图；rules 读取 arcane_seal_burst_vulnerability；target 为本次命中目标；会原地更新 packet.vulnerability_total；需由仍存活的宿主创建并调度。
func _apply_arcane_seal_burst_vulnerability(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("arcane_seal_burst_vulnerability") or target == null:
		return
	if host._now_seconds() > float(target.get_meta("arcane_seal_burst_vulnerability_until", -1.0)):
		return
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(target.get_meta("arcane_seal_burst_primary_attack_damage_taken_multiplier_add", 0.0))


## 作用：根据禁页施放标记、风险和 Boss 叠层修饰直接命中伤害。
## 使用：packet 为待修饰伤害包视图；rules 读取 forbidden_page_risk/forbidden_page_every_n_casts/forbidden_page_upgrade/forbidden_boss_stack；context 携带 projectile；会原地更新 packet.direct_damage_multiplier_add/crit_chance_add/boss_damage_multiplier_add；需由仍存活的宿主创建并调度。
func _apply_forbidden_page_damage_bonus(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if rules.has("forbidden_page_risk"):
		var risk_rule: Dictionary = host._get_dictionary(rules.get("forbidden_page_risk", {}))
		packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(risk_rule.get("damage_multiplier_add", 0.0))
	var projectile: Node = context.get("projectile") as Node
	if projectile != null and bool(projectile.get_meta("forbidden_page", false)):
		var forbidden_rule: Dictionary = host._get_dictionary(rules.get("forbidden_page_every_n_casts", {}))
		packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(forbidden_rule.get("damage_multiplier_add", 0.0))
		var upgrade_rule: Dictionary = host._get_dictionary(rules.get("forbidden_page_upgrade", {}))
		if not upgrade_rule.is_empty():
			packet["crit_chance_add"] = float(packet.get("crit_chance_add", 0.0)) + float(upgrade_rule.get("crit_chance_add", 0.0))
	if target != null and host._is_boss(target) and rules.has("forbidden_boss_stack"):
		var boss_rule: Dictionary = host._get_dictionary(rules.get("forbidden_boss_stack", {}))
		var stacks: int = int(target.get_meta("forbidden_boss_stacks", 0))
		packet["boss_damage_multiplier_add"] = float(packet.get("boss_damage_multiplier_add", 0.0)) + float(stacks) * float(boss_rule.get("boss_damage_multiplier_add_per_stack", 0.0))
