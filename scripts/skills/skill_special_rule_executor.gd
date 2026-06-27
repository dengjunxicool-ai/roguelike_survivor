extends RefCounted
class_name SkillSpecialRuleExecutor


const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")
const MetadataKeyScript: Script = preload("res://scripts/core/metadata_key.gd")

static var _soulburn_target_cooldowns: Dictionary = {}
static var _flame_core_burst_cooldowns: Dictionary = {}
static var _frost_lock_bonus_hit_cooldowns: Dictionary = {}
static var _frost_core_crack_cooldowns: Dictionary = {}
static var _shatter_target_cooldowns: Dictionary = {}
static var _near_player_freeze_cooldowns: Dictionary = {}
static var _overload_target_cooldowns: Dictionary = {}
static var _overload_shock_lightning_cooldowns: Dictionary = {}
static var _shock_hit_cooldowns: Dictionary = {}
static var _magnetic_storm_cooldowns: Dictionary = {}
static var _arcane_seal_burst_cooldowns: Dictionary = {}
static var _soul_ember_cooldowns: Dictionary = {}
static var _frost_lock_cooldowns: Dictionary = {}
static var _frostbite_cooldowns: Dictionary = {}
static var _voltage_cooldowns: Dictionary = {}
static var _execution_burst_cooldowns: Dictionary = {}
static var _wound_on_hit_cooldowns: Dictionary = {}
static var _bleed_on_wound_cooldowns: Dictionary = {}
static var _rupture_cooldowns: Dictionary = {}
static var _marked_hit_refund_cooldowns: Dictionary = {}
static var _marked_death_explosion_cooldowns: Dictionary = {}
static var _pincer_reaction_cooldowns: Dictionary = {}
static var _boss_core_trap_bonus_cooldowns: Dictionary = {}
static var _decoy_trap_spawn_cooldowns: Dictionary = {}
static var _judgment_on_strong_hit_cooldowns: Dictionary = {}
static var _warhammer_judgement_shock_cooldowns: Dictionary = {}
static var _warhammer_boss_poise_judgement_bonus_cooldowns: Dictionary = {}
static var _cross_relic_stand_shield_cooldowns: Dictionary = {}
static var _cross_relic_periodic_shield_timers: Dictionary = {}
static var _cross_relic_low_hp_rescue_cooldowns: Dictionary = {}
static var _toxic_core_boss_pulse_cooldowns: Dictionary = {}
static var _poison_cloud_tick_poison_cooldowns: Dictionary = {}
static var _antidote_cloud_cooldowns: Dictionary = {}
static var _fire_oil_flammable_burst_cooldowns: Dictionary = {}
static var _fire_oil_burn_in_merged_oil_cooldowns: Dictionary = {}
static var _fire_oil_flammable_poise_cooldowns: Dictionary = {}
static var _smoke_cloud_player_damaged_cooldowns: Dictionary = {}
static var _acid_burst_cooldowns: Dictionary = {}
static var _boss_acid_mark_pulse_counts: Dictionary = {}
static var _corrosive_film_boss_hit_cooldowns: Dictionary = {}


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
			return _get_chill_status_params(params, context)
		&"freeze":
			_apply_boss_poise_upgrade_meta(context)
			return params
		&"charge":
			return _get_charge_status_params(params, context)
		&"shock":
			return _get_shock_status_params(params, context)
		&"arcane_mark":
			return _get_arcane_mark_status_params(params, context)
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
		&"burn":
			return _get_burn_status_params(params, context)
		_:
			return params


func _get_burn_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return params

	if rules.has("burn_duration_add"):
		params["duration"] = float(params.get("duration", 3.0)) + float(rules.get("burn_duration_add", 0.0))
	if rules.has("burn_max_stacks_add") or rules.has("boss_burn_max_stacks_add"):
		var target: Node = context.get("target") as Node
		var base_max_stacks: int = int(params.get("max_stacks", _get_burn_base_max_stacks()))
		var add_stacks: int = int(rules.get("burn_max_stacks_add", 0))
		if _is_boss(target):
			add_stacks = int(rules.get("boss_burn_max_stacks_add", add_stacks))
		params["max_stacks"] = maxi(base_max_stacks + add_stacks, 1)
	if rules.has("burn_damage_multiplier_add"):
		var base_damage: float = float(params.get("damage", params.get("tick_damage", _get_burn_base_damage())))
		if base_damage > 0:
			params["damage"] = maxf(base_damage * maxf(1.0 + float(rules.get("burn_damage_multiplier_add", 0.0)), 0.0), 0.0)
	return params


func _get_burn_base_max_stacks() -> int:
	return 5


func _get_burn_base_damage() -> float:
	return 1.6


func adjust_damage_packet(packet: Dictionary, context: Dictionary) -> Dictionary:
	var adjusted: Dictionary = packet
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return adjusted
	var target: Node = context.get("target") as Node
	var packet_object: RefCounted = DamagePacketScript.from_dictionary(packet, context.get("caster") as Node, target)
	var damage_origin: String = String(packet_object.call("get_value", "damage_origin", ""))
	_apply_flammable_mark_fire_vulnerability(adjusted, rules, target, packet_object)
	_apply_acid_mark_vulnerability(adjusted, rules, target)
	if damage_origin == "trap":
		_apply_hunter_trap_damage_bonus(adjusted, rules, target)
		return adjusted
	if damage_origin != "primary_attack":
		return adjusted
	_apply_flame_core_direct_damage_bonus(adjusted, rules, target)
	_apply_boss_poise_damage_bonus(adjusted, rules, target)
	_apply_storm_hail_boss_modifier(adjusted, rules, context, target)
	_apply_arcane_seal_burst_vulnerability(adjusted, rules, target)
	_apply_forbidden_page_damage_bonus(adjusted, rules, context, target)
	_apply_low_hp_damage_bonus(adjusted, rules, target)
	_apply_same_target_short_window_decay(adjusted, rules, context, packet_object, target)
	_apply_execution_mark_crit_damage_bonus(adjusted, rules, target)
	_apply_next_knife_damage_after_kill(adjusted, rules, context)
	_apply_hunter_arrow_pierce_damage(adjusted, rules, context, packet_object)
	_apply_hunter_mark_damage_taken(adjusted, rules, target)
	_apply_holy_mark_holy_vulnerability(adjusted, rules, target, packet_object)
	_apply_warhammer_low_hp_damage_bonus(adjusted, rules, target)
	_apply_warhammer_stun_target_damage_taken(adjusted, rules, target)
	_apply_cross_relic_dot_target_damage_bonus(adjusted, rules, target, packet_object)
	_apply_same_target_multi_projectile_damage(adjusted, rules, context, target, packet_object)
	_apply_hot_rapid_fire_crit_bonus(adjusted, context, packet_object)
	return adjusted


func _apply_hot_rapid_fire_crit_bonus(packet: Dictionary, context: Dictionary, packet_object: RefCounted) -> void:
	if not bool(context.get("hot_rapid_fire_crit", false)):
		return
	packet["crit_chance_add"] = float(packet_object.call("get_value", "crit_chance_add", 0.0)) + float(context.get("hot_rapid_fire_crit_chance_add", 0.0))


func _apply_same_target_multi_projectile_damage(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node, packet_object: RefCounted) -> void:
	if not rules.has("same_target_multi_projectile_damage"):
		return
	var projectile: Node = context.get("projectile") as Node
	var target_key: String = _target_key(target)
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
	var rule: Dictionary = _get_dictionary(rules.get("same_target_multi_projectile_damage", {}))
	packet["special_final_modifier"] = float(packet_object.call("get_value", "special_final_modifier", 1.0)) * maxf(float(rule.get("second_hit_damage_multiplier", 0.6)), 0.0)
	packet["special_final_modifier_source"] = "target_passive"


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
	if not rules.has("hot_rapid_fire"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("hot_rapid_fire", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 3)), 1)
	var cast_count: int = _advance_interval_counter(skill_instance, "fireball_cast_count")
	if cast_count % interval == 0:
		skill_instance.set_meta("hot_rapid_fire_next_cast", true)
		skill_instance.set_meta("hot_rapid_fire_crit_chance_add", float(rule.get("next_projectile_crit_chance_add", 0.4)))


func _prepare_storm_hail_cast(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("storm_hail_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("storm_hail_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 4)), 1)
	var cast_count: int = _advance_interval_counter(skill_instance, "storm_hail_cast_count")
	skill_instance.set_meta("storm_hail_next_cast", cast_count % interval == 0)


func _prepare_arcane_double_page_cast(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("arcane_double_page_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("arcane_double_page_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 5)), 1)
	var cast_count: int = _advance_interval_counter(skill_instance, "arcane_page_cast_count")
	if cast_count % interval == 0:
		skill_instance.set_meta("arcane_double_page_next_cast", true)
		skill_instance.set_meta("arcane_double_page_extra_projectiles", maxi(int(rule.get("extra_projectile_count", 1)), 0))


func _prepare_forbidden_page_cast(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("forbidden_page_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("forbidden_page_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 4)), 1)
	var cast_count: int = _advance_interval_counter(skill_instance, "forbidden_page_cast_count")
	skill_instance.set_meta("forbidden_page_next_cast", cast_count % interval == 0)


func _prepare_extra_knife_cast(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("extra_knife_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("extra_knife_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 4)), 1)
	var cast_count: int = _advance_interval_counter(skill_instance, "extra_knife_cast_count")
	if cast_count % interval == 0:
		SpecialDamageRuleHandlerScript.execute_extra_knife_throw(rules, context, _get_skill_damage(context))


