extends RefCounted
class_name FireSkillRuntime


const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const MetadataKeyScript: Script = preload("res://scripts/core/metadata_key.gd")

# First-pass compatibility adapter for fire passive runtime_rules. Every rule
# listed here has a concrete runtime effect or a deliberately simplified mapping
# so learned passive cards are never silently inert.
const SUPPORTED_RULE_NAMES: Array[String] = [
	"black_sun_fire_spreads_blackflame_on_kill",
	"bonus_fire_damage_against_high_health_ratio_targets",
	"burning_targets_lose_armor",
	"chance_convert_burn_to_blackflame",
	"chance_reignite_after_burn_expires",
	"chance_return_fire_projectile_at_max_range",
	"chance_spawn_weak_flamelet_on_fire_projectile_hit",
	"charge_then_empower_next_fire",
	"delayed_fire_reckoning",
	"grant_shield_from_fire_hits",
	"grant_shield_on_low_health",
	"nearby_fire_aura_and_player_damage_reduction",
	"on_fire_related_kill",
	"on_player_damage_taken",
	"reduce_fire_cooldown_near_burning_enemies",
	"reduce_fire_cooldown_on_burning_kill",
	"revive_once_per_run",
	"scale_with_owned_fire_skill_count",
	"splash_fire_damage_on_fire_critical_hit",
	"stack_mark_then_consume",
]

static var _cooldowns: Dictionary = {}


static func execute_passive_event(event_name: StringName, context: Dictionary, skill_manager: Node = null, action_executor: RefCounted = null) -> void:
	if skill_manager == null:
		skill_manager = context.get("skill_manager") as Node
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return

	var executor: RefCounted = action_executor
	if executor == null:
		executor = SkillActionExecutorScript.new()

	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var passive_skill: RefCounted = skill_variant as RefCounted
		if passive_skill == null or not _is_passive_skill(passive_skill):
			continue
		var rules: Dictionary = _get_fire_runtime_rules(passive_skill)
		if rules.is_empty():
			continue
		var rule_name: String = String(rules.get("rule", "")).strip_edges()
		if rule_name == "" or not SUPPORTED_RULE_NAMES.has(rule_name):
			continue
		if not _rule_matches_event(rule_name, event_name):
			continue
		if not _is_fire_context(rules, context, event_name):
			continue
		if not _cooldown_ready(passive_skill, rule_name, rules):
			continue

		var passive_context: Dictionary = _build_passive_context(context, passive_skill, skill_manager, event_name, rules)
		_execute_configured_actions(rules, passive_context, executor)
		_apply_mapped_rule(rule_name, rules, passive_context, skill_manager, executor)


static func _rule_matches_event(rule_name: String, event_name: StringName) -> bool:
	match rule_name:
		"charge_then_empower_next_fire", "reduce_fire_cooldown_near_burning_enemies", "scale_with_owned_fire_skill_count", "nearby_fire_aura_and_player_damage_reduction":
			return event_name == &"on_cast"
		"stack_mark_then_consume", "chance_spawn_weak_flamelet_on_fire_projectile_hit", "grant_shield_from_fire_hits", "bonus_fire_damage_against_high_health_ratio_targets", "splash_fire_damage_on_fire_critical_hit", "delayed_fire_reckoning", "chance_return_fire_projectile_at_max_range", "chance_convert_burn_to_blackflame", "chance_reignite_after_burn_expires", "burning_targets_lose_armor":
			return event_name == &"on_projectile_hit"
		"on_fire_related_kill", "reduce_fire_cooldown_on_burning_kill", "black_sun_fire_spreads_blackflame_on_kill":
			return event_name == &"on_enemy_killed"
		"on_player_damage_taken", "grant_shield_on_low_health", "revive_once_per_run":
			return event_name == &"on_player_damaged"
	return false


static func _execute_configured_actions(rules: Dictionary, context: Dictionary, executor: RefCounted) -> void:
	var actions: Array = _get_array(rules.get("actions", []))
	if actions.is_empty() or executor == null or not executor.has_method("execute_actions"):
		return
	_ensure_action_target(context)
	executor.call("execute_actions", actions, context)


