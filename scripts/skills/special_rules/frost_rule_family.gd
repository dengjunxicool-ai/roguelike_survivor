extends RefCounted

const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

static var _frost_lock_bonus_hit_cooldowns: Dictionary = {}

static var _frost_core_crack_cooldowns: Dictionary = {}

static var _shatter_target_cooldowns: Dictionary = {}

static var _near_player_freeze_cooldowns: Dictionary = {}

static var _frost_lock_cooldowns: Dictionary = {}

static var _frostbite_cooldowns: Dictionary = {}

var _host_ref: WeakRef

func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


func _prepare_storm_hail_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("storm_hail_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("storm_hail_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 4)), 1)
	var cast_count: int = host._advance_interval_counter(skill_instance, "storm_hail_cast_count")
	skill_instance.set_meta("storm_hail_next_cast", cast_count % interval == 0)


func _apply_frost_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_frost_lock_on_direct_hit(rules, context)
	host._apply_frost_lock_bonus_hit(rules, context)
	host._apply_frostbite_freeze_or_poise(rules, context)
	host._apply_frostbite_on_hail_hit(rules, context)
	host._apply_shatter_on_freeze_or_frost_hit(rules, context)


func _apply_frost_reaction_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_frost_core_crack_on_boss_poise(rules, context)


func _apply_frost_lock_on_direct_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("frost_lock_on_elite_boss_direct_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	if not host._is_elite(target) and not host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("frost_lock_on_elite_boss_direct_hit", {}))
	var key: String = "frost_lock:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_frost_lock_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 0.6)), 0.0)):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "frost_lock"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 4)),
		"duration": float(rule.get("duration", 5.0))
	})


func _apply_frost_lock_bonus_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("frost_lock_bonus_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	if not host._is_elite(target) and not host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("frost_lock_bonus_hit", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "frost_lock")))
	if int(target.call("get_status_stack", status_id)) < maxi(int(rule.get("required_stacks", 4)), 1):
		return
	var key: String = "frost_lock_bonus:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_frost_lock_bonus_hit_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)):
		return
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, int(rule.get("consume_stacks", 4)))
	if host._is_boss(target) and bool(rule.get("boss_converts_to_poise", true)):
		ReactionLimiterScript.apply_boss_control_conversion(target, &"freeze")
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.frost_bonus_hit_intents(rules, context, maxi(int(rule.get("amount", 14)), 0), "frost_lock_bonus_hit"))


func _apply_frostbite_on_hail_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("frostbite_on_hail_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("frostbite_on_hail_hit", {}))
	var key: String = "frostbite:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_frostbite_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 0.4)), 0.0)):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "frostbite"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 3)),
		"duration": float(rule.get("duration", 4.0))
	})


func _apply_frostbite_freeze_or_poise(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("frostbite_freeze_or_poise"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("frostbite_freeze_or_poise", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "frostbite")))
	if int(target.call("get_status_stack", status_id)) < maxi(int(rule.get("required_stacks", 3)), 1):
		return
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, int(rule.get("consume_stacks", 3)))
	if host._is_boss(target):
		if bool(rule.get("boss_converts_to_poise", true)):
			ReactionLimiterScript.apply_boss_control_conversion(target, &"freeze")
	elif target.has_method("apply_status"):
		var duration: float = float(rule.get("elite_freeze_duration", 0.3)) if host._is_elite(target) else float(rule.get("normal_freeze_duration", 0.6))
		target.call("apply_status", &"freeze", {
			"duration": duration,
			"stacks": 1,
			"max_stacks": 1
		})


func _apply_frost_core_crack_on_boss_poise(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("frost_core_crack_on_boss_poise"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not host._is_boss(target):
		return
	var completed_at: float = float(target.get_meta("boss_poise_recently_completed_at", -9999.0))
	if host._now_seconds() - completed_at > 0.2:
		return
	var completed_count: int = int(target.get_meta("boss_poise_completed_count", 0))
	var consumed_count: int = int(target.get_meta("frost_core_crack_consumed_poise_count", 0))
	if completed_count <= consumed_count:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("frost_core_crack_on_boss_poise", {}))
	var key: String = "frost_core_crack:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if now_seconds < float(_frost_core_crack_cooldowns.get(key, 0.0)):
		return
	if not host._reserve_cooldown(_frost_core_crack_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 2.5)), 0.0)):
		return
	target.set_meta("frost_core_crack_consumed_poise_count", completed_count)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.frost_core_crack_intents(rules, context, maxi(int(rule.get("amount", 30)), 0)))


