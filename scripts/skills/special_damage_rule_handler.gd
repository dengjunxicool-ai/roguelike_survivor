extends RefCounted
class_name SpecialDamageRuleHandler


const DamageIntentScript: Script = preload("res://scripts/combat/damage_intent.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")

static var _death_explosion_cooldowns: Dictionary = {}
static var _lava_zone_cooldowns: Dictionary = {}
static var _protective_lava_cooldowns: Dictionary = {}
static var _frost_ring_cooldowns: Dictionary = {}
static var _page_spirit_spawn_cooldowns: Dictionary = {}
static var _page_spirit_attack_cooldowns: Dictionary = {}
static var _trap_fragment_field_ids: Array[int] = []
static var _holy_shield_break_reduction_cooldowns: Dictionary = {}
static var _holy_counter_boss_poise_cooldowns: Dictionary = {}
static var _warhammer_boss_low_hp_shockwave_cooldowns: Dictionary = {}
static var _cross_relic_purify_boss_poise_cooldowns: Dictionary = {}
static var _cross_relic_purify_small_pulse_cooldowns: Dictionary = {}
static var _toxic_vial_small_cloud_cooldowns: Dictionary = {}
static var _poison_death_explosion_cooldowns: Dictionary = {}
static var _fire_oil_secondary_deflagration_cooldowns: Dictionary = {}


static func direct_hit_extra_explosion_intents(rules: Dictionary, context: Dictionary, base_damage: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	if not rules.has("direct_hit_extra_explosion_bonus"):
		return intents
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("take_damage"):
		return intents
	var amount: int = maxi(roundi(float(base_damage) * float(rules.get("direct_hit_extra_explosion_bonus", 0.0))), 0)
	if amount <= 0:
		return intents
	var packet: Dictionary = build_special_packet("fireball_direct_explosion_bonus", amount, "primary_attack", true)
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, &"area_direct"))
	return intents


static func soulburn_burst_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var packet: Dictionary = build_special_packet("soulburn_burst", amount, "special", false)
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, &"true_percent_damage"))
	return intents


static func flame_core_burst_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("flame_core_boss_burst", {}))
	var packet: Dictionary = DamagePacketBuilderScript.from_special_rule({
		"source_id": "flame_core_burst",
		"amount": amount,
		"damage_origin": "primary_attack",
		"damage_type": StringName(String(rule.get("damage_type", "direct_magical"))),
		"element": StringName(String(rule.get("element", "fire"))),
		"can_crit": bool(rule.get("can_crit", true)),
		"special_rule_tags": ["fireball_special_rule", "flame_core_burst"]
	})
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "direct_magical")))))
	return intents


static func frost_bonus_hit_intents(rules: Dictionary, context: Dictionary, amount: int, rule_key: String = "frost_lock_bonus_hit") -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get(rule_key, {}))
	var packet: Dictionary = build_special_packet("frost_lock_bonus_hit", amount, String(rule.get("damage_origin", "primary_attack")), true, String(rule.get("element", "ice")), String(rule.get("damage_type", "direct_magical")))
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "direct_magical")))))
	return intents


static func frost_core_crack_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("frost_core_crack_on_boss_poise", {}))
	var packet: Dictionary = build_special_packet("frost_core_crack", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "ice")), String(rule.get("damage_type", "reaction_damage")))
	packet["reaction_type"] = "shatter"
	packet["reaction_tier"] = "major"
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func execute_burning_target_death_explosion(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("burning_target_death_explosion"):
		return
	var enemy: Node = context.get("enemy") as Node
	if enemy == null or not _has_status(enemy, &"burn"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("burning_target_death_explosion", {}))
	if not bool(rule.get("enabled", true)):
		return
	var source_key_value: String = String(context.get("source_key", ""))
	if not bool(rule.get("can_trigger_self", false)) and source_key_value.find("fireball_burning_death_explosion") >= 0:
		return
	var key: String = "burn_death:%s" % String(context.get("source_key", str(enemy.get_instance_id())))
	var now_seconds: float = _now_seconds()
	var cooldown: float = maxf(float(rule.get("same_source_cooldown", 0.2)), 0.0)
	if now_seconds < float(_death_explosion_cooldowns.get(key, 0.0)):
		return
	_death_explosion_cooldowns[key] = now_seconds + cooldown

	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = enemy.get_parent()
	var radius: float = maxf(float(rule.get("radius", 42.0 * maxf(float(rule.get("radius_multiplier", 0.55)), 0.01))), 1.0)
	var damage: int = maxi(roundi(float(_get_skill_base_damage(context, 16)) * maxf(float(rule.get("damage_multiplier", 0.35)), 0.0)), 1)
	var packet: Dictionary = build_special_packet("fireball_burning_death_explosion", damage, "reaction", false)
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.75)) - 1.0
	packet["source_type"] = "explosion"
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	var position: Vector2 = context.get("position", enemy.global_position if enemy is Node2D else Vector2.ZERO)
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"generic_explosion_area",
		"source_id": &"fireball_burning_death_explosion",
		"position": position,
		"damage": 0,
		"damage_type": &"area_direct",
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"max_targets": maxi(int(rule.get("max_targets", 0)), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(1.0, 0.42, 0.08, 0.28)
	})
	var root: Node = _get_root_node()
	var trace_id: int = DamageTraceContextScript.get_trace_id(context, root)
	if area != null and trace_id > 0:
		DebugCombatTraceScript.record_explosion(root, parent, position, radius, "fireball_burning_death_explosion", String(packet.get("source_instance_id", "")), trace_id, packet)
	var max_targets: int = maxi(int(rule.get("max_targets", 0)), 0)
	var hit_count: int = 0
	for target: Node2D in _find_targets_in_radius(context, position, radius):
		if target == enemy:
			continue
		if max_targets > 0 and hit_count >= max_targets:
			break
		if target == null or not target.has_method("take_damage"):
			continue
		DamageIntentScript.create(target, packet, &"area_direct").call("apply")
		hit_count += 1


static func spawn_ground_fire_or_lava(rules: Dictionary, context: Dictionary, base_damage: int) -> Node2D:
	var ground_fire: Dictionary = _get_dictionary(rules.get("ground_fire_on_hit", {}))
	var lava: Dictionary = _get_dictionary(rules.get("player_lava_on_nearby_fireball_hit", {}))
	if ground_fire.is_empty() and lava.is_empty():
		return null
	if not ground_fire.is_empty() and not lava.is_empty():
		var ground_rules: Dictionary = rules.duplicate(true)
		ground_rules.erase("player_lava_on_nearby_fireball_hit")
		var ground_area: Node2D = spawn_ground_fire_or_lava(ground_rules, context, base_damage)
		var lava_rules: Dictionary = rules.duplicate(true)
		lava_rules.erase("ground_fire_on_hit")
		var lava_area: Node2D = spawn_ground_fire_or_lava(lava_rules, context, base_damage)
		return lava_area if lava_area != null else ground_area
	var parent: Node = context.get("parent") as Node
	var target: Node2D = context.get("target") as Node2D
	if parent == null or target == null:
		return null
	var active_rule: Dictionary = lava if not lava.is_empty() else ground_fire
	var caster: Node2D = context.get("caster") as Node2D
	if not lava.is_empty():
		if caster != null and float(lava.get("near_player_radius", 0.0)) > 0.0:
			var near_radius: float = float(lava.get("near_player_radius", 0.0))
			if caster.global_position.distance_squared_to(target.global_position) > near_radius * near_radius:
				return null
		var cooldown: float = maxf(float(lava.get("same_source_cooldown", 0.0)), 0.0)
		var cooldown_key: String = "lava:%s:player_lava_on_nearby_fireball_hit" % (str(caster.get_instance_id()) if caster != null else "none")
		var now_seconds: float = _now_seconds()
		if cooldown > 0.0 and now_seconds < float(_lava_zone_cooldowns.get(cooldown_key, 0.0)):
			return null
		if cooldown > 0.0:
			_lava_zone_cooldowns[cooldown_key] = now_seconds + cooldown
	var duration: float = float(active_rule.get("duration", 0.8))
	duration += float(rules.get("lava_duration_add", 0.0))
	var radius: float = 42.0
	radius *= maxf(1.0 + float(rules.get("lava_radius_multiplier_add", 0.0)), 0.05)
	var damage: int = maxi(roundi(float(base_damage) * float(active_rule.get("damage_from_fireball_base", 0.25))), 1)
	var field_model: String = String(active_rule.get("field_damage_model", "direct_tick"))
	var position: Vector2 = target.global_position
	if String(active_rule.get("spawn_position", "")) == "player" and caster != null:
		position = caster.global_position
	var slow_rule: Dictionary = _get_dictionary(rules.get("lava_slow", {}))
	var status_id: StringName = &""
	var status_params: Dictionary = {}
	if not slow_rule.is_empty():
		status_id = StringName(String(slow_rule.get("status_id", "slow")))
		status_params = {
			"duration": float(slow_rule.get("duration", 0.5)),
			"slow_percent": float(slow_rule.get("slow_percent", 0.18)),
			"boss_slow_percent": float(slow_rule.get("boss_slow_percent", 0.08))
		}
	var lava_packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet("fireball_lava_zone", damage, "field", false), context)
	lava_packet["source_type"] = "area"
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": position,
		"damage": damage,
		"damage_type": &"status_dot" if field_model == "dot_tick" else &"area_direct",
		"damage_packet": lava_packet,
		"duration": duration,
		"tick_interval": float(active_rule.get("tick_interval", 0.5)),
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "lava_zone",
		"visual_color": Color(1.0, 0.25, 0.05, 0.32),
		"status_on_hit": status_id,
		"status_params": status_params
	})
	if area != null:
		area.set_meta("fireball_lava_zone", true)
	return area


static func execute_protective_lava_ring_on_player_damaged(rules: Dictionary, context: Dictionary) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("protective_lava_ring_on_player_damaged", {}))
	if rule.is_empty():
		return null
	var player: Node2D = context.get("player", context.get("caster")) as Node2D
	if player == null:
		return null
	var key: String = "protective_lava:%s" % str(player.get_instance_id())
	var now_seconds: float = _now_seconds()
	var cooldown: float = maxf(float(rule.get("same_source_cooldown", 12.0)), 0.0)
	if now_seconds < float(_protective_lava_cooldowns.get(key, 0.0)):
		return null
	_protective_lava_cooldowns[key] = now_seconds + cooldown
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = player.get_parent()
	if parent == null:
		return null
	var duration: float = maxf(float(rule.get("duration", 2.0)), 0.05)
	var radius: float = float(rule.get("radius", 130.0))
	player.set_meta("protective_lava_reduction_until", now_seconds + duration)
	player.set_meta("protective_lava_damage_taken_multiplier_add", float(rule.get("damage_taken_multiplier_add", -0.2)))
	player.set_meta("protective_lava_center", player.global_position)
	player.set_meta("protective_lava_radius", radius)
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": player.global_position,
		"damage": 0,
		"duration": duration,
		"tick_interval": 0.5,
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "protective_lava_zone",
		"visual_color": Color(1.0, 0.34, 0.04, 0.22),
		"visual_ring_color": Color(0.4, 1.0, 0.55, 0.8)
	})
	if area != null:
		area.set_meta("fireball_lava_zone", true)
		area.set_meta("protective_lava_zone", true)
	return area


static func execute_frost_ring_on_player_damaged(rules: Dictionary, context: Dictionary) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("frost_ring_on_player_damaged", {}))
	if rule.is_empty():
		return null
	var player: Node2D = context.get("player", context.get("caster")) as Node2D
	if player == null:
		return null
	var key: String = "frost_ring:%s" % str(player.get_instance_id())
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_frost_ring_cooldowns.get(key, 0.0)):
		return null
	_frost_ring_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 12.0)), 0.0)
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = player.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(int(rule.get("amount", 8)), 0)
	var radius: float = maxf(float(rule.get("radius", 120.0)), 1.0)
	var status_params: Dictionary = {}
	var status_id: StringName = &""
	if int(rule.get("status_stacks", 0)) > 0:
		status_id = StringName(String(rule.get("status_id", "frostbite")))
		status_params = {
			"stacks": int(rule.get("status_stacks", 1)),
			"max_stacks": 3,
			"duration": float(rule.get("status_duration", 3.0))
		}
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": player.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": DamageTraceContextScript.apply_to_packet(build_special_packet("frost_ring", amount, String(rule.get("damage_origin", "special")), false, String(rule.get("element", "ice")), String(rule.get("damage_type", "area_direct"))), context),
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(0.55, 0.82, 1.0, 0.35),
		"status_on_hit": status_id,
		"status_params": status_params
	})
	_knockback_targets(parent, player.global_position, radius, float(rule.get("knockback", 45.0)), context.get("target_group", &"enemies"))
	return area


static func execute_holy_shield_pulse(rules: Dictionary, context: Dictionary, pulse_count: int) -> void:
	var base: Dictionary = _get_dictionary(rules.get("holy_shield_base", {}))
	if base.is_empty():
		return
	var player: Node2D = context.get("player", context.get("caster")) as Node2D
	if player == null:
		return
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = player.get_parent()
	if parent == null:
		return
	var radius: float = maxf(float(base.get("radius", 120.0)), 1.0)
	if rules.has("holy_pulse_radius"):
		var radius_rule: Dictionary = _get_dictionary(rules.get("holy_pulse_radius", {}))
		radius *= maxf(1.0 + float(radius_rule.get("radius_multiplier_add", 0.0)), 0.05)
	var amount: int = maxi(int(base.get("pulse_damage", 5)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"holy_shield_pulse",
		amount,
		String(base.get("damage_origin", "primary_attack")),
		false,
		String(base.get("element", "holy")),
		String(base.get("damage_type", "area_direct"))
	), context)
	CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": player.global_position,
		"damage": amount,
		"damage_type": StringName(String(base.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "holy_shield_pulse",
		"visual_color": Color(1.0, 0.92, 0.35, 0.28)
	})
	_apply_holy_mark_on_pulse(rules, context, player.global_position, radius)
	_apply_holy_mark_pulse_focus(rules, context, player.global_position, radius, amount)
	_apply_judgement_beam_on_boss_mark_pulses(rules, context, player.global_position, radius)
	_execute_holy_shockwave_if_due(rules, context, player.global_position, pulse_count)