static func _apply_mapped_rule(rule_name: String, rules: Dictionary, context: Dictionary, skill_manager: Node, executor: RefCounted) -> void:
	match rule_name:
		"charge_then_empower_next_fire":
			_apply_charge_empower(rules, context)
		"scale_with_owned_fire_skill_count":
			_apply_fire_skill_count_scaling(rules, skill_manager)
		"reduce_fire_cooldown_near_burning_enemies", "reduce_fire_cooldown_on_burning_kill":
			# First pass: the configured "near burning enemies" condition is mapped
			# to the fire cast/kill event itself; the effect is a real cooldown cut.
			_reduce_cooldowns(skill_manager, float(rules.get("reduction_seconds", 0.0)))
		"grant_shield_from_fire_hits", "grant_shield_on_low_health":
			_grant_fire_passive_shield(context, rules)
		"nearby_fire_aura_and_player_damage_reduction":
			_apply_player_damage_reduction(context, rules)
		"on_player_damage_taken":
			_grant_fire_passive_shield(context, rules)
			_deal_rule_damage(context, executor, int(rules.get("retaliate_damage", rules.get("damage", 0))))
		"on_fire_related_kill":
			_apply_kill_trigger(rules, context, skill_manager, executor)
		"black_sun_fire_spreads_blackflame_on_kill":
			_deal_rule_damage(context, executor, int(roundi(float(rules.get("spread_damage_multiplier", 0.55)) * 20.0)))
		"stack_mark_then_consume":
			_apply_stack_mark(rules, context, executor)
		"chance_spawn_weak_flamelet_on_fire_projectile_hit":
			_spawn_weak_flamelet(rules, context, executor)
		"bonus_fire_damage_against_high_health_ratio_targets":
			_apply_high_health_bonus(rules, context)
		"splash_fire_damage_on_fire_critical_hit", "delayed_fire_reckoning", "chance_return_fire_projectile_at_max_range":
			_deal_rule_damage(context, executor, _scaled_rule_damage(rules, context))
		"chance_convert_burn_to_blackflame":
			_apply_blackflame_conversion(rules, context, executor)
		"chance_reignite_after_burn_expires":
			# No burn-expire event exists in this adapter path yet, so the first
			# pass maps it to refreshing/applying burn on a qualifying fire hit.
			_apply_burn_action(rules, context, executor)
		"burning_targets_lose_armor":
			_apply_armor_melting_burn(rules, context, executor)
		"revive_once_per_run":
			_apply_revive_once(rules, context, executor)


static func _build_passive_context(context: Dictionary, passive_skill: RefCounted, skill_manager: Node, event_name: StringName, rules: Dictionary) -> Dictionary:
	var result: Dictionary = context.duplicate(true)
	result["event_name"] = event_name
	result["passive_skill_instance"] = passive_skill
	result["passive_skill_id"] = StringName(String(passive_skill.get("skill_id")))
	if not result.has("skill_instance") or result.get("skill_instance") == null:
		result["skill_instance"] = passive_skill
	if not result.has("skill_manager") or result.get("skill_manager") == null:
		result["skill_manager"] = skill_manager
	if not result.has("caster") or result.get("caster") == null:
		result["caster"] = result.get("player", result.get("owner", null))
	if not result.has("owner") or result.get("owner") == null:
		result["owner"] = result.get("caster", result.get("player", null))
	if not result.has("player") or result.get("player") == null:
		result["player"] = result.get("owner", result.get("caster", null))
	if not result.has("target_group"):
		result["target_group"] = &"enemies"
	if not result.has("element"):
		result["element"] = StringName(String(rules.get("element", "fire")))
	return result


