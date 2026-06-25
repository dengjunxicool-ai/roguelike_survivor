extends RefCounted
class_name ReactionLimiter


const ReactionDamageBuilderScript: Script = preload("res://scripts/combat/reaction_damage_builder.gd")

const DEFAULT_REACTION_LIMITS: Dictionary = {
	"death_explosion": {"cooldown": 0.2, "max_targets": 8},
	"lightning_bounce": {"cooldown": 0.0, "max_bounces": 2},
	"shock": {"cooldown": 0.4, "max_per_source": 2},
	"overload": {"cooldown": 1.2, "boss_damage_multiplier": 0.75},
	"chain_end_burst": {"cooldown": 0.3, "max_targets": 6},
	"combustion": {"cooldown": 1.0, "max_targets": 8, "boss_damage_multiplier": 0.75},
	"acid_burst": {"cooldown": 2.0, "boss_damage_multiplier": 0.75},
	"shatter": {"cooldown": 1.5, "tier": "major"},
	"poison_cloud_spread": {"cooldown": 0.5, "max_active": 4},
	"shield_counter": {"cooldown": 7.0}
}
const BOSS_POISE_STACKS_REQUIRED: int = 5
const BOSS_POISE_STACK_DURATION_SECONDS: float = 6.0
const BOSS_POISE_WINDOW_SECONDS: float = 4.0

static var _reaction_cooldowns: Dictionary = {}
static var _source_counts: Dictionary = {}
static var _source_count_expires_at: Dictionary = {}
static var _target_sets: Dictionary = {}


static func prepare_damage_packet(packet: Dictionary) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	var depth: int = maxi(int(result.get("reaction_depth", 0)), 0)
	result["reaction_depth"] = depth
	if not result.has("can_trigger_reaction"):
		result["can_trigger_reaction"] = String(result.get("damage_origin", "")) != "reaction" and depth <= 0
	return result


static func make_reaction_packet(base_packet: Dictionary, reaction_type: String, amount: float, element: Variant = &"neutral") -> Dictionary:
	return ReactionDamageBuilderScript.build(base_packet, reaction_type, amount, element, reaction_tier(reaction_type))


static func make_reaction_packet_any(packet_source: Variant, reaction_type: String, amount: float, element: Variant = &"neutral") -> Dictionary:
	return ReactionDamageBuilderScript.build_any(packet_source, reaction_type, amount, element, reaction_tier(reaction_type))


static func reaction_tier(reaction_type: String) -> String:
	return String(_get_limit(reaction_type).get("tier", "normal"))


static func can_trigger(packet: Dictionary, reaction_type: String, target: Node = null) -> bool:
	return can_trigger_any(packet, reaction_type, target)


static func can_trigger_any(packet_source: Variant, reaction_type: String, target: Node = null) -> bool:
	if not bool(_packet_value(packet_source, "can_trigger_reaction", false)):
		return false
	if int(_packet_value(packet_source, "reaction_depth", 0)) >= 1:
		return false

	var now_seconds: float = _now_seconds()
	var resolved_target: Node = _resolve_target(packet_source, target)
	var key: String = _source_key_for_source(packet_source, reaction_type, resolved_target)
	var cooldown: float = float(_get_limit(reaction_type).get("cooldown", 0.0))
	if cooldown > 0.0 and now_seconds - float(_reaction_cooldowns.get(key, -9999.0)) < cooldown:
		return false
	if _is_count_limit_reached_for_source(packet_source, reaction_type, resolved_target, key, now_seconds):
		return false
	return true


static func can_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node = null) -> bool:
	return can_trigger_any(calculation_context, reaction_type, target)


static func can_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node = null) -> bool:
	return can_trigger_any(packet_object, reaction_type, target)


static func record_trigger(packet: Dictionary, reaction_type: String, target: Node = null) -> void:
	record_trigger_any(packet, reaction_type, target)