static func execute_holy_shield_player_damaged(rules: Dictionary, context: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null or not bool(skill_instance.get_meta("holy_shield_active", false)):
		return
	var amount: int = maxi(int(context.get("amount", 0)), 0)
	if amount <= 0:
		return
	var remaining: int = int(skill_instance.get_meta("holy_shield_remaining", 0)) - amount
	skill_instance.set_meta("holy_shield_remaining", maxi(remaining, 0))
	if remaining > 0:
		return
	skill_instance.set_meta("holy_shield_active", false)
	execute_holy_shield_break(rules, context)


static func execute_holy_shield_break(rules: Dictionary, context: Dictionary) -> void:
	var base: Dictionary = _get_dictionary(rules.get("holy_shield_base", {}))
	if base.is_empty():
		return
	var player: Node2D = context.get("player", context.get("caster")) as Node2D
	if player == null:
		return
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = player.get_parent()
	if parent == null:
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var amount: int = int(skill_instance.get_meta("holy_shield_break_damage", base.get("break_damage", 30))) if skill_instance != null else int(base.get("break_damage", 30))
	var radius: float = maxf(float(base.get("break_radius", 150.0)), 1.0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"holy_shield_break",
		amount,
		String(base.get("damage_origin", "primary_attack")),
		false,
		String(base.get("element", "holy")),
		String(base.get("damage_type", "area_direct"))
	), context)
	CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": player.global_position,
		"damage": amount,
		"damage_type": StringName(String(base.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "holy_shield_break",
		"visual_color": Color(1.0, 0.86, 0.25, 0.36)
	})
	_execute_holy_shield_break_shockwave(rules, context, player.global_position)
	_execute_holy_counter_on_marked_break_hit(rules, context, player.global_position, radius)
	_apply_holy_shield_break_damage_reduction(rules, context)


static func execute_holy_shield_expire(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("holy_shield_expire_heal"):
		return
	var player: Node = context.get("player", context.get("caster")) as Node
	if player == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_shield_expire_heal", {}))
	var amount: int = maxi(int(rule.get("amount", 5)), 0)
	if amount <= 0:
		return
	var max_health: int = int(player.get("max_health"))
	var current_health: int = int(player.get("current_health"))
	player.set("current_health", mini(current_health + amount, max_health))
	if player.has_signal("health_changed"):
		player.emit_signal("health_changed", int(player.get("current_health")), max_health)


static func _execute_holy_shockwave_if_due(rules: Dictionary, context: Dictionary, position: Vector2, pulse_count: int) -> void:
	if not rules.has("holy_shockwave_every_n_pulses"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_shockwave_every_n_pulses", {}))
	var interval: int = maxi(int(rule.get("pulse_interval", 3)), 1)
	if pulse_count % interval != 0:
		return
	_spawn_holy_area(rule, context, position, "holy_shield_shockwave", Color(1.0, 0.94, 0.48, 0.34))


static func _execute_holy_shield_break_shockwave(rules: Dictionary, context: Dictionary, position: Vector2) -> void:
	if not rules.has("holy_shield_break_shockwave"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_shield_break_shockwave", {}))
	_spawn_holy_area(rule, context, position, "holy_shield_break_shockwave", Color(1.0, 0.97, 0.56, 0.40))


static func _spawn_holy_area(rule: Dictionary, context: Dictionary, position: Vector2, source_id: String, color: Color) -> Node2D:
	var parent: Node = context.get("parent") as Node
	if parent == null:
		var player: Node2D = context.get("player", context.get("caster")) as Node2D
		parent = player.get_parent() if player != null else null
	if parent == null:
		return null
	var amount: int = maxi(int(rule.get("amount", 0)), 0)
	if amount <= 0:
		return null
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		source_id,
		amount,
		String(rule.get("damage_origin", "primary_attack")),
		false,
		String(rule.get("element", "holy")),
		String(rule.get("damage_type", "area_direct"))
	), context)
	if rule.has("boss_damage_multiplier"):
		packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 1.0)) - 1.0
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": maxf(float(rule.get("radius", 120.0)), 1.0),
		"max_targets": maxi(int(rule.get("max_targets", 0)), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": source_id,
		"visual_color": color
	})


static func _apply_holy_mark_pulse_focus(rules: Dictionary, context: Dictionary, position: Vector2, radius: float, base_amount: int) -> void:
	if not rules.has("holy_mark_pulse_focus") or base_amount <= 0:
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_mark_pulse_focus", {}))
	var bonus_amount: int = maxi(roundi(float(base_amount) * maxf(float(rule.get("damage_multiplier_add", 0.2)), 0.0)), 0)
	if bonus_amount <= 0:
		return
	var intents: Array[RefCounted] = []
	for target: Node2D in _find_targets_in_radius(context, position, radius):
		if not _has_status(target, &"holy_mark"):
			continue
		var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet("holy_mark_pulse_focus", bonus_amount, "primary_attack", false, "holy", "area_direct"), context)
		intents.append(DamageIntentScript.create(target, packet, &"area_direct"))
	apply_intents(intents)


static func _apply_holy_mark_on_pulse(rules: Dictionary, context: Dictionary, position: Vector2, radius: float) -> void:
	_apply_holy_mark_on_strong_pulse_hit(rules, context, position, radius)
	_apply_holy_mark_nearest_pulse_target(rules, context, position, radius)


static func _apply_holy_mark_on_strong_pulse_hit(rules: Dictionary, context: Dictionary, position: Vector2, radius: float) -> void:
	if not rules.has("holy_mark_on_strong_pulse_hit"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_mark_on_strong_pulse_hit", {}))
	for target: Node2D in _find_targets_in_radius(context, position, radius):
		if not (_is_elite(target) or _is_boss(target)) or not target.has_method("apply_status"):
			continue
		target.call("apply_status", StringName(String(rule.get("status_id", "holy_mark"))), {
			"duration": float(rule.get("duration", 5.0)),
			"stacks": maxi(int(rule.get("stack", 1)), 1),
			"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1)
		})


static func _apply_holy_mark_nearest_pulse_target(rules: Dictionary, context: Dictionary, position: Vector2, radius: float) -> void:
	if not rules.has("holy_mark_nearest_pulse_target"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_mark_nearest_pulse_target", {}))
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for target: Node2D in _find_targets_in_radius(context, position, radius):
		var distance: float = position.distance_squared_to(target.global_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	if nearest == null or not nearest.has_method("apply_status"):
		return
	nearest.call("apply_status", StringName(String(rule.get("status_id", "holy_mark"))), {
		"duration": float(rule.get("duration", 4.0)),
		"stacks": maxi(int(rule.get("stack", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1)
	})


static func _apply_judgement_beam_on_boss_mark_pulses(rules: Dictionary, context: Dictionary, position: Vector2, radius: float) -> void:
	if not rules.has("judgement_beam_on_boss_mark_pulses"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("judgement_beam_on_boss_mark_pulses", {}))
	var required: int = maxi(int(rule.get("required_pulses", 5)), 1)
	var amount: int = maxi(int(rule.get("amount", 30)), 0)
	if amount <= 0:
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var skill_key: String = str(skill_instance.get_instance_id()) if skill_instance != null else "holy_shield"
	var intents: Array[RefCounted] = []
	for target: Node2D in _find_targets_in_radius(context, position, radius):
		if not _is_boss(target) or not _has_status(target, &"holy_mark"):
			continue
		var meta_key: String = "holy_judgement_pulses:%s" % skill_key
		var count: int = int(target.get_meta(meta_key, 0)) + 1
		target.set_meta(meta_key, count)
		if count % required != 0:
			continue
		var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
			"holy_judgement_beam",
			amount,
			String(rule.get("damage_origin", "special")),
			false,
			String(rule.get("element", "holy")),
			String(rule.get("damage_type", "direct_magical"))
		), context)
		intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "direct_magical")))))
	apply_intents(intents)


static func _execute_holy_counter_on_marked_break_hit(rules: Dictionary, context: Dictionary, position: Vector2, radius: float) -> void:
	if not rules.has("holy_counter_on_marked_break_hit"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_counter_on_marked_break_hit", {}))
	var base_amount: int = maxi(int(rule.get("amount", 20)), 0)
	if base_amount <= 0:
		return
	var intents: Array[RefCounted] = []
	for target: Node2D in _find_targets_in_radius(context, position, radius):
		if not _has_status(target, StringName(String(rule.get("required_status_id", "holy_mark")))):
			continue
		var amount: int = base_amount
		if _is_boss(target):
			amount = maxi(roundi(float(amount) * maxf(float(rule.get("boss_damage_multiplier", 0.75)), 0.0)), 0)
			_apply_holy_counter_boss_poise(rules, target)
		var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
			"holy_counter_on_marked_break_hit",
			amount,
			String(rule.get("damage_origin", "reaction")),
			false,
			String(rule.get("element", "holy")),
			String(rule.get("damage_type", "reaction_damage"))
		), context)
		intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	apply_intents(intents)


static func _apply_holy_counter_boss_poise(rules: Dictionary, target: Node) -> void:
	if not rules.has("holy_counter_boss_poise") or target == null or not _is_boss(target):
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_counter_boss_poise", {}))
	var key: String = "holy_counter_poise:%s" % str(target.get_instance_id())
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_holy_counter_boss_poise_cooldowns.get(key, 0.0)):
		return
	_holy_counter_boss_poise_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.5)), 0.0)
	for _i in range(maxi(int(rule.get("stacks", 1)), 1)):
		ReactionLimiterScript.apply_boss_control_conversion(target, &"holy_mark")


static func _apply_holy_shield_break_damage_reduction(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("holy_shield_break_damage_reduction"):
		return
	var player: Node = context.get("player", context.get("caster")) as Node
	if player == null:
		return
	var rule: Dictionary = _get_dictionary(rules.get("holy_shield_break_damage_reduction", {}))
	var key: String = "holy_break_reduction:%s" % str(player.get_instance_id())
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_holy_shield_break_reduction_cooldowns.get(key, 0.0)):
		return
	_holy_shield_break_reduction_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 18.0)), 0.0)
	player.set_meta("holy_shield_break_reduction_until", now_seconds + maxf(float(rule.get("duration", 1.0)), 0.0))
	player.set_meta("holy_shield_break_damage_taken_multiplier_add", float(rule.get("damage_taken_multiplier_add", -0.4)))


static func execute_warhammer_crack_field(rules: Dictionary, context: Dictionary) -> Node2D:
	if not rules.has("warhammer_crack_field"):
		return null
	var target: Node2D = context.get("target") as Node2D
	var source: Node2D = context.get("source") as Node2D
	var caster: Node2D = context.get("caster") as Node2D
	var origin: Node2D = target if target != null else source
	if origin == null:
		origin = caster
	if origin == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = origin.get_parent()
	if parent == null:
		return null
	var rule: Dictionary = _get_dictionary(rules.get("warhammer_crack_field", {}))
	var upgrade: Dictionary = _get_dictionary(rules.get("warhammer_crack_upgrade", {}))
	var quake_rule: Dictionary = _get_dictionary(rules.get("warhammer_quake_slam_every_n_casts", {}))
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	var quake_active: bool = skill_instance != null and bool(skill_instance.get_meta("warhammer_quake_slam_active", false))
	var radius: float = maxf(float(rule.get("radius", 80.0)), 1.0)
	radius *= maxf(1.0 + float(upgrade.get("length_multiplier_add", 0.0)), 0.05)
	if quake_active:
		radius *= maxf(float(quake_rule.get("forward_extension_multiplier", 1.6)), 0.05)
	var duration: float = maxf(float(rule.get("duration", 1.2)), 0.05)
	if quake_active and int(quake_rule.get("same_target_max_hits", 0)) > 0:
		duration = minf(duration, maxf(float(rule.get("tick_interval", 0.4)), 0.05) * float(quake_rule.get("same_target_max_hits", 2)))
	var amount: int = maxi(int(rule.get("amount", 5)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"warhammer_crack_field",
		amount,
		String(rule.get("damage_origin", "field")),
		false,
		String(rule.get("element", "physical")),
		String(rule.get("damage_type", "area_direct"))
	), context)
	var source_weapon_id: String = String(context.get("source_weapon_id", packet.get("source_weapon_id", "")))
	if source_weapon_id == "" and caster != null:
		source_weapon_id = String(caster.get("selected_weapon_id"))
	packet["source_weapon_id"] = StringName(source_weapon_id)
	packet["source_skill_id"] = StringName(String(context.get("skill_id", packet.get("source_skill_id", ""))))
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.85)) - 1.0
	var direction: Vector2 = Vector2.ZERO
	if caster != null:
		direction = caster.global_position.direction_to(origin.global_position)
	var position: Vector2 = origin.global_position
	if quake_active and direction != Vector2.ZERO:
		position += direction.normalized() * radius * 0.35
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"source_weapon_id": StringName(String(packet.get("source_weapon_id", ""))),
		"source_skill_id": StringName(String(packet.get("source_skill_id", ""))),
		"duration": duration,
		"tick_interval": maxf(float(rule.get("tick_interval", 0.4)), 0.05),
		"radius": radius,
		"max_targets": maxi(int(upgrade.get("max_targets", rule.get("max_targets", 0))), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "warhammer_crack_field",
		"visual_color": Color(0.86, 0.58, 0.18, 0.30)
	})