func _prepare_hunter_bow_cast(rules: Dictionary, context: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	_apply_windstep_runtime_modifiers(rules, context)
	if rules.has("windstep_double_arrow") and _is_windstep_active(context):
		var wind_rule: Dictionary = _get_dictionary(rules.get("windstep_double_arrow", {}))
		var wind_interval: int = maxi(int(wind_rule.get("cast_interval", 4)), 1)
		var wind_count: int = _advance_interval_counter(skill_instance, "windstep_arrow_cast_count")
		if wind_count % wind_interval == 0:
			SpecialDamageRuleHandlerScript.execute_windstep_double_arrow(rules, context, _get_skill_damage(context))
	if not rules.has("cloud_arrow_every_n_casts"):
		_set_dynamic_runtime_modifier(skill_instance, "hunter_cloud_arrow", "pierce_override", null)
		return
	var rule: Dictionary = _get_dictionary(rules.get("cloud_arrow_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 3)), 1)
	var cast_count: int = _advance_interval_counter(skill_instance, "cloud_arrow_cast_count")
	var active: bool = cast_count % interval == 0
	skill_instance.set_meta("hunter_cloud_arrow_active", active)
	var pierce_override_value: Variant = null
	if active:
		pierce_override_value = int(rule.get("pierce_override", 7))
	_set_dynamic_runtime_modifier(skill_instance, "hunter_cloud_arrow", "pierce_override", pierce_override_value)


func _prepare_warhammer_cast(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("warhammer_base"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	if rules.has("warhammer_quake_slam_every_n_casts"):
		var quake_rule: Dictionary = _get_dictionary(rules.get("warhammer_quake_slam_every_n_casts", {}))
		var cast_interval: int = maxi(int(quake_rule.get("cast_interval", 3)), 1)
		var cast_count: int = _advance_interval_counter(skill_instance, "warhammer_cast_count")
		skill_instance.set_meta("warhammer_quake_slam_active", cast_count % cast_interval == 0)
	if rules.has("warhammer_forced_shock_every_n_seconds"):
		var shock_rule: Dictionary = _get_dictionary(rules.get("warhammer_forced_shock_every_n_seconds", {}))
		var now_seconds: float = _now_seconds()
		var next_at: float = float(skill_instance.get_meta("warhammer_forced_shock_next_at", 0.0))
		var active_shock: bool = now_seconds >= next_at
		skill_instance.set_meta("warhammer_forced_shock_active", active_shock)
		if active_shock:
			skill_instance.set_meta("warhammer_forced_shock_next_at", now_seconds + maxf(float(shock_rule.get("interval", 8.0)), 0.0))


func _advance_interval_counter(skill_instance: RefCounted, meta_key: String) -> int:
	var count: int = int(skill_instance.get_meta(meta_key, 0)) + 1
	skill_instance.set_meta(meta_key, count)
	return count


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
	_apply_direct_hit_extra_explosion_bonus(rules, context)
	_apply_explosion_burn_rules(rules, context)
	_apply_soul_ember_to_burn(rules, context)
	_apply_soul_ember_on_direct_hit(rules, context)
	_apply_flame_core_on_direct_hit(rules, context)


func _apply_frost_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_frost_lock_on_direct_hit(rules, context)
	_apply_frost_lock_bonus_hit(rules, context)
	_apply_frostbite_freeze_or_poise(rules, context)
	_apply_frostbite_on_hail_hit(rules, context)
	_apply_shatter_on_freeze_or_frost_hit(rules, context)


func _apply_fire_reaction_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_soulburn_burst(rules, context)
	_apply_flame_core_boss_burst(rules, context)


func _apply_frost_reaction_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_frost_core_crack_on_boss_poise(rules, context)


func _apply_lightning_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_lightning_chain_bounce(rules, context)
	_apply_voltage_on_elite_boss_hit(rules, context)
	_apply_overload_on_voltage(rules, context)
	_apply_shock_on_lightning_orb_hit(rules, context)
	_apply_shock_consume_reaction(rules, context)


func _apply_arcane_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_arcane_page_copy(rules, context)
	_apply_arcane_seal_on_elite_boss_hit(rules, context)
	_apply_arcane_seal_burst(rules, context)
	_apply_forbidden_page_hit(rules, context)


func _apply_hunter_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_execution_mark_on_strong_target(rules, context)
	_apply_boss_low_hp_execution_burst(rules, context)
	_apply_wound_on_throwing_knife_hit(rules, context)
	_apply_bleed_on_crit_wound(rules, context)
	_apply_rupture_on_full_wound_crit(rules, context)
	_apply_recycle_boss_hit(rules, context)
	_apply_eagle_mark_on_strong_hit(rules, context)
	_apply_hunter_arrow_hit_explosion(rules, context)
	_apply_hunter_arrow_shards(rules, context)
	_apply_marked_hit_cooldown_refund(rules, context)
	_apply_eagle_shot_on_boss_mark_hits(rules, context)


func _apply_projectile_field_tick_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_cross_relic_on_field_tick(rules, context)
	_apply_toxic_vial_on_field_tick(rules, context)
	_apply_fire_oil_on_field_tick(rules, context)
	_apply_acid_spray_on_field_tick(rules, context)


func _on_trap_hit(rules: Dictionary, context: Dictionary) -> void:
	_apply_hunter_trap_hit_rules(rules, context)
	_apply_trap_damage_hit_rules(rules, context)
	_apply_trap_control_hit_rules(rules, context)


func _apply_hunter_trap_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_prey_mark_on_strong_trap_hit(rules, context)


func _apply_trap_damage_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_boss_core_trap_bonus_damage(rules, context)
	_apply_trap_hit_explosion(rules, context)
	_apply_small_trap_on_trigger(rules, context)


func _apply_trap_control_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_chain_trap_root_on_hit(rules, context)
	_apply_pincer_reaction_on_root(rules, context)


func _on_trap_expired(rules: Dictionary, context: Dictionary) -> void:
	_apply_smoke_cloud_on_oil_expire(rules, context)
	_execute_decoy_trap_expired(rules, context)


func _execute_decoy_trap_expired(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("decoy_trap_explosion"):
		return
	var area: Node = context.get("area") as Node
	if area == null or not bool(area.get_meta("decoy_trap", false)):
		return
	SpecialDamageRuleHandlerScript.execute_decoy_trap_explosion(rules, context)


func _on_enemy_killed(rules: Dictionary, context: Dictionary) -> void:
	_apply_elemental_enemy_kill_rules(rules, context)
	_apply_hunter_enemy_kill_rules(rules, context)
	_apply_toxic_enemy_kill_rules(rules, context)


func _apply_elemental_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	SpecialDamageRuleHandlerScript.execute_burning_target_death_explosion(rules, context)
	SpecialDamageRuleHandlerScript.execute_shatter_kill_spawn_icicle(rules, context)


func _apply_hunter_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	_apply_next_knife_kill_bonus(rules, context)
	_apply_recycle_knife_on_normal_kill(rules, context)
	_apply_marked_target_death_explosion(rules, context)
	_apply_trap_kill_fragment_field(rules, context)


func _apply_toxic_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	SpecialDamageRuleHandlerScript.execute_toxic_vial_small_cloud(rules, context)
	SpecialDamageRuleHandlerScript.execute_poison_death_explosion(rules, context)


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
	if not rules.has("holy_shield_base"):
		return
	var caster: Node = context.get("caster") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if caster == null or skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_shield_base", {}))
	var shield_value: int = maxi(roundi(float(SkillStatServiceScript.get_effective_stat(
		skill_instance,
		"shield_value",
		rule.get("shield_value", 30),
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		caster
	))), 0)
	var break_damage: int = maxi(roundi(float(SkillStatServiceScript.get_effective_stat(
		skill_instance,
		"break_damage",
		rule.get("break_damage", 30),
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		caster
	))), 0)
	var now_seconds: float = _now_seconds()
	var duration: float = maxf(float(rule.get("duration", rule.get("deploy_interval", 7.0))), 0.1)
	skill_instance.set_meta("holy_shield_active", true)
	skill_instance.set_meta("holy_shield_value", shield_value)
	skill_instance.set_meta("holy_shield_remaining", shield_value)
	skill_instance.set_meta("holy_shield_break_damage", break_damage)
	skill_instance.set_meta("holy_shield_started_at", now_seconds)
	skill_instance.set_meta("holy_shield_expires_at", now_seconds + duration)
	skill_instance.set_meta("holy_shield_next_pulse_at", now_seconds)
	skill_instance.set_meta("holy_shield_pulse_count", 0)
	_apply_holy_shield_player_meta(caster, rules, now_seconds + duration)


func _update_holy_shield(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("holy_shield_base"):
		return
	var caster: Node = context.get("caster") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if caster == null or skill_instance == null:
		return
	if not bool(skill_instance.get_meta("holy_shield_active", false)):
		return
	var now_seconds: float = _now_seconds()
	var expires_at: float = float(skill_instance.get_meta("holy_shield_expires_at", now_seconds))
	if now_seconds >= expires_at:
		skill_instance.set_meta("holy_shield_active", false)
		SpecialDamageRuleHandlerScript.execute_holy_shield_expire(rules, context)
		_clear_holy_shield_player_meta(caster)
		return
	_apply_holy_shield_player_meta(caster, rules, expires_at)
	var pulse_interval: float = _holy_shield_pulse_interval(rules)
	if now_seconds < float(skill_instance.get_meta("holy_shield_next_pulse_at", now_seconds)):
		return
	var pulse_count: int = int(skill_instance.get_meta("holy_shield_pulse_count", 0)) + 1
	skill_instance.set_meta("holy_shield_pulse_count", pulse_count)
	skill_instance.set_meta("holy_shield_next_pulse_at", now_seconds + pulse_interval)
	SpecialDamageRuleHandlerScript.execute_holy_shield_pulse(rules, context, pulse_count)


func _holy_shield_pulse_interval(rules: Dictionary) -> float:
	var base: Dictionary = _get_dictionary(rules.get("holy_shield_base", {}))
	var interval: float = maxf(float(base.get("pulse_interval", 1.0)), 0.05)
	if rules.has("holy_pulse_interval"):
		var rule: Dictionary = _get_dictionary(rules.get("holy_pulse_interval", {}))
		interval *= maxf(float(rule.get("multiplier", 1.0)), 0.05)
	return interval


func _apply_holy_shield_player_meta(caster: Node, rules: Dictionary, until_time: float) -> void:
	if caster == null or not rules.has("holy_shield_contact_damage_reduction"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_shield_contact_damage_reduction", {}))
	caster.set_meta("holy_shield_contact_reduction_until", until_time)
	caster.set_meta("holy_shield_contact_damage_taken_multiplier_add", float(rule.get("damage_taken_multiplier_add", -0.15)))


func _clear_holy_shield_player_meta(caster: Node) -> void:
	if caster == null:
		return
	caster.set_meta("holy_shield_contact_reduction_until", 0.0)
	caster.set_meta("holy_shield_contact_damage_taken_multiplier_add", 0.0)


func _apply_direct_hit_extra_explosion_bonus(rules: Dictionary, context: Dictionary) -> void:
	var base_damage: int = _get_skill_damage(context)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.direct_hit_extra_explosion_intents(rules, context, base_damage))


func _apply_explosion_burn_rules(rules: Dictionary, context: Dictionary) -> void:
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var direct_rule: Dictionary = _get_dictionary(rules.get("explosion_direct_hit_burn_on_elite_boss", {}))
	if not direct_rule.is_empty() and (_is_elite(target) or _is_boss(target)):
		var key: String = _metadata_key("burst_explosion_burn", _target_key(target))
		var now_seconds: float = _now_seconds()
		if now_seconds >= float(target.get_meta(key, 0.0)):
			target.set_meta(key, now_seconds + maxf(float(direct_rule.get("same_target_cooldown", 1.5)), 0.0))
			var direct_status_params: Dictionary = DamageTraceContextScript.apply_to_status_params({
				"stacks": int(direct_rule.get("stack", 1)),
				"duration": float(direct_rule.get("duration", 3.0))
			}, context)
			target.call("apply_status", StringName(String(direct_rule.get("status_id", "burn"))), direct_status_params)
	var multi_rule: Dictionary = _get_dictionary(rules.get("explosion_multi_hit_burn", {}))
	if multi_rule.is_empty() or _is_elite(target) or _is_boss(target):
		return
	var hit_count: int = int(context.get("explosion_targets_hit", target.get_meta("fireball_explosion_targets_hit", 1)))
	if hit_count < maxi(int(multi_rule.get("min_targets_hit", 3)), 1):
		return
	var multi_status_params: Dictionary = DamageTraceContextScript.apply_to_status_params({
		"stacks": int(multi_rule.get("stack", 1)),
		"duration": float(multi_rule.get("duration", 3.0))
	}, context)
	target.call("apply_status", StringName(String(multi_rule.get("status_id", "burn"))), multi_status_params)


func _apply_soul_ember_to_burn(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("soul_ember_to_burn_on_full_stack_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("soul_ember_to_burn_on_full_stack_hit", {}))
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
		var burn_params: Dictionary = _get_burn_status_params({
			"stacks": burn_per_conversion * conversion_count,
			"max_stacks": maxi(int(rule.get("burn_max_stacks", 5)), 1)
		}, context)
		burn_params = DamageTraceContextScript.apply_to_status_params(burn_params, context)
		target.call("apply_status", &"burn", burn_params)


func _apply_soul_ember_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("soul_ember_on_direct_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("soul_ember_on_direct_hit", {}))
	var key: String = "soul_ember:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_soul_ember_cooldowns.get(key, 0.0)):
		return
	_soul_ember_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 0.4)), 0.0)
	target.call("apply_status", StringName(String(rule.get("status_id", "soul_ember"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 4)),
		"duration": float(rule.get("duration", 4.0))
	})


func _apply_flame_core_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("flame_core_on_elite_boss_direct_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	if not _is_elite(target) and not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("flame_core_on_elite_boss_direct_hit", {}))
	var duration: float = float(rule.get("duration", 4.0)) + float(rules.get("flame_core_duration_add", 0.0))
	var params: Dictionary = {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 5)),
		"duration": duration,
		"direct_damage_multiplier_add_per_stack": float(rule.get("direct_damage_multiplier_add_per_stack", 0.0))
	}
	var vulnerability_rule: Dictionary = _get_dictionary(rules.get("flame_core_full_stack_explosion_vulnerability", {}))
	if not vulnerability_rule.is_empty():
		params["full_stack_explosion_damage_taken_multiplier_add"] = float(vulnerability_rule.get("explosion_damage_taken_multiplier_add", 0.0))
		params["full_stack_required_stacks"] = int(vulnerability_rule.get("required_stacks", rule.get("max_stacks", 5)))
	target.call("apply_status", StringName(String(rule.get("status_id", "flame_core"))), params)


func _apply_flame_core_boss_burst(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("flame_core_boss_burst"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not _is_boss(target) or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("flame_core_boss_burst", {}))
	var required_stacks: int = maxi(int(rule.get("required_stacks", 5)), 1)
	if int(target.call("get_status_stack", &"flame_core")) < required_stacks:
		return
	var key: String = "flame_core_burst:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_flame_core_burst_cooldowns.get(key, 0.0)):
		return
	var hit_interval: int = maxi(int(rule.get("hit_interval", 4)), 1)
	var hit_count: int = int(target.get_meta("flame_core_boss_direct_hits", 0)) + 1
	target.set_meta("flame_core_boss_direct_hits", hit_count)
	if hit_count % hit_interval != 0:
		return
	_flame_core_burst_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.flame_core_burst_intents(rules, context, maxi(int(rule.get("amount", 32)), 0)))


func _apply_frost_lock_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("frost_lock_on_elite_boss_direct_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	if not _is_elite(target) and not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("frost_lock_on_elite_boss_direct_hit", {}))
	var key: String = "frost_lock:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_frost_lock_cooldowns.get(key, 0.0)):
		return
	_frost_lock_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 0.6)), 0.0)
	target.call("apply_status", StringName(String(rule.get("status_id", "frost_lock"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 4)),
		"duration": float(rule.get("duration", 5.0))
	})


func _apply_frost_lock_bonus_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("frost_lock_bonus_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	if not _is_elite(target) and not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("frost_lock_bonus_hit", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "frost_lock")))
	if int(target.call("get_status_stack", status_id)) < maxi(int(rule.get("required_stacks", 4)), 1):
		return
	var key: String = "frost_lock_bonus:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_frost_lock_bonus_hit_cooldowns.get(key, 0.0)):
		return
	_frost_lock_bonus_hit_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, int(rule.get("consume_stacks", 4)))
	if _is_boss(target) and bool(rule.get("boss_converts_to_poise", true)):
		ReactionLimiterScript.apply_boss_control_conversion(target, &"freeze")
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.frost_bonus_hit_intents(rules, context, maxi(int(rule.get("amount", 14)), 0), "frost_lock_bonus_hit"))


func _apply_frostbite_on_hail_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("frostbite_on_hail_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("frostbite_on_hail_hit", {}))
	var key: String = "frostbite:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_frostbite_cooldowns.get(key, 0.0)):
		return
	_frostbite_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 0.4)), 0.0)
	target.call("apply_status", StringName(String(rule.get("status_id", "frostbite"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 3)),
		"duration": float(rule.get("duration", 4.0))
	})


func _apply_frostbite_freeze_or_poise(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("frostbite_freeze_or_poise"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("frostbite_freeze_or_poise", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "frostbite")))
	if int(target.call("get_status_stack", status_id)) < maxi(int(rule.get("required_stacks", 3)), 1):
		return
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, int(rule.get("consume_stacks", 3)))
	if _is_boss(target):
		if bool(rule.get("boss_converts_to_poise", true)):
			ReactionLimiterScript.apply_boss_control_conversion(target, &"freeze")
	elif target.has_method("apply_status"):
		var duration: float = float(rule.get("elite_freeze_duration", 0.3)) if _is_elite(target) else float(rule.get("normal_freeze_duration", 0.6))
		target.call("apply_status", &"freeze", {
			"duration": duration,
			"stacks": 1,
			"max_stacks": 1
		})