static func _get_fire_runtime_rules(skill_instance: RefCounted) -> Dictionary:
	var special_rules_variant: Variant = skill_instance.get("runtime_special_rules")
	if special_rules_variant is Dictionary:
		var special_rules: Dictionary = special_rules_variant
		var fire_rules: Variant = special_rules.get("fire_runtime_rules", {})
		if fire_rules is Dictionary:
			return (fire_rules as Dictionary).duplicate(true)
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition != null:
		var definition_rules: Variant = definition.get("runtime_rules")
		if definition_rules is Dictionary:
			return (definition_rules as Dictionary).duplicate(true)
	return {}


static func _is_passive_skill(skill_instance: RefCounted) -> bool:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	return definition != null and String(definition.get("category")) == "passive"


static func _is_fire_context(rules: Dictionary, context: Dictionary, event_name: StringName = &"") -> bool:
	if event_name == &"on_player_damaged":
		return true
	var trigger_scope: String = String(rules.get("trigger_scope", "fire"))
	if trigger_scope != "" and trigger_scope != "fire":
		return true
	var element: String = String(context.get("element", context.get("damage_element", "")))
	if element == "fire":
		return true
	var packet: Variant = context.get("damage_packet", {})
	if packet is Dictionary and String((packet as Dictionary).get("element", "")) == "fire":
		return true
	var source_packet: Variant = context.get("source_packet", {})
	if String(_packet_value(source_packet, "element", "")) == "fire":
		return true
	if String(_packet_value(source_packet, "source_skill_id", "")).contains("fire"):
		return true
	if String(_packet_value(source_packet, "source_origin_id", "")).contains("fire"):
		return true
	var damage_result: Variant = context.get("damage_result", {})
	if damage_result is Dictionary:
		var result: Dictionary = damage_result
		if String(result.get("element", "")) == "fire":
			return true
		if String(result.get("source_skill_id", "")).contains("fire"):
			return true
		if String(result.get("source_origin_id", "")).contains("fire"):
			return true
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if _skill_has_fire_tag(skill_instance):
		return true
	var skill_id: String = String(context.get("skill_id", context.get("source_skill_id", "")))
	return skill_id.contains("fire") or String(context.get("source_origin_id", "")).contains("fire")


static func _skill_has_fire_tag(skill_instance: RefCounted) -> bool:
	if skill_instance == null:
		return false
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return false
	var tags_variant: Variant = definition.get("tags")
	if tags_variant is Array:
		for tag: Variant in tags_variant:
			if String(tag) == "fire":
				return true
	return false


static func _cooldown_ready(skill_instance: RefCounted, rule_name: String, rules: Dictionary) -> bool:
	var cooldown: float = maxf(float(rules.get("internal_cooldown", rules.get("cooldown", 0.0))), 0.0)
	if cooldown <= 0.0:
		return true
	var key: String = "%s:%s" % [String(skill_instance.get("skill_id")), rule_name]
	var now_seconds: float = _now_seconds()
	if now_seconds < float(_cooldowns.get(key, 0.0)):
		return false
	_cooldowns[key] = now_seconds + cooldown
	return true


static func _apply_charge_empower(rules: Dictionary, context: Dictionary) -> void:
	var passive_skill: RefCounted = context.get("passive_skill_instance") as RefCounted
	var target_skill: RefCounted = context.get("skill_instance") as RefCounted
	if passive_skill == null or target_skill == null:
		return
	var required: int = maxi(int(rules.get("charges_required", 1)), 1)
	var key: String = _metadata_key("fire_runtime_charge", String(passive_skill.get("skill_id")))
	var charges: int = int(passive_skill.get_meta(key, 0)) + 1
	if charges < required:
		passive_skill.set_meta(key, charges)
		return
	passive_skill.set_meta(key, 0)
	var modifier_namespace: String = "charge_empower:%s" % String(passive_skill.get("skill_id"))
	_set_runtime_modifier(target_skill, modifier_namespace, "damage_multiplier_add", float(rules.get("damage_multiplier_add", 0.0)))
	_set_runtime_modifier(target_skill, modifier_namespace, "area_radius_multiplier_add", float(rules.get("radius_multiplier_add", 0.0)))
	_set_runtime_modifier(target_skill, modifier_namespace, "projectile_count_add", int(rules.get("projectile_count_add", 0)))