static func warhammer_judgement_shock_intents(rules: Dictionary, context: Dictionary, amount: int, source_id: String) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("warhammer_judgement_shock", {}))
	if source_id == "warhammer_boss_poise_judgement_bonus":
		rule = _get_dictionary(rules.get("warhammer_boss_poise_judgement_bonus", {}))
	var final_amount: int = amount
	if _is_elite(target) or _is_boss(target):
		var upgrade: Dictionary = _get_dictionary(rules.get("warhammer_judgement_shock_upgrade", {}))
		final_amount = maxi(roundi(float(final_amount) * maxf(1.0 + float(upgrade.get("elite_boss_damage_multiplier_add", 0.0)), 0.0)), 0)
	if _is_boss(target):
		var shock_rule: Dictionary = _get_dictionary(rules.get("warhammer_judgement_shock", {}))
		final_amount = maxi(roundi(float(final_amount) * maxf(float(shock_rule.get("boss_damage_multiplier", 0.75)), 0.0)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		source_id,
		final_amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "holy")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func execute_warhammer_boss_low_hp_shockwave(rules: Dictionary, context: Dictionary) -> Node2D:
	if not rules.has("warhammer_boss_low_hp_shockwave"):
		return null
	var target: Node2D = context.get("target") as Node2D
	if target == null or not _is_boss(target):
		return null
	var rule: Dictionary = _get_dictionary(rules.get("warhammer_boss_low_hp_shockwave", {}))
	if _health_ratio(target) > float(rule.get("hp_threshold", 0.25)):
		return null
	var key: String = "warhammer_low_hp:%s" % str(target.get_instance_id())
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_warhammer_boss_low_hp_shockwave_cooldowns.get(key, 0.0)):
		return null
	_warhammer_boss_low_hp_shockwave_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 3.0)), 0.0)
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(int(rule.get("amount", 30)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"warhammer_boss_low_hp_shockwave",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "physical")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": target.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "reaction_damage"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": maxf(float(rule.get("radius", 120.0)), 1.0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "warhammer_execution_shockwave",
		"visual_color": Color(1.0, 0.08, 0.04, 0.32)
	})


static func execute_cross_relic_field_tick(rules: Dictionary, context: Dictionary) -> void:
	if not rules.has("cross_relic_base"):
		return
	apply_intents(cross_relic_echo_intents(rules, context))
	execute_cross_relic_purify_dot(rules, context)


static func fire_oil_flammable_burst_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("flammable_mark_burst_on_full_mark_tick", {}))
	var boss_tuning: Dictionary = _get_dictionary(rules.get("flammable_mark_boss_tuning", {}))
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"fire_oil_flammable_burst",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "fire")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	if _is_boss(target):
		packet["boss_damage_multiplier_add"] = float(boss_tuning.get("burst_boss_damage_multiplier_add", 0.0))
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func execute_fire_oil_deflagration(rules: Dictionary, context: Dictionary) -> Node2D:
	if not rules.has("oil_fire_deflagration"):
		return null
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var rule: Dictionary = _get_dictionary(rules.get("oil_fire_deflagration", {}))
	var upgrade: Dictionary = _get_dictionary(rules.get("deflagration_upgrade", {}))
	var amount: int = maxi(roundi(float(rule.get("amount", 18)) * maxf(1.0 + float(rule.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	var radius: float = maxf(float(rule.get("radius", 90.0)) * maxf(1.0 + float(upgrade.get("radius_multiplier_add", 0.0)), 0.05), 1.0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"fire_oil_deflagration",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "fire")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.75)) - 1.0
	packet["can_trigger_reaction"] = false
	var status_id: StringName = &""
	var status_params: Dictionary = {}
	if rules.has("deflagration_apply_burn"):
		var burn_rule: Dictionary = _get_dictionary(rules.get("deflagration_apply_burn", {}))
		status_id = &"burn"
		status_params = {
			"duration": float(burn_rule.get("burn_duration", 3.0)),
			"stacks": int(burn_rule.get("burn_stacks", 1)),
			"max_stacks": int(burn_rule.get("burn_max_stacks", 1))
		}
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"fire_oil_area",
		"position": target.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "reaction_damage"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"max_targets": maxi(int(_get_dictionary(rules.get("deflagration_apply_burn", {})).get("max_targets", 0)), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "lava_zone",
		"visual_color": Color(1.0, 0.48, 0.05, 0.36),
		"status_on_hit": status_id,
		"status_params": status_params
	})
	_execute_fire_oil_secondary_deflagration(rules, context, target, amount, radius)
	return area


static func acid_burst_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _acid_burst_rule(rules)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"acid_burst",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "acid")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.75)) - 1.0
	packet["can_trigger_reaction"] = false
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func execute_acid_burst(rules: Dictionary, context: Dictionary) -> Node2D:
	if not (rules.has("acid_burst_on_full_acid_mark_hit") or rules.has("acid_burst_on_full_acid_residue_hit")):
		return null
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var rule: Dictionary = _acid_burst_rule(rules)
	var damage_tuning: Dictionary = _get_dictionary(rules.get("acid_burst_damage_tuning", {}))
	var high_defense_rule: Dictionary = _get_dictionary(rules.get("acid_burst_high_defense_bonus", {}))
	var amount: int = maxi(int(rule.get("amount", 18)), 0)
	var multiplier: float = maxf(1.0 + float(damage_tuning.get("damage_multiplier_add", 0.0)), 0.0)
	if not high_defense_rule.is_empty() and _target_defense_value(target) >= float(high_defense_rule.get("defense_threshold", 1.0)):
		multiplier *= maxf(1.0 + float(high_defense_rule.get("damage_multiplier_add", 0.2)), 0.0)
	amount = maxi(roundi(float(amount) * multiplier), 0)
	var radius: float = maxf(float(rule.get("radius", _get_dictionary(rules.get("acid_sprayer_base", {})).get("acid_burst_radius", 75.0))), 1.0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"acid_burst",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "acid")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.75)) - 1.0
	packet["can_trigger_reaction"] = false
	var spread_rule: Dictionary = _get_dictionary(rules.get("acid_burst_spread_residue", {}))
	var status_id: StringName = &""
	var status_params: Dictionary = {}
	if not spread_rule.is_empty() and bool(spread_rule.get("can_trigger_self", false)) == false:
		status_id = StringName(String(spread_rule.get("status_id", "acid_residue")))
		status_params = {
			"duration": float(spread_rule.get("duration", 5.0)),
			"stacks": maxi(int(spread_rule.get("spread_stacks", 1)), 1),
			"max_stacks": 5
		}
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"acid_spray_cone_area",
		"position": target.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "reaction_damage"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"max_targets": maxi(int(rule.get("max_targets", 0)), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "poison_zone",
		"visual_color": Color(0.58, 1.0, 0.16, 0.34),
		"status_on_hit": status_id,
		"status_params": status_params
	})
	return area


static func grant_corrosive_film(rules: Dictionary, context: Dictionary, player: Node, amount: int, base_duration: float = 4.0) -> void:
	if player == null or amount <= 0:
		return
	var base: Dictionary = _get_dictionary(rules.get("acid_sprayer_base", {}))
	var upgrade: Dictionary = _get_dictionary(rules.get("corrosive_film_upgrade", {}))
	var cap: int = maxi(int(base.get("corrosive_film_shield_cap", amount)) + int(upgrade.get("shield_cap_add", 0)), amount)
	var duration: float = maxf(base_duration + float(upgrade.get("duration_add", 0.0)), 0.05)
	var current: int = int(player.get_meta("corrosive_film_shield_points", 0))
	player.set_meta("corrosive_film_shield_points", mini(current + amount, cap))
	player.set_meta("corrosive_film_until", _now_seconds() + duration)
	player.set_meta("corrosive_film_shield_cap", cap)


static func _acid_burst_rule(rules: Dictionary) -> Dictionary:
	var base: Dictionary = _get_dictionary(rules.get("acid_sprayer_base", {}))
	var rule: Dictionary = _get_dictionary(rules.get("acid_burst_on_full_acid_mark_hit", {}))
	if rule.is_empty():
		rule = _get_dictionary(rules.get("acid_burst_on_full_acid_residue_hit", {}))
	if rule.is_empty():
		rule = {
			"amount": int(base.get("acid_burst_amount", 18)),
			"radius": float(base.get("acid_burst_radius", 75.0)),
			"same_target_cooldown": float(base.get("acid_burst_cooldown", 2.0)),
			"damage_origin": "reaction",
			"damage_type": "reaction_damage",
			"element": "acid",
			"boss_damage_multiplier": float(base.get("acid_burst_boss_damage_multiplier", 0.75))
		}
	return rule


static func _target_defense_value(target: Node) -> float:
	if target == null:
		return 0.0
	return maxf(float(target.get("defense")) if "defense" in target else 0.0, float(target.get_meta("defense", target.get_meta("armor", 0.0))))


static func _execute_fire_oil_secondary_deflagration(rules: Dictionary, context: Dictionary, target: Node2D, primary_amount: int, primary_radius: float) -> Node2D:
	if not rules.has("full_oil_secondary_deflagration") or target == null:
		return null
	if not target.has_method("get_status_stack"):
		return null
	var rule: Dictionary = _get_dictionary(rules.get("full_oil_secondary_deflagration", {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "oil_stack")))
	var required: int = maxi(int(rule.get("required_stacks", 3)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return null
	if not bool(rule.get("can_trigger_self", false)) and String(context.get("source_key", "")).find("fire_oil_secondary_deflagration") >= 0:
		return null
	var key: String = "secondary_deflagration:%s" % str(target.get_instance_id())
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_fire_oil_secondary_deflagration_cooldowns.get(key, 0.0)):
		return null
	_fire_oil_secondary_deflagration_cooldowns[key] = now_seconds + 1.0
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(roundi(float(primary_amount) * maxf(float(rule.get("damage_multiplier", 0.5)), 0.0)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet("fire_oil_secondary_deflagration", amount, "reaction", false, "fire", "reaction_damage"), context)
	packet["can_trigger_reaction"] = false
	packet["boss_damage_multiplier_add"] = -0.25
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"fire_oil_area",
		"position": target.global_position,
		"damage": amount,
		"damage_type": &"reaction_damage",
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": primary_radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "lava_zone",
		"visual_color": Color(1.0, 0.72, 0.16, 0.32)
	})


static func execute_smoke_cloud(rules: Dictionary, context: Dictionary, rule: Dictionary, source_id: String) -> Node2D:
	if rule.is_empty():
		return null
	var origin: Node2D = context.get("area") as Node2D
	if origin == null:
		origin = context.get("player", context.get("caster")) as Node2D
	if origin == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = origin.get_parent()
	if parent == null:
		return null
	var radius: float = maxf(float(rule.get("radius", 95.0)), 1.0)
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"smoke_cloud_area",
		"position": origin.global_position,
		"damage": 0,
		"duration": maxf(float(rule.get("duration", 1.2)), 0.05),
		"tick_interval": 0.25,
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "smoke_zone",
		"visual_color": Color(0.52, 0.54, 0.56, 0.24),
		"source_id": &"smoke_cloud_area",
		"event_on_hit": &"on_projectile_hit"
	})
	if area != null:
		area.set_meta("fire_oil_smoke_cloud", true)
		area.set_meta("fire_oil_smoke_radius", radius)
		area.set_meta("source_rule_id", source_id)
		area.add_to_group(&"areas")
	return area


