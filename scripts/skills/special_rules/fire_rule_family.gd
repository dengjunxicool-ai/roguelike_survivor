## 文件用途：实现火系燃烧、魂烬、焰核、连发和衍生爆发规则。
## 使用方式：由 SkillSpecialRuleExecutor 按事件调用；构造时保存宿主弱引用，通过宿主共享伤害、状态和冷却能力。
extends RefCounted

const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")
const DamageTraceContextScript: Script = preload("res://scripts/runtime/damage_trace_context.gd")
const BurnStatusRuleHelperScript: Script = preload("res://scripts/skills/special_rules/burn_status_rule_helper.gd")

static var _soulburn_target_cooldowns: Dictionary = {}

static var _flame_core_burst_cooldowns: Dictionary = {}

static var _soul_ember_cooldowns: Dictionary = {}

var _host_ref: WeakRef

## 作用：弱引用保存特殊规则宿主，供本族复用共享伤害、状态与冷却入口。
## 使用：host 为仍存活的规则宿主。
func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


## 作用：补齐燃烧强度，并应用火系时长、层数和伤害特殊规则。
## 使用：params 读取 power/damage/tick_damage；context 携带 target；会原地更新 params.power；需由仍存活的宿主创建并调度。
func _get_burn_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not params.has("power") and not params.has("damage") and not params.has("tick_damage"):
		params["power"] = host._get_burning_power_from_context(context)
	var rules: Dictionary = host._get_rules(context)
	if rules.is_empty():
		return params
	var target: Node = context.get("target") as Node
	return BurnStatusRuleHelperScript.apply(params, rules, target, host._get_burn_base_max_stacks(), host._get_burn_base_damage(), host._is_boss(target))


## 作用：提供火系规则使用的基础燃烧层数上限。
## 使用：需由仍存活的宿主创建并调度。
func _get_burn_base_max_stacks() -> int:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	return 5


## 作用：提供火系规则使用的基础燃烧伤害数值。
## 使用：需由仍存活的宿主创建并调度。
func _get_burn_base_damage() -> float:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	return 1.6


## 作用：优先取事件 power，其次取施法者有效攻击力；无施法者的兼容调用使用基础燃烧强度，不从最终命中伤害推导。
## 使用：context 携带 power/damage/amount；需由仍存活的宿主创建并调度。
func _get_burning_power_from_context(context: Dictionary) -> float:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if context.has("power"):
		return maxf(float(context.get("power", 0.0)), 0.0)
	var caster: Node = context.get("caster", context.get("owner")) as Node
	if caster != null and caster.get("attack_power") != null:
		var multiplier: Variant = caster.get("damage_multiplier")
		return maxf(float(caster.get("attack_power")) * (float(multiplier) if multiplier != null else 1.0), 0.0)
	return host._get_burn_base_damage() / 0.36


## 作用：把本次热连发标记对应的暴击增量加入伤害包。
## 使用：packet 为待修饰伤害包视图；context 携带 hot_rapid_fire_crit/hot_rapid_fire_crit_chance_add；packet_object 为用于读取包字段的伤害对象；会原地更新 packet.crit_chance_add；需由仍存活的宿主创建并调度。
func _apply_hot_rapid_fire_crit_bonus(packet: Dictionary, context: Dictionary, packet_object: RefCounted) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not bool(context.get("hot_rapid_fire_crit", false)):
		return
	packet["crit_chance_add"] = float(packet_object.call("get_value", "crit_chance_add", 0.0)) + float(context.get("hot_rapid_fire_crit_chance_add", 0.0))