func _apply_frost_core_crack_on_boss_poise(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("frost_core_crack_on_boss_poise"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not _is_boss(target):
		return
	var completed_at: float = float(target.get_meta("boss_poise_recently_completed_at", -9999.0))
	if _now_seconds() - completed_at > 0.2:
		return
	var completed_count: int = int(target.get_meta("boss_poise_completed_count", 0))
	var consumed_count: int = int(target.get_meta("frost_core_crack_consumed_poise_count", 0))
	if completed_count <= consumed_count:
		return
	var rule: Dictionary = _get_dictionary(rules.get("frost_core_crack_on_boss_poise", {}))
	var key: String = "frost_core_crack:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_frost_core_crack_cooldowns.get(key, 0.0)):
		return
	target.set_meta("frost_core_crack_consumed_poise_count", completed_count)
	_frost_core_crack_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.5)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.frost_core_crack_intents(rules, context, maxi(int(rule.get("amount", 30)), 0)))


func _apply_shatter_on_freeze_or_frost_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("shatter_on_freeze_or_frost_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("has_status"):
		return
	if not bool(target.call("has_status", &"freeze")):
		return
	var rule: Dictionary = _get_dictionary(rules.get("shatter_on_freeze_or_frost_hit", {}))
	var key: String = "shatter:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_shatter_target_cooldowns.get(key, 0.0)):
		return
	_shatter_target_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)
	SpecialDamageRuleHandlerScript.execute_shatter_area(rules, context)


func _apply_soulburn_burst(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("soulburn_burst_on_full_burn_direct_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack") or not target.has_method("take_damage"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("soulburn_burst_on_full_burn_direct_hit", {}))
	var burn_stacks: int = int(target.call("get_status_stack", &"burn"))
	if burn_stacks < maxi(int(rule.get("required_burn_stacks", 5)), 1):
		return
	var key: String = "soulburn:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_soulburn_target_cooldowns.get(key, 0.0)):
		return
	_soulburn_target_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)
	_consume_soulburn_burn_stacks(target, rule, burn_stacks)
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	var ratio: float = float(rule.get("normal_max_hp_damage", 0.03))
	if _is_boss(target):
		ratio = float(rule.get("boss_max_hp_damage", 0.0025))
	elif _is_elite(target):
		ratio = float(rule.get("elite_max_hp_damage", 0.01))
	var amount: int = maxi(roundi(max_health * ratio), 1)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.soulburn_burst_intents(rules, context, amount))


func _consume_soulburn_burn_stacks(target: Node, rule: Dictionary, current_burn_stacks: int) -> void:
	if target == null or not target.has_method("consume_status_stack"):
		return
	var consume_rule: String = String(rule.get("consume_burn_stacks", ""))
	if consume_rule == "all":
		target.call("consume_status_stack", &"burn", current_burn_stacks)
	elif rule.has("consume_burn_stacks"):
		target.call("consume_status_stack", &"burn", maxi(int(rule.get("consume_burn_stacks", 0)), 0))


func _spawn_ground_fire_or_lava(rules: Dictionary, context: Dictionary) -> void:
	SpecialDamageRuleHandlerScript.spawn_ground_fire_or_lava(rules, context, _get_skill_damage(context))


func _apply_lightning_chain_bounce(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("lightning_chain_bounce"):
		return
	SpecialDamageRuleHandlerScript.execute_lightning_chain_bounce(rules, context, _get_skill_damage(context))


func _apply_voltage_on_elite_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("voltage_on_elite_boss_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	if not _is_elite(target) and not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("voltage_on_elite_boss_hit", {}))
	var key: String = "voltage:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_voltage_cooldowns.get(key, 0.0)):
		return
	_voltage_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 0.45)), 0.0)
	target.call("apply_status", StringName(String(rule.get("status_id", "voltage"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 5)),
		"duration": float(rule.get("duration", 4.0))
	})


func _apply_overload_on_voltage(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("overload_on_voltage"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("overload_on_voltage", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "voltage")))
	var stacks: int = int(target.call("get_status_stack", status_id))
	var required_stacks: int = maxi(int(rule.get("required_stacks", 5)), 1)
	if stacks < required_stacks:
		return
	var key: String = "lightning_overload:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_overload_target_cooldowns.get(key, 0.0)):
		return
	_overload_target_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.2)), 0.0)
	var had_shock: bool = target.has_method("has_status") and bool(target.call("has_status", &"shock"))
	var consume_stacks: int = stacks if bool(rule.get("consume_all", true)) else maxi(int(rule.get("consume_stacks", required_stacks)), 0)
	if consume_stacks > 0 and target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, consume_stacks)
	var amount: int = maxi(int(rule.get("amount", 18)), 0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.lightning_overload_intents(rules, context, amount))
	if target.has_method("apply_status"):
		target.call("apply_status", StringName(String(rule.get("apply_status_id", "shock"))), {
			"stacks": 1,
			"max_stacks": 1,
			"duration": float(rule.get("apply_status_duration", 0.8)) + float(_get_dictionary(rules.get("shock_upgrade", {})).get("duration_add", 0.0))
		})
	if had_shock:
		_apply_overload_shock_lightning(rules, context)


func _apply_overload_shock_lightning(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("overload_shock_lightning"):
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("overload_shock_lightning", {}))
	var key: String = "overload_shock_lightning:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_overload_shock_lightning_cooldowns.get(key, 0.0)):
		return
	_overload_shock_lightning_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.overload_shock_lightning_intents(rules, context, maxi(int(rule.get("amount", 26)), 0)))


func _apply_shock_on_lightning_orb_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("shock_on_lightning_orb_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("shock_on_lightning_orb_hit", {}))
	var key: String = "shock_hit:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_shock_hit_cooldowns.get(key, 0.0)):
		return
	if randf() > clampf(float(rule.get("chance", 0.2)), 0.0, 1.0):
		return
	_shock_hit_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 0.8)), 0.0)
	target.call("apply_status", StringName(String(rule.get("shock_status_id", "shock"))), {
		"duration": float(rule.get("shock_duration", 0.8)) + float(_get_dictionary(rules.get("shock_upgrade", {})).get("duration_add", 0.0)),
		"stacks": 1,
		"max_stacks": 1
	})


func _apply_shock_consume_reaction(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("shock_consume_reaction"):
		return
	var target: Node = context.get("target") as Node
	var projectile: Node = context.get("projectile") as Node
	if target == null or not target.has_method("has_status") or not bool(target.call("has_status", &"shock")):
		return
	var rule: Dictionary = _get_dictionary(rules.get("shock_consume_reaction", {}))
	var max_triggers: int = maxi(int(rule.get("max_triggers_per_orb", 2)), 1)
	var trigger_count: int = int(projectile.get_meta("lightning_shock_trigger_count", 0)) if projectile != null else 0
	if trigger_count >= max_triggers:
		return
	if projectile != null:
		projectile.set_meta("lightning_shock_trigger_count", trigger_count + 1)
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", &"shock", 1)
	var upgrade: Dictionary = _get_dictionary(rules.get("shock_upgrade", {}))
	var amount: int = maxi(roundi(float(rule.get("amount", 8)) * maxf(1.0 + float(upgrade.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.shock_consume_reaction_intents(rules, context, amount))
	SpecialDamageRuleHandlerScript.spread_shock_from_shock(rules, context)
	if not rules.has("magnetic_storm_on_shock_consume"):
		return
	var storm_rule: Dictionary = _get_dictionary(rules.get("magnetic_storm_on_shock_consume", {}))
	if projectile != null:
		if bool(projectile.get_meta("lightning_magnetic_storm_checked", false)):
			return
		projectile.set_meta("lightning_magnetic_storm_checked", true)
	var key: String = "magnetic_storm:%s" % String(context.get("skill_id", "lightning_orb"))
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_magnetic_storm_cooldowns.get(key, 0.0)):
		return
	_magnetic_storm_cooldowns[key] = now_seconds + maxf(float(storm_rule.get("same_source_cooldown", 2.5)), 0.0)
	SpecialDamageRuleHandlerScript.execute_magnetic_storm_on_shock_consume(rules, context)


func _apply_arcane_page_copy(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("arcane_page_copy_on_hit"):
		return
	SpecialDamageRuleHandlerScript.execute_arcane_page_copy(rules, context, _get_skill_damage(context))


func _apply_arcane_seal_on_elite_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("arcane_seal_on_elite_boss_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	if not _is_elite(target) and not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("arcane_seal_on_elite_boss_hit", {}))
	var key: String = "arcane_seal:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_arcane_seal_burst_cooldowns.get(key, 0.0)):
		return
	_arcane_seal_burst_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 0.4)), 0.0)
	target.call("apply_status", StringName(String(rule.get("status_id", "arcane_seal"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 5)),
		"duration": float(rule.get("duration", 5.0)) + float(rules.get("arcane_seal_duration_add", 0.0))
	})


func _apply_arcane_seal_burst(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("arcane_seal_burst"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("arcane_seal_burst", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "arcane_seal")))
	var required_stacks: int = maxi(int(rule.get("required_stacks", 5)), 1)
	if int(target.call("get_status_stack", status_id)) < required_stacks:
		return
	var key: String = "arcane_seal_burst:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_arcane_seal_burst_cooldowns.get(key, 0.0)):
		return
	_arcane_seal_burst_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 0.0)), 0.0)
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, maxi(int(rule.get("consume_stacks", 3)), 0))
	var amount: int = maxi(int(rule.get("amount", 20)), 0)
	var bonus_rule: Dictionary = _get_dictionary(rules.get("arcane_seal_burst_elite_boss_bonus", {}))
	if (_is_elite(target) or _is_boss(target)) and not bonus_rule.is_empty():
		amount = maxi(roundi(float(amount) * maxf(1.0 + float(bonus_rule.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.arcane_seal_burst_intents(rules, context, amount))
	var vulnerability_rule: Dictionary = _get_dictionary(rules.get("arcane_seal_burst_vulnerability", {}))
	if not vulnerability_rule.is_empty():
		target.set_meta("arcane_seal_burst_vulnerability_until", now_seconds + maxf(float(vulnerability_rule.get("duration", 2.0)), 0.0))
		target.set_meta("arcane_seal_burst_primary_attack_damage_taken_multiplier_add", float(vulnerability_rule.get("primary_attack_damage_taken_multiplier_add", 0.12)))


func _apply_forbidden_page_hit(rules: Dictionary, context: Dictionary) -> void:
	var projectile: Node = context.get("projectile") as Node
	if projectile == null or not bool(projectile.get_meta("forbidden_page", false)):
		return
	var caster: Node = context.get("caster") as Node
	var damage_rule: Dictionary = _get_dictionary(rules.get("forbidden_page_every_n_casts", {}))
	var upgrade_rule: Dictionary = _get_dictionary(rules.get("forbidden_page_upgrade", {}))
	var self_damage: int = int(damage_rule.get("self_damage", 0))
	if not upgrade_rule.is_empty():
		self_damage = int(upgrade_rule.get("self_damage", self_damage))
	SpecialDamageRuleHandlerScript.apply_forbidden_page_self_damage(caster, context, maxi(self_damage, 0))
	var target: Node = context.get("target") as Node
	if target == null or not _is_boss(target) or not rules.has("forbidden_boss_stack"):
		return
	var boss_rule: Dictionary = _get_dictionary(rules.get("forbidden_boss_stack", {}))
	var current_stacks: int = int(target.get_meta("forbidden_boss_stacks", 0))
	target.set_meta("forbidden_boss_stacks", mini(current_stacks + 1, maxi(int(boss_rule.get("max_stacks", 5)), 1)))


func _apply_page_spirit_spawn(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("page_spirit_spawn"):
		return
	SpecialDamageRuleHandlerScript.execute_page_spirit_tick(rules, context)


func _apply_execution_mark_on_strong_target(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("execution_mark_on_strong_target"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not (_is_elite(target) or _is_boss(target)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("execution_mark_on_strong_target", {}))
	var key: String = "execution_hits_%s" % _target_key(target)
	var hit_count: int = int(target.get_meta(key, 0)) + 1
	target.set_meta(key, hit_count)
	if hit_count >= maxi(int(rule.get("required_consecutive_hits", 5)), 1):
		target.set_meta("throwing_knife_execution_mark", true)


func _apply_boss_low_hp_execution_burst(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("boss_low_hp_execution_burst"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("boss_low_hp_execution_burst", {}))
	if _health_ratio(target) > float(rule.get("hp_threshold", 0.2)):
		return
	var key: String = "execution_burst:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_execution_burst_cooldowns.get(key, 0.0)):
		return
	_execution_burst_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.execution_burst_intents(rules, context, maxi(int(rule.get("amount", 22)), 0)))


func _apply_wound_on_throwing_knife_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("wound_on_throwing_knife_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("wound_on_throwing_knife_hit", {}))
	var key: String = "wound_on_hit:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_wound_on_hit_cooldowns.get(key, 0.0)):
		return
	_wound_on_hit_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 0.3)), 0.0)
	var duration: float = float(rule.get("duration", 4.0))
	var tuning: Dictionary = _get_dictionary(rules.get("wound_tuning", {}))
	duration += float(tuning.get("duration_add", 0.0))
	target.call("apply_status", StringName(String(rule.get("status_id", "wound"))), {
		"duration": duration,
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 5)), 1)
	})


func _apply_bleed_on_crit_wound(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("bleed_on_crit_wound") or not _is_critical_hit_context(context):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("has_status") or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("bleed_on_crit_wound", {}))
	if not bool(target.call("has_status", StringName(String(rule.get("required_status_id", "wound"))))):
		return
	var key: String = "bleed_on_wound:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_bleed_on_wound_cooldowns.get(key, 0.0)):
		return
	_bleed_on_wound_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.0)), 0.0)
	target.call("apply_status", StringName(String(rule.get("status_id", "bleed"))), {
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1),
		"boss_damage_multiplier": float(rule.get("boss_damage_multiplier", 0.65))
	})