static func record_trigger_any(packet_source: Variant, reaction_type: String, target: Node = null) -> void:
	var resolved_target: Node = _resolve_target(packet_source, target)
	var key: String = _source_key_for_source(packet_source, reaction_type, resolved_target)
	_reaction_cooldowns[key] = _now_seconds()
	_record_count_for_source(packet_source, reaction_type, resolved_target, key)


static func record_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node = null) -> void:
	record_trigger_any(calculation_context, reaction_type, target)


static func record_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node = null) -> void:
	record_trigger_any(packet_object, reaction_type, target)


static func get_defense_reduction_cap(packet: Dictionary, target: Node, default_cap: float) -> float:
	return get_defense_reduction_cap_any(packet, target, default_cap)


static func get_defense_reduction_cap_any(packet_source: Variant, target: Node, default_cap: float) -> float:
	var resolved_target: Node = _resolve_target(packet_source, target)
	var cap: float = clampf(float(_packet_value(packet_source, "defense_reduction_cap", default_cap)), 0.0, 0.95)
	if _is_boss(resolved_target) and _has_special_tag_for_source(packet_source, "lightning_orb_backflow"):
		cap = minf(cap, 0.30)
	return cap


static func get_defense_reduction_cap_for_context(calculation_context: RefCounted, default_cap: float, target: Node = null) -> float:
	return get_defense_reduction_cap_any(calculation_context, target, default_cap)


static func get_defense_reduction_cap_for_packet_object(packet_object: RefCounted, target: Node, default_cap: float) -> float:
	return get_defense_reduction_cap_any(packet_object, target, default_cap)


static func get_special_final_modifier(packet: Dictionary, target: Node) -> float:
	return get_special_final_modifier_any(packet, target)


static func get_special_final_modifier_any(packet_source: Variant, target: Node = null) -> float:
	var resolved_target: Node = _resolve_target(packet_source, target)
	var modifier: float = 1.0
	if _is_boss(resolved_target):
		var reaction_type: String = String(_packet_value(packet_source, "reaction_type", ""))
		if reaction_type != "":
			modifier *= maxf(float(_get_limit(reaction_type).get("boss_damage_multiplier", 1.0)), 0.0)
	return modifier


static func get_special_final_modifier_for_context(calculation_context: RefCounted, target: Node = null) -> float:
	return get_special_final_modifier_any(calculation_context, target)


static func get_special_final_modifier_for_packet_object(packet_object: RefCounted, target: Node = null) -> float:
	return get_special_final_modifier_any(packet_object, target)


static func apply_boss_control_conversion(target: Node, status_id: StringName) -> Dictionary:
	if not _is_boss(target):
		return {}
	if not [&"root", &"freeze", &"stun", &"paralyze"].has(status_id):
		return {}

	_add_boss_poise_stack(target)
	return {
		"convert_to_status": &"slow",
		"duration": 1.0,
		"slow_percent": 0.20
	}


static func get_boss_poise_stacks(target: Node) -> int:
	if target == null or not _is_boss(target):
		return 0
	var now_seconds: float = _now_seconds()
	if now_seconds > float(target.get_meta("boss_poise_expires_at", -1.0)):
		return 0
	return int(target.get_meta("boss_poise_stacks", 0))


static func consume_boss_poise_bonus(target: Node, packet: Dictionary) -> float:
	return consume_boss_poise_bonus_any(target, packet)


static func consume_boss_poise_bonus_any(target: Node, packet_source: Variant) -> float:
	var resolved_target: Node = _resolve_target(packet_source, target)
	if not _is_boss(resolved_target):
		return 1.0
	if String(_packet_value(packet_source, "damage_origin", "")) != "reaction":
		return 1.0
	if String(_packet_value(packet_source, "reaction_tier", "")) != "major":
		return 1.0

	var now_seconds: float = _now_seconds()
	var window_until: float = float(resolved_target.get_meta("boss_poise_window_until", -1.0))
	if now_seconds > window_until:
		return 1.0

	resolved_target.set_meta("boss_poise_window_until", -1.0)
	return 1.10