## 作用：按施放身份与目标记录连发命中次数，并对第二次起命中应用规则衰减。
## 使用：packet 为待修饰伤害包视图；rules 读取 same_target_multi_projectile_damage；context 携带 projectile；会原地更新 packet.special_final_modifier/special_final_modifier_source；写入 rapid_fireball_hits 元数据；需由仍存活的宿主创建并调度。
func _apply_same_target_multi_projectile_damage(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node, packet_object: RefCounted) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("same_target_multi_projectile_damage"):
		return
	var projectile: Node = context.get("projectile") as Node
	var target_key: String = host._target_key(target)
	var cast_key: String = String(projectile.get_meta("cast_instance_id", "default")) if projectile != null else "default"
	var hit_key: String = "rapid:%s:%s" % [cast_key, target_key]
	var hits: int = int(packet.get("_rapid_same_target_hits", 0))
	if target != null:
		var meta_hits: Dictionary = {}
		if target.has_meta("rapid_fireball_hits"):
			var meta_variant: Variant = target.get_meta("rapid_fireball_hits")
			if meta_variant is Dictionary:
				meta_hits = meta_variant
		hits = int(meta_hits.get(hit_key, 0)) + 1
		meta_hits[hit_key] = hits
		target.set_meta("rapid_fireball_hits", meta_hits)
	if hits < 2:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("same_target_multi_projectile_damage", {}))
	packet["special_final_modifier"] = float(packet_object.call("get_value", "special_final_modifier", 1.0)) * maxf(float(rule.get("second_hit_damage_multiplier", 0.6)), 0.0)
	packet["special_final_modifier_source"] = "target_passive"


## 作用：按火球施放次数间隔预留下一发热连发与暴击加成。
## 使用：rules 读取 hot_rapid_fire；context 携带 skill_instance；写入 hot_rapid_fire_next_cast/hot_rapid_fire_crit_chance_add 元数据；需由仍存活的宿主创建并调度。
func _prepare_hot_rapid_fire_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("hot_rapid_fire"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("hot_rapid_fire", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 3)), 1)
	var cast_count: int = host._advance_interval_counter(skill_instance, "fireball_cast_count")
	if cast_count % interval == 0:
		skill_instance.set_meta("hot_rapid_fire_next_cast", true)
		skill_instance.set_meta("hot_rapid_fire_crit_chance_add", float(rule.get("next_projectile_crit_chance_add", 0.4)))


## 作用：顺序执行额外爆炸、燃烧、魂烬与焰核直接命中规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_fire_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_direct_hit_extra_explosion_bonus(rules, context)
	host._apply_explosion_burn_rules(rules, context)
	host._apply_soul_ember_to_burn(rules, context)
	host._apply_soul_ember_on_direct_hit(rules, context)
	host._apply_flame_core_on_direct_hit(rules, context)


## 作用：在火系命中阶段处理魂燃和 Boss 焰核爆发。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_fire_reaction_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_soulburn_burst(rules, context)
	host._apply_flame_core_boss_burst(rules, context)


## 作用：将爆炸命中按强敌直接命中或普通多目标情况分别处理燃烧。
## 使用：rules 为当前技能有效规则；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_explosion_burn_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	host._apply_explosion_direct_hit_burn(rules, context, target)
	host._apply_explosion_multi_hit_burn(rules, context, target)


## 作用：对精英或 Boss 的爆炸直接命中按同目标冷却施加燃烧。
## 使用：rules 读取 explosion_direct_hit_burn_on_elite_boss；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_explosion_direct_hit_burn(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var direct_rule: Dictionary = host._get_dictionary(rules.get("explosion_direct_hit_burn_on_elite_boss", {}))
	if not direct_rule.is_empty() and (host._is_elite(target) or host._is_boss(target)):
		var key: String = host._metadata_key("burst_explosion_burn", host._target_key(target))
		var now_seconds: float = host._now_seconds()
		if now_seconds >= float(target.get_meta(key, 0.0)):
			target.set_meta(key, now_seconds + maxf(float(direct_rule.get("same_target_cooldown", 1.5)), 0.0))
			var direct_status_id: StringName = StringName(String(direct_rule.get("status_id", "burning")))
			var direct_status_params: Dictionary = {
				"stacks": int(direct_rule.get("stack", 1)),
				"duration": float(direct_rule.get("duration", 3.0))
			}
			if direct_status_id == &"burning":
				direct_status_params = host._get_burn_status_params(direct_status_params, context)
			direct_status_params = DamageTraceContextScript.apply_to_status_params(direct_status_params, context)
			target.call("apply_status", direct_status_id, direct_status_params)


