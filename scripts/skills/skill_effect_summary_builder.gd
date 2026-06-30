extends RefCounted
class_name SkillEffectSummaryBuilder
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


const SUMMONS_PATH: String = DataPathsScript.SUMMONS_PATH
const COMBAT_OBJECTS_PATH: String = DataPathsScript.COMBAT_OBJECTS_PATH
const SkillRangeUnitScript: Script = preload("res://scripts/skills/skill_range_unit.gd")
const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")


static func build_for_option(option: Dictionary) -> String:
	var skill_id: StringName = _option_skill_id(option)
	if skill_id == &"":
		return _string_or(option.get("description", ""), "")
	var skill: Dictionary = GameData.get_skill(skill_id)
	if skill.is_empty():
		return _string_or(option.get("description", ""), "")
	return build_for_skill(skill, _skill_instance_for_option(skill, option))


static func build_for_skill(skill: Dictionary, skill_instance: RefCounted = null) -> String:
	var lines: Array[String] = []
	lines.append_array(_summarize_trigger_rules(skill, skill_instance))
	lines.append_array(_summarize_effects(_array(skill.get("effects", [])), skill_instance))
	if lines.is_empty():
		return _string_or(skill.get("description", ""), "")
	return "\n".join(lines)


static func _summarize_trigger_rules(skill: Dictionary, skill_instance: RefCounted = null) -> Array[String]:
	var lines: Array[String] = []
	for rule_variant: Variant in _array(skill.get("trigger_rules", [])):
		if not (rule_variant is Dictionary):
			continue
		var rule: Dictionary = rule_variant
		var trigger: String = _trigger_text(_string_or(rule.get("trigger", ""), ""))
		var cooldown: float = _scaled_float(rule.get("cooldown", 0.0), skill_instance, "cooldown")
		if cooldown > 0.0:
			lines.append("%s CD %ss" % [trigger, _fmt(cooldown)])
		lines.append_array(_summarize_effects(_array(rule.get("effects", [])), skill_instance))
	return _unique_lines(lines)


static func _summarize_effects(effects: Array, skill_instance: RefCounted = null) -> Array[String]:
	var lines: Array[String] = []
	for effect_variant: Variant in effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		match _string_or(effect.get("type", ""), ""):
			"spawn_summon":
				lines.append_array(_summarize_summon_effect(effect, skill_instance))
			"damage":
				var damage_text: String = _damage_text(effect, skill_instance)
				if damage_text != "":
					lines.append("伤害 %s" % damage_text)
			"spawn_area":
				lines.append_array(_summarize_area_effect(effect, skill_instance))
			"spawn_projectile", "spawn_projectile_burst", "spawn_projectiles_at_targets":
				lines.append_array(_summarize_projectile_effect(effect, skill_instance))
			"apply_status":
				lines.append(_status_text(effect, skill_instance))
			"add_modifier":
				lines.append(_modifier_text(effect, skill_instance))
	return _unique_lines(lines)


static func _summarize_summon_effect(effect: Dictionary, skill_instance: RefCounted = null) -> Array[String]:
	var lines: Array[String] = []
	var summon_id: StringName = StringName(_string_or(effect.get("summon_definition_id", effect.get("summon_id", "")), ""))
	var summon: Dictionary = _get_summon(summon_id)
	if summon.is_empty():
		return lines
	var summon_name: String = _string_or(summon.get("name", summon_id), _string_or(summon_id, "召唤物"))
	var duration: float = _scaled_float(summon.get("duration", 0.0), skill_instance, "duration")
	if duration > 0.0 and duration < 900.0:
		lines.append("%s持续 %ss" % [summon_name, _fmt(duration)])
	var max_count: int = int(summon.get("max_count", 0))
	if max_count > 0:
		lines.append("最多存在 %d 个" % max_count)

	var attack: Dictionary = _dict(summon.get("attack", {}))
	if not attack.is_empty():
		var cooldown: float = _scaled_float(attack.get("attack_cooldown", 0.0), skill_instance, "attack_cooldown")
		var attack_type: String = _string_or(attack.get("attack_type", ""), "")
		if cooldown > 0.0:
			if attack_type == "area_pulse":
				lines.append("每 %ss 释放冰脉冲" % _fmt(cooldown))
			else:
				lines.append("攻击间隔 %ss" % _fmt(cooldown))
		var damage_scale: float = _scaled_float(attack.get("damage_scale", 0.0), skill_instance, "damage")
		if damage_scale > 0.0:
			lines.append("伤害 %sP" % _fmt(damage_scale))
		var resolved_attack: Dictionary = SkillRangeUnitScript.resolve_action_params(attack)
		var radius: float = float(resolved_attack.get("pulse_radius", resolved_attack.get("attack_range", 0.0)))
		if radius > 0.0:
			lines.append("范围 %spx" % _fmt(radius))
		for on_hit_variant: Variant in _array(attack.get("on_hit_effects", [])):
			if on_hit_variant is Dictionary:
				lines.append(_status_text(on_hit_variant, skill_instance))
	return _unique_lines(lines)