static func execute_toxic_vial_small_cloud(rules: Dictionary, context: Dictionary) -> Node2D:
	if not rules.has("toxic_vial_small_cloud_on_poison_kill"):
		return null
	var enemy: Node2D = context.get("enemy") as Node2D
	if enemy == null or not _has_status(enemy, &"poison"):
		return null
	var rule: Dictionary = _get_dictionary(rules.get("toxic_vial_small_cloud_on_poison_kill", {}))
	var upgrade: Dictionary = _get_dictionary(rules.get("toxic_vial_small_cloud_upgrade", {}))
	var cooldown_rule: Dictionary = _get_dictionary(rules.get("toxic_vial_small_cloud_cooldown", {}))
	var key: String = "toxic_small_cloud:%s" % String(context.get("source_key", str(enemy.get_instance_id())))
	var now_seconds: float = _now_seconds()
	var cooldown: float = maxf(float(cooldown_rule.get("same_source_cooldown", rule.get("same_source_cooldown", 0.5))), 0.0)
	if now_seconds < float(_toxic_vial_small_cloud_cooldowns.get(key, 0.0)):
		return null
	_toxic_vial_small_cloud_cooldowns[key] = now_seconds + cooldown
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = enemy.get_parent()
	if parent == null:
		return null
	var max_active: int = maxi(int(upgrade.get("max_active", 0)), 0)
	if max_active > 0 and _count_active_toxic_small_clouds(parent) >= max_active:
		_remove_oldest_toxic_small_cloud(parent)
	var base_damage: int = _get_skill_base_damage(context, 6)
	var damage: int = maxi(roundi(float(base_damage) * maxf(float(rule.get("damage_from_poison_bottle_base", 1.0)), 0.0) * maxf(1.0 + float(cooldown_rule.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	var duration: float = maxf(float(rule.get("duration", 1.5)) + float(upgrade.get("duration_add", 0.0)), 0.05)
	var radius: float = maxf(float(rule.get("radius", 70.0)), 1.0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"toxic_vial_small_cloud",
		damage,
		String(rule.get("damage_origin", "field")),
		false,
		String(rule.get("element", "poison")),
		String(rule.get("damage_type", "status_dot"))
	), context)
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"poison_cloud_area",
		"position": enemy.global_position,
		"damage": damage,
		"damage_type": StringName(String(rule.get("damage_type", "status_dot"))),
		"damage_packet": packet,
		"duration": duration,
		"tick_interval": float(rule.get("tick_interval", 0.5)),
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "poison_zone",
		"visual_color": Color(0.34, 1.0, 0.18, 0.26),
		"source_id": &"poison_cloud_area",
		"event_on_hit": &"on_projectile_hit"
	})
	if area != null:
		area.set_meta("toxic_vial_poison_cloud", true)
		area.set_meta("toxic_vial_small_cloud", true)
		area.set_meta("toxic_vial_poison_cloud_radius", radius)
		area.add_to_group(&"areas")
	return area


static func execute_poison_death_explosion(rules: Dictionary, context: Dictionary) -> Node2D:
	if not rules.has("poison_death_explosion") and not rules.has("full_poison_death_explosion"):
		return null
	var enemy: Node2D = context.get("enemy") as Node2D
	if enemy == null or not _has_status(enemy, &"poison"):
		return null
	var full_rule: Dictionary = _get_dictionary(rules.get("full_poison_death_explosion", {}))
	var explosion_rule: Dictionary = _get_dictionary(rules.get("poison_death_explosion", {}))
	var upgrade: Dictionary = _get_dictionary(rules.get("poison_death_explosion_upgrade", {}))
	if explosion_rule.is_empty():
		explosion_rule = {
			"amount": 16,
			"radius": 75,
			"max_targets": 4,
			"same_source_cooldown": 0.5,
			"damage_origin": "reaction",
			"damage_type": "reaction_damage",
			"element": "poison",
			"boss_damage_multiplier": 0.75
		}
	var source_key_value: String = String(context.get("source_key", ""))
	if not bool(full_rule.get("can_trigger_self", explosion_rule.get("can_trigger_self", false))) and source_key_value.find("poison_death_explosion") >= 0:
		return null
	var max_stacks: int = _target_status_max_stacks(enemy, &"poison", 3)
	var full_poison: bool = enemy.has_method("get_status_stack") and int(enemy.call("get_status_stack", &"poison")) >= max_stacks
	var chance: float = float(explosion_rule.get("chance", 0.2))
	if full_poison and bool(full_rule.get("guaranteed_on_full_poison", false)):
		chance = 1.0
	if randf() > clampf(chance, 0.0, 1.0):
		return null
	var key: String = "poison_death_explosion:%s" % String(context.get("source_key", str(enemy.get_instance_id())))
	var now_seconds: float = _now_seconds()
	var cooldown: float = maxf(float(upgrade.get("same_source_cooldown", explosion_rule.get("same_source_cooldown", 0.5))), 0.0)
	if now_seconds < float(_poison_death_explosion_cooldowns.get(key, 0.0)):
		return null
	_poison_death_explosion_cooldowns[key] = now_seconds + cooldown
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = enemy.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(roundi(float(explosion_rule.get("amount", 16)) * maxf(1.0 + float(upgrade.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"poison_death_explosion",
		amount,
		String(explosion_rule.get("damage_origin", "reaction")),
		false,
		String(explosion_rule.get("element", "poison")),
		String(explosion_rule.get("damage_type", "reaction_damage"))
	), context)
	packet["boss_damage_multiplier_add"] = float(explosion_rule.get("boss_damage_multiplier", 0.75)) - 1.0
	packet["can_trigger_reaction"] = false
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"poison_cloud_area",
		"position": enemy.global_position,
		"damage": amount,
		"damage_type": StringName(String(explosion_rule.get("damage_type", "reaction_damage"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": maxf(float(explosion_rule.get("radius", 90.0)), 1.0),
		"max_targets": maxi(int(explosion_rule.get("max_targets", 6)), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "poison_zone",
		"visual_color": Color(0.55, 1.0, 0.12, 0.34)
	})


static func execute_toxic_core_boss_pulse(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("toxic_core_boss_pulse", {}))
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"toxic_core_boss_pulse",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "poison")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 1.0)) - 1.0
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func execute_antidote_cloud(rules: Dictionary, context: Dictionary) -> Node2D:
	if not rules.has("antidote_cloud_on_low_hp"):
		return null
	var player: Node2D = context.get("caster") as Node2D
	if player == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = player.get_parent()
	if parent == null:
		return null
	var rule: Dictionary = _get_dictionary(rules.get("antidote_cloud_on_low_hp", {}))
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"poison_cloud_area",
		"position": player.global_position,
		"damage": 0,
		"duration": maxf(float(rule.get("duration", 2.5)), 0.05),
		"tick_interval": 0.5,
		"radius": maxf(float(rule.get("radius", 105.0)), 1.0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "poison_zone",
		"visual_color": Color(0.52, 1.0, 0.36, 0.22),
		"visual_ring_color": Color(0.75, 1.0, 0.55, 0.9)
	})
	if area != null:
		area.set_meta("toxic_vial_antidote_cloud", true)
		area.add_to_group(&"areas")
	return area


static func cross_relic_echo_intents(rules: Dictionary, context: Dictionary) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	if not rules.has("cross_relic_echo_every_n_ticks"):
		return intents
	var source: Node2D = context.get("source") as Node2D
	if source == null:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_echo_every_n_ticks", {}))
	var interval: int = maxi(int(rule.get("tick_interval", 4)), 1)
	var count: int = int(source.get_meta("cross_relic_echo_tick_count", 0)) + 1
	source.set_meta("cross_relic_echo_tick_count", count)
	if count % interval != 0:
		return intents
	var upgrade: Dictionary = _get_dictionary(rules.get("cross_relic_echo_upgrade", {}))
	var radius: float = maxf(float(rule.get("radius", 130.0)) * maxf(1.0 + float(upgrade.get("radius_multiplier_add", 0.0)), 0.05), 1.0)
	var target: Node = _select_cross_relic_echo_target(rules, context, source.global_position, radius)
	if target == null:
		return intents
	var amount: int = maxi(roundi(float(rule.get("amount", 5)) * maxf(1.0 + float(upgrade.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"cross_relic_echo",
		amount,
		String(rule.get("damage_origin", "field")),
		false,
		String(rule.get("element", "holy")),
		String(rule.get("damage_type", "direct_magical"))
	), context)
	if rules.has("cross_relic_faith_judgement") and _is_boss_core(target):
		var faith_rule: Dictionary = _get_dictionary(rules.get("cross_relic_faith_judgement", {}))
		packet["boss_damage_multiplier_add"] = float(packet.get("boss_damage_multiplier_add", 0.0)) + float(faith_rule.get("boss_core_damage_multiplier_add", 0.35))
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "direct_magical")))))
	if rules.has("cross_relic_faith_judgement") and _is_boss(target):
		intents.append_array(_cross_relic_faith_judgement_intents(rules, context, target))
	return intents


static func execute_cross_relic_purify_dot(rules: Dictionary, context: Dictionary) -> void:
	if rules.has("cross_relic_purify_impurity"):
		execute_cross_relic_purify_impurity(rules, context)
		return
	if not rules.has("cross_relic_purify_dot"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("has_status"):
		return
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_purify_dot", {}))
	if randf() > clampf(float(rule.get("chance", 0.2)), 0.0, 1.0):
		return
	var status_id: StringName = _first_matching_status(target, _get_array(rule.get("status_ids", ["burn", "poison", "bleed"])))
	if status_id == &"":
		return
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, maxi(int(rule.get("consume_stacks", 1)), 1))
	if _is_boss(target) and rules.has("cross_relic_purify_boss_poise"):
		_apply_cross_relic_purify_boss_poise(rules, target)
		return
	var amount: int = maxi(int(rule.get("amount", 12)), 0)
	if (_is_elite(target) or _is_boss(target)) and rules.has("cross_relic_purify_upgrade"):
		var upgrade: Dictionary = _get_dictionary(rules.get("cross_relic_purify_upgrade", {}))
		amount = maxi(roundi(float(amount) * maxf(1.0 + float(upgrade.get("elite_boss_damage_multiplier_add", 0.0)), 0.0)), 0)
	if _is_boss(target):
		amount = maxi(roundi(float(amount) * maxf(float(rule.get("boss_damage_multiplier", 0.75)), 0.0)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"cross_relic_purify_dot",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "holy")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	apply_intents([DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage"))))])


static func execute_cross_relic_purify_impurity(rules: Dictionary, context: Dictionary) -> void:
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_purify_impurity", {}))
	if rule.is_empty():
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var status_id: StringName = StringName(String(rule.get("required_status_id", "impurity")))
	if int(target.call("get_status_stack", status_id)) < maxi(int(rule.get("required_stacks", 3)), 1):
		return
	if target.has_method("consume_status_stack"):
		var consume_count: int = 99 if bool(rule.get("consume_all", true)) else maxi(int(rule.get("consume_stacks", 1)), 1)
		target.call("consume_status_stack", status_id, consume_count)
	var amount: int = maxi(int(rule.get("amount", 12)), 0)
	if (_is_elite(target) or _is_boss(target)) and rules.has("cross_relic_purify_upgrade"):
		var upgrade: Dictionary = _get_dictionary(rules.get("cross_relic_purify_upgrade", {}))
		amount = maxi(roundi(float(amount) * maxf(1.0 + float(upgrade.get("elite_boss_damage_multiplier_add", 0.0)), 0.0)), 0)
	if _is_boss(target):
		amount = maxi(roundi(float(amount) * maxf(float(rule.get("boss_damage_multiplier", 0.75)), 0.0)), 0)
		if rules.has("cross_relic_purify_boss_poise"):
			_apply_cross_relic_purify_boss_poise(rules, target)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"cross_relic_purify_impurity",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "holy")),
		String(rule.get("damage_type", "reaction_damage"))
	), context)
	var intent: RefCounted = DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage"))))
	apply_intents([intent])
	if not _is_boss(target) and int(target.get("current_health")) <= 0:
		execute_cross_relic_purify_small_pulse(rules, context, target)


static func execute_cross_relic_purify_small_pulse(rules: Dictionary, context: Dictionary, target: Node) -> Node2D:
	if not rules.has("cross_relic_purify_small_pulse"):
		return null
	var target_2d: Node2D = target as Node2D
	if target_2d == null:
		return null
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_purify_small_pulse", {}))
	var key: String = "cross_relic_purify_small_pulse:%s" % str(target_2d.get_instance_id())
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_cross_relic_purify_small_pulse_cooldowns.get(key, 0.0)):
		return null
	_cross_relic_purify_small_pulse_cooldowns[key] = now_seconds + maxf(float(rule.get("same_source_cooldown", 0.25)), 0.0)
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target_2d.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(int(rule.get("amount", 6)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"cross_relic_purify_small_pulse",
		amount,
		String(rule.get("damage_origin", "reaction")),
		false,
		String(rule.get("element", "holy")),
		String(rule.get("damage_type", "area_direct"))
	), context)
	packet["can_trigger_reaction"] = bool(rule.get("can_trigger_self", false))
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"holy_field_area",
		"position": target_2d.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": maxf(float(rule.get("radius", 70.0)), 1.0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_style": "holy_shield_pulse",
		"visual_color": Color(1.0, 0.92, 0.38, 0.28)
	})


static func _select_cross_relic_echo_target(rules: Dictionary, context: Dictionary, origin: Vector2, radius: float) -> Node:
	var candidates: Array[Node2D] = _find_targets_in_radius(context, origin, radius)
	if candidates.is_empty():
		return context.get("target") as Node
	if not bool(_get_dictionary(rules.get("cross_relic_echo_targeting", {})).get("prefer_strong_targets", false)):
		return candidates[0]
	var best: Node2D = candidates[0]
	var best_score: int = -1
	for candidate: Node2D in candidates:
		var score: int = 0
		if _is_boss_core(candidate):
			score = 4
		elif _is_boss(candidate):
			score = 3
		elif _is_elite(candidate):
			score = 2
		if score > best_score:
			best_score = score
			best = candidate
	return best


static func _cross_relic_faith_judgement_intents(rules: Dictionary, context: Dictionary, target: Node) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_faith_judgement", {}))
	var required: int = maxi(int(rule.get("boss_echo_hits_required", 6)), 1)
	var key: String = "cross_relic_echo_hits"
	var hits: int = int(target.get_meta(key, 0)) + 1
	target.set_meta(key, hits)
	if hits % required != 0:
		return intents
	var amount: int = maxi(int(rule.get("amount", 28)), 0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet(
		"cross_relic_faith_judgement",
		amount,
		String(rule.get("damage_origin", "special")),
		false,
		String(rule.get("element", "holy")),
		String(rule.get("damage_type", "direct_magical"))
	), context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "direct_magical")))))
	return intents


static func _apply_cross_relic_purify_boss_poise(rules: Dictionary, target: Node) -> void:
	var rule: Dictionary = _get_dictionary(rules.get("cross_relic_purify_boss_poise", {}))
	var key: String = "cross_relic_purify:%s" % str(target.get_instance_id())
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_cross_relic_purify_boss_poise_cooldowns.get(key, 0.0)):
		return
	_cross_relic_purify_boss_poise_cooldowns[key] = now_seconds + maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)
	for _i in range(maxi(int(rule.get("stacks", 1)), 1)):
		ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")