static func consume_boss_poise_bonus_for_context(calculation_context: RefCounted, target: Node = null) -> float:
	return consume_boss_poise_bonus_any(target, calculation_context)


static func consume_boss_poise_bonus_for_packet_object(target: Node, packet_object: RefCounted) -> float:
	return consume_boss_poise_bonus_any(target, packet_object)


static func _add_boss_poise_stack(target: Node) -> void:
	if target == null:
		return

	var now_seconds: float = _now_seconds()
	var expires_at: float = float(target.get_meta("boss_poise_expires_at", -1.0))
	var stacks: int = int(target.get_meta("boss_poise_stacks", 0)) if now_seconds <= expires_at else 0
	stacks = mini(stacks + 1, BOSS_POISE_STACKS_REQUIRED)
	target.set_meta("boss_poise_stacks", stacks)
	target.set_meta("boss_poise_expires_at", now_seconds + BOSS_POISE_STACK_DURATION_SECONDS)
	if stacks >= BOSS_POISE_STACKS_REQUIRED:
		target.set_meta("boss_poise_stacks", 0)
		target.set_meta("boss_poise_recently_completed_at", now_seconds)
		target.set_meta("boss_poise_completed_count", int(target.get_meta("boss_poise_completed_count", 0)) + 1)
		target.set_meta("boss_poise_window_until", now_seconds + BOSS_POISE_WINDOW_SECONDS + maxf(float(target.get_meta("boss_poise_duration_add", 0.0)), 0.0))


static func _source_key(packet: Dictionary, reaction_type: String, target: Node = null) -> String:
	return _source_key_for_source(packet, reaction_type, target)


static func _source_key_for_source(packet_source: Variant, reaction_type: String, target: Node = null) -> String:
	var attacker_id: String = String(_packet_value(packet_source, "attacker_id", ""))
	var origin_id: String = String(_packet_value(packet_source, "source_origin_id", ""))
	var skill_id: String = String(_packet_value(packet_source, "source_skill_id", _packet_value(packet_source, "source_id", "")))
	var key: String = "%s:%s:%s:%s" % [attacker_id, origin_id, skill_id, reaction_type]
	if _uses_instance_scope_for_source(packet_source, reaction_type):
		var instance_id: String = String(_packet_value(packet_source, "source_instance_id", ""))
		if instance_id == "":
			instance_id = skill_id
		key = "%s:%s" % [key, instance_id]
	return key


static func _is_count_limit_reached(packet: Dictionary, reaction_type: String, target: Node, key: String, now_seconds: float) -> bool:
	return _is_count_limit_reached_for_source(packet, reaction_type, target, key, now_seconds)


static func _is_count_limit_reached_for_source(packet_source: Variant, reaction_type: String, target: Node, key: String, now_seconds: float) -> bool:
	_prune_counter(key, now_seconds)
	var limit: Dictionary = _get_limit(reaction_type)
	var count: int = int(_source_counts.get(key, 0))
	for count_key: String in ["max_per_source", "max_bounces", "max_active"]:
		var max_count: int = int(limit.get(count_key, 0))
		if max_count > 0 and count >= max_count:
			return true

	var max_targets: int = int(limit.get("max_targets", 0))
	if max_targets > 0:
		var target_id: String = _target_id_for_source(packet_source, target)
		var target_set: Dictionary = _target_sets.get(key, {})
		if target_id != "" and not target_set.has(target_id) and target_set.size() >= max_targets:
			return true
	return false


static func _record_count(packet: Dictionary, reaction_type: String, target: Node, key: String) -> void:
	_record_count_for_source(packet, reaction_type, target, key)


static func _record_count_for_source(packet_source: Variant, reaction_type: String, target: Node, key: String) -> void:
	var now_seconds: float = _now_seconds()
	_prune_counter(key, now_seconds)
	_source_counts[key] = int(_source_counts.get(key, 0)) + 1
	_source_count_expires_at[key] = now_seconds + _counter_window_seconds(reaction_type)

	var target_id: String = _target_id_for_source(packet_source, target)
	if target_id == "":
		return
	var target_set: Dictionary = _target_sets.get(key, {})
	target_set[target_id] = true
	_target_sets[key] = target_set