static func _apply_fire_skill_count_scaling(rules: Dictionary, skill_manager: Node) -> void:
	var count: int = mini(_count_fire_skills(skill_manager), maxi(int(rules.get("cap_fire_skill_count", 20)), 1))
	var damage_add: float = float(rules.get("per_fire_skill_damage_multiplier_add", 0.0)) * float(count)
	var radius_add: float = float(rules.get("per_fire_skill_radius_multiplier_add", 0.0)) * float(count)
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill: RefCounted = skill_variant as RefCounted
		if skill == null or _is_passive_skill(skill) or not _skill_has_fire_tag(skill):
			continue
		_set_runtime_modifier(skill, "fire_skill_count_scaling", "damage_multiplier_add", damage_add)
		_set_runtime_modifier(skill, "fire_skill_count_scaling", "area_radius_multiplier_add", radius_add)


static func _count_fire_skills(skill_manager: Node) -> int:
	var count: int = 0
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return count
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill: RefCounted = skill_variant as RefCounted
		if skill != null and (_skill_has_fire_tag(skill) or String(skill.get("skill_id")).contains("fire")):
			count += 1
	return count


static func _reduce_cooldowns(skill_manager: Node, seconds: float) -> void:
	if skill_manager == null or seconds <= 0.0 or not skill_manager.has_method("get_all_skills"):
		return
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill: RefCounted = skill_variant as RefCounted
		if skill == null or _is_passive_skill(skill) or not _skill_has_fire_tag(skill):
			continue
		skill.set("cooldown_remaining", maxf(float(skill.get("cooldown_remaining")) - seconds, 0.0))


static func _grant_fire_passive_shield(context: Dictionary, rules: Dictionary) -> void:
	var player: Node = _get_player(context)
	if player == null:
		return
	if rules.has("min_health_ratio") and _player_health_ratio(player) > float(rules.get("min_health_ratio")):
		return
	var amount: int = maxi(int(rules.get("shield_amount", 0)), 0)
	if amount <= 0:
		return
	var now_seconds: float = _now_seconds()
	var expires_at: float = float(player.get_meta("fire_passive_shield_expires_at", 0.0))
	var current: int = int(player.get_meta("fire_passive_shield", 0))
	if expires_at > 0.0 and now_seconds >= expires_at:
		current = 0
		player.set_meta("fire_passive_shield", 0)
		player.set_meta("fire_passive_shield_expires_at", 0.0)
	var max_health: int = maxi(int(player.get("max_health")), 1)
	var default_cap: int = maxi(amount, roundi(float(max_health) * float(rules.get("shield_cap_health_ratio", 0.35))))
	var shield_cap: int = maxi(int(rules.get("shield_cap", default_cap)), amount)
	player.set_meta("fire_passive_shield", mini(current + amount, shield_cap))
	var duration: float = maxf(float(rules.get("duration", 6.0)), 0.0)
	if duration > 0.0:
		player.set_meta("fire_passive_shield_expires_at", now_seconds + duration)


static func _apply_player_damage_reduction(context: Dictionary, rules: Dictionary) -> void:
	var player: Node = _get_player(context)
	var passive_skill: RefCounted = context.get("passive_skill_instance") as RefCounted
	if player == null or passive_skill == null or not player.has_method("set_run_modifier_source"):
		return
	player.call("set_run_modifier_source", "fire_runtime:%s" % String(passive_skill.get("skill_id")), {
		"damage_taken_multiplier_add": float(rules.get("damage_taken_multiplier_add", 0.0))
	})