static func _first_matching_status(target: Node, status_ids: Array) -> StringName:
	for status_variant: Variant in status_ids:
		var status_id: StringName = StringName(String(status_variant))
		if status_id != &"" and target.has_method("has_status") and bool(target.call("has_status", status_id)):
			return status_id
	return &""


static func execute_shatter_area(rules: Dictionary, context: Dictionary) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("shatter_on_freeze_or_frost_hit", {}))
	if rule.is_empty():
		return null
	var upgrade: Dictionary = _get_dictionary(rules.get("shatter_upgrade", {}))
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(roundi(float(rule.get("amount", 14)) * maxf(1.0 + float(upgrade.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	var radius: float = maxf(float(rule.get("radius", 80.0)) * maxf(1.0 + float(upgrade.get("radius_multiplier_add", 0.0)), 0.05), 1.0)
	var packet: Dictionary = DamageTraceContextScript.apply_to_packet(build_special_packet("frost_shatter", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "ice")), String(rule.get("damage_type", "reaction_damage"))), context)
	packet["reaction_type"] = "shatter"
	packet["reaction_tier"] = "major"
	packet["source_instance_id"] = "frost_shatter:%s:%d" % [str(target.get_instance_id()), Time.get_ticks_msec()]
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": target.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "reaction_damage"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(0.72, 0.9, 1.0, 0.42)
	})


static func execute_shatter_kill_spawn_icicle(rules: Dictionary, context: Dictionary) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("shatter_kill_spawn_icicle", {}))
	if rule.is_empty():
		return null
	if String(context.get("source_key", "")).find("frost_shatter") < 0:
		return null
	var enemy: Node2D = context.get("enemy") as Node2D
	var caster: Node2D = context.get("caster") as Node2D
	var parent: Node = context.get("parent") as Node
	if enemy == null or caster == null or parent == null:
		return null
	var target: Node2D = _find_nearest_target(parent, enemy.global_position, context.get("target_group", &"enemies"), enemy)
	if target == null:
		return null
	var direction: Vector2 = enemy.global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		return null
	var packet: Dictionary = build_special_packet("frost_shatter_icicle", maxi(int(rule.get("damage", 8)), 0), String(rule.get("damage_origin", "reaction")), true, String(rule.get("element", "ice")), String(rule.get("damage_type", "direct_magical")))
	packet["can_trigger_reaction"] = bool(rule.get("can_trigger_shatter", false))
	packet["max_targets"] = int(rule.get("max_targets", 3))
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_projectile({
		"parent": parent,
		"projectile_id": StringName(String(rule.get("projectile_id", "hailstorm_projectile"))),
		"position": enemy.global_position,
		"direction": direction,
		"damage": maxi(int(rule.get("damage", 8)), 0),
		"damage_type": StringName(String(rule.get("damage_type", "direct_magical"))),
		"damage_packet": packet,
		"speed": float(rule.get("speed", 520.0)),
		"pierce": maxi(int(rule.get("max_targets", 3)) - 1, 0),
		"radius": float(rule.get("collision_radius", 8.0)),
		"lifetime": 1.2,
		"target_group": context.get("target_group", &"enemies"),
		"source_id": StringName(String(rule.get("projectile_id", "hailstorm_projectile")))
	})


static func execute_lightning_chain_bounce(rules: Dictionary, context: Dictionary, base_damage: int) -> Dictionary:
	var rule: Dictionary = _get_dictionary(rules.get("lightning_chain_bounce", {}))
	if rule.is_empty():
		return {}
	var first_target: Node2D = context.get("target") as Node2D
	var parent: Node = context.get("parent") as Node
	if first_target == null:
		return {}
	if parent == null:
		parent = first_target.get_parent()
	if parent == null:
		return {}
	var projectile: Node = context.get("projectile") as Node
	var hit_ids: Array = _get_projectile_hit_ids(projectile)
	_add_unique_hit_id(hit_ids, first_target)
	var bounce_count: int = maxi(int(rule.get("bounce_count", 2)) + int(rule.get("bounce_count_add", 0)), 0)
	var bounce_range: float = maxf(float(rule.get("range", 260.0)) + float(rule.get("range_add", 0.0)), 1.0)
	var bounce_multiplier: float = maxf(float(rule.get("bounce_damage_multiplier", 0.75)), 0.0)
	var current_origin: Node2D = first_target
	var current_damage: float = float(base_damage) * bounce_multiplier
	var bounces_used: int = 0
	for _bounce_index: int in range(bounce_count):
		var next_target: Node2D = _find_nearest_target_excluding(parent, current_origin.global_position, context.get("target_group", &"enemies"), hit_ids, bounce_range)
		if next_target == null:
			break
		_add_unique_hit_id(hit_ids, next_target)
		var ramp_rule: Dictionary = _get_dictionary(rules.get("chain_new_target_damage_ramp", {}))
		var ramp_add: float = 0.0
		if not ramp_rule.is_empty():
			ramp_add = minf(float(ramp_rule.get("damage_multiplier_add_per_new_target", 0.0)) * float(maxi(hit_ids.size() - 1, 0)), float(ramp_rule.get("max_damage_multiplier_add", 0.0)))
		var amount: int = maxi(roundi(current_damage * maxf(1.0 + ramp_add, 0.0)), 1)
		var packet: Dictionary = build_special_packet("lightning_chain_bounce", amount, "primary_attack", true, "lightning", "direct_magical")
		packet["source_instance_id"] = _source_instance_id(context, projectile, "lightning_chain_bounce")
		packet["can_trigger_reaction"] = false
		_apply_context_source_identity(packet, context, projectile)
		packet = DamageTraceContextScript.apply_to_packet(packet, context)
		_spawn_lightning_chain_path_visual(parent, current_origin.global_position, next_target.global_position)
		DamageIntentScript.create(next_target, packet, &"direct_magical").call("apply")
		if next_target.has_method("apply_status"):
			next_target.call("apply_status", &"charge", {"stacks": 1, "max_stacks": 4, "duration": 4.0})
		current_origin = next_target
		current_damage *= bounce_multiplier
		bounces_used += 1
	if projectile != null:
		projectile.set_meta("lightning_chain_targets", hit_ids)
	if hit_ids.size() >= int(_get_dictionary(rules.get("chain_end_burst", {})).get("unique_targets_required", 999999)):
		execute_chain_end_burst(rules, context, current_origin)
	return {
		"hit_count": hit_ids.size(),
		"bounces_used": bounces_used,
		"unused_bounces": maxi(bounce_count - bounces_used, 0),
		"last_target": current_origin
	}


static func _apply_context_source_identity(packet: Dictionary, context: Dictionary, source_node: Node = null) -> void:
	var source_weapon_id: String = String(context.get("source_weapon_id", packet.get("source_weapon_id", "")))
	if source_weapon_id == "":
		var caster: Node = context.get("caster") as Node
		if caster != null:
			source_weapon_id = String(caster.get("selected_weapon_id"))
	if source_weapon_id == "" and source_node != null:
		source_weapon_id = String(source_node.get_meta("source_weapon_id", ""))
	if source_weapon_id != "":
		packet["source_weapon_id"] = StringName(source_weapon_id)

	var source_skill_id: String = String(context.get("skill_id", packet.get("source_skill_id", "")))
	if source_skill_id == "" and source_node != null:
		source_skill_id = String(source_node.get_meta("source_skill_id", ""))
	if source_skill_id != "":
		packet["source_skill_id"] = StringName(source_skill_id)


static func _spawn_lightning_chain_path_visual(parent: Node, from_position: Vector2, to_position: Vector2, duration: float = 0.18) -> void:
	if parent == null:
		return
	var line: Line2D = Line2D.new()
	line.name = "LightningChainPathVisual"
	line.width = 4.0
	line.default_color = Color(0.62, 0.92, 1.0, 0.86)
	line.z_index = 90
	line.add_to_group(&"lightning_chain_path_visuals")
	line.points = PackedVector2Array([
		_to_parent_local(parent, from_position),
		_to_parent_local(parent, to_position)
	])
	parent.add_child(line)
	var tree: SceneTree = line.get_tree()
	if tree == null:
		return
	tree.create_timer(maxf(duration, 0.05)).timeout.connect(Callable(line, "queue_free"), CONNECT_ONE_SHOT)


static func _to_parent_local(parent: Node, global_position: Vector2) -> Vector2:
	var parent_2d: Node2D = parent as Node2D
	if parent_2d == null:
		return global_position
	return parent_2d.to_local(global_position)


static func execute_chain_end_burst(rules: Dictionary, context: Dictionary, origin_target: Node2D = null) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("chain_end_burst", {}))
	if rule.is_empty():
		return null
	var projectile: Node = context.get("projectile") as Node
	if projectile != null and bool(projectile.get_meta("lightning_chain_end_burst_done", false)):
		return null
	if projectile != null:
		projectile.set_meta("lightning_chain_end_burst_done", true)
	var target: Node2D = origin_target
	if target == null:
		target = context.get("target") as Node2D
	if target == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(int(rule.get("amount", 12)), 0)
	var packet: Dictionary = build_special_packet("lightning_chain_end_burst", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "lightning")), String(rule.get("damage_type", "reaction_damage")))
	packet["can_trigger_reaction"] = bool(rule.get("can_trigger_reaction", false))
	packet["reaction_type"] = "overload"
	packet["reaction_tier"] = "minor"
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 1.0)) - 1.0
	packet["source_instance_id"] = _source_instance_id(context, projectile, "lightning_chain_end_burst")
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": target.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "reaction_damage"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": float(rule.get("radius", 90.0)),
		"max_targets": maxi(int(rule.get("max_targets", 6)), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(0.42, 0.82, 1.0, 0.35)
	})


static func lightning_overload_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("overload_on_voltage", {}))
	var packet: Dictionary = build_special_packet("lightning_overload", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "lightning")), String(rule.get("damage_type", "reaction_damage")))
	packet["reaction_type"] = "overload"
	packet["reaction_tier"] = "major"
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func overload_shock_lightning_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("overload_shock_lightning", {}))
	var packet: Dictionary = build_special_packet("lightning_overload_shock_lightning", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "lightning")), String(rule.get("damage_type", "reaction_damage")))
	packet["reaction_type"] = "overload"
	packet["reaction_tier"] = "major"
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 1.0)) - 1.0
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func shock_consume_reaction_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("shock_consume_reaction", {}))
	var packet: Dictionary = build_special_packet("lightning_shock_consume_reaction", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "lightning")), String(rule.get("damage_type", "reaction_damage")))
	packet["reaction_type"] = "overload"
	packet["reaction_tier"] = "minor"
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func spread_shock_from_shock(rules: Dictionary, context: Dictionary) -> void:
	var rule: Dictionary = _get_dictionary(rules.get("shock_consume_reaction", {}))
	if rule.is_empty():
		return
	var target: Node2D = context.get("target") as Node2D
	var parent: Node = context.get("parent") as Node
	if target == null:
		return
	if parent == null:
		parent = target.get_parent()
	var spread_targets: int = maxi(int(rule.get("spread_shock_targets", 1)), 0)
	if parent == null or spread_targets <= 0:
		return
	var excluded_ids: Array = []
	_add_unique_hit_id(excluded_ids, target)
	for _index: int in range(spread_targets):
		var next_target: Node2D = _find_nearest_target_excluding(parent, target.global_position, context.get("target_group", &"enemies"), excluded_ids, 260.0)
		if next_target == null:
			return
		_add_unique_hit_id(excluded_ids, next_target)
		if next_target.has_method("apply_status"):
			next_target.call("apply_status", &"shock", {
				"stacks": maxi(int(rule.get("spread_shock_stacks", 1)), 1),
				"max_stacks": 1,
				"duration": 0.8 + float(_get_dictionary(rules.get("shock_upgrade", {})).get("duration_add", 0.0))
			})


static func execute_magnetic_storm_on_shock_consume(rules: Dictionary, context: Dictionary) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("magnetic_storm_on_shock_consume", {}))
	if rule.is_empty():
		return null
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(int(rule.get("damage", 4)), 0)
	var packet: Dictionary = build_special_packet("lightning_magnetic_storm", amount, String(rule.get("damage_origin", "field")), false, String(rule.get("element", "lightning")), String(rule.get("damage_type", "area_direct")))
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.85)) - 1.0
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": target.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": float(rule.get("duration", 1.2)),
		"tick_interval": float(rule.get("tick_interval", 0.4)),
		"radius": float(rule.get("radius", 120.0)),
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(0.35, 0.72, 1.0, 0.28)
	})