static func _summarize_area_effect(effect: Dictionary, skill_instance: RefCounted = null) -> Array[String]:
	var lines: Array[String] = []
	var area_id: StringName = StringName(_string_or(effect.get("area_id", ""), ""))
	var label: String = _combat_object_name(area_id)
	var resolved_effect: Dictionary = SkillRangeUnitScript.resolve_action_params(effect)
	var radius: float = _scaled_float(resolved_effect.get("radius", 0.0), skill_instance, "radius")
	var duration: float = _scaled_float(resolved_effect.get("duration", 0.0), skill_instance, "duration")
	var tick_interval: float = float(resolved_effect.get("tick_interval", 0.0))
	if radius > 0.0:
		lines.append("%s范围 %spx" % [label, _fmt(radius)])
	if duration > 0.0:
		lines.append("%s持续 %ss" % [label, _fmt(duration)])
	if tick_interval > 0.0:
		lines.append("每 %ss 触发一次" % _fmt(tick_interval))
	lines.append_array(_summarize_effects(_array(effect.get("effects_on_apply", [])), skill_instance))
	lines.append_array(_summarize_effects(_array(effect.get("effects_on_tick", [])), null))
	return _unique_lines(lines)


static func _summarize_projectile_effect(effect: Dictionary, skill_instance: RefCounted = null) -> Array[String]:
	var lines: Array[String] = []
	var count: int = int(effect.get("count", 0))
	if count > 0:
		lines.append("发射数量 %d" % count)
	var damage: Dictionary = _dict(effect.get("damage", {}))
	if not damage.is_empty():
		var damage_text: String = _damage_text(damage, skill_instance)
		if damage_text != "":
			lines.append("伤害 %s" % damage_text)
	var resolved_effect: Dictionary = SkillRangeUnitScript.resolve_action_params(effect)
	var radius: float = _scaled_float(resolved_effect.get("radius", resolved_effect.get("collision_radius", 0.0)), skill_instance, "radius")
	if radius > 0.0:
		lines.append("命中半径 %spx" % _fmt(radius))
	lines.append_array(_summarize_effects(_array(effect.get("on_hit", [])), skill_instance))
	return _unique_lines(lines)


static func _damage_text(effect: Dictionary, skill_instance: RefCounted = null) -> String:
	if effect.has("power_scale"):
		return "%sP" % _fmt(_scaled_float(effect.get("power_scale", 0.0), skill_instance, "damage"))
	if effect.has("scale"):
		return "%sP" % _fmt(_scaled_float(effect.get("scale", 0.0), skill_instance, "damage"))
	if effect.has("damage") and effect.get("damage") is Dictionary:
		return _damage_text(effect.get("damage"), skill_instance)
	if effect.has("amount"):
		var amount: Variant = effect.get("amount")
		if typeof(amount) == TYPE_INT or typeof(amount) == TYPE_FLOAT:
			return _fmt(_scaled_float(amount, skill_instance, "damage"))
		return str(amount)
	return ""


static func _status_text(effect: Dictionary, skill_instance: RefCounted = null) -> String:
	var status_id: String = _string_or(effect.get("status", effect.get("status_id", "")), "")
	if status_id == "":
		return ""
	var stacks: int = int(effect.get("stacks", 0))
	var duration: float = _scaled_float(effect.get("duration", 0.0), skill_instance, "status_duration")
	var parts: Array[String] = ["施加 %s" % _status_name(status_id)]
	if stacks > 0:
		parts.append("%d层" % stacks)
	if duration > 0.0:
		parts.append("%ss" % _fmt(duration))
	return " ".join(parts)