func _apply_rupture_on_full_wound_crit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("rupture_on_full_wound_crit") or not _is_critical_hit_context(context):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("rupture_on_full_wound_crit", {}))
	if int(target.call("get_status_stack", StringName(String(rule.get("required_status_id", "wound"))))) < maxi(int(rule.get("required_wound_stacks", 5)), 1):
		return
	var key: String = "rupture:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_rupture_cooldowns.get(key, 0.0)):
		return
	_rupture_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.rupture_on_full_wound_crit_intents(rules, context, maxi(int(rule.get("amount", 18)), 0)))


func _apply_recycle_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("recycle_dash_buff"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not _is_boss(target):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("recycle_dash_buff", {}))
	var interval: int = maxi(int(rule.get("boss_hit_interval", 6)), 1)
	var hit_count: int = int(skill_instance.get_meta("recycle_boss_hit_count", 0)) + 1
	skill_instance.set_meta("recycle_boss_hit_count", hit_count)
	if hit_count % interval == 0:
		SpecialDamageRuleHandlerScript.apply_recycle_dash_buff(rules, context)


func _apply_next_knife_kill_bonus(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("next_knife_damage_after_kill"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("next_knife_damage_after_kill", {}))
	skill_instance.set_meta("next_knife_damage_after_kill_bonus", float(rule.get("damage_multiplier_add", 0.2)))


func _apply_recycle_knife_on_normal_kill(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("recycle_knife_on_normal_kill"):
		return
	SpecialDamageRuleHandlerScript.execute_recycle_knife(rules, context, _get_skill_damage(context))


func _apply_eagle_mark_on_strong_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("eagle_mark_on_strong_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not (_is_elite(target) or _is_boss(target)) or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("eagle_mark_on_strong_hit", {}))
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


func _apply_hunter_arrow_hit_explosion(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("hunter_arrow_hit_explosion"):
		return
	SpecialDamageRuleHandlerScript.execute_hunter_arrow_hit_explosion(rules, context, _get_skill_damage(context))


func _apply_hunter_arrow_shards(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("hunter_arrow_shards_after_pierce_hits"):
		return
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("hunter_arrow_shards_after_pierce_hits", {}))
	var hit_count: int = int(projectile.get_meta("hunter_arrow_hit_count", 0))
	if hit_count < maxi(int(rule.get("required_hits", 3)), 1):
		return
	if bool(projectile.get_meta("hunter_arrow_shards_spawned", false)):
		return
	projectile.set_meta("hunter_arrow_shards_spawned", true)
	SpecialDamageRuleHandlerScript.execute_hunter_arrow_shards(rules, context)


func _apply_marked_hit_cooldown_refund(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("eagle_marked_hit_cooldown_refund") and not rules.has("marked_hit_cooldown_refund"):
		return
	var target: Node = context.get("target") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if target == null or skill_instance == null or not target.has_method("has_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("eagle_marked_hit_cooldown_refund", rules.get("marked_hit_cooldown_refund", {})))
	if not bool(target.call("has_status", StringName(String(rule.get("status_id", "eagle_mark"))))):
		return
	if randf() > clampf(float(rule.get("chance", 0.25)), 0.0, 1.0):
		return
	var key: String = "marked_refund:%s:%s" % [String(context.get("skill_id", "piercing_arrow")), str(skill_instance.get_instance_id())]
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_marked_hit_refund_cooldowns.get(key, 0.0)):
		return
	_marked_hit_refund_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 2.0)), 0.0)
	skill_instance.set("cooldown_remaining", 0.0)


func _apply_eagle_shot_on_boss_mark_hits(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("eagle_shot_on_boss_eagle_mark_hits") and not rules.has("eagle_shot_on_boss_mark_hits"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not _is_boss(target) or not target.has_method("has_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("eagle_shot_on_boss_eagle_mark_hits", rules.get("eagle_shot_on_boss_mark_hits", {})))
	if not bool(target.call("has_status", StringName(String(rule.get("status_id", "eagle_mark"))))):
		return
	var key: String = _metadata_key("eagle_shot_hits", _target_key(target))
	var hit_count: int = int(target.get_meta(key, 0)) + 1
	target.set_meta(key, hit_count)
	if hit_count % maxi(int(rule.get("required_hits", 6)), 1) == 0:
		SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.eagle_shot_intents(rules, context, maxi(int(rule.get("amount", 36)), 0)))


func _apply_marked_target_death_explosion(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("burst_mark_death_explosion") and not rules.has("marked_target_death_explosion"):
		return
	var enemy: Node = context.get("enemy") as Node
	if enemy == null or not enemy.has_method("has_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("burst_mark_death_explosion", rules.get("marked_target_death_explosion", {})))
	if not bool(enemy.call("has_status", StringName(String(rule.get("required_status_id", "burst_mark"))))):
		return
	if String(context.get("source_key", "")).find("hunter_burst_mark_death_explosion") >= 0 and not bool(rule.get("can_trigger_self", false)):
		return
	var key: String = "marked_death:%s" % String(context.get("source_key", str(enemy.get_instance_id())))
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_marked_death_explosion_cooldowns.get(key, 0.0)):
		return
	_marked_death_explosion_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 0.25)), 0.0)
	SpecialDamageRuleHandlerScript.execute_burst_mark_death_explosion(rules, context, _get_skill_damage(context))


func _apply_small_trap_on_trigger(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("small_trap_on_trigger"):
		return
	var area: Node = context.get("area") as Node
	if area != null and bool(area.get_meta("small_trap", false)):
		return
	SpecialDamageRuleHandlerScript.execute_small_trap_on_trigger(rules, context, _get_skill_damage(context))


func _apply_chain_trap_root_on_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("chain_trap_root_on_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("chain_trap_root_on_hit", {}))
	if _is_boss(target):
		target.call("apply_status", StringName(String(rule.get("boss_status_id", "slow"))), {
			"duration": float(rule.get("elite_duration", 0.25)),
			"slow_percent": float(rule.get("boss_slow_percent", 0.35))
		})
		if bool(rule.get("boss_converts_to_poise", true)):
			ReactionLimiterScript.apply_boss_control_conversion(target, StringName(String(rule.get("status_id", "root"))))
		return
	var duration: float = float(rule.get("elite_duration", 0.25)) if _is_elite(target) else float(rule.get("normal_duration", 0.5))
	target.call("apply_status", StringName(String(rule.get("status_id", "root"))), {
		"duration": duration,
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1)
	})


func _apply_pincer_reaction_on_root(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("pincer_reaction_on_root"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("has_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("pincer_reaction_on_root", {}))
	if not bool(target.call("has_status", StringName(String(rule.get("required_status_id", "root"))))):
		return
	var key: String = "trap_pincer:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_pincer_reaction_cooldowns.get(key, 0.0)):
		return
	_pincer_reaction_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.pincer_reaction_intents(rules, context, maxi(int(rule.get("amount", 16)), 0)))


func _apply_prey_mark_on_strong_trap_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("prey_mark_on_strong_trap_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not (_is_elite(target) or _is_boss(target)) or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("prey_mark_on_strong_trap_hit", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "prey_mark"))), {
		"duration": float(rule.get("duration", 5.0)),
		"stacks": 1,
		"max_stacks": 1
	})


func _apply_boss_core_trap_bonus_damage(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("boss_core_trap_bonus_damage"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not (_is_boss(target) or _is_boss_core(target)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("boss_core_trap_bonus_damage", {}))
	var key: String = "boss_core_trap_bonus:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_boss_core_trap_bonus_cooldowns.get(key, 0.0)):
		return
	_boss_core_trap_bonus_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 3.0)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.boss_core_trap_bonus_intents(rules, context, maxi(int(rule.get("amount", 28)), 0)))


func _apply_trap_hit_explosion(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("trap_hit_explosion"):
		return
	SpecialDamageRuleHandlerScript.execute_trap_hit_explosion(rules, context, _get_skill_damage(context))


func _apply_trap_kill_fragment_field(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("trap_kill_fragment_field"):
		return
	var enemy: Node = context.get("enemy") as Node
	if enemy == null or _is_elite(enemy) or _is_boss(enemy):
		return
	SpecialDamageRuleHandlerScript.execute_trap_kill_fragment_field(rules, context)


func _apply_decoy_trap_spawn(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("decoy_trap_spawn"):
		return
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("decoy_trap_spawn", {}))
	var key: String = "decoy_trap:%s" % str(caster.get_instance_id())
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_decoy_trap_spawn_cooldowns.get(key, 0.0)):
		return
	_decoy_trap_spawn_cooldowns[key] = now_seconds + maxf(float(rule.get("spawn_interval", 10.0)), 0.05)
	SpecialDamageRuleHandlerScript.execute_decoy_trap_spawn(rules, context)


func _apply_flame_core_direct_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("flame_core_on_elite_boss_direct_hit", {}))
	if rule.is_empty():
		return
	var stacks: int = int(target.call("get_status_stack", StringName(String(rule.get("status_id", "flame_core")))))
	if stacks <= 0:
		return
	var per_stack: float = float(rule.get("direct_damage_multiplier_add_per_stack", 0.0))
	if per_stack == 0.0:
		return
	packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + per_stack * float(stacks)


func _get_chill_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return params


func _get_charge_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return params


func _get_holy_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty() or not rules.has("holy_mark_tuning"):
		return params
	var rule: Dictionary = _get_dictionary(rules.get("holy_mark_tuning", {}))
	params["duration"] = float(params.get("duration", 4.0)) + float(rule.get("duration_add", 0.0))
	return params


func _get_shock_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return params
	var rule: Dictionary = _get_dictionary(rules.get("shock_upgrade", {}))
	if rule.is_empty():
		return params
	params["duration"] = float(params.get("duration", 0.8)) + float(rule.get("duration_add", 0.0))
	return params


func _get_arcane_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	return params


func _get_arcane_seal_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return params
	params["duration"] = float(params.get("duration", 5.0)) + float(rules.get("arcane_seal_duration_add", 0.0))
	return params


func _get_hunter_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return params
	var rule: Dictionary = _get_dictionary(rules.get("hunter_mark_tuning", {}))
	if rule.is_empty():
		return params
	params["duration"] = float(params.get("duration", 5.0)) + float(rule.get("duration_add", 0.0))
	params["max_stacks"] = maxi(int(params.get("max_stacks", 1)) + int(rule.get("max_stacks_add", 0)), 1)
	return params


func _get_wound_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return params
	var rule: Dictionary = _get_dictionary(rules.get("wound_tuning", {}))
	if rule.is_empty():
		return params
	params["duration"] = float(params.get("duration", 5.0)) + float(rule.get("duration_add", 0.0))
	return params


func _get_bleed_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	if rules.is_empty():
		return params
	var rule: Dictionary = _get_dictionary(rules.get("bleed_moving_target_bonus", {}))
	var target: Node = context.get("target") as Node
	if not rule.is_empty() and _is_target_moving(target):
		var base_damage: int = int(params.get("damage", params.get("tick_damage", 0)))
		if base_damage > 0:
			params["damage"] = maxi(roundi(float(base_damage) * maxf(1.0 + float(rule.get("damage_multiplier_add", 0.2)), 0.0)), 0)
	if _is_boss(target):
		var boss_multiplier: float = float(params.get("boss_damage_multiplier", 0.65))
		var base_boss_damage: int = int(params.get("damage", params.get("tick_damage", 0)))
		if base_boss_damage > 0:
			params["damage"] = maxi(roundi(float(base_boss_damage) * maxf(boss_multiplier, 0.0)), 0)
	return params


func _apply_boss_poise_upgrade_meta(context: Dictionary) -> void:
	var rules: Dictionary = _get_rules(context)
	if not rules.has("boss_poise_upgrade"):
		return
	var target: Node = context.get("target") as Node
	if not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("boss_poise_upgrade", {}))
	target.set_meta("boss_poise_duration_add", maxf(float(rule.get("duration_add", 2.0)), 0.0))


func _apply_boss_poise_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if not rules.has("boss_poise_upgrade") or not _is_boss(target):
		return
	if _now_seconds() > float(target.get_meta("boss_poise_window_until", -1.0)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("boss_poise_upgrade", {}))
	packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(rule.get("damage_multiplier_add", 0.08))


func _apply_storm_hail_boss_modifier(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node) -> void:
	if not rules.has("storm_hail_every_n_casts") or not _is_boss(target):
		return
	var projectile: Node = context.get("projectile") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if projectile == null or skill_instance == null:
		return
	if String(projectile.get_meta("cast_instance_id", "")) != String(skill_instance.get_meta("storm_hail_cast_instance_id", "")):
		return
	var rule: Dictionary = _get_dictionary(rules.get("storm_hail_every_n_casts", {}))
	packet["boss_damage_multiplier_add"] = float(packet.get("boss_damage_multiplier_add", 0.0)) + float(rule.get("boss_damage_multiplier", 0.8)) - 1.0


func _apply_arcane_seal_burst_vulnerability(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if not rules.has("arcane_seal_burst_vulnerability") or target == null:
		return
	if _now_seconds() > float(target.get_meta("arcane_seal_burst_vulnerability_until", -1.0)):
		return
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(target.get_meta("arcane_seal_burst_primary_attack_damage_taken_multiplier_add", 0.0))


func _apply_forbidden_page_damage_bonus(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node) -> void:
	if rules.has("forbidden_page_risk"):
		var risk_rule: Dictionary = _get_dictionary(rules.get("forbidden_page_risk", {}))
		packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(risk_rule.get("damage_multiplier_add", 0.0))
	var projectile: Node = context.get("projectile") as Node
	if projectile != null and bool(projectile.get_meta("forbidden_page", false)):
		var forbidden_rule: Dictionary = _get_dictionary(rules.get("forbidden_page_every_n_casts", {}))
		packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(forbidden_rule.get("damage_multiplier_add", 0.0))
		var upgrade_rule: Dictionary = _get_dictionary(rules.get("forbidden_page_upgrade", {}))
		if not upgrade_rule.is_empty():
			packet["crit_chance_add"] = float(packet.get("crit_chance_add", 0.0)) + float(upgrade_rule.get("crit_chance_add", 0.0))
	if target != null and _is_boss(target) and rules.has("forbidden_boss_stack"):
		var boss_rule: Dictionary = _get_dictionary(rules.get("forbidden_boss_stack", {}))
		var stacks: int = int(target.get_meta("forbidden_boss_stacks", 0))
		packet["boss_damage_multiplier_add"] = float(packet.get("boss_damage_multiplier_add", 0.0)) + float(stacks) * float(boss_rule.get("boss_damage_multiplier_add_per_stack", 0.0))


func _apply_low_hp_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if not rules.has("low_hp_damage_bonus") or target == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("low_hp_damage_bonus", {}))
	if _health_ratio(target) <= float(rule.get("hp_threshold", 0.35)):
		packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(rule.get("damage_multiplier_add", 0.15))


func _apply_same_target_short_window_decay(packet: Dictionary, rules: Dictionary, context: Dictionary, packet_object: RefCounted, target: Node) -> void:
	if not rules.has("same_target_short_window_decay") or target == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("same_target_short_window_decay", {}))
	var now_seconds: float = _now_seconds()
	var window: float = maxf(float(rule.get("window", 0.25)), 0.0)
	var key: String = "throwing_knife_short_window_%s" % _target_key(target)
	var last_hit_at: float = float(target.get_meta(key, -9999.0))
	target.set_meta(key, now_seconds)
	if now_seconds - last_hit_at <= window:
		packet["special_final_modifier"] = float(packet_object.call("get_value", "special_final_modifier", 1.0)) * maxf(float(rule.get("second_hit_multiplier", 0.6)), 0.0)
		packet["special_final_modifier_source"] = "target_passive"


func _apply_execution_mark_crit_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if not rules.has("execution_mark_crit_damage_taken") or target == null:
		return
	if not bool(target.get_meta("throwing_knife_execution_mark", false)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("execution_mark_crit_damage_taken", {}))
	packet["crit_damage_add"] = float(packet.get("crit_damage_add", 0.0)) + float(rule.get("crit_damage_taken_add", 0.25))


func _apply_next_knife_damage_after_kill(packet: Dictionary, rules: Dictionary, context: Dictionary) -> void:
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


func _apply_hunter_arrow_pierce_damage(packet: Dictionary, rules: Dictionary, context: Dictionary, packet_object: RefCounted) -> void:
	if not rules.has("hunter_arrow_pierce_tuning") and not rules.has("cloud_arrow_every_n_casts"):
		return
	var projectile: Node = context.get("projectile") as Node
	if projectile == null:
		return
	var hit_count: int = int(projectile.get_meta("hunter_arrow_hit_count", 0)) + 1
	projectile.set_meta("hunter_arrow_hit_count", hit_count)
	var multiplier_per_extra_hit: float = 0.85
	if rules.has("hunter_arrow_pierce_tuning"):
		var rule: Dictionary = _get_dictionary(rules.get("hunter_arrow_pierce_tuning", {}))
		multiplier_per_extra_hit = float(rule.get("pierce_damage_multiplier_per_extra_hit", multiplier_per_extra_hit))
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance != null and bool(skill_instance.get_meta("hunter_cloud_arrow_active", false)):
		var cloud_rule: Dictionary = _get_dictionary(rules.get("cloud_arrow_every_n_casts", {}))
		multiplier_per_extra_hit = float(cloud_rule.get("pierce_damage_multiplier_per_extra_hit", 0.82))
	var extra_hits: int = maxi(hit_count - 1, 0)
	if extra_hits <= 0:
		return
	var final_multiplier: float = pow(maxf(multiplier_per_extra_hit, 0.0), extra_hits)
	packet["special_final_modifier"] = float(packet_object.call("get_value", "special_final_modifier", 1.0)) * final_multiplier
	packet["special_final_modifier_source"] = "target_passive"


func _apply_hunter_mark_damage_taken(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if not rules.has("eagle_mark_primary_damage_taken") and not rules.has("hunter_mark_primary_damage_taken"):
		return
	if target == null or not target.has_method("has_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("eagle_mark_primary_damage_taken", rules.get("hunter_mark_primary_damage_taken", {})))
	if not bool(target.call("has_status", StringName(String(rule.get("status_id", "eagle_mark"))))):
		return
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("primary_attack_damage_taken_multiplier_add", 0.15))


func _apply_holy_mark_holy_vulnerability(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	if not rules.has("holy_mark_holy_vulnerability") or target == null or packet_object == null:
		return
	if not target.has_method("has_status") or not bool(target.call("has_status", &"holy_mark")):
		return
	if String(packet_object.call("get_value", "element", "")) != "holy":
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_mark_holy_vulnerability", {}))
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("holy_damage_taken_multiplier_add", 0.08))


func _apply_warhammer_low_hp_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if not rules.has("warhammer_low_hp_damage_bonus") or target == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("warhammer_low_hp_damage_bonus", {}))
	if _health_ratio(target) <= float(rule.get("hp_threshold", 0.4)):
		packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(rule.get("damage_multiplier_add", 0.25))


func _apply_warhammer_stun_target_damage_taken(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if not rules.has("warhammer_stun_target_damage_taken") or target == null:
		return
	if not target.has_method("has_status") or not bool(target.call("has_status", &"stun")):
		return
	var rule: Dictionary = _get_dictionary(rules.get("warhammer_stun_target_damage_taken", {}))
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("primary_attack_damage_taken_multiplier_add", 0.15))


func _apply_cross_relic_dot_target_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	if not rules.has("cross_relic_dot_target_damage_bonus") and not rules.has("cross_relic_purify_impurity"):
		return
	if target == null or packet_object == null:
		return
	if String(packet_object.call("get_value", "damage_origin", "")) != "field":
		return
	if not target.has_method("has_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_dot_target_damage_bonus", {}))
	if rule.is_empty():
		return
	for status_variant: Variant in _get_array(rule.get("status_ids", ["burn", "poison", "bleed"])):
		if bool(target.call("has_status", StringName(String(status_variant)))):
			packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(rule.get("damage_multiplier_add", 0.15))
			return


func _apply_cross_relic_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("cross_relic_base"):
		return
	if String(context.get("source_id", "")) != "holy_field_area":
		return
	_apply_cross_relic_impurity_on_field_tick(rules, context)
	SpecialDamageRuleHandlerScript.execute_cross_relic_field_tick(rules, context)


func _apply_cross_relic_impurity_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("cross_relic_impurity_on_field_tick"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_impurity_on_field_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "impurity"))), {
		"duration": float(rule.get("duration", 4.0)),
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 3)), 1)
	})