static func _apply_kill_trigger(rules: Dictionary, context: Dictionary, skill_manager: Node, executor: RefCounted) -> void:
	if randf() > clampf(float(rules.get("chance", 1.0)), 0.0, 1.0):
		return
	var effect: String = String(rules.get("effect", ""))
	if effect.contains("empower"):
		var passive_skill: RefCounted = context.get("passive_skill_instance") as RefCounted
		var passive_skill_id: String = String(passive_skill.get("skill_id") if passive_skill != null else "fire")
		var modifier_namespace: String = "kill_trigger:%s" % passive_skill_id
		var stack_key: String = _metadata_key("kill_trigger_stack_count", passive_skill_id)
		var max_stacks: int = maxi(int(rules.get("max_stacks", rules.get("empower_max_stacks", 5))), 1)
		var stack_count: int = 1
		if passive_skill != null:
			stack_count = mini(int(passive_skill.get_meta(stack_key, 0)) + 1, max_stacks)
			passive_skill.set_meta(stack_key, stack_count)
		var damage_add: float = float(rules.get("damage_multiplier_add", 0.05)) * float(stack_count)
		for skill_variant: Variant in skill_manager.call("get_all_skills"):
			var skill: RefCounted = skill_variant as RefCounted
			if skill != null and not _is_passive_skill(skill) and _skill_has_fire_tag(skill):
				_set_runtime_modifier(skill, modifier_namespace, "damage_multiplier_add", damage_add)
	_deal_rule_damage(context, executor, int(rules.get("damage", 0)))


static func _apply_stack_mark(rules: Dictionary, context: Dictionary, executor: RefCounted) -> void:
	var target: Node = _ensure_action_target(context)
	if target == null:
		return
	var stack_id: String = _metadata_identifier(String(rules.get("stack_id", "fire_runtime_stack")))
	var stacks: int = mini(int(target.get_meta(stack_id, 0)) + 1, maxi(int(rules.get("max_stacks", 6)), 1))
	var required: int = maxi(int(rules.get("stacks_required", 4)), 1)
	if stacks < required:
		target.set_meta(stack_id, stacks)
		return
	target.set_meta(stack_id, 0)
	_deal_rule_damage(context, executor, int(rules.get("consume_damage", rules.get("damage", 0))))


static func _spawn_weak_flamelet(rules: Dictionary, context: Dictionary, executor: RefCounted) -> void:
	if randf() > clampf(float(rules.get("chance", 1.0)), 0.0, 1.0):
		return
	_ensure_action_target(context)
	var damage: int = maxi(roundi(float(context.get("amount", context.get("damage", 10))) * float(rules.get("flamelet_damage_multiplier", 0.45))), 1)
	executor.call("execute_actions", [{
		"type": "spawn_projectile",
		"params": {
			"projectile_id": String(rules.get("flamelet_projectile_id", "fire_runtime_flamelet")),
			"count": maxi(int(rules.get("max_extra_projectiles_per_hit", 1)), 1),
			"speed": float(rules.get("flamelet_speed", 420.0)),
			"damage": damage,
			"element": "fire"
		}
	}], context)


static func _apply_high_health_bonus(rules: Dictionary, context: Dictionary) -> void:
	var target: Node = context.get("target") as Node
	var skill: RefCounted = context.get("skill_instance") as RefCounted
	if target == null or skill == null:
		return
	var passive_skill: RefCounted = context.get("passive_skill_instance") as RefCounted
	var modifier_namespace: String = "high_health_bonus:%s" % String(passive_skill.get("skill_id") if passive_skill != null else "fire")
	if _target_health_ratio(target) < float(rules.get("min_health_ratio", 0.7)):
		_set_runtime_modifier(skill, modifier_namespace, "damage_multiplier_add", null)
		return
	_set_runtime_modifier(skill, modifier_namespace, "damage_multiplier_add", float(rules.get("damage_multiplier_add", 0.0)))


static func _deal_rule_damage(context: Dictionary, executor: RefCounted, amount: int) -> void:
	if amount <= 0 or executor == null:
		return
	_ensure_action_target(context)
	executor.call("execute_actions", [{
		"type": "deal_damage",
		"params": {
			"amount": amount,
			"damage_type": "direct_magical",
			"element": "fire"
		}
	}], context)