func _apply_shatter_on_freeze_or_frost_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("shatter_on_freeze_or_frost_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("has_status"):
		return
	if not bool(target.call("has_status", &"freeze")):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("shatter_on_freeze_or_frost_hit", {}))
	var key: String = "shatter:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_shatter_target_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.execute_shatter_area(rules, context)


func _apply_boss_poise_upgrade_meta(context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	if not rules.has("boss_poise_upgrade"):
		return
	var target: Node = context.get("target") as Node
	if not host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("boss_poise_upgrade", {}))
	target.set_meta("boss_poise_duration_add", maxf(float(rule.get("duration_add", 2.0)), 0.0))


func _apply_boss_poise_damage_bonus(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("boss_poise_upgrade") or not host._is_boss(target):
		return
	if host._now_seconds() > float(target.get_meta("boss_poise_window_until", -1.0)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("boss_poise_upgrade", {}))
	packet["direct_damage_multiplier_add"] = float(packet.get("direct_damage_multiplier_add", 0.0)) + float(rule.get("damage_multiplier_add", 0.08))


func _apply_storm_hail_boss_modifier(packet: Dictionary, rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("storm_hail_every_n_casts") or not host._is_boss(target):
		return
	var projectile: Node = context.get("projectile") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if projectile == null or skill_instance == null:
		return
	if String(projectile.get_meta("cast_instance_id", "")) != String(skill_instance.get_meta("storm_hail_cast_instance_id", "")):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("storm_hail_every_n_casts", {}))
	packet["boss_damage_multiplier_add"] = float(packet.get("boss_damage_multiplier_add", 0.0)) + float(rule.get("boss_damage_multiplier", 0.8)) - 1.0


func _apply_frost_aura_slow(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("frost_aura_slow"):
		return
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("frost_aura_slow", {}))
	var radius: float = maxf(float(rule.get("radius", 120.0)) * maxf(1.0 + float(rule.get("radius_multiplier_add", 0.0)), 0.05), 1.0)
	var radius_squared: float = radius * radius
	var target_group: StringName = StringName(String(context.get("target_group", &"enemies")))
	var registry: Node = CombatTargetRegistryScript.get_or_create(caster)
	var targets: Array = registry.call("get_targets_in_radius", caster.global_position, radius, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in targets:
		var enemy: Node2D = node as Node2D
		if enemy == null or caster.global_position.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", StringName(String(rule.get("status_id", "slow"))), {
				"duration": float(rule.get("duration", 0.35)),
				"slow_percent": float(rule.get("slow_percent", 0.15))
			})


func _apply_freeze_frostbite_near_player(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("freeze_frostbite_near_player"):
		return
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("freeze_frostbite_near_player", {}))
	var radius: float = maxf(float(rule.get("radius", 90.0)), 1.0)
	var radius_squared: float = radius * radius
	var target_group: StringName = StringName(String(context.get("target_group", &"enemies")))
	var registry: Node = CombatTargetRegistryScript.get_or_create(caster)
	var targets: Array = registry.call("get_targets_in_radius", caster.global_position, radius, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in targets:
		var enemy: Node2D = node as Node2D
		if enemy == null or not enemy.has_method("get_status_stack") or caster.global_position.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		if int(enemy.call("get_status_stack", StringName(String(rule.get("status_id", "frostbite"))))) < maxi(int(rule.get("required_stacks", 1)), 1):
			continue
		var key: String = "near_freeze:%s" % host._target_key(enemy)
		var now_seconds: float = host._now_seconds()
		if not host._reserve_cooldown(_near_player_freeze_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 5.0)), 0.0)):
			continue
		if host._is_boss(enemy) and bool(rule.get("boss_converts_to_poise", true)):
			ReactionLimiterScript.apply_boss_control_conversion(enemy, &"freeze")
			host._apply_frost_core_crack_on_boss_poise(rules, context.merged({"target": enemy}))
		elif enemy.has_method("apply_status"):
			enemy.call("apply_status", &"freeze", {"duration": float(rule.get("freeze_duration", 0.5))})