## 作用：普通目标在爆炸命中人数达到门槛时额外施加燃烧。
## 使用：rules 读取 explosion_multi_hit_burn；context 携带 explosion_targets_hit；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_explosion_multi_hit_burn(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var multi_rule: Dictionary = host._get_dictionary(rules.get("explosion_multi_hit_burn", {}))
	if multi_rule.is_empty() or host._is_elite(target) or host._is_boss(target):
		return
	var hit_count: int = int(context.get("explosion_targets_hit", target.get_meta("fireball_explosion_targets_hit", 1)))
	if hit_count < maxi(int(multi_rule.get("min_targets_hit", 3)), 1):
		return
	var multi_status_id: StringName = StringName(String(multi_rule.get("status_id", "burning")))
	var multi_status_params: Dictionary = {
		"stacks": int(multi_rule.get("stack", 1)),
		"duration": float(multi_rule.get("duration", 3.0))
	}
	if multi_status_id == &"burning":
		multi_status_params = host._get_burn_status_params(multi_status_params, context)
	multi_status_params = DamageTraceContextScript.apply_to_status_params(multi_status_params, context)
	target.call("apply_status", multi_status_id, multi_status_params)


## 作用：魂烬达到满层命中条件后消耗魂烬并转换为燃烧。
## 使用：rules 读取 soul_ember_to_burn_on_full_stack_hit；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_soul_ember_to_burn(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("soul_ember_to_burn_on_full_stack_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("soul_ember_to_burn_on_full_stack_hit", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "soul_ember")))
	var current_stacks: int = int(target.call("get_status_stack", status_id))
	var required_stacks: int = maxi(int(rule.get("required_stacks", 2)), 1)
	if current_stacks < required_stacks:
		return
	var conversion_count: int = current_stacks / required_stacks
	var consume_per_conversion: int = maxi(int(rule.get("consume_stacks", required_stacks)), 1)
	var burn_per_conversion: int = maxi(int(rule.get("apply_burn_stacks", 1)), 1)
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, mini(current_stacks, consume_per_conversion * conversion_count))
	if target.has_method("apply_status"):
		var burn_params: Dictionary = host._get_burn_status_params({
			"stacks": burn_per_conversion * conversion_count,
			"max_stacks": maxi(int(rule.get("burn_max_stacks", 5)), 1)
		}, context)
		burn_params = DamageTraceContextScript.apply_to_status_params(burn_params, context)
		target.call("apply_status", &"burning", burn_params)


## 作用：直接命中时按来源冷却为目标累积魂烬。
## 使用：rules 读取 soul_ember_on_direct_hit；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_soul_ember_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("soul_ember_on_direct_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("soul_ember_on_direct_hit", {}))
	var key: String = "soul_ember:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_soul_ember_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 0.4)), 0.0)):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "soul_ember"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 4)),
		"duration": float(rule.get("duration", 4.0))
	})


## 作用：对强敌直接命中施加焰核，并配置满层爆炸易伤与持续时间。
## 使用：rules 读取 flame_core_on_elite_boss_direct_hit/flame_core_duration_add/flame_core_full_stack_explosion_vulnerability；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_flame_core_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("flame_core_on_elite_boss_direct_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	if not host._is_elite(target) and not host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("flame_core_on_elite_boss_direct_hit", {}))
	var duration: float = float(rule.get("duration", 4.0)) + float(rules.get("flame_core_duration_add", 0.0))
	var params: Dictionary = {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 5)),
		"duration": duration,
		"direct_damage_multiplier_add_per_stack": float(rule.get("direct_damage_multiplier_add_per_stack", 0.0))
	}
	var vulnerability_rule: Dictionary = host._get_dictionary(rules.get("flame_core_full_stack_explosion_vulnerability", {}))
	if not vulnerability_rule.is_empty():
		params["full_stack_explosion_damage_taken_multiplier_add"] = float(vulnerability_rule.get("explosion_damage_taken_multiplier_add", 0.0))
		params["full_stack_required_stacks"] = int(vulnerability_rule.get("required_stacks", rule.get("max_stacks", 5)))
	target.call("apply_status", StringName(String(rule.get("status_id", "flame_core"))), params)