static func execute_lightning_orbit_before_launch(rules: Dictionary, context: Dictionary, base_damage: int) -> Array[Node2D]:
	var orbit_rule: Dictionary = _get_dictionary(rules.get("orbit_before_launch", {}))
	if orbit_rule.is_empty():
		return []
	var caster: Node2D = context.get("caster") as Node2D
	var parent: Node = context.get("parent") as Node
	if caster == null:
		return []
	if parent == null:
		parent = caster.get_parent()
	if parent == null:
		return []
	var damage_rule: Dictionary = _get_dictionary(rules.get("orbit_contact_damage", {}))
	var slow_rule: Dictionary = _get_dictionary(rules.get("orbit_contact_slow", {}))
	var extra_rule: Dictionary = _get_dictionary(rules.get("orbit_guard_extra_orb", {}))
	var object_count: int = 1 + int(extra_rule.get("orbit_object_count_add", 0))
	var result: Array[Node2D] = []
	var damage_multiplier: float = maxf(1.0 + float(extra_rule.get("damage_multiplier_add", 0.0)), 0.0)
	for index: int in range(maxi(object_count, 1)):
		var amount: int = maxi(roundi(float(damage_rule.get("amount", base_damage)) * damage_multiplier), 0) if not damage_rule.is_empty() else 0
		var packet: Dictionary = build_special_packet("lightning_orbit_guard", amount, String(damage_rule.get("damage_origin", "primary_attack")), true, String(damage_rule.get("element", "lightning")), String(damage_rule.get("damage_type", "direct_magical")))
		packet["can_trigger_reaction"] = false
		packet = DamageTraceContextScript.apply_to_packet(packet, context)
		var status_params: Dictionary = {
			"stacks": 1,
			"max_stacks": 4,
			"duration": 4.0
		}
		var statuses: Array[StringName] = [&"charge"]
		if not slow_rule.is_empty():
			statuses.append(StringName(String(slow_rule.get("status_id", "slow"))))
			status_params["slow_percent"] = float(slow_rule.get("slow_percent", 0.15))
			status_params["duration"] = maxf(float(slow_rule.get("duration", 0.6)), status_params["duration"])
		var orbit: Node2D = CombatObjectFactoryScript.create_orbit_object({
			"parent": parent,
			"owner": caster,
			"object_id": StringName("spinning_sword_blade"),
			"source_id": StringName("lightning_orbit_guard"),
			"damage": amount,
			"damage_type": StringName(String(damage_rule.get("damage_type", "direct_magical"))),
			"damage_packet": packet,
			"orbit_radius": float(orbit_rule.get("radius", 110.0)),
			"rotation_speed": 540.0,
			"hit_interval": float(damage_rule.get("tick_interval", 0.45)),
			"duration": float(orbit_rule.get("duration", 0.6)),
			"max_targets": maxi(int(damage_rule.get("max_targets", 3)), 0),
			"target_group": context.get("target_group", &"enemies"),
			"statuses_on_hit": statuses,
			"status_params": status_params,
			"angle": TAU * float(index) / float(maxi(object_count, 1))
		})
		if orbit != null:
			result.append(orbit)
	return result


static func execute_arcane_page_copy(rules: Dictionary, context: Dictionary, base_damage: int) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("arcane_page_copy_on_hit", {}))
	if rule.is_empty():
		return null
	var projectile: Node = context.get("projectile") as Node
	if projectile != null and bool(projectile.get_meta("arcane_page_copy", false)):
		return null
	if randf() > clampf(float(rule.get("chance", 0.25)), 0.0, 1.0):
		return null
	var hit_target: Node2D = context.get("target") as Node2D
	if hit_target == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = hit_target.get_parent()
	if parent == null:
		return null
	var excluded_ids: Array = []
	if projectile != null:
		var meta_ids: Variant = projectile.get_meta("arcane_page_hit_ids", [])
		if meta_ids is Array:
			excluded_ids = (meta_ids as Array).duplicate(true)
	_add_unique_hit_id(excluded_ids, hit_target)
	var next_target: Node2D = _find_nearest_target_excluding(parent, hit_target.global_position, context.get("target_group", &"enemies"), excluded_ids, 520.0)
	if next_target == null:
		next_target = _find_nearest_target(parent, hit_target.global_position, context.get("target_group", &"enemies"), hit_target)
	if next_target == null:
		return null
	_add_unique_hit_id(excluded_ids, next_target)
	if projectile != null:
		projectile.set_meta("arcane_page_hit_ids", excluded_ids)
	var amount: int = maxi(roundi(float(base_damage) * maxf(float(rule.get("damage_multiplier", 0.45)), 0.0)), 1)
	var packet: Dictionary = build_special_packet("arcane_page_copy", amount, "primary_attack", true, "arcane", "direct_magical")
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.9)) - 1.0
	packet["can_trigger_reaction"] = false
	packet["source_instance_id"] = _source_instance_id(context, projectile, "arcane_page_copy")
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	var direction: Vector2 = hit_target.global_position.direction_to(next_target.global_position)
	if direction == Vector2.ZERO:
		return null
	return CombatObjectFactoryScript.create_projectile({
		"parent": parent,
		"projectile_id": StringName("arcane_page_projectile"),
		"position": hit_target.global_position,
		"direction": direction,
		"damage": amount,
		"damage_type": &"direct_magical",
		"damage_packet": packet,
		"speed": 520.0,
		"pierce": 0,
		"radius": 9.0,
		"lifetime": 1.2,
		"target_group": context.get("target_group", &"enemies"),
		"source_id": &"arcane_page_projectile",
		"event_bus": context.get("event_bus"),
		"skill_instance": context.get("skill_instance"),
		"caster": context.get("caster"),
		"skill_manager": context.get("skill_manager"),
		"relic_manager": context.get("relic_manager"),
		"event_on_hit": &"on_projectile_hit",
		"arcane_page_copy": true,
		"arcane_page_hit_ids": excluded_ids
	})


static func arcane_seal_burst_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("arcane_seal_burst", {}))
	var packet: Dictionary = build_special_packet("arcane_seal_burst", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "arcane")), String(rule.get("damage_type", "reaction_damage")))
	packet["reaction_type"] = "arcane_seal_burst"
	packet["reaction_tier"] = "major"
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.75)) - 1.0
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func apply_forbidden_page_self_damage(caster: Node, context: Dictionary, amount: int) -> void:
	if caster == null or amount <= 0 or not caster.has_method("take_damage"):
		return
	var packet: Dictionary = build_special_packet("forbidden_page_self_damage", amount, "special", false, "arcane", "true_damage")
	packet["ignore_defense"] = true
	packet["ignore_resistance"] = true
	packet["ignore_vulnerability"] = true
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	caster.call("take_damage", packet, &"true_damage")


static func execute_page_spirit_tick(rules: Dictionary, context: Dictionary) -> void:
	var spawn_rule: Dictionary = _get_dictionary(rules.get("page_spirit_spawn", {}))
	if spawn_rule.is_empty():
		return
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return
	var caster_key: String = str(caster.get_instance_id())
	var now_seconds: float = _now_seconds()
	var current_count: int = int(caster.get_meta("page_spirit_count", 0))
	var max_spirits: int = maxi(int(spawn_rule.get("max_spirits", 2)), 0)
	if current_count < max_spirits:
		var spawn_key: String = "page_spirit_spawn:%s" % caster_key
		if now_seconds >= float(_page_spirit_spawn_cooldowns.get(spawn_key, 0.0)):
			current_count += 1
			caster.set_meta("page_spirit_count", current_count)
			_page_spirit_spawn_cooldowns[spawn_key] = now_seconds + maxf(float(spawn_rule.get("spawn_interval", 8.0)), 0.05)
	if current_count <= 0:
		return
	var attack_rule: Dictionary = _get_dictionary(rules.get("page_spirit_attack", {}))
	if attack_rule.is_empty():
		return
	var attack_key: String = "page_spirit_attack:%s" % caster_key
	if now_seconds < float(_page_spirit_attack_cooldowns.get(attack_key, 0.0)):
		return
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = caster.get_parent()
	var target: Node2D = _find_nearest_target(parent, caster.global_position, context.get("target_group", &"enemies"))
	if target == null:
		return
	_page_spirit_attack_cooldowns[attack_key] = now_seconds + maxf(float(attack_rule.get("attack_interval", 1.2)), 0.05)
	var amount: int = maxi(int(attack_rule.get("amount", 5)), 0)
	var packet: Dictionary = build_special_packet("page_spirit_attack", amount, String(attack_rule.get("damage_origin", "special")), false, String(attack_rule.get("element", "arcane")), String(attack_rule.get("damage_type", "summon_damage")))
	packet["boss_damage_multiplier_add"] = float(attack_rule.get("boss_damage_multiplier", 0.8)) - 1.0
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	DamageIntentScript.create(target, packet, StringName(String(attack_rule.get("damage_type", "summon_damage")))).call("apply")


static func page_spirit_intercept(rules: Dictionary, context: Dictionary) -> bool:
	var rule: Dictionary = _get_dictionary(rules.get("page_spirit_intercept", {}))
	if rule.is_empty():
		return false
	var player: Node = context.get("player", context.get("caster")) as Node
	if player == null or int(player.get_meta("page_spirit_count", 0)) <= 0:
		return false
	var now_seconds: float = _now_seconds()
	if now_seconds < float(player.get_meta("page_spirit_intercept_ready_at", 0.0)):
		return false
	player.set_meta("page_spirit_intercept_ready_at", now_seconds + maxf(float(rule.get("same_source_cooldown", 12.0)), 0.0))
	if bool(rule.get("consume_spirit", true)):
		player.set_meta("page_spirit_count", maxi(int(player.get_meta("page_spirit_count", 0)) - 1, 0))
	return true


static func execute_extra_knife_throw(rules: Dictionary, context: Dictionary, base_damage: int) -> Array[Node2D]:
	var rule: Dictionary = _get_dictionary(rules.get("extra_knife_every_n_casts", {}))
	if rule.is_empty():
		return []
	var count: int = maxi(int(rule.get("extra_projectile_count", 1)), 0)
	var result: Array[Node2D] = []
	for index: int in range(count):
		var projectile: Node2D = _spawn_throwing_knife_projectile(rules, context, base_damage, 1.0 + float(rule.get("damage_multiplier_add", -0.35)), "throwing_knife_extra", false, index)
		if projectile != null:
			result.append(projectile)
	return result


static func execution_burst_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("boss_low_hp_execution_burst", {}))
	var packet: Dictionary = build_special_packet("throwing_knife_execution_burst", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "reaction_damage")))
	packet["reaction_type"] = "execution"
	packet["reaction_tier"] = "major"
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func rupture_on_full_wound_crit_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("rupture_on_full_wound_crit", {}))
	var packet: Dictionary = build_special_packet("throwing_knife_rupture", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "reaction_damage")))
	packet["reaction_type"] = "rupture"
	packet["reaction_tier"] = "major"
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.75)) - 1.0
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func execute_recycle_knife(rules: Dictionary, context: Dictionary, base_damage: int) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("recycle_knife_on_normal_kill", {}))
	if rule.is_empty():
		return null
	if String(context.get("source_key", "")).find("throwing_knife_recycle") >= 0 and not bool(rule.get("can_trigger_self", false)):
		return null
	var enemy: Node = context.get("enemy") as Node
	if enemy == null or _is_elite(enemy) or _is_boss(enemy):
		return null
	if randf() > clampf(float(rule.get("chance", 0.35)), 0.0, 1.0):
		return null
	var upgrade: Dictionary = _get_dictionary(rules.get("recycle_knife_upgrade", {}))
	var projectile: Node2D = _spawn_throwing_knife_projectile(rules, context, base_damage, float(upgrade.get("damage_multiplier", 1.0)), "throwing_knife_recycle", true, 0)
	if projectile != null:
		_record_recycle_trigger(rules, context)
	return projectile


static func apply_recycle_dash_buff(rules: Dictionary, context: Dictionary) -> void:
	var rule: Dictionary = _get_dictionary(rules.get("recycle_dash_buff", {}))
	if rule.is_empty():
		return
	var player: Node = context.get("player", context.get("caster")) as Node
	if player == null:
		return
	var now_seconds: float = _now_seconds()
	var duration: float = maxf(float(rule.get("duration", 2.0)), 0.0)
	player.set_meta("recycle_dash_buff_until", now_seconds + duration)
	player.set_meta("recycle_dash_move_speed_multiplier_add", float(rule.get("move_speed_multiplier_add", 0.12)))
	player.set_meta("recycle_dash_dodge_chance_add", float(rule.get("dodge_chance_add", 0.08)))


static func execute_hunter_arrow_shards(rules: Dictionary, context: Dictionary) -> Array[Node2D]:
	var rule: Dictionary = _get_dictionary(rules.get("hunter_arrow_shards_after_pierce_hits", {}))
	if rule.is_empty():
		return []
	var origin_node: Node2D = context.get("target") as Node2D
	if origin_node == null:
		return []
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = origin_node.get_parent()
	if parent == null:
		return []
	var projectile: Node = context.get("projectile") as Node
	var excluded_ids: Array = _get_projectile_hit_ids(projectile)
	_add_unique_hit_id(excluded_ids, origin_node)
	var shard_count: int = maxi(int(rule.get("shard_count", 3)), 0)
	var amount: int = maxi(int(rule.get("amount", 6)), 0)
	var result: Array[Node2D] = []
	for index: int in range(shard_count):
		var target: Node2D = _find_nearest_target_excluding(parent, origin_node.global_position, context.get("target_group", &"enemies"), excluded_ids, 720.0)
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / float(maxi(shard_count, 1)))
		if target != null:
			_add_unique_hit_id(excluded_ids, target)
			direction = origin_node.global_position.direction_to(target.global_position)
		if direction == Vector2.ZERO:
			continue
		var packet: Dictionary = build_special_packet("hunter_arrow_shard", amount, String(rule.get("damage_origin", "primary_attack")), true, String(rule.get("element", "physical")), String(rule.get("damage_type", "direct_physical")))
		packet["can_trigger_reaction"] = bool(rule.get("can_trigger_self", false))
		packet["source_instance_id"] = "hunter_arrow_shard:%d:%d" % [Time.get_ticks_msec(), index]
		packet = DamageTraceContextScript.apply_to_packet(packet, context)
		var shard: Node2D = CombatObjectFactoryScript.create_projectile({
			"parent": parent,
			"projectile_id": StringName("hunter_arrow_projectile"),
			"position": origin_node.global_position,
			"direction": direction.normalized(),
			"damage": amount,
			"damage_type": StringName(String(rule.get("damage_type", "direct_physical"))),
			"damage_packet": packet,
			"speed": float(rule.get("speed", 820.0)),
			"pierce": 0,
			"radius": float(rule.get("collision_radius", 7.0)),
			"lifetime": 0.8,
			"target_group": context.get("target_group", &"enemies"),
			"source_id": &"hunter_arrow_projectile",
			"event_bus": context.get("event_bus"),
			"skill_instance": context.get("skill_instance"),
			"caster": context.get("caster"),
			"skill_manager": context.get("skill_manager"),
			"relic_manager": context.get("relic_manager"),
			"event_on_hit": &"on_projectile_hit"
		})
		if shard != null:
			result.append(shard)
	return result