func _prepare_acid_pressure_cast(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("acid_pressure_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("acid_pressure_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 4)), 1)
	var cast_count: int = int(skill_instance.get_meta("acid_pressure_cast_count", 0)) + 1
	skill_instance.set_meta("acid_pressure_cast_count", cast_count)
	skill_instance.set_meta("acid_pressure_next_cast", cast_count % interval == 0)


func _apply_acid_spray_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("acid_sprayer_base"):
		return
	if String(context.get("source_id", "")) != "acid_spray_cone_area":
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	_apply_acid_mark_on_strong_tick(rules, target)
	_apply_acid_residue_on_tick(rules, target)
	_apply_acid_hit_shield(rules, context)
	_apply_boss_acid_mark_armor_break_pulse(rules, target)
	_apply_acid_burst_on_full_status(rules, context, target)


func _apply_acid_mark_on_strong_tick(rules: Dictionary, target: Node) -> void:
	if not rules.has("acid_mark_on_strong_acid_tick") or target == null or not target.has_method("apply_status"):
		return
	if not (_is_elite(target) or _is_boss(target)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("acid_mark_on_strong_acid_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "acid_mark"))), {
		"duration": float(rule.get("duration", 4.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 5)), 1)
	})


func _apply_acid_residue_on_tick(rules: Dictionary, target: Node) -> void:
	if not rules.has("acid_residue_on_acid_tick") or target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("acid_residue_on_acid_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "acid_residue"))), {
		"duration": float(rule.get("duration", 5.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 5)), 1)
	})


func _apply_acid_burst_on_full_status(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if target == null or not target.has_method("get_status_stack"):
		return
	var trigger_rule: Dictionary = _get_dictionary(rules.get("acid_burst_on_full_acid_mark_hit", {}))
	if trigger_rule.is_empty():
		trigger_rule = _get_dictionary(rules.get("acid_burst_on_full_acid_residue_hit", {}))
	if trigger_rule.is_empty():
		return
	var status_id: StringName = StringName(String(trigger_rule.get("required_status_id", "acid_mark")))
	var required: int = maxi(int(trigger_rule.get("required_stacks", 5)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return
	var cooldown_rule: Dictionary = _get_dictionary(rules.get("acid_burst_cooldown_tuning", {}))
	var cooldown: float = maxf(float(cooldown_rule.get("same_target_cooldown", trigger_rule.get("same_target_cooldown", 2.0))), 0.0)
	var key: String = "acid_burst:%s:%s:%s" % [String(context.get("source_instance_id", "")), String(status_id), _target_key(target)]
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_acid_burst_cooldowns.get(key, 0.0)):
		return
	_acid_burst_cooldowns[key] = now_seconds + cooldown
	SpecialDamageRuleHandlerScript.execute_acid_burst(rules, context)


func _apply_acid_hit_shield(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("acid_hit_shield"):
		return
	var caster: Node = context.get("caster") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if caster == null or skill_instance == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("acid_hit_shield", {}))
	var hits_required: int = maxi(int(rule.get("hits_required", 5)), 1)
	var hit_count: int = int(skill_instance.get_meta("acid_hit_shield_count", 0)) + 1
	if hit_count < hits_required:
		skill_instance.set_meta("acid_hit_shield_count", hit_count)
		return
	skill_instance.set_meta("acid_hit_shield_count", 0)
	SpecialDamageRuleHandlerScript.grant_corrosive_film(rules, context, caster, int(rule.get("shield_value", 8)), float(rule.get("shield_duration", 4.0)))


func _apply_boss_acid_mark_armor_break_pulse(rules: Dictionary, target: Node) -> void:
	if not rules.has("boss_acid_mark_armor_break_pulse") or not _is_boss(target):
		return
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("boss_acid_mark_armor_break_pulse", {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "acid_mark")))
	var required: int = maxi(int(rule.get("required_stacks", 5)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return
	var interval: int = maxi(int(rule.get("tick_interval", 3)), 1)
	var key: String = "boss_acid_mark:%s" % _target_key(target)
	var tick_count: int = int(_boss_acid_mark_pulse_counts.get(key, 0)) + 1
	_boss_acid_mark_pulse_counts[key] = tick_count
	if tick_count % interval != 0:
		return
	target.set_meta("acid_boss_defense_reduction", maxf(float(rule.get("defense_reduction", 2.0)), 0.0))
	target.set_meta("acid_boss_defense_reduction_until", _now_seconds() + maxf(float(rule.get("duration", 3.0)), 0.0))


func _update_corrosive_film(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("corrosive_film_nearby_acid_mark"):
		return
	var player: Node2D = context.get("caster", context.get("player")) as Node2D
	if player == null:
		return
	if float(player.get_meta("corrosive_film_shield_points", 0)) <= 0.0:
		return
	if _now_seconds() > float(player.get_meta("corrosive_film_until", 0.0)):
		player.set_meta("corrosive_film_shield_points", 0)
		return
	var rule: Dictionary = _get_dictionary(rules.get("corrosive_film_nearby_acid_mark", {}))
	var interval: float = maxf(float(rule.get("interval", 1.0)), 0.05)
	var next_at: float = float(player.get_meta("corrosive_film_next_corrosion_at", 0.0))
	var now_seconds: float = _now_seconds()
	if now_seconds < next_at:
		return
	player.set_meta("corrosive_film_next_corrosion_at", now_seconds + interval)
	var radius: float = maxf(float(rule.get("radius", 120.0)), 1.0)
	var tree: SceneTree = player.get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not enemy.has_method("apply_status"):
			continue
		if player.global_position.distance_squared_to(enemy.global_position) > radius * radius:
			continue
		enemy.call("apply_status", StringName(String(rule.get("status_id", "acid_mark"))), {
			"duration": float(rule.get("duration", 4.0)),
			"stacks": maxi(int(rule.get("stacks", 1)), 1),
			"max_stacks": maxi(int(rule.get("max_stacks", 3)), 1)
		})


func _apply_corrosive_film_on_boss_skill_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("corrosive_film_on_boss_skill_hit"):
		return
	if not _is_boss_damage_source(context):
		return
	var player: Node = context.get("player", context.get("caster")) as Node
	if player == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("corrosive_film_on_boss_skill_hit", {}))
	var key: String = "corrosive_film_boss:%s" % _target_key(player)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_corrosive_film_boss_hit_cooldowns.get(key, 0.0)):
		return
	_corrosive_film_boss_hit_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 18.0)), 0.0)
	SpecialDamageRuleHandlerScript.grant_corrosive_film(rules, context, player, int(rule.get("shield_value", 8)), float(rule.get("shield_duration", 4.0)))


func _apply_acid_mark_vulnerability(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if not rules.has("acid_mark_vulnerability") or target == null or not target.has_method("get_status_stack"):
		return
	var stacks: int = int(target.call("get_status_stack", &"acid_mark"))
	if stacks <= 0:
		return
	var rule: Dictionary = _get_dictionary(rules.get("acid_mark_vulnerability", {}))
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("damage_taken_multiplier_add_per_stack", 0.005)) * float(stacks)


