## 文件用途：为学习和升级卡片生成实际技能效果的中文摘要。
## 使用方式：build_for_option 解析卡片目标技能与等级，build_for_skill 遍历触发和效果；数值使用成长系数和配置对象名称。
extends RefCounted
class_name SkillEffectSummaryBuilder


const SkillRangeUnitScript: Script = preload("res://scripts/skills/skill_range_unit.gd")
const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")


## 作用：解析选项学习或升级技能，以目标等级稀有度生成效果摘要；无技能定义时保留卡片说明。
## 使用：build_for_option 解析卡片目标技能与等级，build_for_skill 遍历触发和效果；数值使用成长系数和配置对象名称。
static func build_for_option(option: Dictionary) -> String:
	var skill_id: StringName = _option_skill_id(option)
	if skill_id == &"":
		return _string_or(option.get("description", ""), "")
	var skill: Dictionary = GameData.get_skill(skill_id)
	if skill.is_empty():
		return _string_or(option.get("description", ""), "")
	return build_for_skill(skill, _skill_instance_for_option(skill, option))


## 作用：依次汇总触发规则与顶层效果摘要，均为空时使用技能原说明。
## 使用：skill 为技能实例或定义；skill_instance 为技能运行实例。
static func build_for_skill(skill: Dictionary, skill_instance: RefCounted = null) -> String:
	var lines: Array[String] = []
	lines.append_array(_summarize_trigger_rules(skill, skill_instance))
	lines.append_array(_summarize_effects(_array(skill.get("effects", [])), skill_instance))
	if lines.is_empty():
		return _string_or(skill.get("description", ""), "")
	return "\n".join(lines)


## 作用：按规则触发时机、成长后的冷却和效果生成去重摘要行。
## 使用：skill 为技能实例或定义；skill_instance 为技能运行实例。
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


## 作用：按召唤、伤害、区域、弹体、状态和属性类型生成效果摘要行。
## 使用：effects 为配置效果列表；skill_instance 为技能运行实例。
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


## 作用：读取召唤定义，展示持续时间、数量上限、攻击间隔、范围和命中状态。
## 使用：skill_instance 为技能运行实例。
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


## 作用：展示区域名称、范围、持续时间和 tick 间隔，并汇总施加与 tick 效果。
## 使用：skill_instance 为技能运行实例。
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


## 作用：展示弹数、伤害和命中半径，再递归汇总命中效果。
## 使用：skill_instance 为技能运行实例。
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


## 作用：按 power_scale、scale、嵌套 damage 或 amount 优先级生成实际伤害文本。
## 使用：skill_instance 为技能运行实例。
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


## 作用：把状态 ID、层数和成长后持续时间组合为施加状态说明。
## 使用：skill_instance 为技能运行实例。
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


## 作用：把属性名称及成长后数值转换为带正负号的百分比文本。
## 使用：skill_instance 为技能运行实例。
static func _modifier_text(effect: Dictionary, skill_instance: RefCounted = null) -> String:
	var modifier: String = _string_or(effect.get("modifier", effect.get("stat", "")), "")
	var value: float = _scaled_float(effect.get("value", 0.0), skill_instance, _modifier_stat_kind(modifier))
	if modifier == "":
		return ""
	return "%s %s" % [_modifier_name(modifier), _signed_percent(value)]


## 作用：从选项载荷优先读取 learn_skill_id，其次技能 ID 和顶层对应字段。
## 使用：由本文件 build_for_option 调用。
static func _option_skill_id(option: Dictionary) -> StringName:
	var payload: Dictionary = _dict(option.get("payload", {}))
	var skill_id: StringName = StringName(_string_or(payload.get("learn_skill_id", payload.get("skill_id", option.get("learn_skill_id", option.get("skill_id", "")))), ""))
	return skill_id


## 作用：创建仅用于摘要计算的技能实例，并应用选项目标等级和稀有度。
## 使用：skill 为技能实例或定义。
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


## 作用：只接受整数或浮点数，按技能属性类别计算展示成长数值。
## 使用：skill_instance 为技能运行实例。
static func _scaled_float(value: Variant, skill_instance: RefCounted, stat_kind: String) -> float:
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return 0.0
	return SkillGrowthScalingScript.apply_to_number(float(value), skill_instance, stat_kind)


## 作用：按属性键中的冷却、范围、时长或伤害语义确定成长类别。
## 使用：由本文件 _modifier_text 调用。
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


## 作用：通过 GameData 查询召唤定义。
## 使用：由本文件 _summarize_summon_effect 调用。
static func _get_summon(summon_id: StringName) -> Dictionary:
	return GameData.get_summon(summon_id)


## 作用：通过 GameData 查询战斗对象定义。
## 使用：由本文件 _combat_object_name 调用。
static func _get_combat_object(object_id: StringName) -> Dictionary:
	return GameData.get_combat_object(object_id)


## 作用：读取战斗对象配置名称，缺定义时显示对象 ID 或区域默认名。
## 使用：由本文件 _summarize_area_effect 调用。
static func _combat_object_name(object_id: StringName) -> String:
	var object: Dictionary = _get_combat_object(object_id)
	return _string_or(object.get("name", object_id), _string_or(object_id, "效果区域")) if not object.is_empty() else _string_or(object_id, "效果区域")


## 作用：把常用触发 ID 转换为施放、命中、冲刺或伤害后文字，其他保留原 ID。
## 使用：由本文件 _summarize_trigger_rules 调用。
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


## 作用：映射摘要中识别的状态名称，未知状态保留 ID。
## 使用：status_id 为标准状态 ID。
static func _status_name(status_id: String) -> String:
	match status_id:
		"chilled":
			return "Chilled"
		"frozen":
			return "Frozen"
		"burning":
			return "Burning"
	return status_id


## 作用：映射摘要中支持的属性名称，未知属性保留键名。
## 使用：由本文件 _modifier_text 调用。
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


## 作用：把小数数值乘百并生成含正负号的百分比文字。
## 使用：由本文件 _modifier_text 调用。
static func _signed_percent(value: float) -> String:
	var prefix: String = "+" if value >= 0.0 else ""
	return "%s%s%%" % [prefix, _fmt(value * 100.0)]


## 作用：近整数以整数显示，其余保留两位小数并去末尾零。
## 使用：由本文件 _summarize_trigger_rules/_summarize_summon_effect 调用。
static func _fmt(value: float) -> String:
	if absf(value - roundf(value)) < 0.001:
		return str(int(roundi(value)))
	var text: String = "%.2f" % value
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


## 作用：保持原顺序去掉空摘要行和重复摘要行。
## 使用：由本文件 _summarize_trigger_rules/_summarize_effects 调用。
static func _unique_lines(lines: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	for line: String in lines:
		if line == "" or seen.has(line):
			continue
		seen[line] = true
		result.append(line)
	return result


## 作用：仅接受 Dictionary；深拷贝输出以隔离调用方修改，其余类型返回空字典。
## 使用：由本文件 _summarize_summon_effect/_summarize_projectile_effect 调用；无适用数据时返回空字典。
static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：仅接受 Array；深拷贝输出以隔离调用方修改，其余类型返回空数组。
## 使用：由本文件 build_for_skill/_summarize_trigger_rules 调用；无匹配项时返回空数组。
static func _array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：fallback 为缺值备用结果。
static func _string_or(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	return str(value)