static func _scaled_rule_damage(rules: Dictionary, context: Dictionary) -> int:
	var base: float = float(context.get("amount", context.get("damage", 20)))
	if rules.has("source_damage_portion"):
		base *= float(rules.get("source_damage_portion", 1.0))
	if rules.has("damage_multiplier"):
		base *= float(rules.get("damage_multiplier", 1.0))
	if rules.has("splash_damage_multiplier"):
		base *= float(rules.get("splash_damage_multiplier", 1.0))
	if rules.has("return_damage_multiplier"):
		base *= float(rules.get("return_damage_multiplier", 1.0))
	return maxi(roundi(base), 1)


static func _apply_burn_action(rules: Dictionary, context: Dictionary, executor: RefCounted) -> void:
	if randf() > clampf(float(rules.get("chance", 1.0)), 0.0, 1.0):
		return
	_ensure_action_target(context)
	executor.call("execute_actions", [{
		"type": "apply_status",
		"params": {
			"status_id": "burning",
			"duration": maxf(float(rules.get("reignite_duration_multiplier", 0.6)) * 3.0, 0.1),
			"power": maxi(int(context.get("damage", context.get("amount", 4))), 1)
		}
	}], context)


static func _apply_blackflame_conversion(rules: Dictionary, context: Dictionary, executor: RefCounted) -> void:
	var target: Node = context.get("target") as Node
	if target == null or not _target_has_status(target, &"burning"):
		return
	var chance: float = clampf(float(rules.get("conversion_chance", 1.0)), 0.0, 1.0)
	if _is_target_boss(target):
		chance *= clampf(float(rules.get("boss_conversion_chance_multiplier", 1.0)), 0.0, 1.0)
	if randf() > chance:
		return
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", &"burning", 1)
	var base_damage: int = maxi(int(context.get("damage", context.get("amount", 4))), 1)
	if executor != null:
		executor.call("execute_actions", [{
			"type": "apply_status",
			"params": {
				"status_id": "blackfire",
				"duration": maxf(3.0 * float(rules.get("blackflame_duration_multiplier", 0.65)), 0.1),
				"damage": maxi(roundi(float(base_damage) * float(rules.get("blackflame_damage_multiplier", 1.75))), 1),
				"tick_interval": 0.5,
				"element": "fire"
			}
		}], context)


static func _apply_armor_melting_burn(rules: Dictionary, context: Dictionary, executor: RefCounted) -> void:
	var target: Node = context.get("target") as Node
	if target == null or not _target_has_status(target, &"burning") or executor == null:
		return
	var vulnerability_add: float = maxf(-float(rules.get("armor_multiplier_add", 0.0)), 0.0)
	if _is_target_boss(target):
		vulnerability_add *= maxf(float(rules.get("boss_effect_multiplier", 1.0)), 0.0)
	if vulnerability_add <= 0.0:
		return
	executor.call("execute_actions", [{
		"type": "apply_status",
		"params": {
			"status_id": "heat",
			"duration": 2.5,
			"stacks": 1,
			"max_stacks": 1,
			"fire_damage_taken_multiplier_add_per_stack": vulnerability_add
		}
	}], context)


static func _apply_revive_once(rules: Dictionary, context: Dictionary, executor: RefCounted) -> void:
	var player: Node = _get_player(context)
	var passive_skill: RefCounted = context.get("passive_skill_instance") as RefCounted
	if player == null or passive_skill == null or bool(passive_skill.get_meta("fire_runtime_revive_used", false)):
		return
	if int(player.get("current_health")) > 0:
		return
	passive_skill.set_meta("fire_runtime_revive_used", true)
	var max_health: int = maxi(int(player.get("max_health")), 1)
	player.set("current_health", maxi(roundi(float(max_health) * float(rules.get("revive_health_ratio", 0.45))), 1))
	if player.has_signal("health_changed"):
		player.emit_signal("health_changed", int(player.get("current_health")), max_health)
	_deal_rule_damage(context, executor, int(rules.get("explosion_damage", 0)))
	var fire_damage_add: float = float(rules.get("post_revive_fire_damage_multiplier_add", 0.0))
	if not is_zero_approx(fire_damage_add) and player.has_method("set_run_modifier_source"):
		player.call("set_run_modifier_source", "fire_runtime:%s:post_revive" % String(passive_skill.get("skill_id")), {
			"fire_damage_multiplier_add": fire_damage_add
		})