func _is_boss_damage_source(context: Dictionary) -> bool:
	var source_packet: Variant = context.get("source_packet", {})
	if source_packet is Dictionary:
		var packet: Dictionary = source_packet
		for key in ["source_id", "source_origin_id", "source_skill_id", "source_instance_id", "attacker_id"]:
			if String(packet.get(key, "")).to_lower().find("boss") >= 0:
				return true
	var result: Variant = context.get("damage_result", {})
	if result is Dictionary:
		var result_dict: Dictionary = result
		for key in ["source_id", "source_origin_id", "source_skill_id", "source_instance_id", "attacker_id"]:
			if String(result_dict.get(key, "")).to_lower().find("boss") >= 0:
				return true
	return false


func _apply_fire_oil_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("fire_oil_canister_base"):
		return
	var source_id: String = String(context.get("source_id", ""))
	if source_id != "fire_oil_area" and source_id != "smoke_cloud_area":
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	if source_id == "smoke_cloud_area":
		_apply_smoke_cloud_target_effects(rules, target)
		return
	_apply_burn_in_merged_oil(rules, context, target)
	_apply_flammable_mark_on_oil_tick(rules, target)
	_apply_oil_stack_on_fire_oil_tick(rules, target)
	if rules.has("fire_oil_burn_damage_in_big_oil"):
		var burn_rule: Dictionary = _get_dictionary(rules.get("fire_oil_burn_damage_in_big_oil", {}))
		target.set_meta("fire_oil_burn_damage_until", _now_seconds() + 0.75)
		target.set_meta("fire_oil_burn_damage_multiplier_add", float(burn_rule.get("burn_damage_multiplier_add", 0.3)))
		target.set_meta("fire_oil_boss_burn_damage_multiplier", float(burn_rule.get("boss_burn_damage_multiplier", 0.7)))
	if rules.has("flammable_mark_burst_on_full_mark_tick"):
		_apply_flammable_mark_burst(rules, context, target)
	if rules.has("oil_fire_deflagration"):
		_apply_fire_oil_deflagration(rules, context, target)


func _apply_burn_in_merged_oil(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if not rules.has("burn_in_merged_oil") or target == null or not target.has_method("apply_status"):
		return
	var area: Node = context.get("area") as Node
	if area == null or not bool(area.get_meta("fire_oil_merged_area", false)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("burn_in_merged_oil", {}))
	var key: String = "burn_in_merged_oil:%s:%s" % [str(area.get_instance_id()), _target_key(target)]
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_fire_oil_burn_in_merged_oil_cooldowns.get(key, 0.0)):
		return
	_fire_oil_burn_in_merged_oil_cooldowns[key] = now_seconds + maxf(float(rule.get("interval", 1.5)), 0.05)
	target.call("apply_status", StringName(String(rule.get("status_id", "burn"))), {
		"duration": float(rule.get("duration", 3.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1)
	})


func _apply_flammable_mark_on_oil_tick(rules: Dictionary, target: Node) -> void:
	if not rules.has("flammable_mark_on_strong_oil_tick") or target == null or not target.has_method("apply_status"):
		return
	if not (_is_elite(target) or _is_boss(target)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("flammable_mark_on_strong_oil_tick", {}))
	var duration: float = float(rule.get("duration", 4.0))
	if _is_boss(target) and rules.has("flammable_mark_boss_tuning"):
		duration += float(_get_dictionary(rules.get("flammable_mark_boss_tuning", {})).get("duration_add", 1.0))
	target.call("apply_status", StringName(String(rule.get("status_id", "flammable_mark"))), {
		"duration": duration,
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 5)), 1)
	})


func _apply_oil_stack_on_fire_oil_tick(rules: Dictionary, target: Node) -> void:
	if not rules.has("oil_stack_on_fire_oil_tick") or target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("oil_stack_on_fire_oil_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "oil_stack"))), {
		"duration": float(rule.get("duration", 4.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 3)), 1)
	})


func _apply_fire_oil_deflagration(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("oil_fire_deflagration", {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "oil_stack")))
	var required: int = maxi(int(rule.get("required_stacks", 3)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return
	var area: Node = context.get("area") as Node
	var key: String = "fire_oil_deflagration:%s:%s" % [String(context.get("source_instance_id", "")), _target_key(target)]
	var upgrade: Dictionary = _get_dictionary(rules.get("deflagration_upgrade", {}))
	var cooldown: float = maxf(float(upgrade.get("same_source_cooldown", rule.get("same_source_cooldown", 1.2))), 0.0)
	var now_seconds: float = _now_seconds()
	if area != null:
		var cooldowns: Dictionary = {}
		var value: Variant = area.get_meta("fire_oil_deflagration_cooldowns", {})
		if value is Dictionary:
			cooldowns = (value as Dictionary).duplicate(true)
		if now_seconds < float(cooldowns.get(key, 0.0)):
			return
		cooldowns[key] = now_seconds + cooldown
		area.set_meta("fire_oil_deflagration_cooldowns", cooldowns)
	SpecialDamageRuleHandlerScript.execute_fire_oil_deflagration(rules, context)


func _apply_flammable_mark_burst(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if target == null or not target.has_method("get_status_stack"):
		return
	if not (_is_elite(target) or _is_boss(target)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("flammable_mark_burst_on_full_mark_tick", {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "flammable_mark")))
	if int(target.call("get_status_stack", status_id)) < maxi(int(rule.get("required_stacks", 5)), 1):
		return
	var key: String = "flammable_burst:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_fire_oil_flammable_burst_cooldowns.get(key, 0.0)):
		return
	_fire_oil_flammable_burst_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.fire_oil_flammable_burst_intents(rules, context, maxi(int(rule.get("amount", 14)), 0)))
	if _is_boss(target) and rules.has("flammable_burst_boss_poise"):
		_apply_flammable_burst_boss_poise(rules, target)


func _apply_smoke_cloud_target_effects(rules: Dictionary, target: Node) -> void:
	if target == null:
		return
	if rules.has("smoke_enemy_damage_down") and (not _is_boss(target)) and (not _is_elite(target)):
		var damage_rule: Dictionary = _get_dictionary(rules.get("smoke_enemy_damage_down", {}))
		target.set_meta("fire_oil_smoke_enemy_damage_down_until", _now_seconds() + maxf(float(damage_rule.get("duration", 0.6)), 0.0))
		target.set_meta("fire_oil_smoke_enemy_damage_multiplier_add", float(damage_rule.get("damage_multiplier_add", -0.15)))


func _apply_smoke_cloud_on_oil_expire(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("smoke_cloud_on_oil_expire"):
		return
	if String(context.get("source_id", "")) != "fire_oil_area":
		return
	SpecialDamageRuleHandlerScript.execute_smoke_cloud(rules, context, _get_dictionary(rules.get("smoke_cloud_on_oil_expire", {})), "fire_oil_smoke_expire")


func _apply_smoke_cloud_on_player_damaged(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("smoke_cloud_on_player_damaged"):
		return
	var player: Node = context.get("player", context.get("caster")) as Node
	if player == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("smoke_cloud_on_player_damaged", {}))
	var key: String = "smoke_damage:%s" % _target_key(player)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_smoke_cloud_player_damaged_cooldowns.get(key, 0.0)):
		return
	_smoke_cloud_player_damaged_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 16.0)), 0.0)
	SpecialDamageRuleHandlerScript.execute_smoke_cloud(rules, context, rule, "fire_oil_smoke_player_damaged")


func _update_fire_oil_smoke_player_buff(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("smoke_player_speed_buff"):
		return
	var player: Node2D = context.get("caster") as Node2D
	if player == null:
		return
	var inside_smoke: bool = false
	var tree: SceneTree = player.get_tree()
	if tree != null:
		for node: Node in tree.get_nodes_in_group(&"areas"):
			var area: Node2D = node as Node2D
			if area == null or not bool(area.get_meta("fire_oil_smoke_cloud", false)):
				continue
			var radius: float = maxf(float(area.get_meta("fire_oil_smoke_radius", 95.0)), 1.0)
			if player.global_position.distance_squared_to(area.global_position) <= radius * radius:
				inside_smoke = true
				break
	var modifier_id: String = "fire_oil_smoke_speed"
	if inside_smoke:
		var rule: Dictionary = _get_dictionary(rules.get("smoke_player_speed_buff", {}))
		var modifiers: Array = [{
			"stat": "move_speed",
			"op": "multiplier_add",
			"value": float(rule.get("move_speed_multiplier_add", 0.08)),
			"scope": {"domain": "player"}
		}]
		if player.has_method("set_run_modifier_source"):
			player.call("set_run_modifier_source", modifier_id, modifiers)
		player.set_meta("fire_oil_smoke_speed_until", _now_seconds() + maxf(float(rule.get("duration", 0.6)), 0.0))
	elif _now_seconds() > float(player.get_meta("fire_oil_smoke_speed_until", 0.0)) and player.has_method("clear_run_modifier_source"):
		player.call("clear_run_modifier_source", modifier_id)


func _apply_flammable_mark_fire_vulnerability(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	if not rules.has("flammable_mark_fire_vulnerability") or target == null or packet_object == null:
		return
	if String(packet_object.call("get_value", "element", "")) != "fire":
		return
	if not target.has_method("get_status_stack"):
		return
	var stacks: int = int(target.call("get_status_stack", &"flammable_mark"))
	if stacks <= 0:
		return
	var rule: Dictionary = _get_dictionary(rules.get("flammable_mark_fire_vulnerability", {}))
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("fire_damage_taken_multiplier_add_per_stack", 0.01)) * float(stacks)


func _apply_flammable_burst_boss_poise(rules: Dictionary, target: Node) -> void:
	if target == null or not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("flammable_burst_boss_poise", {}))
	var key: String = "flammable_burst_poise:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_fire_oil_flammable_poise_cooldowns.get(key, 0.0)):
		return
	_fire_oil_flammable_poise_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.5)), 0.0)
	for _i in range(maxi(int(rule.get("stacks", 1)), 1)):
		ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")


func _get_flammable_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	if _is_boss(context.get("target") as Node) and rules.has("flammable_mark_boss_tuning"):
		params["duration"] = float(params.get("duration", 4.0)) + float(_get_dictionary(rules.get("flammable_mark_boss_tuning", {})).get("duration_add", 1.0))
	return params


func _apply_toxic_vial_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("toxic_vial_base"):
		return
	if String(context.get("source_id", "")) != "poison_cloud_area":
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	_apply_toxin_seed_on_poison_cloud_tick(rules, target)
	_apply_toxic_core_on_poison_cloud_tick(rules, target)
	_convert_toxic_vial_status_to_poison(rules, context, target, "toxin_seed_to_poison")
	_convert_toxic_vial_status_to_poison(rules, context, target, "toxic_core_to_poison")
	_apply_poison_on_cloud_tick_chance(rules, context, target)
	_apply_poison_cloud_stable_effects(rules, target)
	_apply_toxic_core_boss_pulse(rules, context, target)


func _apply_toxin_seed_on_poison_cloud_tick(rules: Dictionary, target: Node) -> void:
	if not rules.has("toxin_seed_on_poison_cloud_tick") or target == null or not target.has_method("apply_status"):
		return
	if _is_elite(target) or _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("toxin_seed_on_poison_cloud_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "toxin_seed"))), {
		"duration": float(rule.get("duration", 5.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 4)), 1)
	})


func _apply_toxic_core_on_poison_cloud_tick(rules: Dictionary, target: Node) -> void:
	if not rules.has("toxic_core_on_strong_cloud_tick") or target == null or not target.has_method("apply_status"):
		return
	if not (_is_elite(target) or _is_boss(target)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("toxic_core_on_strong_cloud_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "toxic_core"))), {
		"duration": float(rule.get("duration", 5.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 4)), 1)
	})


func _convert_toxic_vial_status_to_poison(rules: Dictionary, context: Dictionary, target: Node, rule_key: String) -> void:
	if not rules.has(rule_key) or target == null or not target.has_method("get_status_stack") or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get(rule_key, {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "toxin_seed")))
	var required: int = maxi(int(rule.get("required_stacks", 4)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return
	if target.has_method("consume_status_stack"):
		var consume_count: int = 99 if bool(rule.get("consume_all", true)) else required
		target.call("consume_status_stack", status_id, consume_count)
	_apply_poison_status_from_toxic_vial(rules, context, target, maxi(int(rule.get("apply_stacks", 1)), 1))


func _apply_poison_on_cloud_tick_chance(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if not rules.has("poison_on_cloud_tick_chance") or target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("poison_on_cloud_tick_chance", {}))
	var key: String = "poison_cloud_tick:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_poison_cloud_tick_poison_cooldowns.get(key, 0.0)):
		return
	if randf() > clampf(float(rule.get("chance", 0.2)), 0.0, 1.0):
		return
	_poison_cloud_tick_poison_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.0)), 0.0)
	_apply_poison_status_from_toxic_vial(rules, context, target, maxi(int(rule.get("stacks", 1)), 1))


func _apply_poison_status_from_toxic_vial(rules: Dictionary, context: Dictionary, target: Node, stacks: int) -> void:
	var base: Dictionary = _get_dictionary(rules.get("toxic_vial_base", {}))
	var poison_params: Dictionary = _get_poison_status_params({
		"duration": float(base.get("poison_duration", 4.0)),
		"damage": int(base.get("poison_damage", 6)),
		"tick_interval": float(base.get("poison_tick_interval", 0.5)),
		"stacks": 1,
		"max_stacks": int(base.get("poison_max_stacks", 3))
	}, context.merged({"target": target}))
	poison_params["stacks"] = maxi(stacks, 1)
	target.call("apply_status", &"poison", poison_params)


