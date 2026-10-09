## 文件用途：按施放、命中、陷阱、击杀与玩家更新事件编排神系特殊规则族。
## 使用方式：动作执行和事件总线提供 context；具体规则由 special_rules 各 family 处理，共享方法承担状态与伤害辅助。
extends RefCounted
class_name SkillSpecialRuleExecutor


const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")
const SkillSpecialRuleSourceScript: Script = preload("res://scripts/skills/special_rules/skill_special_rule_source.gd")
const SpecialRuleCommonScript: Script = preload("res://scripts/skills/special_rules/special_rule_common.gd")



const FireRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/fire_rule_family.gd")
const FrostRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/frost_rule_family.gd")
const LightningRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/lightning_rule_family.gd")
const ArcaneRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/arcane_rule_family.gd")
const HunterRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/hunter_rule_family.gd")
const HolyRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/holy_rule_family.gd")
const ToxicRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/toxic_rule_family.gd")
const OilRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/oil_rule_family.gd")
const AcidRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/acid_rule_family.gd")
const MovementRuleFamilyScript: Script = preload("res://scripts/skills/special_rules/movement_rule_family.gd")

var _fire_rules: RefCounted = FireRuleFamilyScript.new(self)
var _frost_rules: RefCounted = FrostRuleFamilyScript.new(self)
var _lightning_rules: RefCounted = LightningRuleFamilyScript.new(self)
var _arcane_rules: RefCounted = ArcaneRuleFamilyScript.new(self)
var _hunter_rules: RefCounted = HunterRuleFamilyScript.new(self)
var _holy_rules: RefCounted = HolyRuleFamilyScript.new(self)
var _toxic_rules: RefCounted = ToxicRuleFamilyScript.new(self)
var _oil_rules: RefCounted = OilRuleFamilyScript.new(self)
var _acid_rules: RefCounted = AcidRuleFamilyScript.new(self)
var _movement_rules: RefCounted = MovementRuleFamilyScript.new(self)