static func eagle_shot_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("eagle_shot_on_boss_mark_hits", {}))
	var packet: Dictionary = build_special_packet("hunter_bow_eagle_shot", amount, String(rule.get("damage_origin", "primary_attack")), bool(rule.get("can_crit", true)), String(rule.get("element", "physical")), String(rule.get("damage_type", "projectile_heavy")))
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "projectile_heavy")))))
	return intents


static func execute_hunter_arrow_hit_explosion(rules: Dictionary, context: Dictionary, base_damage: int) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("hunter_arrow_hit_explosion", {}))
	if rule.is_empty():
		return null
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var upgrade: Dictionary = _get_dictionary(rules.get("hunter_arrow_explosion_upgrade", {}))
	var radius: float = maxf(float(rule.get("radius", 75.0)) * maxf(1.0 + float(upgrade.get("radius_multiplier_add", 0.0)), 0.05), 1.0)
	var amount: int = maxi(roundi(float(base_damage) * maxf(float(rule.get("damage_multiplier", 0.35)), 0.0)), 0)
	var max_targets: int = maxi(int(upgrade.get("max_targets", 0)), 0)
	var mark_rule: Dictionary = _get_dictionary(rules.get("burst_mark_on_arrow_explosion", rules.get("hunter_arrow_explosion_mark", {})))
	if max_targets == 0 and not mark_rule.is_empty():
		max_targets = maxi(int(mark_rule.get("max_targets", 3)), 0)
	var status_id: StringName = &""
	var status_params: Dictionary = {}
	if not mark_rule.is_empty():
		status_id = StringName(String(mark_rule.get("status_id", "burst_mark")))
		status_params = {
			"duration": float(mark_rule.get("duration", 5.0)),
			"stacks": maxi(int(mark_rule.get("stack", 1)), 1),
			"max_stacks": maxi(int(mark_rule.get("max_stacks", 1)), 1)
		}
	var packet: Dictionary = build_special_packet("hunter_arrow_hit_explosion", amount, String(rule.get("damage_origin", "primary_attack")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "area_direct")))
	packet["can_trigger_reaction"] = false
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": target.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"max_targets": max_targets,
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(0.95, 0.66, 0.22, 0.34),
		"status_on_hit": status_id,
		"status_params": status_params,
		"status_normal_only": bool(mark_rule.get("normal_only", false))
	})


static func execute_burst_mark_death_explosion(rules: Dictionary, context: Dictionary, base_damage: int) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("burst_mark_death_explosion", rules.get("marked_target_death_explosion", {})))
	if rule.is_empty():
		return null
	var enemy: Node2D = context.get("enemy") as Node2D
	if enemy == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = enemy.get_parent()
	if parent == null:
		return null
	var amount: int = maxi(roundi(float(base_damage) * maxf(float(rule.get("damage_multiplier", 0.35)), 0.0)), 0)
	var packet: Dictionary = build_special_packet("hunter_burst_mark_death_explosion", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "area_direct")))
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.75)) - 1.0
	packet["can_trigger_reaction"] = bool(rule.get("can_trigger_self", false))
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": enemy.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": float(rule.get("radius", 52.0)),
		"max_targets": maxi(int(rule.get("max_targets", 6)), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(1.0, 0.74, 0.24, 0.32)
	})


static func execute_marked_target_death_explosion(rules: Dictionary, context: Dictionary, base_damage: int) -> Node2D:
	return execute_burst_mark_death_explosion(rules, context, base_damage)


static func execute_windstep_double_arrow(rules: Dictionary, context: Dictionary, base_damage: int) -> Array[Node2D]:
	var rule: Dictionary = _get_dictionary(rules.get("windstep_double_arrow", {}))
	if rule.is_empty():
		return []
	var count: int = maxi(int(rule.get("extra_projectile_count", 1)), 0)
	var result: Array[Node2D] = []
	for index: int in range(count):
		var projectile: Node2D = _spawn_hunter_arrow_projectile(rules, context, base_damage, 1.0 + float(rule.get("damage_multiplier_add", -0.25)), "hunter_windstep_double_arrow", index)
		if projectile != null:
			result.append(projectile)
	return result


static func execute_small_trap_on_trigger(rules: Dictionary, context: Dictionary, base_damage: int) -> Array[Node2D]:
	var rule: Dictionary = _get_dictionary(rules.get("small_trap_on_trigger", {}))
	if rule.is_empty():
		return []
	var hit_target: Node2D = context.get("target") as Node2D
	if hit_target == null:
		return []
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = hit_target.get_parent()
	if parent == null:
		return []
	var upgrade: Dictionary = _get_dictionary(rules.get("small_trap_upgrade", {}))
	var max_active: int = int(upgrade.get("max_active", 0))
	if max_active > 0:
		_enforce_child_meta_limit(parent, "small_trap", max_active)
	var count: int = maxi(int(rule.get("count", 1)), 0)
	var spawn_radius: float = maxf(float(rule.get("spawn_radius", 120.0)), 1.0)
	var radius: float = maxf(float(rule.get("radius", 90.0)) * maxf(1.0 + float(upgrade.get("radius_multiplier_add", 0.0)), 0.05), 1.0)
	var amount: int = maxi(roundi(float(base_damage) * maxf(float(rule.get("damage_multiplier", 0.5)), 0.0)), 1)
	var result: Array[Node2D] = []
	for index: int in range(count):
		var angle: float = TAU * float(index) / float(maxi(count, 1)) + randf() * 0.35
		var area: Node2D = CombatObjectFactoryScript.create_area_effect({
			"parent": parent,
			"area_id": &"bear_trap_area",
			"position": hit_target.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius,
			"damage": amount,
			"damage_type": &"trap_damage",
			"damage_packet": DamageTraceContextScript.apply_to_packet(build_special_packet("trap_small_chain", amount, "trap", false, "physical", "trap_damage"), context),
			"duration": float(rule.get("duration", 6.0)),
			"tick_interval": float(rule.get("tick_interval", 0.2)),
			"radius": radius,
			"target_group": context.get("target_group", &"enemies"),
			"visual_color": Color(0.86, 0.74, 0.28, 0.32),
			"event_bus": context.get("event_bus"),
			"skill_instance": context.get("skill_instance"),
			"caster": context.get("caster"),
			"skill_manager": context.get("skill_manager"),
			"relic_manager": context.get("relic_manager"),
			"event_on_hit": &"on_trap_hit",
			"finish_after_damage": bool(rule.get("finish_after_damage", true))
		})
		if area != null:
			area.set_meta("small_trap", true)
			result.append(area)
	return result


static func pincer_reaction_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("pincer_reaction_on_root", {}))
	var packet: Dictionary = build_special_packet("trap_pincer_reaction", amount, String(rule.get("damage_origin", "reaction")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "reaction_damage")))
	packet["reaction_type"] = "trap_pincer"
	packet["reaction_tier"] = "normal"
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "reaction_damage")))))
	return intents


static func boss_core_trap_bonus_intents(rules: Dictionary, context: Dictionary, amount: int) -> Array[RefCounted]:
	var intents: Array[RefCounted] = []
	var target: Node = context.get("target") as Node
	if target == null or amount <= 0:
		return intents
	var rule: Dictionary = _get_dictionary(rules.get("boss_core_trap_bonus_damage", {}))
	var packet: Dictionary = build_special_packet("trap_boss_core_bonus", amount, String(rule.get("damage_origin", "trap")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "trap_damage")))
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	intents.append(DamageIntentScript.create(target, packet, StringName(String(rule.get("damage_type", "trap_damage")))))
	return intents


static func execute_trap_hit_explosion(rules: Dictionary, context: Dictionary, base_damage: int) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("trap_hit_explosion", {}))
	if rule.is_empty():
		return null
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = target.get_parent()
	if parent == null:
		return null
	var upgrade: Dictionary = _get_dictionary(rules.get("trap_explosion_upgrade", {}))
	var amount: int = maxi(roundi(float(base_damage) * maxf(float(rule.get("damage_multiplier", 1.0)) + float(upgrade.get("damage_multiplier_add", 0.0)), 0.0)), 1)
	var packet: Dictionary = build_special_packet("trap_hit_explosion", amount, String(rule.get("damage_origin", "trap")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "area_direct")))
	packet["can_trigger_reaction"] = false
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"generic_explosion_area",
		"position": target.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": float(rule.get("radius", 100.0)),
		"max_targets": maxi(int(rule.get("max_targets", 6)), 0),
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(1.0, 0.24, 0.16, 0.34)
	})


static func execute_trap_kill_fragment_field(rules: Dictionary, context: Dictionary) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("trap_kill_fragment_field", {}))
	if rule.is_empty():
		return null
	var enemy: Node2D = context.get("enemy") as Node2D
	if enemy == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = enemy.get_parent()
	if parent == null:
		return null
	_enforce_fragment_field_limit(maxi(int(rule.get("max_active", 4)), 0))
	var amount: int = maxi(int(rule.get("amount", 4)), 0)
	var packet: Dictionary = build_special_packet("trap_fragment_field", amount, String(rule.get("damage_origin", "field")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "trap_damage")))
	packet["boss_damage_multiplier_add"] = float(rule.get("boss_damage_multiplier", 0.85)) - 1.0
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"generic_explosion_area",
		"position": enemy.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "trap_damage"))),
		"damage_packet": packet,
		"duration": float(rule.get("duration", 1.5)),
		"tick_interval": float(rule.get("tick_interval", 0.5)),
		"radius": float(rule.get("radius", 80.0)),
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(0.95, 0.32, 0.18, 0.24)
	})
	if area != null:
		area.set_meta("trap_fragment_field", true)
		_trap_fragment_field_ids.append(int(area.get_instance_id()))
	return area


static func execute_decoy_trap_spawn(rules: Dictionary, context: Dictionary) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("decoy_trap_spawn", {}))
	if rule.is_empty():
		return null
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = caster.get_parent()
	if parent == null:
		return null
	var upgrade: Dictionary = _get_dictionary(rules.get("decoy_trap_upgrade", {}))
	var hp: int = maxi(roundi(float(rule.get("hp", 40)) * maxf(1.0 + float(upgrade.get("hp_multiplier_add", 0.0)), 0.05)), 1)
	var area: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"bear_trap_area",
		"position": caster.global_position,
		"damage": 0,
		"duration": float(rule.get("duration", 4.0)),
		"tick_interval": 0.5,
		"radius": float(rule.get("radius", 90.0)),
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(0.45, 0.85, 1.0, 0.26),
		"event_bus": context.get("event_bus"),
		"skill_instance": context.get("skill_instance"),
		"caster": caster,
		"skill_manager": context.get("skill_manager"),
		"relic_manager": context.get("relic_manager"),
		"event_on_expire": &"on_trap_expired"
	})
	if area != null:
		area.set_meta("decoy_trap", true)
		area.set_meta("decoy_trap_hp", hp)
		var decoy_rule: Dictionary = _get_dictionary(rules.get("decoy_trap_explosion", {}))
		area.set_meta("decoy_attracts_normal", bool(decoy_rule.get("attracts_normal", false)))
		var boss_rule: Dictionary = _get_dictionary(rules.get("decoy_boss_core_bonus", {}))
		area.set_meta("boss_summon_prefer_decoy", bool(boss_rule.get("boss_summon_prefer_decoy", false)))
	return area


static func execute_decoy_trap_explosion(rules: Dictionary, context: Dictionary) -> Node2D:
	var rule: Dictionary = _get_dictionary(rules.get("decoy_trap_explosion", {}))
	if rule.is_empty() or not bool(rule.get("explode_on_expire", true)):
		return null
	var area: Node2D = context.get("area") as Node2D
	if area == null:
		return null
	var parent: Node = context.get("parent") as Node
	if parent == null:
		parent = area.get_parent()
	if parent == null:
		return null
	var upgrade: Dictionary = _get_dictionary(rules.get("decoy_trap_upgrade", {}))
	var boss_rule: Dictionary = _get_dictionary(rules.get("decoy_boss_core_bonus", {}))
	var radius: float = maxf(float(rule.get("radius", 90.0)) * maxf(1.0 + float(upgrade.get("explosion_radius_multiplier_add", 0.0)), 0.05), 1.0)
	var amount: int = maxi(int(rule.get("amount", 12)), 0)
	var packet: Dictionary = build_special_packet("decoy_trap_explosion", amount, String(rule.get("damage_origin", "special")), false, String(rule.get("element", "physical")), String(rule.get("damage_type", "area_direct")))
	packet["boss_core_damage_multiplier_add"] = float(boss_rule.get("boss_core_damage_multiplier_add", 0.0))
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"area_id": &"generic_explosion_area",
		"position": area.global_position,
		"damage": amount,
		"damage_type": StringName(String(rule.get("damage_type", "area_direct"))),
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": radius,
		"target_group": context.get("target_group", &"enemies"),
		"visual_color": Color(0.48, 0.9, 1.0, 0.32)
	})


