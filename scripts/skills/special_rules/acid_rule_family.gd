extends RefCounted

const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

static var _acid_burst_cooldowns: Dictionary = {}

static var _boss_acid_mark_pulse_counts: Dictionary = {}

static var _corrosive_film_boss_hit_cooldowns: Dictionary = {}

var _host_ref: WeakRef

func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


func _prepare_acid_pressure_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("acid_pressure_every_n_casts"):
		return
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("acid_pressure_every_n_casts", {}))
	var interval: int = maxi(int(rule.get("cast_interval", 4)), 1)
	var cast_count: int = int(skill_instance.get_meta("acid_pressure_cast_count", 0)) + 1
	skill_instance.set_meta("acid_pressure_cast_count", cast_count)
	skill_instance.set_meta("acid_pressure_next_cast", cast_count % interval == 0)


func _apply_acid_spray_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("acid_sprayer_base"):
		return
	if String(context.get("source_id", "")) != "acid_spray_cone_area":
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	host._apply_acid_mark_on_strong_tick(rules, target)
	host._apply_acid_residue_on_tick(rules, target)
	host._apply_acid_hit_shield(rules, context)
	host._apply_boss_acid_mark_armor_break_pulse(rules, target)
	host._apply_acid_burst_on_full_status(rules, context, target)


func _apply_acid_mark_on_strong_tick(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("acid_mark_on_strong_acid_tick") or target == null or not target.has_method("apply_status"):
		return
	if not (host._is_elite(target) or host._is_boss(target)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("acid_mark_on_strong_acid_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "acid_mark"))), {
		"duration": float(rule.get("duration", 4.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 5)), 1)
	})


func _apply_acid_residue_on_tick(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("acid_residue_on_acid_tick") or target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("acid_residue_on_acid_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "acid_residue"))), {
		"duration": float(rule.get("duration", 5.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 5)), 1)
	})


func _apply_acid_burst_on_full_status(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if target == null or not target.has_method("get_status_stack"):
		return
	var trigger_rule: Dictionary = host._get_dictionary(rules.get("acid_burst_on_full_acid_mark_hit", {}))
	if trigger_rule.is_empty():
		trigger_rule = host._get_dictionary(rules.get("acid_burst_on_full_acid_residue_hit", {}))
	if trigger_rule.is_empty():
		return
	var status_id: StringName = StringName(String(trigger_rule.get("required_status_id", "acid_mark")))
	var required: int = maxi(int(trigger_rule.get("required_stacks", 5)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return
	var cooldown_rule: Dictionary = host._get_dictionary(rules.get("acid_burst_cooldown_tuning", {}))
	var cooldown: float = maxf(float(cooldown_rule.get("same_target_cooldown", trigger_rule.get("same_target_cooldown", 2.0))), 0.0)
	var key: String = "acid_burst:%s:%s:%s" % [String(context.get("source_instance_id", "")), String(status_id), host._target_key(target)]
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_acid_burst_cooldowns, key, now_seconds, cooldown):
		return
	SpecialDamageRuleHandlerScript.execute_acid_burst(rules, context)


func _apply_acid_hit_shield(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("acid_hit_shield"):
		return
	var caster: Node = context.get("caster") as Node
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if caster == null or skill_instance == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("acid_hit_shield", {}))
	var hits_required: int = maxi(int(rule.get("hits_required", 5)), 1)
	var hit_count: int = int(skill_instance.get_meta("acid_hit_shield_count", 0)) + 1
	if hit_count < hits_required:
		skill_instance.set_meta("acid_hit_shield_count", hit_count)
		return
	skill_instance.set_meta("acid_hit_shield_count", 0)
	SpecialDamageRuleHandlerScript.grant_corrosive_film(rules, context, caster, int(rule.get("shield_value", 8)), float(rule.get("shield_duration", 4.0)))


func _apply_boss_acid_mark_armor_break_pulse(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("boss_acid_mark_armor_break_pulse") or not host._is_boss(target):
		return
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("boss_acid_mark_armor_break_pulse", {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "acid_mark")))
	var required: int = maxi(int(rule.get("required_stacks", 5)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return
	var interval: int = maxi(int(rule.get("tick_interval", 3)), 1)
	var key: String = "boss_acid_mark:%s" % host._target_key(target)
	var tick_count: int = int(_boss_acid_mark_pulse_counts.get(key, 0)) + 1
	_boss_acid_mark_pulse_counts[key] = tick_count
	if tick_count % interval != 0:
		return
	target.set_meta("acid_boss_defense_reduction", maxf(float(rule.get("defense_reduction", 2.0)), 0.0))
	target.set_meta("acid_boss_defense_reduction_until", host._now_seconds() + maxf(float(rule.get("duration", 3.0)), 0.0))


func _update_corrosive_film(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("corrosive_film_nearby_acid_mark"):
		return
	var player: Node2D = context.get("caster", context.get("player")) as Node2D
	if player == null:
		return
	if float(player.get_meta("corrosive_film_shield_points", 0)) <= 0.0:
		return
	if host._now_seconds() > float(player.get_meta("corrosive_film_until", 0.0)):
		player.set_meta("corrosive_film_shield_points", 0)
		return
	var rule: Dictionary = host._get_dictionary(rules.get("corrosive_film_nearby_acid_mark", {}))
	var interval: float = maxf(float(rule.get("interval", 1.0)), 0.05)
	var next_at: float = float(player.get_meta("corrosive_film_next_corrosion_at", 0.0))
	var now_seconds: float = host._now_seconds()
	if now_seconds < next_at:
		return
	player.set_meta("corrosive_film_next_corrosion_at", now_seconds + interval)
	var radius: float = maxf(float(rule.get("radius", 120.0)), 1.0)
	var registry: Node = CombatTargetRegistryScript.get_or_create(player)
	var targets: Array = registry.call("get_targets_in_radius", player.global_position, radius, &"enemies") if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in targets:
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
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("corrosive_film_on_boss_skill_hit"):
		return
	if not host._is_boss_damage_source(context):
		return
	var player: Node = context.get("player", context.get("caster")) as Node
	if player == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("corrosive_film_on_boss_skill_hit", {}))
	var key: String = "corrosive_film_boss:%s" % host._target_key(player)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_corrosive_film_boss_hit_cooldowns, key, now_seconds, maxf(float(rule.get("same_source_cooldown", 18.0)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.grant_corrosive_film(rules, context, player, int(rule.get("shield_value", 8)), float(rule.get("shield_duration", 4.0)))


func _apply_acid_mark_vulnerability(packet: Dictionary, rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("acid_mark_vulnerability") or target == null or not target.has_method("get_status_stack"):
		return
	var stacks: int = int(target.call("get_status_stack", &"acid_mark"))
	if stacks <= 0:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("acid_mark_vulnerability", {}))
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("damage_taken_multiplier_add_per_stack", 0.005)) * float(stacks)


func _is_boss_damage_source(context: Dictionary) -> bool:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
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
