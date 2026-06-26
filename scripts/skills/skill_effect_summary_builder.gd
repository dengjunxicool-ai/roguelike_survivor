extends RefCounted
class_name SkillEffectSummaryBuilder


const SUMMONS_PATH: String = "res://data/summons.json"
const COMBAT_OBJECTS_PATH: String = "res://data/combat_objects.json"
const SkillRangeUnitScript: Script = preload("res://scripts/skills/skill_range_unit.gd")


static func build_for_option(option: Dictionary) -> String:
	var skill_id: StringName = _option_skill_id(option)
	if skill_id == &"":
		return _string_or(option.get("description", ""), "")
	var skill: Dictionary = GameData.get_skill(skill_id)
	if skill.is_empty():
		return _string_or(option.get("description", ""), "")
	return build_for_skill(skill)


static func build_for_skill(skill: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append_array(_summarize_trigger_rules(skill))
	lines.append_array(_summarize_effects(_array(skill.get("effects", []))))
	if lines.is_empty():
		return _string_or(skill.get("description", ""), "")
	return "\n".join(lines)


static func _summarize_trigger_rules(skill: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for rule_variant: Variant in _array(skill.get("trigger_rules", [])):
		if not (rule_variant is Dictionary):
			continue
		var rule: Dictionary = rule_variant
		var trigger: String = _trigger_text(_string_or(rule.get("trigger", ""), ""))
		var cooldown: float = float(rule.get("cooldown", 0.0))
		if cooldown > 0.0:
			lines.append("%s CD %ss" % [trigger, _fmt(cooldown)])
		lines.append_array(_summarize_effects(_array(rule.get("effects", []))))
	return _unique_lines(lines)


static func _summarize_effects(effects: Array) -> Array[String]:
	var lines: Array[String] = []
	for effect_variant: Variant in effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		match _string_or(effect.get("type", ""), ""):
			"spawn_summon":
				lines.append_array(_summarize_summon_effect(effect))
			"damage":
				var damage_text: String = _damage_text(effect)
				if damage_text != "":
					lines.append("伤害 %s" % damage_text)
			"spawn_area":
				lines.append_array(_summarize_area_effect(effect))
			"spawn_projectile", "spawn_projectile_burst", "spawn_projectiles_at_targets":
				lines.append_array(_summarize_projectile_effect(effect))
			"apply_status":
				lines.append(_status_text(effect))
			"add_modifier":
				lines.append(_modifier_text(effect))
	return _unique_lines(lines)


static func _summarize_summon_effect(effect: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var summon_id: StringName = StringName(_string_or(effect.get("summon_definition_id", effect.get("summon_id", "")), ""))
	var summon: Dictionary = _get_summon(summon_id)
	if summon.is_empty():
		return lines
	var summon_name: String = _string_or(summon.get("name", summon_id), _string_or(summon_id, "召唤物"))
	var duration: float = float(summon.get("duration", 0.0))
	if duration > 0.0 and duration < 900.0:
		lines.append("%s持续 %ss" % [summon_name, _fmt(duration)])
	var max_count: int = int(summon.get("max_count", 0))
	if max_count > 0:
		lines.append("最多存在 %d 个" % max_count)

	var attack: Dictionary = _dict(summon.get("attack", {}))
	if not attack.is_empty():
		var cooldown: float = float(attack.get("attack_cooldown", 0.0))
		var attack_type: String = _string_or(attack.get("attack_type", ""), "")
		if cooldown > 0.0:
			if attack_type == "area_pulse":
				lines.append("每 %ss 释放冰脉冲" % _fmt(cooldown))
			else:
				lines.append("攻击间隔 %ss" % _fmt(cooldown))
		var damage_scale: float = float(attack.get("damage_scale", 0.0))
		if damage_scale > 0.0:
			lines.append("伤害 %sP" % _fmt(damage_scale))
		var resolved_attack: Dictionary = SkillRangeUnitScript.resolve_action_params(attack)
		var radius: float = float(resolved_attack.get("pulse_radius", resolved_attack.get("attack_range", 0.0)))
		if radius > 0.0:
			lines.append("范围 %spx" % _fmt(radius))
		for on_hit_variant: Variant in _array(attack.get("on_hit_effects", [])):
			if on_hit_variant is Dictionary:
				lines.append(_status_text(on_hit_variant))
	return _unique_lines(lines)


static func _summarize_area_effect(effect: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var area_id: StringName = StringName(_string_or(effect.get("area_id", ""), ""))
	var label: String = _combat_object_name(area_id)
	var resolved_effect: Dictionary = SkillRangeUnitScript.resolve_action_params(effect)
	var radius: float = float(resolved_effect.get("radius", 0.0))
	var duration: float = float(resolved_effect.get("duration", 0.0))
	var tick_interval: float = float(resolved_effect.get("tick_interval", 0.0))
	if radius > 0.0:
		lines.append("%s范围 %spx" % [label, _fmt(radius)])
	if duration > 0.0:
		lines.append("%s持续 %ss" % [label, _fmt(duration)])
	if tick_interval > 0.0:
		lines.append("每 %ss 触发一次" % _fmt(tick_interval))
	lines.append_array(_summarize_effects(_array(effect.get("effects_on_apply", []))))
	lines.append_array(_summarize_effects(_array(effect.get("effects_on_tick", []))))
	return _unique_lines(lines)


static func _summarize_projectile_effect(effect: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var count: int = int(effect.get("count", 0))
	if count > 0:
		lines.append("发射数量 %d" % count)
	var damage: Dictionary = _dict(effect.get("damage", {}))
	if not damage.is_empty():
		var damage_text: String = _damage_text(damage)
		if damage_text != "":
			lines.append("伤害 %s" % damage_text)
	var resolved_effect: Dictionary = SkillRangeUnitScript.resolve_action_params(effect)
	var radius: float = float(resolved_effect.get("radius", resolved_effect.get("collision_radius", 0.0)))
	if radius > 0.0:
		lines.append("命中半径 %spx" % _fmt(radius))
	lines.append_array(_summarize_effects(_array(effect.get("on_hit", []))))
	return _unique_lines(lines)


static func _damage_text(effect: Dictionary) -> String:
	if effect.has("power_scale"):
		return "%sP" % _fmt(float(effect.get("power_scale", 0.0)))
	if effect.has("scale"):
		return "%sP" % _fmt(float(effect.get("scale", 0.0)))
	if effect.has("damage") and effect.get("damage") is Dictionary:
		return _damage_text(effect.get("damage"))
	if effect.has("amount"):
		return str(effect.get("amount"))
	return ""


static func _status_text(effect: Dictionary) -> String:
	var status_id: String = _string_or(effect.get("status", effect.get("status_id", "")), "")
	if status_id == "":
		return ""
	var stacks: int = int(effect.get("stacks", 0))
	var duration: float = float(effect.get("duration", 0.0))
	var parts: Array[String] = ["施加 %s" % _status_name(status_id)]
	if stacks > 0:
		parts.append("%d层" % stacks)
	if duration > 0.0:
		parts.append("%ss" % _fmt(duration))
	return " ".join(parts)


static func _modifier_text(effect: Dictionary) -> String:
	var modifier: String = _string_or(effect.get("modifier", effect.get("stat", "")), "")
	var value: float = float(effect.get("value", 0.0))
	if modifier == "":
		return ""
	return "%s %s" % [_modifier_name(modifier), _signed_percent(value)]


static func _option_skill_id(option: Dictionary) -> StringName:
	var payload: Dictionary = _dict(option.get("payload", {}))
	var skill_id: StringName = StringName(_string_or(payload.get("learn_skill_id", payload.get("skill_id", option.get("learn_skill_id", option.get("skill_id", "")))), ""))
	return skill_id


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
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return _array((parsed as Dictionary).get(key, []))
	return []


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