static func _prune_counter(key: String, now_seconds: float) -> void:
	if not _source_count_expires_at.has(key):
		return
	if now_seconds <= float(_source_count_expires_at[key]):
		return
	_source_count_expires_at.erase(key)
	_source_counts.erase(key)
	_target_sets.erase(key)


static func _counter_window_seconds(reaction_type: String) -> float:
	var limit: Dictionary = _get_limit(reaction_type)
	if limit.has("window"):
		return maxf(float(limit["window"]), 0.01)
	if limit.has("reset_after"):
		return maxf(float(limit["reset_after"]), 0.01)
	return maxf(float(limit.get("cooldown", 0.0)), 0.01)


static func _uses_instance_scope(packet: Dictionary, reaction_type: String) -> bool:
	return _uses_instance_scope_for_source(packet, reaction_type)


static func _uses_instance_scope_for_source(packet_source: Variant, reaction_type: String) -> bool:
	if String(_packet_value(packet_source, "reaction_scope", "")) == "instance":
		return true
	var origin: String = String(_packet_value(packet_source, "damage_origin", ""))
	if origin == "field" or origin == "status_dot":
		return true
	if String(_packet_value(packet_source, "damage_type", "")) == "status_dot":
		return true
	return ["death_explosion", "lightning_bounce", "chain_end_burst", "poison_cloud_spread"].has(reaction_type)


static func _target_id(packet: Dictionary, target: Node) -> String:
	return _target_id_for_source(packet, target)


static func _target_id_for_source(packet_source: Variant, target: Node) -> String:
	if target != null:
		return str(target.get_instance_id())
	return String(_packet_value(packet_source, "target_id", ""))


static func _has_special_tag(packet: Dictionary, tag: String) -> bool:
	return _has_special_tag_for_source(packet, tag)


static func _has_special_tag_for_source(packet_source: Variant, tag: String) -> bool:
	var tags_variant: Variant = _packet_value(packet_source, "special_rule_tags", [])
	if not (tags_variant is Array):
		return false
	var tags: Array = tags_variant
	return tags.has(tag) or tags.has(StringName(tag))


static func _resolve_target(packet_source: Variant, target: Node = null) -> Node:
	if target != null:
		return target
	if packet_source is RefCounted and packet_source.has_method("packet_value"):
		return packet_source.get("target") as Node
	return null


static func _packet_value(packet_source: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).get(key, fallback)
	if packet_source is RefCounted:
		if packet_source.has_method("packet_value"):
			return packet_source.call("packet_value", key, fallback)
		if packet_source.has_method("get_value"):
			return packet_source.call("get_value", key, fallback)
	return fallback


static func _packet_dictionary(packet_source: Variant) -> Dictionary:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).duplicate(true)
	if packet_source is RefCounted:
		if packet_source.has_method("packet_dict"):
			return packet_source.call("packet_dict")
		if packet_source.has_method("to_dictionary"):
			return packet_source.call("to_dictionary")
	return {}


static func _merge_tags(value: Variant, extra_tags: Array[String]) -> Array:
	var tags: Array = []
	if value is Array:
		tags = (value as Array).duplicate()
	for tag: String in extra_tags:
		if not tags.has(tag) and not tags.has(StringName(tag)):
			tags.append(tag)
	return tags


static func _get_limit(reaction_type: String) -> Dictionary:
	var value: Variant = DEFAULT_REACTION_LIMITS.get(reaction_type, {})
	if value is Dictionary:
		return value
	return {}


static func _is_boss(node: Node) -> bool:
	return node != null and (node.is_in_group(&"bosses") or bool(node.get_meta("is_boss", false)) or String(node.get_meta("enemy_rank", "")) == "boss")


static func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
