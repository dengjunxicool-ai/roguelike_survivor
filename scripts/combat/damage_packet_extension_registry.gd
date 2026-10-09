## 文件用途：登记核心包以外允许携带的伤害、事件与追踪扩展及其类型。
## 使用方式：DamagePacket.validate 调用 validate 检查 extras；新增扩展必须在此明确登记。
extends RefCounted
class_name DamagePacketExtensionRegistry

# These fields have behavior beyond the core amount, source, flags and scaling.
# Numeric bonuses are snapshots, not input aliases; percent and caps have their
# own units. Event-only fields preserve trace and reaction scheduling identity.
const NUMERIC_FIELDS: Array[String] = [
	"defense_reduction_cap", "character_damage_multiplier", "origin_bonus_total", "element_bonus_total",
	"enemy_type_bonus_total", "special_final_modifier", "vulnerability_total",
	"crit_chance_add", "crit_damage_add", "crit_multiplier", "percent",
	"percent_of_max_health", "true_percent_damage_cap", "low_hp_execute_threshold",
	"player_damage_reduction_total", "boss_phase_modifier", "wave_damage_multiplier",
	"primary_attack_damage_multiplier_add", "direct_damage_multiplier_add",
	"starting_skill_damage_add", "dot_damage_multiplier_add", "reaction_damage_multiplier_add",
	"field_damage_multiplier_add", "area_damage_multiplier_add", "trap_damage_multiplier_add",
	"summon_damage_multiplier_add", "boss_damage_multiplier_add", "elite_damage_multiplier_add",
	"normal_damage_multiplier_add", "boss_core_damage_multiplier_add",
	"physical_damage_multiplier_add", "fire_damage_multiplier_add", "ice_damage_multiplier_add",
	"lightning_damage_multiplier_add", "poison_damage_multiplier_add", "holy_damage_multiplier_add",
	"acid_damage_multiplier_add", "arcane_damage_multiplier_add", "neutral_damage_multiplier_add"
]
const BOOLEAN_FIELDS: Array[String] = [
	"critical_resolved", "is_critical", "low_hp_execute", "ignore_fractional_buffer",
	"ignore_target_class_origin_modifier", "uses_fractional_buffer"
]
const TEXT_FIELDS: Array[String] = [
	"source_id", "field_damage_model", "special_final_modifier_source", "reaction_type",
	"reaction_tier", "object_type", "skill_id", "status_id", "target_type"
]
const INTEGER_FIELDS: Array[String] = ["max_targets", "debug_attack_trace_id", "_rapid_same_target_hits"]

## 作用：逐项检查扩展是否登记并符合数值、布尔、文本、整数或技能实例类型。
## 使用：输入 extras 字典；返回所有错误，不修改输入也不静默接受未知字段。
static func validate(fields: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: Variant in fields:
		var name: String = String(key)
		var value: Variant = fields[key]
		if NUMERIC_FIELDS.has(name):
			if not (value is int or value is float) or not is_finite(float(value)):
				errors.append("extension %s must be a finite number" % name)
		elif BOOLEAN_FIELDS.has(name):
			if not value is bool:
				errors.append("extension %s must be bool" % name)
		elif TEXT_FIELDS.has(name):
			if not (value is String or value is StringName):
				errors.append("extension %s must be text" % name)
		elif INTEGER_FIELDS.has(name):
			if not value is int:
				errors.append("extension %s must be int" % name)
		elif name == "skill_instance":
			if value != null and not value is SkillInstance:
				errors.append("extension skill_instance must be SkillInstance")
		else:
			errors.append("unregistered DamagePacket extension: %s" % name)
	return errors
