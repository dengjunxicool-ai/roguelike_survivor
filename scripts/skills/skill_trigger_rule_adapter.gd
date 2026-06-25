extends RefCounted
class_name SkillTriggerRuleAdapter


const SkillEffectAdapterScript: Script = preload("res://scripts/skills/skill_effect_adapter.gd")

const TRIGGER_ALIASES: Dictionary = {
	"attack_hit": &"attack_hit",
	"dash_start": &"dash_start",
	"dash_end": &"dash_end",
	"cast_skill": &"on_cast",
	"projectile_hit": &"on_projectile_hit",
	"area_tick": &"area_tick",
	"enemy_death": &"enemy_death",
	"player_damage_taken": &"player_damage_taken",
	"status_applied": &"status_applied",
	"status_tick": &"status_tick",
	"status_expired": &"status_expired",
	"status_max_stack_reached": &"status_max_stack_reached",
	"shield_gained": &"shield_gained",
	"shield_broken": &"shield_broken",
	"summon_attack_hit": &"summon_attack_hit",
	"always": &"always",
}


static func to_events(skill_instance: RefCounted, definition: RefCounted) -> Array:
	var events: Array = []
	if definition == null:
		return events

	var rules_variant: Variant = definition.get("trigger_rules")
	if not (rules_variant is Array):
		return events

	var rules: Array = rules_variant
	for rule_variant: Variant in rules:
		if rule_variant is Dictionary:
			var event: Dictionary = to_event(rule_variant as Dictionary, skill_instance)
			if not event.is_empty():
				events.append(event)
	return events


static func to_event(rule: Dictionary, _skill_instance: RefCounted = null) -> Dictionary:
	var trigger_name: String = String(rule.get("trigger", ""))
	var event_name: StringName = TRIGGER_ALIASES.get(trigger_name, StringName(trigger_name))
	if event_name == &"":
		return {}

	var event: Dictionary = {
		"trigger": event_name,
		"conditions": _normalize_conditions(rule.get("conditions", [])),
		"actions": SkillEffectAdapterScript.to_actions(_get_array(rule.get("effects", [])))
	}
	for optional_key: String in ["source_id", "counter_key", "threshold", "cooldown", "max_triggers_per_second"]:
		if rule.has(optional_key):
			event[optional_key] = rule[optional_key]
	return event


static func can_execute_rule_event(event: Dictionary, context: Dictionary, skill_instance: RefCounted) -> bool:
	if not _passes_counter(event, skill_instance):
		return false
	if not _passes_cooldown(event, context, skill_instance):
		return false
	return true


static func _normalize_conditions(value: Variant) -> Array:
	var normalized: Array = []
	for condition_variant: Variant in _get_array(value):
		if not (condition_variant is Dictionary):
			continue
		var condition: Dictionary = condition_variant
		var condition_type: String = String(condition.get("type", ""))
		var params: Dictionary = _get_dictionary(condition.get("params", {})).duplicate(true)
		match condition_type:
			"target_has_status":
				if condition.has("status") and not params.has("status_id"):
					params["status_id"] = condition["status"]
			"target_has_tag", "skill_has_tag":
				if condition.has("tag") and not params.has("tag"):
					params["tag"] = condition["tag"]
			"owner_has_skill":
				if condition.has("skill") and not params.has("skill_id"):
					params["skill_id"] = condition["skill"]
			"owner_has_relic":
				if condition.has("relic") and not params.has("relic_id"):
					params["relic_id"] = condition["relic"]
			"random_chance":
				if condition.has("chance") and not params.has("chance"):
					params["chance"] = condition["chance"]
			"target_hp_below":
				if condition.has("percent") and not params.has("percent"):
					params["percent"] = condition["percent"]
			"enemy_count_in_radius":
				for key: String in ["count", "radius"]:
					if condition.has(key) and not params.has(key):
						params[key] = condition[key]

		normalized.append({
			"type": condition_type,
			"params": params
		})
	return normalized


static func _passes_counter(event: Dictionary, skill_instance: RefCounted) -> bool:
	var counter_key: String = String(event.get("counter_key", ""))
	if counter_key == "" or skill_instance == null:
		return true

	var threshold: int = maxi(int(event.get("threshold", 1)), 1)
	var current: int = int(skill_instance.get_meta(counter_key, 0)) + 1
	if current >= threshold:
		skill_instance.set_meta(counter_key, 0)
		return true
	skill_instance.set_meta(counter_key, current)
	return false


static func _passes_cooldown(event: Dictionary, context: Dictionary, skill_instance: RefCounted) -> bool:
	if not event.has("cooldown") or skill_instance == null:
		return true

	var cooldown: float = maxf(float(event.get("cooldown", 0.0)), 0.0)
	if cooldown <= 0.0:
		return true

	var key: String = "trigger_cd:%s:%s" % [String(event.get("trigger", "")), String(event.get("source_id", ""))]
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var ready_at: float = float(skill_instance.get_meta(key, 0.0))
	if now < ready_at:
		return false
	skill_instance.set_meta(key, now + cooldown)
	context["last_trigger_cooldown_key"] = key
	return true


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