static func _record_recycle_trigger(rules: Dictionary, context: Dictionary) -> void:
	var rule: Dictionary = _get_dictionary(rules.get("recycle_dash_buff", {}))
	if rule.is_empty():
		return
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return
	var now_seconds: float = _now_seconds()
	var window: float = maxf(float(rule.get("window", 3.0)), 0.0)
	var events: Array = []
	var value: Variant = caster.get_meta("recycle_knife_trigger_times", [])
	if value is Array:
		events = value
	events.append(now_seconds)
	var filtered: Array = []
	for event_time_variant: Variant in events:
		var event_time: float = float(event_time_variant)
		if now_seconds - event_time <= window:
			filtered.append(event_time)
	caster.set_meta("recycle_knife_trigger_times", filtered)
	if filtered.size() >= maxi(int(rule.get("required_recycles", 3)), 1):
		apply_recycle_dash_buff(rules, context)
		caster.set_meta("recycle_knife_trigger_times", [])


static func _spawn_throwing_knife_projectile(rules: Dictionary, context: Dictionary, base_damage: int, damage_multiplier: float, source_key: String, prefer_low_hp: bool, projectile_index: int) -> Node2D:
	var caster: Node2D = context.get("caster") as Node2D
	var parent: Node = context.get("parent") as Node
	if caster == null:
		return null
	if parent == null:
		parent = caster.get_parent()
	if parent == null:
		return null
	var origin: Vector2 = caster.global_position
	var killed_enemy: Node2D = context.get("enemy") as Node2D
	if killed_enemy != null:
		origin = killed_enemy.global_position
	var target: Node2D = _find_lowest_hp_target(parent, origin, context.get("target_group", &"enemies")) if prefer_low_hp else _find_nearest_target(parent, origin, context.get("target_group", &"enemies"), killed_enemy)
	if target == null:
		return null
	var direction: Vector2 = origin.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		return null
	var amount: int = maxi(roundi(float(base_damage) * maxf(damage_multiplier, 0.0)), 1)
	var packet: Dictionary = build_special_packet(source_key, amount, "primary_attack", true, "physical", "direct_physical")
	packet["source_instance_id"] = "%s:%d:%d" % [source_key, Time.get_ticks_msec(), projectile_index]
	packet["can_trigger_reaction"] = false
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_projectile({
		"parent": parent,
		"projectile_id": StringName("throwing_knife_projectile"),
		"position": origin,
		"direction": direction,
		"damage": amount,
		"damage_type": &"direct_physical",
		"damage_packet": packet,
		"speed": 700.0,
		"pierce": 0,
		"radius": 8.0,
		"lifetime": 1.2,
		"target_group": context.get("target_group", &"enemies"),
		"source_id": &"throwing_knife_projectile",
		"event_bus": context.get("event_bus"),
		"skill_instance": context.get("skill_instance"),
		"caster": caster,
		"skill_manager": context.get("skill_manager"),
		"relic_manager": context.get("relic_manager"),
		"event_on_hit": &"on_projectile_hit"
	})


static func _spawn_hunter_arrow_projectile(_rules: Dictionary, context: Dictionary, base_damage: int, damage_multiplier: float, source_key: String, projectile_index: int) -> Node2D:
	var caster: Node2D = context.get("caster") as Node2D
	var parent: Node = context.get("parent") as Node
	if caster == null:
		return null
	if parent == null:
		parent = caster.get_parent()
	if parent == null:
		return null
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		target = _find_nearest_target(parent, caster.global_position, context.get("target_group", &"enemies"))
	if target == null:
		return null
	var direction: Vector2 = caster.global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		return null
	var amount: int = maxi(roundi(float(base_damage) * maxf(damage_multiplier, 0.0)), 1)
	var packet: Dictionary = build_special_packet(source_key, amount, "primary_attack", true, "physical", "direct_physical")
	packet["source_instance_id"] = "%s:%d:%d" % [source_key, Time.get_ticks_msec(), projectile_index]
	packet["can_trigger_reaction"] = false
	packet = DamageTraceContextScript.apply_to_packet(packet, context)
	return CombatObjectFactoryScript.create_projectile({
		"parent": parent,
		"projectile_id": StringName("hunter_arrow_projectile"),
		"position": caster.global_position + direction.normalized() * 24.0,
		"direction": direction.normalized(),
		"damage": amount,
		"damage_type": &"direct_physical",
		"damage_packet": packet,
		"speed": 760.0,
		"pierce": 3,
		"radius": 9.0,
		"lifetime": 1.25,
		"target_group": context.get("target_group", &"enemies"),
		"source_id": &"hunter_arrow_projectile",
		"event_bus": context.get("event_bus"),
		"skill_instance": context.get("skill_instance"),
		"caster": caster,
		"skill_manager": context.get("skill_manager"),
		"relic_manager": context.get("relic_manager"),
		"event_on_hit": &"on_projectile_hit"
	})


static func _enforce_child_meta_limit(parent: Node, meta_key: String, max_active: int) -> void:
	if parent == null or meta_key == "" or max_active <= 0:
		return
	var matches: Array[Node] = []
	for child: Node in parent.get_children():
		if child == null or not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if bool(child.get_meta(meta_key, false)):
			matches.append(child)
	while matches.size() >= max_active:
		var oldest: Node = matches.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()


static func _enforce_fragment_field_limit(max_active: int) -> void:
	if max_active <= 0:
		return
	var live_ids: Array[int] = []
	for id: int in _trap_fragment_field_ids:
		var instance: Object = instance_from_id(id)
		if instance is Node and is_instance_valid(instance) and not (instance as Node).is_queued_for_deletion():
			live_ids.append(id)
	_trap_fragment_field_ids = live_ids
	while _trap_fragment_field_ids.size() >= max_active:
		var oldest_id: int = _trap_fragment_field_ids.pop_front()
		var oldest: Object = instance_from_id(oldest_id)
		if oldest is Node and is_instance_valid(oldest):
			(oldest as Node).queue_free()


static func apply_intents(intents: Array[RefCounted]) -> void:
	for intent: RefCounted in intents:
		if intent != null:
			intent.call("apply")


static func build_special_packet(source_id: String, amount: int, origin: String, can_crit: bool, element: String = "fire", damage_type: String = "") -> Dictionary:
	var args: Dictionary = {
		"source_id": source_id,
		"amount": amount,
		"damage_origin": origin,
		"element": StringName(element),
		"can_crit": can_crit,
		"special_rule_tags": ["fireball_special_rule"]
	}
	if damage_type != "":
		args["damage_type"] = StringName(damage_type)
	return DamagePacketBuilderScript.from_special_rule({
		"source_id": args["source_id"],
		"amount": args["amount"],
		"damage_origin": args["damage_origin"],
		"damage_type": args.get("damage_type", &"area_direct" if origin != "special" else &"true_damage"),
		"element": args["element"],
		"can_crit": args["can_crit"],
		"special_rule_tags": args["special_rule_tags"]
	})


static func _get_skill_base_damage(context: Dictionary, fallback: int) -> int:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return fallback
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition != null and definition.has_method("get_base_stat"):
		return maxi(roundi(float(definition.call("get_base_stat", "damage", fallback))), 0)
	return maxi(roundi(float(SkillStatServiceScript.get_effective_stat(
		skill_instance,
		"damage",
		fallback,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	))), 0)


static func _merge_existing_lava_zone(parent: Node, position: Vector2, radius: float, duration: float, rule: Dictionary) -> bool:
	for child: Node in parent.get_children():
		var area: Node2D = child as Node2D
		if area == null or not bool(area.get_meta("fireball_lava_zone", false)):
			continue
		if area.global_position.distance_squared_to(position) > radius * radius:
			continue
		if area.has_method("extend_duration"):
			area.call("extend_duration", duration + float(rule.get("duration_add", 1.0)), float(rule.get("max_duration", 5.0)))
		return true
	return false


static func _count_active_lava_zones(parent: Node) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child != null and bool(child.get_meta("fireball_lava_zone", false)) and not child.is_queued_for_deletion():
			count += 1
	return count


static func _knockback_targets(parent: Node, origin: Vector2, radius: float, force: float, target_group: Variant) -> void:
	if parent == null or force <= 0.0:
		return
	var tree: SceneTree = parent.get_tree()
	if tree == null:
		return
	var radius_squared: float = radius * radius
	for node: Node in tree.get_nodes_in_group(StringName(String(target_group))):
		var target: Node2D = node as Node2D
		if target == null or target.global_position.distance_squared_to(origin) > radius_squared:
			continue
		var direction: Vector2 = origin.direction_to(target.global_position)
		if direction != Vector2.ZERO:
			target.global_position += direction.normalized() * force


static func _find_targets_in_radius(context: Dictionary, origin: Vector2, radius: float) -> Array[Node2D]:
	var parent: Node = context.get("parent") as Node
	if parent == null:
		var player: Node2D = context.get("player", context.get("caster")) as Node2D
		parent = player.get_parent() if player != null else null
	if parent == null:
		return []
	var tree: SceneTree = parent.get_tree()
	if tree == null:
		return []
	var targets: Array[Node2D] = []
	var radius_squared: float = radius * radius
	for node: Node in tree.get_nodes_in_group(StringName(String(context.get("target_group", &"enemies")))):
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if target.global_position.distance_squared_to(origin) <= radius_squared:
			targets.append(target)
	return targets


static func _find_nearest_target(parent: Node, origin: Vector2, target_group: Variant, excluded: Node = null) -> Node2D:
	if parent == null:
		return null
	var tree: SceneTree = parent.get_tree()
	if tree == null:
		return null
	var best: Node2D = null
	var best_distance: float = INF
	for node: Node in tree.get_nodes_in_group(StringName(String(target_group))):
		var target: Node2D = node as Node2D
		if target == null or target == excluded or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		var distance: float = origin.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


static func _find_nearest_target_excluding(parent: Node, origin: Vector2, target_group: Variant, excluded_ids: Array, max_distance: float) -> Node2D:
	if parent == null:
		return null
	var tree: SceneTree = parent.get_tree()
	if tree == null:
		return null
	var max_distance_squared: float = max_distance * max_distance
	var best: Node2D = null
	var best_distance: float = INF
	for node: Node in tree.get_nodes_in_group(StringName(String(target_group))):
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if excluded_ids.has(int(target.get_instance_id())):
			continue
		var distance: float = origin.distance_squared_to(target.global_position)
		if distance > max_distance_squared or distance >= best_distance:
			continue
		best_distance = distance
		best = target
	return best


static func _find_lowest_hp_target(parent: Node, origin: Vector2, target_group: Variant) -> Node2D:
	if parent == null:
		return null
	var tree: SceneTree = parent.get_tree()
	if tree == null:
		return null
	var best: Node2D = null
	var best_health: float = INF
	var best_distance: float = INF
	for node: Node in tree.get_nodes_in_group(StringName(String(target_group))):
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		var current_health: float = float(target.get("current_health"))
		var distance: float = origin.distance_squared_to(target.global_position)
		if current_health < best_health or (is_equal_approx(current_health, best_health) and distance < best_distance):
			best_health = current_health
			best_distance = distance
			best = target
	return best


static func _get_projectile_hit_ids(projectile: Node) -> Array:
	if projectile == null:
		return []
	var value: Variant = projectile.get_meta("lightning_chain_targets", [])
	if value is Array:
		return (value as Array).duplicate(true)
	return []


static func _add_unique_hit_id(hit_ids: Array, target: Node) -> void:
	if target == null:
		return
	var target_id: int = int(target.get_instance_id())
	if not hit_ids.has(target_id):
		hit_ids.append(target_id)


static func _source_instance_id(context: Dictionary, source: Node, fallback: String) -> String:
	if source != null:
		return "%s:%s" % [fallback, str(source.get_instance_id())]
	return "%s:%d" % [fallback, Time.get_ticks_msec()]


static func _has_status(target: Node, status_id: StringName) -> bool:
	return target != null and target.has_method("has_status") and bool(target.call("has_status", status_id))


static func _target_status_max_stacks(_target: Node, status_id: StringName, fallback: int) -> int:
	match status_id:
		&"poison":
			return maxi(fallback, 3)
		_:
			return maxi(fallback, 1)


static func _count_active_toxic_small_clouds(parent: Node) -> int:
	if parent == null:
		return 0
	var count: int = 0
	for child: Node in parent.get_children():
		if child != null and bool(child.get_meta("toxic_vial_small_cloud", false)) and not child.is_queued_for_deletion():
			count += 1
	return count


static func _remove_oldest_toxic_small_cloud(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child != null and bool(child.get_meta("toxic_vial_small_cloud", false)) and not child.is_queued_for_deletion():
			child.queue_free()
			return


static func _is_boss(target: Node) -> bool:
	return target != null and (target.is_in_group(&"bosses") or bool(target.get_meta("is_boss", false)) or String(target.get_meta("enemy_rank", "")) == "boss")


static func _is_elite(target: Node) -> bool:
	return target != null and (target.is_in_group(&"elites") or bool(target.get_meta("is_elite", false)) or String(target.get_meta("enemy_rank", "")) == "elite")


static func _is_boss_core(target: Node) -> bool:
	return target != null and (target.is_in_group(&"boss_cores") or bool(target.get_meta("is_boss_core", false)) or String(target.get_meta("enemy_type", "")) == "boss_core")


static func _health_ratio(target: Node) -> float:
	if target == null:
		return 1.0
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	return clampf(float(target.get("current_health")) / max_health, 0.0, 1.0)


static func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


static func _get_root_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