## 作用：读取技能有效规则后按施放、投射物命中、陷阱或击杀事件分派。
## 使用：event_name 为统一技能事件名；context 携带 skill_instance。
func execute_event(event_name: StringName, context: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return

	match event_name:
		&"on_cast":
			_on_cast(rules, context)
		&"on_projectile_hit":
			_on_projectile_hit(rules, context)
		&"on_trap_hit":
			_on_trap_hit(rules, context)
		&"on_trap_expired":
			_on_trap_expired(rules, context)
		&"on_enemy_killed":
			_on_enemy_killed(rules, context)


## 作用：复制状态参数并按状态 ID 转入对应神系修饰路径，冻结同时更新 Boss 韧性元数据。
## 使用：status_id 为标准状态 ID；context 为施放或命中上下文。
func get_status_params(status_id: StringName, base_params: Dictionary, context: Dictionary) -> Dictionary:
	var params: Dictionary = base_params.duplicate(true)
	match status_id:
		&"chill":
			return params
		&"freeze":
			_apply_boss_poise_upgrade_meta(context)
			return params
		&"charge":
			return params
		&"shock":
			return _get_shock_status_params(params, context)
		&"arcane_mark":
			return params
		&"arcane_seal":
			return _get_arcane_seal_status_params(params, context)
		&"hunter_mark":
			return _get_hunter_mark_status_params(params, context)
		&"holy_mark":
			return _get_holy_mark_status_params(params, context)
		&"wound":
			return _get_wound_status_params(params, context)
		&"bleed":
			return _get_bleed_status_params(params, context)
		&"poison":
			return _get_poison_status_params(params, context)
		&"flammable_mark":
			return _get_flammable_mark_status_params(params, context)
		&"burning":
			return _get_burn_status_params(params, context)
		_:
			return params


## 作用：补齐燃烧强度，并应用火系时长、层数和伤害特殊规则。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _fire_rules._get_burn_status_params，参数与返回语义沿用该族。
func _get_burn_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _fire_rules._get_burn_status_params(params, context)


## 作用：提供火系规则使用的基础燃烧层数上限。
## 使用：转入 _fire_rules._get_burn_base_max_stacks，参数与返回语义沿用该族。
func _get_burn_base_max_stacks() -> int:
	return _fire_rules._get_burn_base_max_stacks()


## 作用：提供火系规则使用的基础燃烧伤害数值。
## 使用：转入 _fire_rules._get_burn_base_damage，参数与返回语义沿用该族。
func _get_burn_base_damage() -> float:
	return _fire_rules._get_burn_base_damage()


## 作用：优先取事件 power，否则由 damage/amount 或基础燃烧值推导非负强度。
## 使用：context 为施放或命中上下文；转入 _fire_rules._get_burning_power_from_context，参数与返回语义沿用该族。
func _get_burning_power_from_context(context: Dictionary) -> float:
	return _fire_rules._get_burning_power_from_context(context)


## 作用：按规则原地修饰伤害视图，先应用通用易伤，再按陷阱或主攻击来源处理。
## 使用：packet 为待修饰伤害包视图；context 携带 target/caster。
func adjust_damage_packet(packet: Dictionary, context: Dictionary) -> Dictionary:
	var adjusted: Dictionary = packet
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return adjusted
	var target: Node = context.get("target") as Node
	var packet_object: RefCounted = DamagePacketScript.from_dictionary(packet, context.get("caster") as Node, target)
	var damage_origin: String = String(packet_object.call("get_value", "damage_origin", ""))
	_apply_global_damage_packet_modifiers(adjusted, rules, target, packet_object)
	if damage_origin == "trap":
		_apply_trap_damage_packet_modifiers(adjusted, rules, target)
		return adjusted
	if damage_origin != "primary_attack":
		return adjusted
	_apply_primary_attack_damage_packet_modifiers(adjusted, rules, context, target, packet_object)
	return adjusted


## 作用：顺序应用易燃标记的火系易伤和酸痕通用易伤。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标。
func _apply_global_damage_packet_modifiers(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_apply_flammable_mark_fire_vulnerability(packet, rules, target, packet_object)
	_apply_acid_mark_vulnerability(packet, rules, target)


## 作用：在陷阱伤害路径应用猎手标记与 Boss 核心相关加成。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _hunter_rules._apply_trap_damage_packet_modifiers，参数与返回语义沿用该族。
func _apply_trap_damage_packet_modifiers(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_trap_damage_packet_modifiers(packet, rules, target)


## 作用：按固定顺序合并各神系目标状态、低血、暴击、重复命中和施放强化修正。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；context 为施放或命中上下文。
func _apply_primary_attack_damage_packet_modifiers(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_apply_flame_core_direct_damage_bonus(packet, rules, target)
	_apply_boss_poise_damage_bonus(packet, rules, target)
	_apply_storm_hail_boss_modifier(packet, rules, context, target)
	_apply_arcane_seal_burst_vulnerability(packet, rules, target)
	_apply_forbidden_page_damage_bonus(packet, rules, context, target)
	_apply_low_hp_damage_bonus(packet, rules, target)
	_apply_same_target_short_window_decay(packet, rules, context, packet_object, target)
	_apply_execution_mark_crit_damage_bonus(packet, rules, target)
	_apply_next_knife_damage_after_kill(packet, rules, context)
	_apply_hunter_arrow_pierce_damage(packet, rules, context, packet_object)
	_apply_hunter_mark_damage_taken(packet, rules, target)
	_apply_holy_mark_holy_vulnerability(packet, rules, target, packet_object)
	_apply_warhammer_low_hp_damage_bonus(packet, rules, target)
	_apply_warhammer_stun_target_damage_taken(packet, rules, target)
	_apply_cross_relic_dot_target_damage_bonus(packet, rules, target, packet_object)
	_apply_same_target_multi_projectile_damage(packet, rules, context, target, packet_object)
	_apply_hot_rapid_fire_crit_bonus(packet, context, packet_object)


## 作用：把本次热连发标记对应的暴击增量加入伤害包。
## 使用：packet 为待修饰伤害包视图；context 为施放或命中上下文；packet_object 为用于读取包字段的伤害对象；转入 _fire_rules._apply_hot_rapid_fire_crit_bonus，参数与返回语义沿用该族。
func _apply_hot_rapid_fire_crit_bonus(packet: Dictionary, context: Dictionary, packet_object: RefCounted) -> void:
	_fire_rules._apply_hot_rapid_fire_crit_bonus(packet, context, packet_object)


## 作用：按施放身份与目标记录连发命中次数，并对第二次起命中应用规则衰减。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_same_target_multi_projectile_damage，参数与返回语义沿用该族。
func _apply_same_target_multi_projectile_damage(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_fire_rules._apply_same_target_multi_projectile_damage(packet, rules, context, target, packet_object)


## 作用：顺序预备圣盾、冰雹、奥术、飞刀、猎弓、战锤、热连发、解毒和酸液施放规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _on_cast(rules: Dictionary, context: Dictionary) -> void:
	_deploy_holy_shield(rules, context)
	_prepare_storm_hail_cast(rules, context)
	_prepare_arcane_double_page_cast(rules, context)
	_prepare_forbidden_page_cast(rules, context)
	_prepare_extra_knife_cast(rules, context)
	_prepare_hunter_bow_cast(rules, context)
	_prepare_warhammer_cast(rules, context)
	_prepare_hot_rapid_fire_cast(rules, context)
	_apply_toxic_vial_antidote_on_cast(rules, context)
	_prepare_acid_pressure_cast(rules, context)
	SpecialDamageRuleHandlerScript.execute_lightning_orbit_before_launch(rules, context, _get_skill_damage(context))


## 作用：按火球施放次数间隔预留下一发热连发与暴击加成。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._prepare_hot_rapid_fire_cast，参数与返回语义沿用该族。
func _prepare_hot_rapid_fire_cast(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._prepare_hot_rapid_fire_cast(rules, context)


## 作用：按冰雹施放计数预留周期强化标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._prepare_storm_hail_cast，参数与返回语义沿用该族。
func _prepare_storm_hail_cast(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._prepare_storm_hail_cast(rules, context)


## 作用：按施法计数预留奥术双页强化及额外弹体数量。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._prepare_arcane_double_page_cast，参数与返回语义沿用该族。
func _prepare_arcane_double_page_cast(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._prepare_arcane_double_page_cast(rules, context)


## 作用：按施法计数预留下一次禁页标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._prepare_forbidden_page_cast，参数与返回语义沿用该族。
func _prepare_forbidden_page_cast(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._prepare_forbidden_page_cast(rules, context)


## 作用：按周期施放计数触发额外飞刀投射。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._prepare_extra_knife_cast，参数与返回语义沿用该族。
func _prepare_extra_knife_cast(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._prepare_extra_knife_cast(rules, context)


## 作用：更新风步属性并预备风步双箭与周期云箭标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._prepare_hunter_bow_cast，参数与返回语义沿用该族。
func _prepare_hunter_bow_cast(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._prepare_hunter_bow_cast(rules, context)


## 作用：按战锤施放计数和秒数预留震地及强制震击标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _holy_rules._prepare_warhammer_cast，参数与返回语义沿用该族。
func _prepare_warhammer_cast(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._prepare_warhammer_cast(rules, context)


## 作用：递增技能元数据中的周期施放计数并返回新值。
## 使用：skill_instance 为技能运行实例。
func _advance_interval_counter(skill_instance: RefCounted, meta_key: String) -> int:
	var count: int = int(skill_instance.get_meta(meta_key, 0)) + 1
	skill_instance.set_meta(meta_key, count)
	return count


## 作用：检查指定冷却键，到期立即写入下次可触发时间并返回 true。
## 使用：cooldowns 为可修改的冷却表；now_seconds 为当前单调计时秒数；cooldown_seconds 为预留冷却秒数；返回布尔判断或执行是否成功。
func _reserve_cooldown(cooldowns: Dictionary, key: String, now_seconds: float, cooldown_seconds: float) -> bool:
	if now_seconds < float(cooldowns.get(key, 0.0)):
		return false
	cooldowns[key] = now_seconds + cooldown_seconds
	return true


## 作用：按族顺序处理投射物命中及区域 tick 规则，最后检查地火或熔岩生成。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _on_projectile_hit(rules: Dictionary, context: Dictionary) -> void:
	_apply_fire_projectile_hit_rules(rules, context)
	_apply_frost_projectile_hit_rules(rules, context)
	_apply_fire_reaction_hit_rules(rules, context)
	_apply_frost_reaction_hit_rules(rules, context)
	_apply_lightning_projectile_hit_rules(rules, context)
	_apply_arcane_projectile_hit_rules(rules, context)
	_apply_hunter_projectile_hit_rules(rules, context)
	_apply_warhammer_on_hit(rules, context)
	_apply_projectile_field_tick_rules(rules, context)
	_spawn_ground_fire_or_lava(rules, context)


## 作用：顺序执行额外爆炸、燃烧、魂烬与焰核直接命中规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_fire_projectile_hit_rules，参数与返回语义沿用该族。
func _apply_fire_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_fire_projectile_hit_rules(rules, context)


## 作用：依次执行冰锁、冰锁额外命中、冻伤和碎裂规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_frost_projectile_hit_rules，参数与返回语义沿用该族。
func _apply_frost_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_projectile_hit_rules(rules, context)


## 作用：在火系命中阶段处理魂燃和 Boss 焰核爆发。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_fire_reaction_hit_rules，参数与返回语义沿用该族。
func _apply_fire_reaction_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_fire_reaction_hit_rules(rules, context)


## 作用：对 Boss 韧性破坏事件检查冰核裂解触发。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_frost_reaction_hit_rules，参数与返回语义沿用该族。
func _apply_frost_reaction_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_reaction_hit_rules(rules, context)


## 作用：依次执行闪电弹跳、电压、过载、感电与感电消耗反应。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _lightning_rules._apply_lightning_projectile_hit_rules，参数与返回语义沿用该族。
func _apply_lightning_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_lightning_projectile_hit_rules(rules, context)


## 作用：顺序处理奥术复制、强敌封印、封印爆发和禁页命中规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._apply_arcane_projectile_hit_rules，参数与返回语义沿用该族。
func _apply_arcane_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_arcane_projectile_hit_rules(rules, context)


## 作用：按既定顺序执行飞刀标记、创伤回收与弓箭爆炸分裂等命中规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_hunter_projectile_hit_rules，参数与返回语义沿用该族。
func _apply_hunter_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_projectile_hit_rules(rules, context)


## 作用：将以投射物事件表示的区域 tick 转入圣、酸、火油和毒瓶规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _apply_projectile_field_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_cross_relic_on_field_tick(rules, context)
	_apply_toxic_vial_on_field_tick(rules, context)
	_apply_fire_oil_on_field_tick(rules, context)
	_apply_acid_spray_on_field_tick(rules, context)


## 作用：依次执行猎手陷阱标记、伤害和控制规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._on_trap_hit，参数与返回语义沿用该族。
func _on_trap_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._on_trap_hit(rules, context)


## 作用：在陷阱命中时处理强敌猎物标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_hunter_trap_hit_rules，参数与返回语义沿用该族。
func _apply_hunter_trap_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_trap_hit_rules(rules, context)


## 作用：在陷阱命中时顺序处理 Boss 核心增伤、爆炸及小陷阱。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_trap_damage_hit_rules，参数与返回语义沿用该族。
func _apply_trap_damage_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_trap_damage_hit_rules(rules, context)


## 作用：在陷阱命中时处理锁链定身及钳击反应。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_trap_control_hit_rules，参数与返回语义沿用该族。
func _apply_trap_control_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_trap_control_hit_rules(rules, context)


## 作用：陷阱到期时处理火油烟云和诱饵陷阱爆炸。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._on_trap_expired，参数与返回语义沿用该族。
func _on_trap_expired(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._on_trap_expired(rules, context)


## 作用：依据诱饵到期爆炸规则转入特殊伤害服务。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._execute_decoy_trap_expired，参数与返回语义沿用该族。
func _execute_decoy_trap_expired(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._execute_decoy_trap_expired(rules, context)


## 作用：顺序处理元素死亡规则、猎手击杀规则和毒系死亡规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _on_enemy_killed(rules: Dictionary, context: Dictionary) -> void:
	_apply_elemental_enemy_kill_rules(rules, context)
	_apply_hunter_enemy_kill_rules(rules, context)
	_apply_toxic_enemy_kill_rules(rules, context)


## 作用：根据死亡目标来源与规则执行燃烧爆炸或粉碎后冰锥生成。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _apply_elemental_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	SpecialDamageRuleHandlerScript.execute_burning_target_death_explosion(rules, context)
	SpecialDamageRuleHandlerScript.execute_shatter_kill_spawn_icicle(rules, context)


## 作用：击杀时更新下一刀增伤、普通怪飞刀回收、标记爆炸及陷阱碎片领域。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_hunter_enemy_kill_rules，参数与返回语义沿用该族。
func _apply_hunter_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_enemy_kill_rules(rules, context)


## 作用：按毒系死亡规则生成毒云或毒死亡爆炸。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _toxic_rules._apply_toxic_enemy_kill_rules，参数与返回语义沿用该族。
func _apply_toxic_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	_toxic_rules._apply_toxic_enemy_kill_rules(rules, context)


## 作用：针对拥有技能逐帧更新防御、控制和领域规则状态。
## 使用：context 为施放或命中上下文。
func execute_player_tick(context: Dictionary) -> void:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return
	_update_player_defensive_tick_rules(rules, context)
	_update_player_control_tick_rules(rules, context)
	_update_player_field_tick_rules(rules, context)


## 作用：更新圣盾及腐蚀薄膜等持续防御规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _update_player_defensive_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_update_holy_shield(rules, context)


## 作用：更新玩家周围冰霜减速、冻伤冻结及猎弓风步状态。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _update_player_control_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_frost_aura_slow(rules, context)
	_apply_freeze_frostbite_near_player(rules, context)
	_apply_page_spirit_spawn(rules, context)
	_update_windstep_state(rules, context)
	_apply_decoy_trap_spawn(rules, context)


## 作用：更新十字领域、火油烟云和毒云玩家增益状态。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _update_player_field_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_update_cross_relic_field(rules, context)
	_update_toxic_vial_player_cloud(rules, context)
	_update_fire_oil_smoke_player_buff(rules, context)
	_update_corrosive_film(rules, context)


## 作用：按玩家受击事件执行圣盾、熔岩环、冰环、烟云及腐蚀薄膜规则。
## 使用：context 为施放或命中上下文。
func execute_player_damaged(context: Dictionary) -> void:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return
	SpecialDamageRuleHandlerScript.execute_holy_shield_player_damaged(rules, context)
	_apply_smoke_cloud_on_player_damaged(rules, context)
	_apply_corrosive_film_on_boss_skill_hit(rules, context)


## 作用：按圣盾规则创建盾值、持续时间及脉冲元数据，并同步玩家接触减伤。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _holy_rules._deploy_holy_shield，参数与返回语义沿用该族。
func _deploy_holy_shield(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._deploy_holy_shield(rules, context)


## 作用：推进圣盾有效期与脉冲计数，按规则执行脉冲或到期处理。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _holy_rules._update_holy_shield，参数与返回语义沿用该族。
func _update_holy_shield(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._update_holy_shield(rules, context)


## 作用：合并基础圣盾与脉冲间隔规则，计算下一次脉冲间隔。
## 使用：rules 为当前技能有效规则；转入 _holy_rules._holy_shield_pulse_interval，参数与返回语义沿用该族。
func _holy_shield_pulse_interval(rules: Dictionary) -> float:
	return _holy_rules._holy_shield_pulse_interval(rules)


## 作用：将圣盾接触减伤及有效截止时间同步到玩家元数据。
## 使用：caster 为施法者节点；rules 为当前技能有效规则；转入 _holy_rules._apply_holy_shield_player_meta，参数与返回语义沿用该族。
func _apply_holy_shield_player_meta(caster: Node, rules: Dictionary, until_time: float) -> void:
	_holy_rules._apply_holy_shield_player_meta(caster, rules, until_time)


## 作用：清空玩家圣盾接触减伤值和有效时间。
## 使用：caster 为施法者节点；转入 _holy_rules._clear_holy_shield_player_meta，参数与返回语义沿用该族。
func _clear_holy_shield_player_meta(caster: Node) -> void:
	_holy_rules._clear_holy_shield_player_meta(caster)


## 作用：构建直接命中额外爆炸意图，并通过标准意图应用入口执行。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文。
func _apply_direct_hit_extra_explosion_bonus(rules: Dictionary, context: Dictionary) -> void:
	var base_damage: int = _get_skill_damage(context)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.direct_hit_extra_explosion_intents(rules, context, base_damage))


## 作用：将爆炸命中按强敌直接命中或普通多目标情况分别处理燃烧。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_explosion_burn_rules，参数与返回语义沿用该族。
func _apply_explosion_burn_rules(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_explosion_burn_rules(rules, context)


## 作用：对精英或 Boss 的爆炸直接命中按同目标冷却施加燃烧。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _fire_rules._apply_explosion_direct_hit_burn，参数与返回语义沿用该族。
func _apply_explosion_direct_hit_burn(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_fire_rules._apply_explosion_direct_hit_burn(rules, context, target)


## 作用：普通目标在爆炸命中人数达到门槛时额外施加燃烧。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _fire_rules._apply_explosion_multi_hit_burn，参数与返回语义沿用该族。
func _apply_explosion_multi_hit_burn(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_fire_rules._apply_explosion_multi_hit_burn(rules, context, target)


## 作用：魂烬达到满层命中条件后消耗魂烬并转换为燃烧。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_soul_ember_to_burn，参数与返回语义沿用该族。
func _apply_soul_ember_to_burn(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_soul_ember_to_burn(rules, context)


## 作用：直接命中时按来源冷却为目标累积魂烬。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_soul_ember_on_direct_hit，参数与返回语义沿用该族。
func _apply_soul_ember_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_soul_ember_on_direct_hit(rules, context)


## 作用：对强敌直接命中施加焰核，并配置满层爆炸易伤与持续时间。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_flame_core_on_direct_hit，参数与返回语义沿用该族。
func _apply_flame_core_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_flame_core_on_direct_hit(rules, context)


## 作用：记录 Boss 满层焰核直接命中计数，达到要求后在冷却允许时触发爆发。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_flame_core_boss_burst，参数与返回语义沿用该族。
func _apply_flame_core_boss_burst(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_flame_core_boss_burst(rules, context)


## 作用：强敌直接命中在同来源冷却允许时施加冰锁。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_frost_lock_on_direct_hit，参数与返回语义沿用该族。
func _apply_frost_lock_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_lock_on_direct_hit(rules, context)


## 作用：按冰锁层数门槛与冷却触发额外命中，并消耗对应状态。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_frost_lock_bonus_hit，参数与返回语义沿用该族。
func _apply_frost_lock_bonus_hit(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_lock_bonus_hit(rules, context)


## 作用：冰雹命中在冷却允许时给目标累积冻伤。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_frostbite_on_hail_hit，参数与返回语义沿用该族。
func _apply_frostbite_on_hail_hit(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frostbite_on_hail_hit(rules, context)


## 作用：冻伤达到门槛后消耗层数，对普通敌人冻结，对 Boss 转入韧性处理。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_frostbite_freeze_or_poise，参数与返回语义沿用该族。
func _apply_frostbite_freeze_or_poise(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frostbite_freeze_or_poise(rules, context)


## 作用：识别尚未消费的 Boss 韧性破坏计数，在冷却允许时触发冰核裂解。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_frost_core_crack_on_boss_poise，参数与返回语义沿用该族。
func _apply_frost_core_crack_on_boss_poise(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_core_crack_on_boss_poise(rules, context)


## 作用：按冻结或冰系命中条件与冷却触发粉碎区域。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_shatter_on_freeze_or_frost_hit，参数与返回语义沿用该族。
func _apply_shatter_on_freeze_or_frost_hit(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_shatter_on_freeze_or_frost_hit(rules, context)


## 作用：燃烧满层直接命中满足冷却后消耗规则层数并触发魂燃爆发。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._apply_soulburn_burst，参数与返回语义沿用该族。
func _apply_soulburn_burst(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_soulburn_burst(rules, context)


## 作用：按魂燃规则调用目标公开接口消耗燃烧层数。
## 使用：target 为本次命中目标；rule 为单项规则配置；转入 _fire_rules._consume_soulburn_burn_stacks，参数与返回语义沿用该族。
func _consume_soulburn_burn_stacks(target: Node, rule: Dictionary, current_burn_stacks: int) -> void:
	_fire_rules._consume_soulburn_burn_stacks(target, rule, current_burn_stacks)


## 作用：根据命中规则交给特殊伤害服务生成地火或熔岩区域。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _fire_rules._spawn_ground_fire_or_lava，参数与返回语义沿用该族。
func _spawn_ground_fire_or_lava(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._spawn_ground_fire_or_lava(rules, context)


## 作用：按连锁弹跳规则派生额外闪电命中。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _lightning_rules._apply_lightning_chain_bounce，参数与返回语义沿用该族。
func _apply_lightning_chain_bounce(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_lightning_chain_bounce(rules, context)


## 作用：强敌命中在同来源冷却允许时累积电压层数。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _lightning_rules._apply_voltage_on_elite_boss_hit，参数与返回语义沿用该族。
func _apply_voltage_on_elite_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_voltage_on_elite_boss_hit(rules, context)


## 作用：电压满足门槛后消耗层数并触发过载伤害与感电相关效果。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _lightning_rules._apply_overload_on_voltage，参数与返回语义沿用该族。
func _apply_overload_on_voltage(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_overload_on_voltage(rules, context)


## 作用：过载与感电条件满足且冷却允许时生成衍生闪电伤害。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _lightning_rules._apply_overload_shock_lightning，参数与返回语义沿用该族。
func _apply_overload_shock_lightning(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_overload_shock_lightning(rules, context)


## 作用：闪电球命中在冷却允许时施加感电，包含感电升级修正。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _lightning_rules._apply_shock_on_lightning_orb_hit，参数与返回语义沿用该族。
func _apply_shock_on_lightning_orb_hit(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_shock_on_lightning_orb_hit(rules, context)


## 作用：目标带感电时处理消耗反应、触发计数与磁暴追加效果。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _lightning_rules._apply_shock_consume_reaction，参数与返回语义沿用该族。
func _apply_shock_consume_reaction(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_shock_consume_reaction(rules, context)


## 作用：按奥术页命中配置创建复制弹体。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._apply_arcane_page_copy，参数与返回语义沿用该族。
func _apply_arcane_page_copy(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_arcane_page_copy(rules, context)


## 作用：在强敌命中与来源冷却允许时施加奥术封印。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._apply_arcane_seal_on_elite_boss_hit，参数与返回语义沿用该族。
func _apply_arcane_seal_on_elite_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_arcane_seal_on_elite_boss_hit(rules, context)


## 作用：达到封印门槛后消耗封印并造成爆发，可登记限时主攻击易伤。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._apply_arcane_seal_burst，参数与返回语义沿用该族。
func _apply_arcane_seal_burst(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_arcane_seal_burst(rules, context)


## 作用：处理禁页命中收益与风险，并累积 Boss 禁页叠层。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._apply_forbidden_page_hit，参数与返回语义沿用该族。
func _apply_forbidden_page_hit(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_forbidden_page_hit(rules, context)


## 作用：按规则创建纸灵并接入周期效果。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._apply_page_spirit_spawn，参数与返回语义沿用该族。
func _apply_page_spirit_spawn(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_page_spirit_spawn(rules, context)


## 作用：对强敌命中写入飞刀处决标记供暴击收益使用。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_execution_mark_on_strong_target，参数与返回语义沿用该族。
func _apply_execution_mark_on_strong_target(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_execution_mark_on_strong_target(rules, context)


## 作用：Boss 血量低于规则门槛且冷却允许时触发处决爆发。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_boss_low_hp_execution_burst，参数与返回语义沿用该族。
func _apply_boss_low_hp_execution_burst(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_boss_low_hp_execution_burst(rules, context)


## 作用：飞刀命中在冷却允许时按创伤调整规则施加 wound。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_wound_on_throwing_knife_hit，参数与返回语义沿用该族。
func _apply_wound_on_throwing_knife_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_wound_on_throwing_knife_hit(rules, context)


## 作用：暴击命中带创伤目标时按冷却施加流血。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_bleed_on_crit_wound，参数与返回语义沿用该族。
func _apply_bleed_on_crit_wound(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_bleed_on_crit_wound(rules, context)


## 作用：目标满创伤暴击命中在冷却允许时触发撕裂伤害。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_rupture_on_full_wound_crit，参数与返回语义沿用该族。
func _apply_rupture_on_full_wound_crit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_rupture_on_full_wound_crit(rules, context)


## 作用：累计 Boss 飞刀命中计数，达到门槛后授予回收冲刺增益。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_recycle_boss_hit，参数与返回语义沿用该族。
func _apply_recycle_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_recycle_boss_hit(rules, context)


## 作用：击杀后记录下一次飞刀额外伤害的待消费数值。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_next_knife_kill_bonus，参数与返回语义沿用该族。
func _apply_next_knife_kill_bonus(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_next_knife_kill_bonus(rules, context)


## 作用：普通怪击杀满足回收规则时生成回收飞刀。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_recycle_knife_on_normal_kill，参数与返回语义沿用该族。
func _apply_recycle_knife_on_normal_kill(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_recycle_knife_on_normal_kill(rules, context)


## 作用：强敌箭命中时按规则清理或累积鹰眼标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_eagle_mark_on_strong_hit，参数与返回语义沿用该族。
func _apply_eagle_mark_on_strong_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_eagle_mark_on_strong_hit(rules, context)


## 作用：弓箭命中时按规则生成命中爆炸。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_hunter_arrow_hit_explosion，参数与返回语义沿用该族。
func _apply_hunter_arrow_hit_explosion(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_arrow_hit_explosion(rules, context)


## 作用：穿透命中次数满足条件且未生成过时，生成弓箭碎片。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_hunter_arrow_shards，参数与返回语义沿用该族。
func _apply_hunter_arrow_shards(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_arrow_shards(rules, context)


## 作用：箭命中带标记目标且冷却允许时返还技能冷却。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_marked_hit_cooldown_refund，参数与返回语义沿用该族。
func _apply_marked_hit_cooldown_refund(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_marked_hit_cooldown_refund(rules, context)


## 作用：累计 Boss 标记命中条件并触发鹰击额外伤害。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_eagle_shot_on_boss_mark_hits，参数与返回语义沿用该族。
func _apply_eagle_shot_on_boss_mark_hits(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_eagle_shot_on_boss_mark_hits(rules, context)


## 作用：带指定标记目标死亡在来源冷却允许时触发死亡爆炸。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_marked_target_death_explosion，参数与返回语义沿用该族。
func _apply_marked_target_death_explosion(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_marked_target_death_explosion(rules, context)


## 作用：陷阱触发后按规则生成小型派生陷阱。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_small_trap_on_trigger，参数与返回语义沿用该族。
func _apply_small_trap_on_trigger(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_small_trap_on_trigger(rules, context)


## 作用：锁链陷阱命中时施加定身状态。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_chain_trap_root_on_hit，参数与返回语义沿用该族。
func _apply_chain_trap_root_on_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_chain_trap_root_on_hit(rules, context)


## 作用：命中带定身目标且冷却允许时触发钳击反应。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_pincer_reaction_on_root，参数与返回语义沿用该族。
func _apply_pincer_reaction_on_root(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_pincer_reaction_on_root(rules, context)


## 作用：陷阱命中强敌时施加猎物标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_prey_mark_on_strong_trap_hit，参数与返回语义沿用该族。
func _apply_prey_mark_on_strong_trap_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_prey_mark_on_strong_trap_hit(rules, context)


## 作用：Boss 核心陷阱命中在冷却允许时触发额外伤害。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_boss_core_trap_bonus_damage，参数与返回语义沿用该族。
func _apply_boss_core_trap_bonus_damage(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_boss_core_trap_bonus_damage(rules, context)


## 作用：陷阱命中时按规则生成爆炸区域。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_trap_hit_explosion，参数与返回语义沿用该族。
func _apply_trap_hit_explosion(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_trap_hit_explosion(rules, context)


## 作用：陷阱击杀时生成碎片伤害领域。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_trap_kill_fragment_field，参数与返回语义沿用该族。
func _apply_trap_kill_fragment_field(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_trap_kill_fragment_field(rules, context)


## 作用：规则冷却允许时创建诱饵陷阱。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_decoy_trap_spawn，参数与返回语义沿用该族。
func _apply_decoy_trap_spawn(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_decoy_trap_spawn(rules, context)


## 作用：按目标焰核层数给直接命中包增加规则伤害收益。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _fire_rules._apply_flame_core_direct_damage_bonus，参数与返回语义沿用该族。
func _apply_flame_core_direct_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_fire_rules._apply_flame_core_direct_damage_bonus(packet, rules, target)


## 作用：按圣印调整规则补充状态层数与时长参数。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _holy_rules._get_holy_mark_status_params，参数与返回语义沿用该族。
func _get_holy_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _holy_rules._get_holy_mark_status_params(params, context)


## 作用：按感电升级规则修饰状态参数。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _lightning_rules._get_shock_status_params，参数与返回语义沿用该族。
func _get_shock_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _lightning_rules._get_shock_status_params(params, context)


## 作用：根据奥术封印时长规则修饰状态参数。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _arcane_rules._get_arcane_seal_status_params，参数与返回语义沿用该族。
func _get_arcane_seal_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _arcane_rules._get_arcane_seal_status_params(params, context)


## 作用：按猎手标记调整规则修饰状态参数。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _hunter_rules._get_hunter_mark_status_params，参数与返回语义沿用该族。
func _get_hunter_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _hunter_rules._get_hunter_mark_status_params(params, context)


## 作用：按创伤调整规则修饰状态参数。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _hunter_rules._get_wound_status_params，参数与返回语义沿用该族。
func _get_wound_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _hunter_rules._get_wound_status_params(params, context)


## 作用：根据目标移动状态和流血规则修饰流血参数。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _hunter_rules._get_bleed_status_params，参数与返回语义沿用该族。
func _get_bleed_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _hunter_rules._get_bleed_status_params(params, context)


## 作用：把 Boss 韧性升级的持续时间修正写入目标元数据。
## 使用：context 为施放或命中上下文；转入 _frost_rules._apply_boss_poise_upgrade_meta，参数与返回语义沿用该族。
func _apply_boss_poise_upgrade_meta(context: Dictionary) -> void:
	_frost_rules._apply_boss_poise_upgrade_meta(context)


## 作用：按 Boss 当前韧性状态给伤害包应用增伤规则。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _frost_rules._apply_boss_poise_damage_bonus，参数与返回语义沿用该族。
func _apply_boss_poise_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_frost_rules._apply_boss_poise_damage_bonus(packet, rules, target)


## 作用：根据冰雹本次周期强化标记应用 Boss 专属伤害系数。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_storm_hail_boss_modifier，参数与返回语义沿用该族。
func _apply_storm_hail_boss_modifier(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node) -> void:
	_frost_rules._apply_storm_hail_boss_modifier(packet, rules, context, target)


## 作用：将目标尚未过期的封印爆发易伤应用到伤害包。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _arcane_rules._apply_arcane_seal_burst_vulnerability，参数与返回语义沿用该族。
func _apply_arcane_seal_burst_vulnerability(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_arcane_rules._apply_arcane_seal_burst_vulnerability(packet, rules, target)


## 作用：根据禁页施放标记、风险和 Boss 叠层修饰直接命中伤害。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；context 为施放或命中上下文；转入 _arcane_rules._apply_forbidden_page_damage_bonus，参数与返回语义沿用该族。
func _apply_forbidden_page_damage_bonus(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node) -> void:
	_arcane_rules._apply_forbidden_page_damage_bonus(packet, rules, context, target)


## 作用：按目标血量条件给伤害包追加低血伤害收益。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _hunter_rules._apply_low_hp_damage_bonus，参数与返回语义沿用该族。
func _apply_low_hp_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_low_hp_damage_bonus(packet, rules, target)


## 作用：按来源和目标维护短时间命中记录，对重复命中应用衰减。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_same_target_short_window_decay，参数与返回语义沿用该族。
func _apply_same_target_short_window_decay(packet: Dictionary, rules: Dictionary, context: Dictionary, packet_object: RefCounted, target: Node) -> void:
	_hunter_rules._apply_same_target_short_window_decay(packet, rules, context, packet_object, target)


## 作用：目标具有处决标记时修改暴击伤害相关字段。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _hunter_rules._apply_execution_mark_crit_damage_bonus，参数与返回语义沿用该族。
func _apply_execution_mark_crit_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_execution_mark_crit_damage_bonus(packet, rules, target)


## 作用：将击杀预留的下一刀增量加入伤害包并消费预留标记。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_next_knife_damage_after_kill，参数与返回语义沿用该族。
func _apply_next_knife_damage_after_kill(packet: Dictionary, rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_next_knife_damage_after_kill(packet, rules, context)


## 作用：按箭命中序号与云箭标记修改本次穿透伤害系数。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；context 为施放或命中上下文；转入 _hunter_rules._apply_hunter_arrow_pierce_damage，参数与返回语义沿用该族。
func _apply_hunter_arrow_pierce_damage(packet: Dictionary, rules: Dictionary, context: Dictionary, packet_object: RefCounted) -> void:
	_hunter_rules._apply_hunter_arrow_pierce_damage(packet, rules, context, packet_object)


## 作用：带猎手或鹰眼标记的目标受到主攻击时应用规则易伤。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _hunter_rules._apply_hunter_mark_damage_taken，参数与返回语义沿用该族。
func _apply_hunter_mark_damage_taken(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_hunter_mark_damage_taken(packet, rules, target)


## 作用：目标带圣印且伤害符合圣系条件时修改伤害包易伤。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _holy_rules._apply_holy_mark_holy_vulnerability，参数与返回语义沿用该族。
func _apply_holy_mark_holy_vulnerability(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_holy_rules._apply_holy_mark_holy_vulnerability(packet, rules, target, packet_object)


## 作用：按目标低血门槛修改战锤直接伤害。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _hunter_rules._apply_warhammer_low_hp_damage_bonus，参数与返回语义沿用该族。
func _apply_warhammer_low_hp_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_warhammer_low_hp_damage_bonus(packet, rules, target)


## 作用：目标处于战锤眩晕条件时应用承伤加成。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _holy_rules._apply_warhammer_stun_target_damage_taken，参数与返回语义沿用该族。
func _apply_warhammer_stun_target_damage_taken(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_stun_target_damage_taken(packet, rules, target)


## 作用：根据目标持续伤害或杂质状态应用十字领域直接伤害收益。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _holy_rules._apply_cross_relic_dot_target_damage_bonus，参数与返回语义沿用该族。
func _apply_cross_relic_dot_target_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_holy_rules._apply_cross_relic_dot_target_damage_bonus(packet, rules, target, packet_object)


## 作用：十字领域命中 tick 时转入杂质施加规则。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _holy_rules._apply_cross_relic_on_field_tick，参数与返回语义沿用该族。
func _apply_cross_relic_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._apply_cross_relic_on_field_tick(rules, context)


## 作用：按十字领域杂质规则给命中目标施加状态。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _holy_rules._apply_cross_relic_impurity_on_field_tick，参数与返回语义沿用该族。
func _apply_cross_relic_impurity_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._apply_cross_relic_impurity_on_field_tick(rules, context)


## 作用：按酸液周期施放计数预留下一发压力强化标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _acid_rules._prepare_acid_pressure_cast，参数与返回语义沿用该族。
func _prepare_acid_pressure_cast(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._prepare_acid_pressure_cast(rules, context)


## 作用：在酸液喷射区域 tick 时依次处理酸痕、残留、护盾和满层爆发。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _acid_rules._apply_acid_spray_on_field_tick，参数与返回语义沿用该族。
func _apply_acid_spray_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._apply_acid_spray_on_field_tick(rules, context)


## 作用：在酸液 tick 命中强敌时施加酸痕状态。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _acid_rules._apply_acid_mark_on_strong_tick，参数与返回语义沿用该族。
func _apply_acid_mark_on_strong_tick(rules: Dictionary, target: Node) -> void:
	_acid_rules._apply_acid_mark_on_strong_tick(rules, target)


## 作用：按酸液区域规则为命中目标施加残留层数。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _acid_rules._apply_acid_residue_on_tick，参数与返回语义沿用该族。
func _apply_acid_residue_on_tick(rules: Dictionary, target: Node) -> void:
	_acid_rules._apply_acid_residue_on_tick(rules, target)


## 作用：检查酸痕或残留满层条件及同目标冷却，触发对应酸爆。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _acid_rules._apply_acid_burst_on_full_status，参数与返回语义沿用该族。
func _apply_acid_burst_on_full_status(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_acid_rules._apply_acid_burst_on_full_status(rules, context, target)


## 作用：累计酸液命中次数，达到规则门槛后授予腐蚀薄膜护盾。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _acid_rules._apply_acid_hit_shield，参数与返回语义沿用该族。
func _apply_acid_hit_shield(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._apply_acid_hit_shield(rules, context)


## 作用：按 Boss 酸痕层数触发限时降甲，并保存降甲数值和截止时间。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _acid_rules._apply_boss_acid_mark_armor_break_pulse，参数与返回语义沿用该族。
func _apply_boss_acid_mark_armor_break_pulse(rules: Dictionary, target: Node) -> void:
	_acid_rules._apply_boss_acid_mark_armor_break_pulse(rules, target)


## 作用：更新腐蚀薄膜护盾状态，并按附近酸痕目标触发周期腐蚀。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _acid_rules._update_corrosive_film，参数与返回语义沿用该族。
func _update_corrosive_film(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._update_corrosive_film(rules, context)


## 作用：玩家被 Boss 来源技能击中时按冷却限制触发腐蚀薄膜效果。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _acid_rules._apply_corrosive_film_on_boss_skill_hit，参数与返回语义沿用该族。
func _apply_corrosive_film_on_boss_skill_hit(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._apply_corrosive_film_on_boss_skill_hit(rules, context)


## 作用：按目标酸痕与规则修改伤害包易伤系数。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _acid_rules._apply_acid_mark_vulnerability，参数与返回语义沿用该族。
func _apply_acid_mark_vulnerability(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_acid_rules._apply_acid_mark_vulnerability(packet, rules, target)


## 作用：检查玩家受击来源是否具有 Boss 身份。
## 使用：context 为施放或命中上下文；转入 _acid_rules._is_boss_damage_source，参数与返回语义沿用该族。
func _is_boss_damage_source(context: Dictionary) -> bool:
	return _acid_rules._is_boss_damage_source(context)


## 作用：火油区域 tick 时按区域类型处理烟云、燃烧、易燃标记、油层与爆燃。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _oil_rules._apply_fire_oil_on_field_tick，参数与返回语义沿用该族。
func _apply_fire_oil_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_oil_rules._apply_fire_oil_on_field_tick(rules, context)


## 作用：合并油区命中在冷却允许时施加燃烧。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _oil_rules._apply_burn_in_merged_oil，参数与返回语义沿用该族。
func _apply_burn_in_merged_oil(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_oil_rules._apply_burn_in_merged_oil(rules, context, target)


## 作用：油区 tick 命中强敌时施加易燃标记并应用 Boss 调整。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _oil_rules._apply_flammable_mark_on_oil_tick，参数与返回语义沿用该族。
func _apply_flammable_mark_on_oil_tick(rules: Dictionary, target: Node) -> void:
	_oil_rules._apply_flammable_mark_on_oil_tick(rules, target)


## 作用：油区 tick 时为命中目标累积油层。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _oil_rules._apply_oil_stack_on_fire_oil_tick，参数与返回语义沿用该族。
func _apply_oil_stack_on_fire_oil_tick(rules: Dictionary, target: Node) -> void:
	_oil_rules._apply_oil_stack_on_fire_oil_tick(rules, target)


## 作用：目标油层满足门槛且冷却允许时触发火油爆燃并记录来源冷却。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _oil_rules._apply_fire_oil_deflagration，参数与返回语义沿用该族。
func _apply_fire_oil_deflagration(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_oil_rules._apply_fire_oil_deflagration(rules, context, target)


## 作用：易燃标记满层 tick 满足冷却后触发爆发，并可影响 Boss 韧性。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _oil_rules._apply_flammable_mark_burst，参数与返回语义沿用该族。
func _apply_flammable_mark_burst(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_oil_rules._apply_flammable_mark_burst(rules, context, target)


## 作用：给烟云内目标刷新限时伤害降低属性元数据。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _oil_rules._apply_smoke_cloud_target_effects，参数与返回语义沿用该族。
func _apply_smoke_cloud_target_effects(rules: Dictionary, target: Node) -> void:
	_oil_rules._apply_smoke_cloud_target_effects(rules, target)


## 作用：油区到期按配置生成烟云。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _oil_rules._apply_smoke_cloud_on_oil_expire，参数与返回语义沿用该族。
func _apply_smoke_cloud_on_oil_expire(rules: Dictionary, context: Dictionary) -> void:
	_oil_rules._apply_smoke_cloud_on_oil_expire(rules, context)


## 作用：玩家受伤在规则冷却允许时生成保护烟云。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _oil_rules._apply_smoke_cloud_on_player_damaged，参数与返回语义沿用该族。
func _apply_smoke_cloud_on_player_damaged(rules: Dictionary, context: Dictionary) -> void:
	_oil_rules._apply_smoke_cloud_on_player_damaged(rules, context)


## 作用：根据玩家是否处于烟云增益窗口设置或移除火油移速属性来源。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _oil_rules._update_fire_oil_smoke_player_buff，参数与返回语义沿用该族。
func _update_fire_oil_smoke_player_buff(rules: Dictionary, context: Dictionary) -> void:
	_oil_rules._update_fire_oil_smoke_player_buff(rules, context)


## 作用：火系伤害命中带易燃标记目标时按层数修改易伤。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _oil_rules._apply_flammable_mark_fire_vulnerability，参数与返回语义沿用该族。
func _apply_flammable_mark_fire_vulnerability(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_oil_rules._apply_flammable_mark_fire_vulnerability(packet, rules, target, packet_object)


## 作用：易燃标记爆发对 Boss 在冷却允许时施加韧性效果。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _oil_rules._apply_flammable_burst_boss_poise，参数与返回语义沿用该族。
func _apply_flammable_burst_boss_poise(rules: Dictionary, target: Node) -> void:
	_oil_rules._apply_flammable_burst_boss_poise(rules, target)


## 作用：按 Boss 专用易燃标记规则修饰状态参数。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _oil_rules._get_flammable_mark_status_params，参数与返回语义沿用该族。
func _get_flammable_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _oil_rules._get_flammable_mark_status_params(params, context)


## 作用：毒瓶区域 tick 时依次施加毒种、毒核、中毒和稳定场效果并检查 Boss 脉冲。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _toxic_rules._apply_toxic_vial_on_field_tick，参数与返回语义沿用该族。
func _apply_toxic_vial_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_toxic_rules._apply_toxic_vial_on_field_tick(rules, context)


## 作用：毒云命中时按规则累积毒种状态。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _toxic_rules._apply_toxin_seed_on_poison_cloud_tick，参数与返回语义沿用该族。
func _apply_toxin_seed_on_poison_cloud_tick(rules: Dictionary, target: Node) -> void:
	_toxic_rules._apply_toxin_seed_on_poison_cloud_tick(rules, target)


## 作用：毒云命中强敌时按规则累积毒核。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _toxic_rules._apply_toxic_core_on_poison_cloud_tick，参数与返回语义沿用该族。
func _apply_toxic_core_on_poison_cloud_tick(rules: Dictionary, target: Node) -> void:
	_toxic_rules._apply_toxic_core_on_poison_cloud_tick(rules, target)


## 作用：满足源状态层数条件时消耗源状态并转换为中毒。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _toxic_rules._convert_toxic_vial_status_to_poison，参数与返回语义沿用该族。
func _convert_toxic_vial_status_to_poison(rules: Dictionary, context: Dictionary, target: Node, rule_key: String) -> void:
	_toxic_rules._convert_toxic_vial_status_to_poison(rules, context, target, rule_key)


## 作用：毒云 tick 通过概率与冷却判断后施加中毒。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _toxic_rules._apply_poison_on_cloud_tick_chance，参数与返回语义沿用该族。
func _apply_poison_on_cloud_tick_chance(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_toxic_rules._apply_poison_on_cloud_tick_chance(rules, context, target)


## 作用：以毒瓶基础规则和目标分类构造中毒参数并施加到目标。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _toxic_rules._apply_poison_status_from_toxic_vial，参数与返回语义沿用该族。
func _apply_poison_status_from_toxic_vial(rules: Dictionary, context: Dictionary, target: Node, stacks: int) -> void:
	_toxic_rules._apply_poison_status_from_toxic_vial(rules, context, target, stacks)


## 作用：刷新毒云内敌人的限时伤害降低，并施加配置减速。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _toxic_rules._apply_poison_cloud_stable_effects，参数与返回语义沿用该族。
func _apply_poison_cloud_stable_effects(rules: Dictionary, target: Node) -> void:
	_toxic_rules._apply_poison_cloud_stable_effects(rules, target)


## 作用：Boss 毒核层数满足条件且冷却允许时触发毒核脉冲。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _toxic_rules._apply_toxic_core_boss_pulse，参数与返回语义沿用该族。
func _apply_toxic_core_boss_pulse(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_toxic_rules._apply_toxic_core_boss_pulse(rules, context, target)


## 作用：玩家低血施放毒瓶满足冷却后生成解毒云并治疗。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _toxic_rules._apply_toxic_vial_antidote_on_cast，参数与返回语义沿用该族。
func _apply_toxic_vial_antidote_on_cast(rules: Dictionary, context: Dictionary) -> void:
	_toxic_rules._apply_toxic_vial_antidote_on_cast(rules, context)


## 作用：根据玩家毒云边缘增益窗口设置或移除移动属性来源。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _toxic_rules._update_toxic_vial_player_cloud，参数与返回语义沿用该族。
func _update_toxic_vial_player_cloud(rules: Dictionary, context: Dictionary) -> void:
	_toxic_rules._update_toxic_vial_player_cloud(rules, context)


## 作用：结合毒瓶基础和强敌调整规则修饰中毒参数。
## 使用：params 为动作或状态参数；context 为施放或命中上下文；转入 _toxic_rules._get_poison_status_params，参数与返回语义沿用该族。
func _get_poison_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _toxic_rules._get_poison_status_params(params, context)


## 作用：按普通、精英与 Boss 分类计算中毒层数上限。
## 使用：rules 为当前技能有效规则；target 为本次命中目标；转入 _toxic_rules._poison_max_stacks_for_target，参数与返回语义沿用该族。
func _poison_max_stacks_for_target(rules: Dictionary, target: Node) -> int:
	return _toxic_rules._poison_max_stacks_for_target(rules, target)


## 作用：在战锤命中时依次处理审判、击退、眩晕或韧性及审判冲击。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _holy_rules._apply_warhammer_on_hit，参数与返回语义沿用该族。
func _apply_warhammer_on_hit(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._apply_warhammer_on_hit(rules, context)


## 作用：在强敌命中且同来源冷却允许时累积审判状态。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _holy_rules._apply_warhammer_judgment_status，参数与返回语义沿用该族。
func _apply_warhammer_judgment_status(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_judgment_status(rules, context, target)


## 作用：按战锤基础值与击退倍率对命中目标执行击退。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _holy_rules._apply_warhammer_knockback，参数与返回语义沿用该族。
func _apply_warhammer_knockback(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_knockback(rules, context, target)


## 作用：按目标类型施加战锤眩晕或 Boss 韧性效果，并消费强制震击标记。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _holy_rules._apply_warhammer_stun_or_poise，参数与返回语义沿用该族。
func _apply_warhammer_stun_or_poise(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_stun_or_poise(rules, context, target)


## 作用：按审判层数与冷却触发审判冲击，并检查 Boss 韧性追加收益。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _holy_rules._apply_warhammer_judgement_shock，参数与返回语义沿用该族。
func _apply_warhammer_judgement_shock(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_judgement_shock(rules, context, target)


## 作用：仅对新的 Boss 韧性破坏计数触发审判加成，避免重复消费。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；转入 _holy_rules._apply_warhammer_boss_poise_judgement_bonus，参数与返回语义沿用该族。
func _apply_warhammer_boss_poise_judgement_bonus(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_boss_poise_judgement_bonus(rules, context, target)


## 作用：按战锤来源身份限制同一来源重复处理。
## 使用：context 为施放或命中上下文；转入 _holy_rules._warhammer_source_once，参数与返回语义沿用该族。
func _warhammer_source_once(context: Dictionary, source_namespace: String) -> bool:
	return _holy_rules._warhammer_source_once(context, source_namespace)


## 作用：读取并清除技能预留强制震击标记，返回本次是否强化。
## 使用：context 为施放或命中上下文；转入 _holy_rules._consume_warhammer_forced_shock，参数与返回语义沿用该族。
func _consume_warhammer_forced_shock(context: Dictionary) -> bool:
	return _holy_rules._consume_warhammer_forced_shock(context)


## 作用：确定玩家是否站在十字领域内，更新治疗、减伤、补盾及低血救援。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _holy_rules._update_cross_relic_field，参数与返回语义沿用该族。
func _update_cross_relic_field(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._update_cross_relic_field(rules, context)


## 作用：按领域治疗与庇护规则的间隔恢复玩家生命。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；player 为玩家节点；转入 _holy_rules._apply_cross_relic_field_heal，参数与返回语义沿用该族。
func _apply_cross_relic_field_heal(rules: Dictionary, context: Dictionary, player: Node, now_seconds: float, base: Dictionary) -> void:
	_holy_rules._apply_cross_relic_field_heal(rules, context, player, now_seconds, base)


## 作用：刷新玩家领域承伤修正及其短时有效截止时间。
## 使用：rules 为当前技能有效规则；player 为玩家节点；now_seconds 为当前单调计时秒数；转入 _holy_rules._apply_cross_relic_field_damage_reduction，参数与返回语义沿用该族。
func _apply_cross_relic_field_damage_reduction(rules: Dictionary, player: Node, now_seconds: float) -> void:
	_holy_rules._apply_cross_relic_field_damage_reduction(rules, player, now_seconds)


## 作用：在领域内按规则冷却补充十字护盾。
## 使用：rules 为当前技能有效规则；player 为玩家节点；now_seconds 为当前单调计时秒数；转入 _holy_rules._apply_cross_relic_periodic_shield，参数与返回语义沿用该族。
func _apply_cross_relic_periodic_shield(rules: Dictionary, player: Node, now_seconds: float) -> void:
	_holy_rules._apply_cross_relic_periodic_shield(rules, player, now_seconds)


## 作用：玩家在领域内持续站立达门槛后，按冷却授予十字护盾。
## 使用：rules 为当前技能有效规则；player 为玩家节点；now_seconds 为当前单调计时秒数；转入 _holy_rules._apply_cross_relic_stand_shield，参数与返回语义沿用该族。
func _apply_cross_relic_stand_shield(rules: Dictionary, player: Node, now_seconds: float) -> void:
	_holy_rules._apply_cross_relic_stand_shield(rules, player, now_seconds)


## 作用：领域内玩家满足低血条件且冷却允许时恢复生命并授予护盾。
## 使用：rules 为当前技能有效规则；player 为玩家节点；now_seconds 为当前单调计时秒数；转入 _holy_rules._apply_cross_relic_low_hp_rescue，参数与返回语义沿用该族。
func _apply_cross_relic_low_hp_rescue(rules: Dictionary, player: Node, now_seconds: float) -> void:
	_holy_rules._apply_cross_relic_low_hp_rescue(rules, player, now_seconds)


## 作用：查找当前包含玩家位置的有效十字领域对象。
## 使用：player 为玩家节点；转入 _holy_rules._find_cross_relic_field_containing_player，参数与返回语义沿用该族。
func _find_cross_relic_field_containing_player(player: Node2D) -> Node2D:
	return _holy_rules._find_cross_relic_field_containing_player(player)


## 作用：结合基础领域和庇护规则增加玩家十字护盾点数。
## 使用：player 为玩家节点；amount 为本次伤害或动作数值；rules 为当前技能有效规则；转入 _holy_rules._grant_cross_relic_shield，参数与返回语义沿用该族。
func _grant_cross_relic_shield(player: Node, amount: int, rules: Dictionary) -> void:
	_holy_rules._grant_cross_relic_shield(player, amount, rules)


## 作用：在玩家治疗接口存在时恢复指定正数生命。
## 使用：player 为玩家节点；amount 为本次伤害或动作数值；转入 _holy_rules._heal_player，参数与返回语义沿用该族。
func _heal_player(player: Node, amount: int) -> void:
	_holy_rules._heal_player(player, amount)


## 作用：读取玩家当前生命比例并夹紧到零至一，缺玩家视作满血。
## 使用：player 为玩家节点；转入 _holy_rules._player_health_ratio，参数与返回语义沿用该族。
func _player_health_ratio(player: Node) -> float:
	return _holy_rules._player_health_ratio(player)


## 作用：根据猎物标记、强敌类型及 Boss 核心规则修改陷阱伤害。
## 使用：packet 为待修饰伤害包视图；rules 为当前技能有效规则；target 为本次命中目标；转入 _hunter_rules._apply_hunter_trap_damage_bonus，参数与返回语义沿用该族。
func _apply_hunter_trap_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_hunter_trap_damage_bonus(packet, rules, target)


## 作用：查询玩家附近敌人并按冰霜光环规则施加减速。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_frost_aura_slow，参数与返回语义沿用该族。
func _apply_frost_aura_slow(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_aura_slow(rules, context)


## 作用：对玩家附近达到冻伤门槛的目标按冷却施加冻结或韧性相关效果。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _frost_rules._apply_freeze_frostbite_near_player，参数与返回语义沿用该族。
func _apply_freeze_frostbite_near_player(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_freeze_frostbite_near_player(rules, context)


## 作用：根据玩家连续移动状态更新风步开始时间和激活截止时间。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _movement_rules._update_windstep_state，参数与返回语义沿用该族。
func _update_windstep_state(rules: Dictionary, context: Dictionary) -> void:
	_movement_rules._update_windstep_state(rules, context)


## 作用：按风步是否有效更新技能投射物速度等运行属性。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；转入 _movement_rules._apply_windstep_runtime_modifiers，参数与返回语义沿用该族。
func _apply_windstep_runtime_modifiers(rules: Dictionary, context: Dictionary) -> void:
	_movement_rules._apply_windstep_runtime_modifiers(rules, context)


## 作用：检查技能风步激活截止时间是否仍在当前时间之后。
## 使用：context 为施放或命中上下文；转入 _movement_rules._is_windstep_active，参数与返回语义沿用该族。
func _is_windstep_active(context: Dictionary) -> bool:
	return _movement_rules._is_windstep_active(context)


## 作用：按当前效果设置或清除技能动态属性，避免每帧无限累加。
## 使用：skill_instance 为技能运行实例；转入 _movement_rules._set_dynamic_runtime_modifier，参数与返回语义沿用该族。
func _set_dynamic_runtime_modifier(skill_instance: RefCounted, modifier_namespace: String, key: String, value: Variant) -> void:
	_movement_rules._set_dynamic_runtime_modifier(skill_instance, modifier_namespace, key, value)


## 作用：取得当前技能基础、运行属性与运行特殊规则的合并结果。
## 使用：context 携带 skill_instance。
func _get_rules(context: Dictionary) -> Dictionary:
	return SkillSpecialRuleSourceScript.get_rules(context.get("skill_instance") as RefCounted)


## 作用：取得当前规则来源技能的有效伤害数值。
## 使用：context 携带 skill_instance。
func _get_skill_damage(context: Dictionary) -> int:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	return _get_effective_skill_stat_int(skill_instance, context, "damage", 16)


## 作用：通过统一属性服务读取技能最终属性并转换为整数。
## 使用：skill_instance 为技能运行实例；context 携带 skill_manager/relic_manager/caster；stat_name 为待查询属性键。
func _get_effective_skill_stat_int(skill_instance: RefCounted, context: Dictionary, stat_name: String, fallback: Variant) -> int:
	return maxi(roundi(float(SkillStatServiceScript.get_effective_stat(
		skill_instance,
		stat_name,
		fallback,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	))), 0)


## 作用：为特殊规则额外伤害构建带标准来源和追踪信息的伤害包。
## 使用：source_id 为稳定效果来源 ID；amount 为本次伤害或动作数值；origin 为世界位置或伤害来源。
func _build_special_packet(source_id: String, amount: int, origin: String, can_crit: bool) -> Dictionary:
	return SpecialDamageRuleHandlerScript.build_special_packet(source_id, amount, origin, can_crit)


## 作用：根据目标的标准敌人等级判断 Boss。
## 使用：target 为本次命中目标。
func _is_boss(target: Node) -> bool:
	return SpecialRuleCommonScript.is_boss(target)


## 作用：根据目标的标准敌人等级判断精英。
## 使用：target 为本次命中目标。
func _is_elite(target: Node) -> bool:
	return SpecialRuleCommonScript.is_elite(target)


## 作用：判断目标是否为 Boss 核心，供核心专属规则使用。
## 使用：target 为本次命中目标。
func _is_boss_core(target: Node) -> bool:
	return SpecialRuleCommonScript.is_boss_core(target)


## 作用：使用有效目标实例身份构造同目标冷却和命中记录键。
## 使用：target 为本次命中目标。
func _target_key(target: Node) -> String:
	return SpecialRuleCommonScript.target_key(target)


## 作用：通过项目 MetadataKey 规范组合规则命名空间与后缀。
## 使用：动作执行和事件总线提供 context；具体规则由 special_rules 各 family 处理，共享方法承担状态与伤害辅助。
func _metadata_key(namespace_text: String, suffix: String) -> String:
	return SpecialRuleCommonScript.metadata_key(namespace_text, suffix)


## 作用：将规则键转换为项目允许的统一元数据标识。
## 使用：动作执行和事件总线提供 context；具体规则由 special_rules 各 family 处理，共享方法承担状态与伤害辅助。
func _metadata_identifier(raw_key: String) -> String:
	return SpecialRuleCommonScript.metadata_identifier(raw_key)


## 作用：读取目标生命比例并夹紧到零至一。
## 使用：target 为本次命中目标。
func _health_ratio(target: Node) -> float:
	return SpecialRuleCommonScript.health_ratio(target)


## 作用：从命中上下文或伤害结果判断本次是否暴击。
## 使用：context 携带 was_crit/is_crit/projectile。
func _is_critical_hit_context(context: Dictionary) -> bool:
	if bool(context.get("was_crit", context.get("is_crit", false))):
		return true
	var projectile: Node = context.get("projectile") as Node
	return projectile != null and bool(projectile.get_meta("last_hit_was_crit", false))


## 作用：从目标运动属性判断其是否正在移动。
## 使用：target 为本次命中目标。
func _is_target_moving(target: Node) -> bool:
	return SpecialRuleCommonScript.is_target_moving(target)


## 作用：把引擎单调毫秒计时转换为冷却使用的秒数。
## 使用：动作执行和事件总线提供 context；具体规则由 special_rules 各 family 处理，共享方法承担状态与伤害辅助。
func _now_seconds() -> float:
	return SpecialRuleCommonScript.now_seconds()


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：动作执行和事件总线提供 context；具体规则由 special_rules 各 family 处理，共享方法承担状态与伤害辅助。
func _get_dictionary(value: Variant) -> Dictionary:
	return SpecialRuleCommonScript.get_dictionary(value)


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：动作执行和事件总线提供 context；具体规则由 special_rules 各 family 处理，共享方法承担状态与伤害辅助。
func _get_array(value: Variant) -> Array:
	return SpecialRuleCommonScript.get_array(value)