static func _ensure_action_target(context: Dictionary) -> Node:
	var target: Node = context.get("target") as Node
	if target != null:
		return target
	target = context.get("enemy") as Node
	if target != null:
		context["target"] = target
		return target
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return null
	var tree: SceneTree = caster.get_tree()
	if tree == null:
		return null
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for node: Node in tree.get_nodes_in_group(StringName(String(context.get("target_group", &"enemies")))):
		var candidate: Node2D = node as Node2D
		if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if candidate.has_method("is_dead") and bool(candidate.call("is_dead")):
			continue
		var distance: float = caster.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest != null:
		context["target"] = nearest
	return nearest


static func _add_runtime_modifier(skill_instance: RefCounted, key: String, value: Variant) -> void:
	if skill_instance == null:
		return
	if typeof(value) == TYPE_INT and int(value) == 0:
		return
	if typeof(value) == TYPE_FLOAT and is_zero_approx(float(value)):
		return
	if skill_instance.has_method("add_runtime_modifier"):
		skill_instance.call("add_runtime_modifier", key, value)
		return
	var modifiers: Dictionary = _get_dictionary(skill_instance.get("runtime_modifiers"))
	modifiers[key] = float(modifiers.get(key, 0.0)) + float(value)
	skill_instance.set("runtime_modifiers", modifiers)


static func _set_runtime_modifier(skill_instance: RefCounted, modifier_namespace: String, key: String, value: Variant) -> void:
	if skill_instance == null or key == "":
		return
	var modifiers: Dictionary = _get_dictionary(skill_instance.get("runtime_modifiers"))
	var originals_key: String = _metadata_key(modifier_namespace, "runtime_originals")
	var originals: Dictionary = _get_dictionary(skill_instance.get_meta(originals_key, {}))
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


static func _metadata_key(namespace_text: String, suffix: String) -> String:
	return MetadataKeyScript.key(namespace_text, suffix, "fire_runtime")


static func _metadata_identifier(raw_key: String) -> String:
	return MetadataKeyScript.identifier(raw_key, "fire_runtime")


static func _get_player(context: Dictionary) -> Node:
	var player: Node = context.get("player") as Node
	if player != null:
		return player
	player = context.get("owner") as Node
	if player != null:
		return player
	return context.get("caster") as Node


static func _player_health_ratio(player: Node) -> float:
	if player == null:
		return 1.0
	return clampf(float(player.get("current_health")) / maxf(float(player.get("max_health")), 1.0), 0.0, 1.0)


static func _target_health_ratio(target: Node) -> float:
	if target == null:
		return 1.0
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	var current_health: float = float(target.get("current_health"))
	return clampf(current_health / max_health, 0.0, 1.0)


static func _target_has_status(target: Node, status_id: StringName) -> bool:
	if target == null:
		return false
	if target.has_method("has_status"):
		return bool(target.call("has_status", status_id))
	var manager: Node = target.get_node_or_null("StatusEffectManager")
	if manager != null and manager.has_method("has_status"):
		return bool(manager.call("has_status", status_id))
	return false


static func _is_target_boss(target: Node) -> bool:
	if target == null:
		return false
	return target.is_in_group(&"bosses") or bool(target.get_meta("is_boss", false)) or String(target.get_meta("enemy_rank", "")) == "boss"


static func _packet_value(packet: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet is Dictionary:
		return (packet as Dictionary).get(key, fallback)
	if packet is RefCounted:
		if packet.has_method("get_value"):
			return packet.call("get_value", key, fallback)
		if packet.has_method("packet_value"):
			return packet.call("packet_value", key, fallback)
	return fallback


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