func _apply_poison_cloud_stable_effects(rules: Dictionary, target: Node) -> void:
	var now_seconds: float = _now_seconds()
	if rules.has("poison_cloud_enemy_damage_down"):
		var damage_rule: Dictionary = _get_dictionary(rules.get("poison_cloud_enemy_damage_down", {}))
		target.set_meta("toxic_vial_enemy_damage_down_until", now_seconds + maxf(float(damage_rule.get("duration", 0.6)), 0.0))
		target.set_meta("toxic_vial_enemy_damage_multiplier_add", float(damage_rule.get("damage_multiplier_add", -0.08)))
	if rules.has("poison_cloud_slow") and target.has_method("apply_status"):
		var slow_rule: Dictionary = _get_dictionary(rules.get("poison_cloud_slow", {}))
		target.call("apply_status", StringName(String(slow_rule.get("status_id", "slow"))), {
			"duration": float(slow_rule.get("duration", 0.6)),
			"slow_percent": float(slow_rule.get("slow_percent", 0.15)),
			"boss_slow_percent": float(slow_rule.get("boss_slow_percent", 0.08))
		})


func _apply_toxic_core_boss_pulse(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if not rules.has("toxic_core_boss_pulse") or not _is_boss(target):
		return
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("toxic_core_boss_pulse", {}))
	var required_status: StringName = StringName(String(rule.get("required_status_id", "poison")))
	var max_stacks: int = _poison_max_stacks_for_target(rules, target)
	if bool(rule.get("required_full_poison", true)) and int(target.call("get_status_stack", required_status)) < max_stacks:
		return
	var key: String = "toxic_core:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_toxic_core_boss_pulse_cooldowns.get(key, 0.0)):
		return
	_toxic_core_boss_pulse_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.execute_toxic_core_boss_pulse(rules, context, maxi(int(rule.get("amount", 20)), 0)))


func _apply_toxic_vial_antidote_on_cast(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("antidote_cloud_on_low_hp"):
		return
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("antidote_cloud_on_low_hp", {}))
	if _player_health_ratio(caster) > float(rule.get("hp_threshold", 0.35)):
		return
	var key: String = "antidote:%s" % _target_key(caster)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_antidote_cloud_cooldowns.get(key, 0.0)):
		return
	_antidote_cloud_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 18.0)), 0.0)
	_heal_player(caster, maxi(int(rule.get("heal", 6)), 0))
	SpecialDamageRuleHandlerScript.execute_antidote_cloud(rules, context)


func _update_toxic_vial_player_cloud(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("poison_cloud_edge_speed_buff"):
		return
	var player: Node2D = context.get("caster") as Node2D
	if player == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("poison_cloud_edge_speed_buff", {}))
	var near_edge: bool = false
	var tree: SceneTree = player.get_tree()
	if tree != null:
		for node: Node in tree.get_nodes_in_group(&"areas"):
			var area: Node2D = node as Node2D
			if area == null or not bool(area.get_meta("toxic_vial_poison_cloud", false)):
				continue
			var radius: float = maxf(float(area.get_meta("toxic_vial_poison_cloud_radius", 105.0)), 1.0)
			var edge_width: float = maxf(float(rule.get("edge_width", 24.0)), 1.0)
			var distance: float = player.global_position.distance_to(area.global_position)
			if absf(distance - radius) <= edge_width:
				near_edge = true
				break
	var modifier_id: String = "toxic_vial_edge_speed"
	if near_edge:
		var modifiers: Array = [{
			"stat": "move_speed",
			"op": "multiplier_add",
			"value": float(rule.get("move_speed_multiplier_add", 0.08)),
			"scope": {"domain": "player"}
		}]
		if player.has_method("set_run_modifier_source"):
			player.call("set_run_modifier_source", modifier_id, modifiers)
		player.set_meta("toxic_vial_edge_speed_until", _now_seconds() + maxf(float(rule.get("duration", 1.0)), 0.0))
	elif _now_seconds() > float(player.get_meta("toxic_vial_edge_speed_until", 0.0)) and player.has_method("clear_run_modifier_source"):
		player.call("clear_run_modifier_source", modifier_id)


func _get_poison_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var rules: Dictionary = _get_rules(context)
	var target: Node = context.get("target") as Node
	var base: Dictionary = _get_dictionary(rules.get("toxic_vial_base", {}))
	if not base.is_empty():
		params["duration"] = float(params.get("duration", base.get("poison_duration", 4.0)))
		params["damage"] = int(params.get("damage", base.get("poison_damage", 6)))
		params["tick_interval"] = float(params.get("tick_interval", base.get("poison_tick_interval", 0.5)))
	params["max_stacks"] = _poison_max_stacks_for_target(rules, target)
	if (_is_elite(target) or _is_boss(target)) and rules.has("poison_elite_boss_tuning"):
		var tuning: Dictionary = _get_dictionary(rules.get("poison_elite_boss_tuning", {}))
		params["damage_multiplier_add"] = float(params.get("damage_multiplier_add", 0.0)) + float(tuning.get("elite_boss_dot_multiplier_add", 0.1))
	return params


func _poison_max_stacks_for_target(rules: Dictionary, target: Node) -> int:
	var base: Dictionary = _get_dictionary(rules.get("toxic_vial_base", {}))
	var max_stacks: int = maxi(int(base.get("poison_max_stacks", 3)), 1)
	if rules.has("poison_max_stack_tuning"):
		var tuning: Dictionary = _get_dictionary(rules.get("poison_max_stack_tuning", {}))
		if _is_boss(target):
			max_stacks += int(tuning.get("boss_max_stacks_add", 0))
		else:
			max_stacks += int(tuning.get("max_stacks_add", 0))
	return maxi(max_stacks, 1)


func _apply_warhammer_on_hit(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("warhammer_base"):
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	_apply_warhammer_judgment_status(rules, context, target)
	_apply_warhammer_knockback(rules, context, target)
	_apply_warhammer_stun_or_poise(rules, context, target)
	if _warhammer_source_once(context, "warhammer_crack_field"):
		SpecialDamageRuleHandlerScript.execute_warhammer_crack_field(rules, context)
	_apply_warhammer_judgement_shock(rules, context, target)
	SpecialDamageRuleHandlerScript.execute_warhammer_boss_low_hp_shockwave(rules, context)


func _apply_warhammer_judgment_status(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if not rules.has("judgment_on_strong_hit") or target == null or not target.has_method("apply_status"):
		return
	if not (_is_elite(target) or _is_boss(target)):
		return
	var rule: Dictionary = _get_dictionary(rules.get("judgment_on_strong_hit", {}))
	var key: String = "judgment_on_hit:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_judgment_on_strong_hit_cooldowns.get(key, 0.0)):
		return
	_judgment_on_strong_hit_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.0)), 0.0)
	target.call("apply_status", StringName(String(rule.get("status_id", "judgment"))), {
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 4)), 1),
		"duration": float(rule.get("duration", 5.0))
	})


func _apply_warhammer_knockback(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var target_2d: Node2D = target as Node2D
	if target_2d == null or _is_boss(target):
		return
	var source: Node2D = context.get("source") as Node2D
	if source == null:
		source = context.get("caster") as Node2D
	if source == null:
		return
	var base: Dictionary = _get_dictionary(rules.get("warhammer_base", {}))
	var force: float = float(base.get("knockback", 16.0))
	if rules.has("warhammer_knockback_multiplier"):
		var rule: Dictionary = _get_dictionary(rules.get("warhammer_knockback_multiplier", {}))
		force *= maxf(1.0 + float(rule.get("multiplier_add", 0.25)), 0.0)
	var direction: Vector2 = source.global_position.direction_to(target_2d.global_position)
	if direction != Vector2.ZERO:
		target_2d.global_position += direction.normalized() * force


func _apply_warhammer_stun_or_poise(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var forced: bool = _consume_warhammer_forced_shock(context)
	if not rules.has("warhammer_stun_on_hit") and not forced:
		return
	if _is_boss(target):
		if forced:
			var forced_rule: Dictionary = _get_dictionary(rules.get("warhammer_forced_shock_every_n_seconds", {}))
			for _i in range(maxi(int(forced_rule.get("boss_poise_stacks", 1)), 1)):
				ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")
		elif bool(_get_dictionary(rules.get("warhammer_stun_on_hit", {})).get("boss_converts_to_poise", true)):
			ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")
		return
	if not target.has_method("apply_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("warhammer_stun_on_hit", {}))
	var chance: float = 1.0 if forced else float(rule.get("chance", 0.25))
	if _is_elite(target):
		chance *= float(rule.get("elite_chance_multiplier", 0.5))
	if randf() > clampf(chance, 0.0, 1.0):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "stun"))), {
		"duration": float(rule.get("duration", 0.6)),
		"stacks": 1,
		"max_stacks": 1
	})


func _apply_warhammer_judgement_shock(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if not rules.has("warhammer_judgement_shock") or target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("warhammer_judgement_shock", {}))
	if int(target.call("get_status_stack", &"judgment")) < maxi(int(rule.get("required_stacks", 4)), 1):
		return
	var key: String = "warhammer_judgement:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_warhammer_judgement_shock_cooldowns.get(key, 0.0)):
		return
	_warhammer_judgement_shock_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)
	if _is_boss(target):
		for _i in range(maxi(int(rule.get("boss_poise_stacks", 0)), 0)):
			ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.warhammer_judgement_shock_intents(rules, context, maxi(int(rule.get("amount", 22)), 0), "warhammer_judgement_shock"))
	_apply_warhammer_boss_poise_judgement_bonus(rules, context, target)


func _apply_warhammer_boss_poise_judgement_bonus(rules: Dictionary, context: Dictionary, target: Node) -> void:
	if not rules.has("warhammer_boss_poise_judgement_bonus") or not _is_boss(target):
		return
	var completed_at: float = float(target.get_meta("boss_poise_recently_completed_at", -9999.0))
	if _now_seconds() - completed_at > 4.0:
		return
	var completed_count: int = int(target.get_meta("boss_poise_completed_count", 0))
	var consumed_count: int = int(target.get_meta("warhammer_poise_judgement_consumed_count", 0))
	if completed_count <= consumed_count:
		return
	var rule: Dictionary = _get_dictionary(rules.get("warhammer_boss_poise_judgement_bonus", {}))
	var key: String = "warhammer_boss_poise_judgement:%s" % _target_key(target)
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_warhammer_boss_poise_judgement_bonus_cooldowns.get(key, 0.0)):
		return
	_warhammer_boss_poise_judgement_bonus_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.5)), 0.0)
	target.set_meta("warhammer_poise_judgement_consumed_count", completed_count)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.warhammer_judgement_shock_intents(rules, context, maxi(int(rule.get("amount", 34)), 0), "warhammer_boss_poise_judgement_bonus"))


func _warhammer_source_once(context: Dictionary, source_namespace: String) -> bool:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return true
	var source_instance_id: String = String(context.get("source_instance_id", context.get("source_key", "")))
	if source_instance_id == "":
		source_instance_id = String(context.get("source_id", "warhammer"))
	var meta_key: String = _metadata_key(source_namespace, "sources")
	var seen: Dictionary = {}
	var seen_variant: Variant = skill_instance.get_meta(meta_key, {})
	if seen_variant is Dictionary:
		seen = (seen_variant as Dictionary).duplicate(true)
	if bool(seen.get(source_instance_id, false)):
		return false
	seen[source_instance_id] = true
	skill_instance.set_meta(meta_key, seen)
	return true


func _consume_warhammer_forced_shock(context: Dictionary) -> bool:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("warhammer_forced_shock_active", false)):
		return false
	skill_instance.set_meta("warhammer_forced_shock_active", false)
	return true