## 作用：记录 Boss 满层焰核直接命中计数，达到要求后在冷却允许时触发爆发。
## 使用：rules 读取 flame_core_boss_burst；context 携带 target；写入 flame_core_boss_direct_hits 元数据；需由仍存活的宿主创建并调度。
func _apply_flame_core_boss_burst(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("flame_core_boss_burst"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not host._is_boss(target) or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("flame_core_boss_burst", {}))
	var required_stacks: int = maxi(int(rule.get("required_stacks", 5)), 1)
	if int(target.call("get_status_stack", &"flame_core")) < required_stacks:
		return
	var key: String = "flame_core_burst:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if now_seconds < float(_flame_core_burst_cooldowns.get(key, 0.0)):
		return
	var hit_interval: int = maxi(int(rule.get("hit_interval", 4)), 1)
	var hit_count: int = int(target.get_meta("flame_core_boss_direct_hits", 0)) + 1
	target.set_meta("flame_core_boss_direct_hits", hit_count)
	if hit_count % hit_interval != 0:
		return
	if not host._reserve_cooldown(_flame_core_burst_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.flame_core_burst_intents(rules, context, maxi(int(rule.get("amount", 32)), 0)))


## 作用：燃烧满层直接命中满足冷却后消耗规则层数并触发魂燃爆发。
## 使用：rules 读取 soulburn_burst_on_full_burn_direct_hit；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_soulburn_burst(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("soulburn_burst_on_full_burn_direct_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack") or not target.has_method("take_damage"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("soulburn_burst_on_full_burn_direct_hit", {}))
	var burn_stacks: int = int(target.call("get_status_stack", &"burning"))
	if burn_stacks < maxi(int(rule.get("required_burn_stacks", 5)), 1):
		return
	var key: String = "soulburn:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_soulburn_target_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)):
		return
	host._consume_soulburn_burn_stacks(target, rule, burn_stacks)
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	var ratio: float = float(rule.get("normal_max_hp_damage", 0.03))
	if host._is_boss(target):
		ratio = float(rule.get("boss_max_hp_damage", 0.0025))
	elif host._is_elite(target):
		ratio = float(rule.get("elite_max_hp_damage", 0.01))
	var amount: int = maxi(roundi(max_health * ratio), 1)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.soulburn_burst_intents(rules, context, amount))


## 作用：按魂燃规则调用目标公开接口消耗燃烧层数。
## 使用：target 为本次命中目标；rule 读取 consume_burn_stacks；需由仍存活的宿主创建并调度。
func _consume_soulburn_burn_stacks(target: Node, rule: Dictionary, current_burn_stacks: int) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if target == null or not target.has_method("consume_status_stack"):
		return
	var consume_rule: String = String(rule.get("consume_burn_stacks", ""))
	if consume_rule == "all":
		target.call("consume_status_stack", &"burning", current_burn_stacks)
	elif rule.has("consume_burn_stacks"):
		target.call("consume_status_stack", &"burning", maxi(int(rule.get("consume_burn_stacks", 0)), 0))


## 作用：根据命中规则交给特殊伤害服务生成地火或熔岩区域。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _spawn_ground_fire_or_lava(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	SpecialDamageRuleHandlerScript.spawn_ground_fire_or_lava(rules, context, host._get_skill_damage(context))


## 作用：按目标焰核层数给直接命中包增加规则伤害收益。
## 使用：packet 为待修饰伤害包视图；rules 读取 flame_core_on_elite_boss_direct_hit；target 为本次命中目标；会原地更新 packet.direct_damage_multiplier_add；需由仍存活的宿主创建并调度。
func _apply_flame_core_direct_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("flame_core_on_elite_boss_direct_hit", {}))
	if rule.is_empty():
		return
	var stacks: int = int(target.call("get_status_stack", StringName(String(rule.get("status_id", "flame_core")))))
	if stacks <= 0:
		return
	var per_stack: float = float(rule.get("direct_damage_multiplier_add_per_stack", 0.0))
	if per_stack == 0.0:
		return
	packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + per_stack * float(stacks)