static func _modifier_text(effect: Dictionary, skill_instance: RefCounted = null) -> String:
	var modifier: String = _string_or(effect.get("modifier", effect.get("stat", "")), "")
	var value: float = _scaled_float(effect.get("value", 0.0), skill_instance, _modifier_stat_kind(modifier))
	if modifier == "":
		return ""
	return "%s %s" % [_modifier_name(modifier), _signed_percent(value)]


static func _option_skill_id(option: Dictionary) -> StringName:
	var payload: Dictionary = _dict(option.get("payload", {}))
	var skill_id: StringName = StringName(_string_or(payload.get("learn_skill_id", payload.get("skill_id", option.get("learn_skill_id", option.get("skill_id", "")))), ""))
	return skill_id


static func _skill_instance_for_option(skill: Dictionary, option: Dictionary) -> RefCounted:
	var definition: RefCounted = SkillDefinitionScript.new(skill)
	var skill_instance: RefCounted = SkillInstanceScript.new(definition)
	var payload: Dictionary = _dict(option.get("payload", {}))
	var level: int = maxi(int(payload.get("level", 1)), 1)
	skill_instance.set("current_level", level)
	var rarity: String = _string_or(payload.get("target_rarity", option.get("rarity", "")), "")
	if rarity != "":
		skill_instance.set("current_rarity", rarity)
	return skill_instance


static func _scaled_float(value: Variant, skill_instance: RefCounted, stat_kind: String) -> float:
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return 0.0
	return SkillGrowthScalingScript.apply_to_number(float(value), skill_instance, stat_kind)


static func _modifier_stat_kind(modifier: String) -> String:
	if modifier.contains("cooldown") or modifier.contains("interval"):
		return "cooldown"
	if modifier.contains("radius") or modifier.contains("area") or modifier.contains("range"):
		return "radius"
	if modifier.contains("duration"):
		return "duration"
	if modifier.contains("damage") or modifier.contains("attack"):
		return "damage"
	return "modifier"


static func _get_summon(summon_id: StringName) -> Dictionary:
	return _find_by_id(_load_array(SUMMONS_PATH, "summons"), summon_id)


static func _get_combat_object(object_id: StringName) -> Dictionary:
	return _find_by_id(_load_array(COMBAT_OBJECTS_PATH, "combat_objects"), object_id)


static func _combat_object_name(object_id: StringName) -> String:
	var object: Dictionary = _get_combat_object(object_id)
	return _string_or(object.get("name", object_id), _string_or(object_id, "效果区域")) if not object.is_empty() else _string_or(object_id, "效果区域")


static func _trigger_text(trigger: String) -> String:
	match trigger:
		"cast_skill":
			return "施放"
		"attack_hit":
			return "攻击命中"
		"dash_start":
			return "冲刺"
		"post_damage_hit":
			return "伤害后"
	return trigger


static func _status_name(status_id: String) -> String:
	match status_id:
		"chilled":
			return "Chilled"
		"frozen":
			return "Frozen"
		"burning":
			return "Burning"
	return status_id


static func _modifier_name(modifier: String) -> String:
	match modifier:
		"frozen_damage_taken_multiplier":
			return "冰冻/强控易伤"
		"attack_damage_multiplier":
			return "攻击伤害"
		"chilled_duration_multiplier":
			return "Chilled持续"
		"frozen_duration_multiplier":
			return "Frozen持续"
		"frost_area_duration_multiplier":
			return "冰霜区域持续"
	return modifier


static func _signed_percent(value: float) -> String:
	var prefix: String = "+" if value >= 0.0 else ""
	return "%s%s%%" % [prefix, _fmt(value * 100.0)]


static func _fmt(value: float) -> String:
	if absf(value - roundf(value)) < 0.001:
		return str(int(roundi(value)))
	var text: String = "%.2f" % value
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


static func _unique_lines(lines: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	for line: String in lines:
		if line == "" or seen.has(line):
			continue
		seen[line] = true
		result.append(line)
	return result


static func _find_by_id(items: Array, id: StringName) -> Dictionary:
	for item_variant: Variant in items:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			if StringName(_string_or(item.get("id", ""), "")) == id:
				return item.duplicate(true)
	return {}


static func _load_array(path: String, key: String) -> Array:
	return JsonDataLoaderScript.load_array(path, key, "SkillEffectSummaryBuilder", JsonDataLoaderScript.REPORT_SILENT)


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


static func _string_or(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	return str(value)
