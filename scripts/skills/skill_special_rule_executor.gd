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


func _get_burn_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _fire_rules._get_burn_status_params(params, context)


func _get_burn_base_max_stacks() -> int:
	return _fire_rules._get_burn_base_max_stacks()


func _get_burn_base_damage() -> float:
	return _fire_rules._get_burn_base_damage()


func _get_burning_power_from_context(context: Dictionary) -> float:
	return _fire_rules._get_burning_power_from_context(context)


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


func _apply_global_damage_packet_modifiers(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_apply_flammable_mark_fire_vulnerability(packet, rules, target, packet_object)
	_apply_acid_mark_vulnerability(packet, rules, target)


func _apply_trap_damage_packet_modifiers(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_trap_damage_packet_modifiers(packet, rules, target)


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


func _apply_hot_rapid_fire_crit_bonus(packet: Dictionary, context: Dictionary, packet_object: RefCounted) -> void:
	_fire_rules._apply_hot_rapid_fire_crit_bonus(packet, context, packet_object)


func _apply_same_target_multi_projectile_damage(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_fire_rules._apply_same_target_multi_projectile_damage(packet, rules, context, target, packet_object)


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


func _prepare_hot_rapid_fire_cast(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._prepare_hot_rapid_fire_cast(rules, context)


func _prepare_storm_hail_cast(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._prepare_storm_hail_cast(rules, context)


func _prepare_arcane_double_page_cast(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._prepare_arcane_double_page_cast(rules, context)


func _prepare_forbidden_page_cast(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._prepare_forbidden_page_cast(rules, context)


func _prepare_extra_knife_cast(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._prepare_extra_knife_cast(rules, context)


func _prepare_hunter_bow_cast(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._prepare_hunter_bow_cast(rules, context)


func _prepare_warhammer_cast(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._prepare_warhammer_cast(rules, context)


func _advance_interval_counter(skill_instance: RefCounted, meta_key: String) -> int:
	var count: int = int(skill_instance.get_meta(meta_key, 0)) + 1
	skill_instance.set_meta(meta_key, count)
	return count


func _reserve_cooldown(cooldowns: Dictionary, key: String, now_seconds: float, cooldown_seconds: float) -> bool:
	if now_seconds < float(cooldowns.get(key, 0.0)):
		return false
	cooldowns[key] = now_seconds + cooldown_seconds
	return true


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


func _apply_fire_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_fire_projectile_hit_rules(rules, context)


func _apply_frost_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_projectile_hit_rules(rules, context)


func _apply_fire_reaction_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_fire_reaction_hit_rules(rules, context)


func _apply_frost_reaction_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_reaction_hit_rules(rules, context)


func _apply_lightning_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_lightning_projectile_hit_rules(rules, context)


func _apply_arcane_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_arcane_projectile_hit_rules(rules, context)


func _apply_hunter_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_projectile_hit_rules(rules, context)


func _apply_projectile_field_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_cross_relic_on_field_tick(rules, context)
	_apply_toxic_vial_on_field_tick(rules, context)
	_apply_fire_oil_on_field_tick(rules, context)
	_apply_acid_spray_on_field_tick(rules, context)


func _on_trap_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._on_trap_hit(rules, context)


func _apply_hunter_trap_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_trap_hit_rules(rules, context)


func _apply_trap_damage_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_trap_damage_hit_rules(rules, context)


func _apply_trap_control_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_trap_control_hit_rules(rules, context)


func _on_trap_expired(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._on_trap_expired(rules, context)


func _execute_decoy_trap_expired(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._execute_decoy_trap_expired(rules, context)


func _on_enemy_killed(rules: Dictionary, context: Dictionary) -> void:
	_apply_elemental_enemy_kill_rules(rules, context)
	_apply_hunter_enemy_kill_rules(rules, context)
	_apply_toxic_enemy_kill_rules(rules, context)


func _apply_elemental_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	SpecialDamageRuleHandlerScript.execute_burning_target_death_explosion(rules, context)
	SpecialDamageRuleHandlerScript.execute_shatter_kill_spawn_icicle(rules, context)


func _apply_hunter_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_enemy_kill_rules(rules, context)


func _apply_toxic_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	_toxic_rules._apply_toxic_enemy_kill_rules(rules, context)


func execute_player_tick(context: Dictionary) -> void:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return
	_update_player_defensive_tick_rules(rules, context)
	_update_player_control_tick_rules(rules, context)
	_update_player_field_tick_rules(rules, context)


func _update_player_defensive_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_update_holy_shield(rules, context)


func _update_player_control_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_frost_aura_slow(rules, context)
	_apply_freeze_frostbite_near_player(rules, context)
	_apply_page_spirit_spawn(rules, context)
	_update_windstep_state(rules, context)
	_apply_decoy_trap_spawn(rules, context)


func _update_player_field_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_update_cross_relic_field(rules, context)
	_update_toxic_vial_player_cloud(rules, context)
	_update_fire_oil_smoke_player_buff(rules, context)
	_update_corrosive_film(rules, context)


func execute_player_damaged(context: Dictionary) -> void:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return
	SpecialDamageRuleHandlerScript.execute_holy_shield_player_damaged(rules, context)
	_apply_smoke_cloud_on_player_damaged(rules, context)
	_apply_corrosive_film_on_boss_skill_hit(rules, context)


func _deploy_holy_shield(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._deploy_holy_shield(rules, context)


func _update_holy_shield(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._update_holy_shield(rules, context)


func _holy_shield_pulse_interval(rules: Dictionary) -> float:
	return _holy_rules._holy_shield_pulse_interval(rules)


func _apply_holy_shield_player_meta(caster: Node, rules: Dictionary, until_time: float) -> void:
	_holy_rules._apply_holy_shield_player_meta(caster, rules, until_time)


func _clear_holy_shield_player_meta(caster: Node) -> void:
	_holy_rules._clear_holy_shield_player_meta(caster)


func _apply_direct_hit_extra_explosion_bonus(rules: Dictionary, context: Dictionary) -> void:
	var base_damage: int = _get_skill_damage(context)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.direct_hit_extra_explosion_intents(rules, context, base_damage))


func _apply_explosion_burn_rules(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_explosion_burn_rules(rules, context)


func _apply_explosion_direct_hit_burn(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_fire_rules._apply_explosion_direct_hit_burn(rules, context, target)


func _apply_explosion_multi_hit_burn(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_fire_rules._apply_explosion_multi_hit_burn(rules, context, target)


func _apply_soul_ember_to_burn(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_soul_ember_to_burn(rules, context)


func _apply_soul_ember_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_soul_ember_on_direct_hit(rules, context)


func _apply_flame_core_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_flame_core_on_direct_hit(rules, context)


func _apply_flame_core_boss_burst(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_flame_core_boss_burst(rules, context)


func _apply_frost_lock_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_lock_on_direct_hit(rules, context)


func _apply_frost_lock_bonus_hit(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_lock_bonus_hit(rules, context)


func _apply_frostbite_on_hail_hit(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frostbite_on_hail_hit(rules, context)


func _apply_frostbite_freeze_or_poise(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frostbite_freeze_or_poise(rules, context)


func _apply_frost_core_crack_on_boss_poise(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_core_crack_on_boss_poise(rules, context)


func _apply_shatter_on_freeze_or_frost_hit(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_shatter_on_freeze_or_frost_hit(rules, context)


func _apply_soulburn_burst(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._apply_soulburn_burst(rules, context)


func _consume_soulburn_burn_stacks(target: Node, rule: Dictionary, current_burn_stacks: int) -> void:
	_fire_rules._consume_soulburn_burn_stacks(target, rule, current_burn_stacks)


func _spawn_ground_fire_or_lava(rules: Dictionary, context: Dictionary) -> void:
	_fire_rules._spawn_ground_fire_or_lava(rules, context)


func _apply_lightning_chain_bounce(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_lightning_chain_bounce(rules, context)


func _apply_voltage_on_elite_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_voltage_on_elite_boss_hit(rules, context)


func _apply_overload_on_voltage(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_overload_on_voltage(rules, context)


func _apply_overload_shock_lightning(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_overload_shock_lightning(rules, context)


func _apply_shock_on_lightning_orb_hit(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_shock_on_lightning_orb_hit(rules, context)


func _apply_shock_consume_reaction(rules: Dictionary, context: Dictionary) -> void:
	_lightning_rules._apply_shock_consume_reaction(rules, context)


func _apply_arcane_page_copy(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_arcane_page_copy(rules, context)


func _apply_arcane_seal_on_elite_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_arcane_seal_on_elite_boss_hit(rules, context)


func _apply_arcane_seal_burst(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_arcane_seal_burst(rules, context)


func _apply_forbidden_page_hit(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_forbidden_page_hit(rules, context)


func _apply_page_spirit_spawn(rules: Dictionary, context: Dictionary) -> void:
	_arcane_rules._apply_page_spirit_spawn(rules, context)


func _apply_execution_mark_on_strong_target(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_execution_mark_on_strong_target(rules, context)


func _apply_boss_low_hp_execution_burst(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_boss_low_hp_execution_burst(rules, context)


func _apply_wound_on_throwing_knife_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_wound_on_throwing_knife_hit(rules, context)


func _apply_bleed_on_crit_wound(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_bleed_on_crit_wound(rules, context)


func _apply_rupture_on_full_wound_crit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_rupture_on_full_wound_crit(rules, context)


func _apply_recycle_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_recycle_boss_hit(rules, context)


func _apply_next_knife_kill_bonus(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_next_knife_kill_bonus(rules, context)


func _apply_recycle_knife_on_normal_kill(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_recycle_knife_on_normal_kill(rules, context)


func _apply_eagle_mark_on_strong_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_eagle_mark_on_strong_hit(rules, context)


func _apply_hunter_arrow_hit_explosion(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_arrow_hit_explosion(rules, context)


func _apply_hunter_arrow_shards(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_hunter_arrow_shards(rules, context)


func _apply_marked_hit_cooldown_refund(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_marked_hit_cooldown_refund(rules, context)


func _apply_eagle_shot_on_boss_mark_hits(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_eagle_shot_on_boss_mark_hits(rules, context)


func _apply_marked_target_death_explosion(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_marked_target_death_explosion(rules, context)


func _apply_small_trap_on_trigger(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_small_trap_on_trigger(rules, context)


func _apply_chain_trap_root_on_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_chain_trap_root_on_hit(rules, context)


func _apply_pincer_reaction_on_root(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_pincer_reaction_on_root(rules, context)


func _apply_prey_mark_on_strong_trap_hit(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_prey_mark_on_strong_trap_hit(rules, context)


func _apply_boss_core_trap_bonus_damage(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_boss_core_trap_bonus_damage(rules, context)


func _apply_trap_hit_explosion(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_trap_hit_explosion(rules, context)


func _apply_trap_kill_fragment_field(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_trap_kill_fragment_field(rules, context)


func _apply_decoy_trap_spawn(rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_decoy_trap_spawn(rules, context)


func _apply_flame_core_direct_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_fire_rules._apply_flame_core_direct_damage_bonus(packet, rules, target)


func _get_holy_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _holy_rules._get_holy_mark_status_params(params, context)


func _get_shock_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _lightning_rules._get_shock_status_params(params, context)


func _get_arcane_seal_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _arcane_rules._get_arcane_seal_status_params(params, context)


func _get_hunter_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _hunter_rules._get_hunter_mark_status_params(params, context)


func _get_wound_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _hunter_rules._get_wound_status_params(params, context)


func _get_bleed_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _hunter_rules._get_bleed_status_params(params, context)


func _apply_boss_poise_upgrade_meta(context: Dictionary) -> void:
	_frost_rules._apply_boss_poise_upgrade_meta(context)


func _apply_boss_poise_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_frost_rules._apply_boss_poise_damage_bonus(packet, rules, target)


func _apply_storm_hail_boss_modifier(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node) -> void:
	_frost_rules._apply_storm_hail_boss_modifier(packet, rules, context, target)


func _apply_arcane_seal_burst_vulnerability(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_arcane_rules._apply_arcane_seal_burst_vulnerability(packet, rules, target)


func _apply_forbidden_page_damage_bonus(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node) -> void:
	_arcane_rules._apply_forbidden_page_damage_bonus(packet, rules, context, target)


func _apply_low_hp_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_low_hp_damage_bonus(packet, rules, target)


func _apply_same_target_short_window_decay(packet: Dictionary, rules: Dictionary, context: Dictionary, packet_object: RefCounted, target: Node) -> void:
	_hunter_rules._apply_same_target_short_window_decay(packet, rules, context, packet_object, target)


func _apply_execution_mark_crit_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_execution_mark_crit_damage_bonus(packet, rules, target)


func _apply_next_knife_damage_after_kill(packet: Dictionary, rules: Dictionary, context: Dictionary) -> void:
	_hunter_rules._apply_next_knife_damage_after_kill(packet, rules, context)


func _apply_hunter_arrow_pierce_damage(packet: Dictionary, rules: Dictionary, context: Dictionary, packet_object: RefCounted) -> void:
	_hunter_rules._apply_hunter_arrow_pierce_damage(packet, rules, context, packet_object)


func _apply_hunter_mark_damage_taken(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_hunter_mark_damage_taken(packet, rules, target)


func _apply_holy_mark_holy_vulnerability(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_holy_rules._apply_holy_mark_holy_vulnerability(packet, rules, target, packet_object)


func _apply_warhammer_low_hp_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_warhammer_low_hp_damage_bonus(packet, rules, target)


func _apply_warhammer_stun_target_damage_taken(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_stun_target_damage_taken(packet, rules, target)


func _apply_cross_relic_dot_target_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_holy_rules._apply_cross_relic_dot_target_damage_bonus(packet, rules, target, packet_object)


func _apply_cross_relic_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._apply_cross_relic_on_field_tick(rules, context)


func _apply_cross_relic_impurity_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._apply_cross_relic_impurity_on_field_tick(rules, context)


func _prepare_acid_pressure_cast(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._prepare_acid_pressure_cast(rules, context)


func _apply_acid_spray_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._apply_acid_spray_on_field_tick(rules, context)


func _apply_acid_mark_on_strong_tick(rules: Dictionary, target: Node) -> void:
	_acid_rules._apply_acid_mark_on_strong_tick(rules, target)


func _apply_acid_residue_on_tick(rules: Dictionary, target: Node) -> void:
	_acid_rules._apply_acid_residue_on_tick(rules, target)


func _apply_acid_burst_on_full_status(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_acid_rules._apply_acid_burst_on_full_status(rules, context, target)


func _apply_acid_hit_shield(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._apply_acid_hit_shield(rules, context)


func _apply_boss_acid_mark_armor_break_pulse(rules: Dictionary, target: Node) -> void:
	_acid_rules._apply_boss_acid_mark_armor_break_pulse(rules, target)


func _update_corrosive_film(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._update_corrosive_film(rules, context)


func _apply_corrosive_film_on_boss_skill_hit(rules: Dictionary, context: Dictionary) -> void:
	_acid_rules._apply_corrosive_film_on_boss_skill_hit(rules, context)


func _apply_acid_mark_vulnerability(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_acid_rules._apply_acid_mark_vulnerability(packet, rules, target)


func _is_boss_damage_source(context: Dictionary) -> bool:
	return _acid_rules._is_boss_damage_source(context)


func _apply_fire_oil_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_oil_rules._apply_fire_oil_on_field_tick(rules, context)


func _apply_burn_in_merged_oil(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_oil_rules._apply_burn_in_merged_oil(rules, context, target)


func _apply_flammable_mark_on_oil_tick(rules: Dictionary, target: Node) -> void:
	_oil_rules._apply_flammable_mark_on_oil_tick(rules, target)


func _apply_oil_stack_on_fire_oil_tick(rules: Dictionary, target: Node) -> void:
	_oil_rules._apply_oil_stack_on_fire_oil_tick(rules, target)


func _apply_fire_oil_deflagration(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_oil_rules._apply_fire_oil_deflagration(rules, context, target)


func _apply_flammable_mark_burst(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_oil_rules._apply_flammable_mark_burst(rules, context, target)


func _apply_smoke_cloud_target_effects(rules: Dictionary, target: Node) -> void:
	_oil_rules._apply_smoke_cloud_target_effects(rules, target)


func _apply_smoke_cloud_on_oil_expire(rules: Dictionary, context: Dictionary) -> void:
	_oil_rules._apply_smoke_cloud_on_oil_expire(rules, context)


func _apply_smoke_cloud_on_player_damaged(rules: Dictionary, context: Dictionary) -> void:
	_oil_rules._apply_smoke_cloud_on_player_damaged(rules, context)


func _update_fire_oil_smoke_player_buff(rules: Dictionary, context: Dictionary) -> void:
	_oil_rules._update_fire_oil_smoke_player_buff(rules, context)


func _apply_flammable_mark_fire_vulnerability(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	_oil_rules._apply_flammable_mark_fire_vulnerability(packet, rules, target, packet_object)


func _apply_flammable_burst_boss_poise(rules: Dictionary, target: Node) -> void:
	_oil_rules._apply_flammable_burst_boss_poise(rules, target)


func _get_flammable_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _oil_rules._get_flammable_mark_status_params(params, context)


func _apply_toxic_vial_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	_toxic_rules._apply_toxic_vial_on_field_tick(rules, context)


func _apply_toxin_seed_on_poison_cloud_tick(rules: Dictionary, target: Node) -> void:
	_toxic_rules._apply_toxin_seed_on_poison_cloud_tick(rules, target)


func _apply_toxic_core_on_poison_cloud_tick(rules: Dictionary, target: Node) -> void:
	_toxic_rules._apply_toxic_core_on_poison_cloud_tick(rules, target)


func _convert_toxic_vial_status_to_poison(rules: Dictionary, context: Dictionary, target: Node, rule_key: String) -> void:
	_toxic_rules._convert_toxic_vial_status_to_poison(rules, context, target, rule_key)


func _apply_poison_on_cloud_tick_chance(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_toxic_rules._apply_poison_on_cloud_tick_chance(rules, context, target)


func _apply_poison_status_from_toxic_vial(rules: Dictionary, context: Dictionary, target: Node, stacks: int) -> void:
	_toxic_rules._apply_poison_status_from_toxic_vial(rules, context, target, stacks)


func _apply_poison_cloud_stable_effects(rules: Dictionary, target: Node) -> void:
	_toxic_rules._apply_poison_cloud_stable_effects(rules, target)


func _apply_toxic_core_boss_pulse(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_toxic_rules._apply_toxic_core_boss_pulse(rules, context, target)


func _apply_toxic_vial_antidote_on_cast(rules: Dictionary, context: Dictionary) -> void:
	_toxic_rules._apply_toxic_vial_antidote_on_cast(rules, context)


func _update_toxic_vial_player_cloud(rules: Dictionary, context: Dictionary) -> void:
	_toxic_rules._update_toxic_vial_player_cloud(rules, context)


func _get_poison_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return _toxic_rules._get_poison_status_params(params, context)


func _poison_max_stacks_for_target(rules: Dictionary, target: Node) -> int:
	return _toxic_rules._poison_max_stacks_for_target(rules, target)


func _apply_warhammer_on_hit(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._apply_warhammer_on_hit(rules, context)


func _apply_warhammer_judgment_status(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_judgment_status(rules, context, target)


func _apply_warhammer_knockback(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_knockback(rules, context, target)


func _apply_warhammer_stun_or_poise(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_stun_or_poise(rules, context, target)


func _apply_warhammer_judgement_shock(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_judgement_shock(rules, context, target)


func _apply_warhammer_boss_poise_judgement_bonus(rules: Dictionary, context: Dictionary, target: Node) -> void:
	_holy_rules._apply_warhammer_boss_poise_judgement_bonus(rules, context, target)


func _warhammer_source_once(context: Dictionary, source_namespace: String) -> bool:
	return _holy_rules._warhammer_source_once(context, source_namespace)


func _consume_warhammer_forced_shock(context: Dictionary) -> bool:
	return _holy_rules._consume_warhammer_forced_shock(context)


func _update_cross_relic_field(rules: Dictionary, context: Dictionary) -> void:
	_holy_rules._update_cross_relic_field(rules, context)


func _apply_cross_relic_field_heal(rules: Dictionary, context: Dictionary, player: Node, now_seconds: float, base: Dictionary) -> void:
	_holy_rules._apply_cross_relic_field_heal(rules, context, player, now_seconds, base)


func _apply_cross_relic_field_damage_reduction(rules: Dictionary, player: Node, now_seconds: float) -> void:
	_holy_rules._apply_cross_relic_field_damage_reduction(rules, player, now_seconds)


func _apply_cross_relic_periodic_shield(rules: Dictionary, player: Node, now_seconds: float) -> void:
	_holy_rules._apply_cross_relic_periodic_shield(rules, player, now_seconds)


func _apply_cross_relic_stand_shield(rules: Dictionary, player: Node, now_seconds: float) -> void:
	_holy_rules._apply_cross_relic_stand_shield(rules, player, now_seconds)


func _apply_cross_relic_low_hp_rescue(rules: Dictionary, player: Node, now_seconds: float) -> void:
	_holy_rules._apply_cross_relic_low_hp_rescue(rules, player, now_seconds)


func _find_cross_relic_field_containing_player(player: Node2D) -> Node2D:
	return _holy_rules._find_cross_relic_field_containing_player(player)


func _grant_cross_relic_shield(player: Node, amount: int, rules: Dictionary) -> void:
	_holy_rules._grant_cross_relic_shield(player, amount, rules)


func _heal_player(player: Node, amount: int) -> void:
	_holy_rules._heal_player(player, amount)


func _player_health_ratio(player: Node) -> float:
	return _holy_rules._player_health_ratio(player)


func _apply_hunter_trap_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	_hunter_rules._apply_hunter_trap_damage_bonus(packet, rules, target)


func _apply_frost_aura_slow(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_frost_aura_slow(rules, context)


func _apply_freeze_frostbite_near_player(rules: Dictionary, context: Dictionary) -> void:
	_frost_rules._apply_freeze_frostbite_near_player(rules, context)


func _update_windstep_state(rules: Dictionary, context: Dictionary) -> void:
	_movement_rules._update_windstep_state(rules, context)


func _apply_windstep_runtime_modifiers(rules: Dictionary, context: Dictionary) -> void:
	_movement_rules._apply_windstep_runtime_modifiers(rules, context)


func _is_windstep_active(context: Dictionary) -> bool:
	return _movement_rules._is_windstep_active(context)


func _set_dynamic_runtime_modifier(skill_instance: RefCounted, modifier_namespace: String, key: String, value: Variant) -> void:
	_movement_rules._set_dynamic_runtime_modifier(skill_instance, modifier_namespace, key, value)


func _get_rules(context: Dictionary) -> Dictionary:
	return SkillSpecialRuleSourceScript.get_rules(context.get("skill_instance") as RefCounted)


func _get_skill_damage(context: Dictionary) -> int:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	return _get_effective_skill_stat_int(skill_instance, context, "damage", 16)


func _get_effective_skill_stat_int(skill_instance: RefCounted, context: Dictionary, stat_name: String, fallback: Variant) -> int:
	return maxi(roundi(float(SkillStatServiceScript.get_effective_stat(
		skill_instance,
		stat_name,
		fallback,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	))), 0)


func _build_special_packet(source_id: String, amount: int, origin: String, can_crit: bool) -> Dictionary:
	return SpecialDamageRuleHandlerScript.build_special_packet(source_id, amount, origin, can_crit)


func _is_boss(target: Node) -> bool:
	return SpecialRuleCommonScript.is_boss(target)


func _is_elite(target: Node) -> bool:
	return SpecialRuleCommonScript.is_elite(target)


func _is_boss_core(target: Node) -> bool:
	return SpecialRuleCommonScript.is_boss_core(target)


func _target_key(target: Node) -> String:
	return SpecialRuleCommonScript.target_key(target)


func _metadata_key(namespace_text: String, suffix: String) -> String:
	return SpecialRuleCommonScript.metadata_key(namespace_text, suffix)


func _metadata_identifier(raw_key: String) -> String:
	return SpecialRuleCommonScript.metadata_identifier(raw_key)


func _health_ratio(target: Node) -> float:
	return SpecialRuleCommonScript.health_ratio(target)


func _is_critical_hit_context(context: Dictionary) -> bool:
	if bool(context.get("was_crit", context.get("is_crit", false))):
		return true
	var projectile: Node = context.get("projectile") as Node
	return projectile != null and bool(projectile.get_meta("last_hit_was_crit", false))


func _is_target_moving(target: Node) -> bool:
	return SpecialRuleCommonScript.is_target_moving(target)


func _now_seconds() -> float:
	return SpecialRuleCommonScript.now_seconds()


func _get_dictionary(value: Variant) -> Dictionary:
	return SpecialRuleCommonScript.get_dictionary(value)


func _get_array(value: Variant) -> Array:
	return SpecialRuleCommonScript.get_array(value)