func _update_cross_relic_field(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("cross_relic_base"):
		return
	var player: Node2D = context.get("player", context.get("caster")) as Node2D
	if player == null:
		return
	var field: Node2D = _find_cross_relic_field_containing_player(player)
	var now_seconds: float = _now_seconds()
	if field == null:
		player.set_meta("cross_relic_field_reduction_until", 0.0)
		player.set_meta("cross_relic_inside_field_since", -1.0)
		return
	if float(player.get_meta("cross_relic_inside_field_since", -1.0)) < 0.0:
		player.set_meta("cross_relic_inside_field_since", now_seconds)
	var base: Dictionary = _get_dictionary(rules.get("cross_relic_base", {}))
	_apply_cross_relic_field_heal(rules, context, player, now_seconds, base)
	_apply_cross_relic_field_damage_reduction(rules, player, now_seconds)
	_apply_cross_relic_periodic_shield(rules, player, now_seconds)
	_apply_cross_relic_stand_shield(rules, player, now_seconds)
	_apply_cross_relic_low_hp_rescue(rules, player, now_seconds)


func _apply_cross_relic_field_heal(rules: Dictionary, context: Dictionary, player: Node, now_seconds: float, base: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var heal_interval: float = float(base.get("heal_interval", 0.5))
	var heal_amount: int = int(base.get("heal", 1))
	if rules.has("cross_relic_field_heal_upgrade"):
		var heal_rule: Dictionary = _get_dictionary(rules.get("cross_relic_field_heal_upgrade", {}))
		heal_amount += int(heal_rule.get("heal_add", 0))
		heal_interval = float(heal_rule.get("heal_interval", heal_interval))
	if rules.has("cross_relic_shelter_upgrade"):
		var shelter_rule: Dictionary = _get_dictionary(rules.get("cross_relic_shelter_upgrade", {}))
		heal_amount = maxi(roundi(float(heal_amount) * maxf(1.0 + float(shelter_rule.get("heal_multiplier_add", 0.0)), 0.0)), 0)
	if heal_amount <= 0:
		return
	var next_at: float = float(skill_instance.get_meta("cross_relic_next_heal_at", 0.0))
	if now_seconds < next_at:
		return
	skill_instance.set_meta("cross_relic_next_heal_at", now_seconds + maxf(heal_interval, 0.05))
	_heal_player(player, heal_amount)


func _apply_cross_relic_field_damage_reduction(rules: Dictionary, player: Node, now_seconds: float) -> void:
	if not rules.has("cross_relic_field_damage_reduction"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_field_damage_reduction", {}))
	player.set_meta("cross_relic_field_reduction_until", now_seconds + 0.25)
	player.set_meta("cross_relic_field_damage_taken_multiplier_add", float(rule.get("damage_taken_multiplier_add", -0.08)))


func _apply_cross_relic_periodic_shield(rules: Dictionary, player: Node, now_seconds: float) -> void:
	if not rules.has("cross_relic_periodic_shield"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_periodic_shield", {}))
	var key: String = "periodic:%s" % str(player.get_instance_id())
	var next_at: float = float(_cross_relic_periodic_shield_timers.get(key, 0.0))
	if now_seconds < next_at:
		return
	_cross_relic_periodic_shield_timers[key] = now_seconds + maxf(float(rule.get("interval", 2.0)), 0.05)
	_grant_cross_relic_shield(player, int(rule.get("shield_value", 5)), rules)


func _apply_cross_relic_stand_shield(rules: Dictionary, player: Node, now_seconds: float) -> void:
	if not rules.has("cross_relic_stand_shield"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_stand_shield", {}))
	var inside_since: float = float(player.get_meta("cross_relic_inside_field_since", now_seconds))
	if now_seconds - inside_since < float(rule.get("required_stand_time", 2.0)):
		return
	var key: String = "stand:%s" % str(player.get_instance_id())
	if now_seconds < float(_cross_relic_stand_shield_cooldowns.get(key, 0.0)):
		return
	_cross_relic_stand_shield_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 12.0)), 0.0)
	_grant_cross_relic_shield(player, int(rule.get("shield_value", 12)), rules)


func _apply_cross_relic_low_hp_rescue(rules: Dictionary, player: Node, now_seconds: float) -> void:
	if not rules.has("cross_relic_low_hp_rescue"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_low_hp_rescue", {}))
	if _player_health_ratio(player) > float(rule.get("hp_threshold", 0.35)):
		return
	var key: String = "rescue:%s" % str(player.get_instance_id())
	if now_seconds < float(_cross_relic_low_hp_rescue_cooldowns.get(key, 0.0)):
		return
	_cross_relic_low_hp_rescue_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 20.0)), 0.0)
	_heal_player(player, int(rule.get("heal", 8)))
	_grant_cross_relic_shield(player, int(rule.get("shield_value", 12)), rules)


func _find_cross_relic_field_containing_player(player: Node2D) -> Node2D:
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


func _grant_cross_relic_shield(player: Node, amount: int, rules: Dictionary) -> void:
	if player == null or amount <= 0:
		return
	var base: Dictionary = _get_dictionary(rules.get("cross_relic_base", {}))
	var cap: int = int(base.get("shield_cap", 12))
	if rules.has("cross_relic_shelter_upgrade"):
		var rule: Dictionary = _get_dictionary(rules.get("cross_relic_shelter_upgrade", {}))
		cap += int(rule.get("shield_cap_add", 0))
	var current: int = int(player.get_meta("cross_relic_shield_points", 0))
	player.set_meta("cross_relic_shield_points", mini(current + amount, maxi(cap, amount)))


func _heal_player(player: Node, amount: int) -> void:
	if player == null or amount <= 0:
		return
	var max_health: int = int(player.get("max_health"))
	var current_health: int = int(player.get("current_health"))
	player.set("current_health", mini(current_health + amount, max_health))
	if player.has_signal("health_changed"):
		player.emit_signal("health_changed", int(player.get("current_health")), max_health)


func _player_health_ratio(player: Node) -> float:
	if player == null:
		return 1.0
	var max_health: float = maxf(float(player.get("max_health")), 1.0)
	return clampf(float(player.get("current_health")) / max_health, 0.0, 1.0)


func _apply_hunter_trap_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	if target == null:
		return
	if rules.has("prey_mark_on_strong_trap_hit"):
		var prey_rule: Dictionary = _get_dictionary(rules.get("prey_mark_on_strong_trap_hit", {}))
		if (_is_elite(target) or _is_boss(target)) or (target.has_method("has_status") and bool(target.call("has_status", StringName(String(prey_rule.get("status_id", "prey_mark")))))):
			packet["trap_damage_multiplier_add"] = float(packet.get("trap_damage_multiplier_add", 0.0)) + float(prey_rule.get("trap_damage_multiplier_add", 0.15))
	if rules.has("boss_core_focus") and _is_boss_core(target):
		var core_rule: Dictionary = _get_dictionary(rules.get("boss_core_focus", {}))
		packet["trap_damage_multiplier_add"] = float(packet.get("trap_damage_multiplier_add", 0.0)) + float(core_rule.get("boss_core_damage_multiplier_add", 0.25))


func _apply_frost_aura_slow(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("frost_aura_slow"):
		return
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("frost_aura_slow", {}))
	var radius: float = maxf(float(rule.get("radius", 120.0)) * maxf(1.0 + float(rule.get("radius_multiplier_add", 0.0)), 0.05), 1.0)
	var radius_squared: float = radius * radius
	var tree: SceneTree = caster.get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(context.get("target_group", &"enemies")):
		var enemy: Node2D = node as Node2D
		if enemy == null or caster.global_position.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", StringName(String(rule.get("status_id", "slow"))), {
				"duration": float(rule.get("duration", 0.35)),
				"slow_percent": float(rule.get("slow_percent", 0.15))
			})


func _apply_freeze_frostbite_near_player(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("freeze_frostbite_near_player"):
		return
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("freeze_frostbite_near_player", {}))
	var radius: float = maxf(float(rule.get("radius", 90.0)), 1.0)
	var radius_squared: float = radius * radius
	var tree: SceneTree = caster.get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(context.get("target_group", &"enemies")):
		var enemy: Node2D = node as Node2D
		if enemy == null or not enemy.has_method("get_status_stack") or caster.global_position.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		if int(enemy.call("get_status_stack", StringName(String(rule.get("status_id", "frostbite"))))) < maxi(int(rule.get("required_stacks", 1)), 1):
			continue
		var key: String = "near_freeze:%s" % _target_key(enemy)
		var now_seconds: float = _now_seconds()
		if now_seconds < float(_near_player_freeze_cooldowns.get(key, 0.0)):
			continue
		_near_player_freeze_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 5.0)), 0.0)
		if _is_boss(enemy) and bool(rule.get("boss_converts_to_poise", true)):
			ReactionLimiterScript.apply_boss_control_conversion(enemy, &"freeze")
			_apply_frost_core_crack_on_boss_poise(rules, context.merged({"target": enemy}))
		elif enemy.has_method("apply_status"):
			enemy.call("apply_status", &"freeze", {"duration": float(rule.get("freeze_duration", 0.5))})


func _update_windstep_state(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("windstep_state") and not rules.has("windstep_projectile_speed"):
		return
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return
	var now_seconds: float = _now_seconds()
	var moving: bool = _is_target_moving(caster)
	if moving:
		if not caster.has_meta("hunter_bow_windstep_moving_started_at"):
			caster.set_meta("hunter_bow_windstep_moving_started_at", now_seconds)
	else:
		caster.set_meta("hunter_bow_windstep_moving_started_at", -1.0)
	var state_rule: Dictionary = _get_dictionary(rules.get("windstep_state", {}))
	if state_rule.is_empty():
		caster.set_meta("hunter_bow_windstep_active_until", now_seconds if moving else -1.0)
		return
	var started_at: float = float(caster.get_meta("hunter_bow_windstep_moving_started_at", -1.0))
	var required: float = maxf(float(state_rule.get("required_moving_seconds", 2.5)), 0.0)
	if moving and started_at >= 0.0 and now_seconds - started_at >= required:
		caster.set_meta("hunter_bow_windstep_active_until", now_seconds + maxf(float(state_rule.get("keep_after_stop", 0.0)), 0.0))
	elif not moving:
		var active_until: float = float(caster.get_meta("hunter_bow_windstep_active_until", -1.0))
		if now_seconds > active_until:
			caster.set_meta("hunter_bow_windstep_active_until", -1.0)


func _apply_windstep_runtime_modifiers(rules: Dictionary, context: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var moving: bool = _is_target_moving(context.get("caster") as Node)
	var speed_rule: Dictionary = _get_dictionary(rules.get("windstep_projectile_speed", {}))
	var projectile_speed_add: Variant = float(speed_rule.get("projectile_speed_multiplier_add", 0.2)) if moving and not speed_rule.is_empty() else null
	_set_dynamic_runtime_modifier(skill_instance, "hunter_windstep", "projectile_speed_multiplier_add", projectile_speed_add)
	var state_rule: Dictionary = _get_dictionary(rules.get("windstep_state", {}))
	var attack_speed_add: Variant = float(state_rule.get("attack_speed_multiplier_add", 0.1364)) if _is_windstep_active(context) and not state_rule.is_empty() else null
	_set_dynamic_runtime_modifier(skill_instance, "hunter_windstep", "attack_speed_multiplier_add", attack_speed_add)


func _is_windstep_active(context: Dictionary) -> bool:
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return false
	return _now_seconds() <= float(caster.get_meta("hunter_bow_windstep_active_until", -1.0))


func _set_dynamic_runtime_modifier(skill_instance: RefCounted, modifier_namespace: String, key: String, value: Variant) -> void:
	if skill_instance == null or key == "":
		return
	var modifiers: Dictionary = {}
	var modifiers_variant: Variant = skill_instance.get("runtime_modifiers")
	if modifiers_variant is Dictionary:
		modifiers = (modifiers_variant as Dictionary).duplicate(true)
	var originals_key: String = _metadata_key(modifier_namespace, "runtime_originals")
	var originals: Dictionary = {}
	var originals_variant: Variant = skill_instance.get_meta(originals_key, {})
	if originals_variant is Dictionary:
		originals = (originals_variant as Dictionary).duplicate(true)
	if not originals.has(key):
		originals[key] = modifiers[key] if modifiers.has(key) else null
	if value == null:
		if originals.has(key):
			if originals[key] == null:
				modifiers.erase(key)
			else:
				modifiers[key] = originals[key]
			originals.erase(key)
	else:
		var base_value: float = float(originals.get(key, 0.0)) if originals.get(key, null) != null else 0.0
		modifiers[key] = base_value + float(value)
	skill_instance.set("runtime_modifiers", modifiers)
	skill_instance.set_meta(originals_key, originals)


func _get_rules(context: Dictionary) -> Dictionary:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return {}
	var result: Dictionary = {}
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition != null:
		var base_rules_value: Variant = definition.get("base_special_rules")
		if base_rules_value is Dictionary:
			var base_rules: Dictionary = base_rules_value
			for key_variant: Variant in base_rules.keys():
				result[String(key_variant)] = base_rules[key_variant]
	var modifiers_variant: Variant = skill_instance.get("runtime_modifiers")
	if modifiers_variant is Dictionary:
		var modifiers: Dictionary = modifiers_variant
		for key: String in [
			"burn_damage_multiplier_add",
			"burn_duration_add",
			"burn_max_stacks_add",
			"boss_burn_max_stacks_add",
			"burn_move_speed_multiplier_add_per_stack",
			"lava_duration_add",
			"lava_radius_multiplier_add"
		]:
			if modifiers.has(key):
				result[key] = modifiers[key]
	var value: Variant = skill_instance.get("runtime_special_rules")
	if value is Dictionary:
		var special_rules: Dictionary = value
		for key_variant: Variant in special_rules.keys():
			result[String(key_variant)] = special_rules[key_variant]
	return result


func _get_skill_damage(context: Dictionary) -> int:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	return maxi(roundi(float(SkillStatServiceScript.get_effective_stat(
		skill_instance,
		"damage",
		16,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	))), 0)


func _build_special_packet(source_id: String, amount: int, origin: String, can_crit: bool) -> Dictionary:
	return SpecialDamageRuleHandlerScript.build_special_packet(source_id, amount, origin, can_crit)


func _is_boss(target: Node) -> bool:
	return target != null and (target.is_in_group(&"bosses") or bool(target.get_meta("is_boss", false)) or String(target.get_meta("enemy_rank", "")) == "boss")


func _is_elite(target: Node) -> bool:
	return target != null and (target.is_in_group(&"elites") or bool(target.get_meta("is_elite", false)) or String(target.get_meta("enemy_rank", "")) == "elite")


func _is_boss_core(target: Node) -> bool:
	return target != null and (target.is_in_group(&"boss_cores") or bool(target.get_meta("is_boss_core", false)) or String(target.get_meta("enemy_type", "")) == "boss_core")


func _target_key(target: Node) -> String:
	return str(target.get_instance_id()) if target != null else "none"


func _metadata_key(namespace_text: String, suffix: String) -> String:
	return MetadataKeyScript.key(namespace_text, suffix, "skill_rule")


func _metadata_identifier(raw_key: String) -> String:
	return MetadataKeyScript.identifier(raw_key, "skill_rule")


func _health_ratio(target: Node) -> float:
	if target == null:
		return 1.0
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	return clampf(float(target.get("current_health")) / max_health, 0.0, 1.0)


func _is_critical_hit_context(context: Dictionary) -> bool:
	if bool(context.get("was_crit", context.get("is_crit", false))):
		return true
	var projectile: Node = context.get("projectile") as Node
	return projectile != null and bool(projectile.get_meta("last_hit_was_crit", false))


func _is_target_moving(target: Node) -> bool:
	if target == null:
		return false
	var velocity_variant: Variant = target.get("velocity")
	if velocity_variant is Vector2:
		return (velocity_variant as Vector2).length_squared() > 1.0
	return false


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
