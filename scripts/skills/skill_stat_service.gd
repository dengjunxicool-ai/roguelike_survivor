extends RefCounted
class_name SkillStatService


const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")


static func get_effective_stat(
	skill_instance: RefCounted,
	stat_name: String,
	default_value: Variant = 0,
	skill_manager: Node = null,
	relic_manager: Node = null,
	caster: Node = null
) -> Variant:
	var definition: RefCounted = _get_definition(skill_instance)
	if definition == null:
		return default_value

	var base_value: Variant = definition.call("get_base_stat", stat_name, default_value)
	return calculate_value(skill_instance, stat_name, base_value, skill_manager, relic_manager, caster)


static func calculate_value(
	skill_instance: RefCounted,
	stat_name: String,
	base_value: Variant,
	skill_manager: Node = null,
	relic_manager: Node = null,
	caster: Node = null
) -> Variant:
	var modifiers: Dictionary = get_combined_modifiers(skill_instance, skill_manager, relic_manager, caster)
	var value: Variant = SkillModifierCalculatorScript.calculate(base_value, stat_name, modifiers)

	if _is_number(value):
		value = _apply_alias_modifiers(value, stat_name, modifiers)
		value = _apply_caster_modifiers(value, stat_name, modifiers, skill_instance, caster)

	return value


static func get_combined_modifiers(skill_instance: RefCounted, skill_manager: Node = null, relic_manager: Node = null, caster: Node = null) -> Dictionary:
	return ModifierAggregatorScript.collect(ModifierQueryScript.for_skill(skill_instance, caster), skill_manager, relic_manager)


static func get_damage_type(skill_instance: RefCounted) -> StringName:
	var definition: RefCounted = _get_definition(skill_instance)
	if definition == null or not definition.has_method("has_tag"):
		return &""

	if definition.has_method("get_base_stat"):
		var configured_damage_type: String = String(definition.call("get_base_stat", "damage_type", ""))
		if configured_damage_type != "":
			return StringName(configured_damage_type)

	for damage_type: String in ["physical", "poison", "fire", "ice", "lightning"]:
		if bool(definition.call("has_tag", damage_type)):
			return StringName(damage_type)

	return &""


static func skill_has_tag(skill_instance: RefCounted, tag: String) -> bool:
	var definition: RefCounted = _get_definition(skill_instance)
	if definition != null and definition.has_method("has_tag") and bool(definition.call("has_tag", tag)):
		return true

	var runtime_tags_variant: Variant = skill_instance.get("runtime_tags") if skill_instance != null else []
	if runtime_tags_variant is Array:
		var runtime_tags: Array = runtime_tags_variant
		return runtime_tags.has(tag) or runtime_tags.has(StringName(tag))

	return false


static func _apply_alias_modifiers(value: Variant, stat_name: String, modifiers: Dictionary) -> Variant:
	var adjusted_value: float = float(value)
	if stat_name == "area_radius":
		adjusted_value *= float(modifiers.get("area_multiplier", 1.0))
		adjusted_value *= maxf(1.0 + float(modifiers.get("area_multiplier_add", 0.0)), 0.05)

	return _match_number_type(adjusted_value, value)


static func _apply_caster_modifiers(value: Variant, stat_name: String, modifiers: Dictionary, skill_instance: RefCounted, caster: Node) -> Variant:
	if caster == null:
		return value

	var adjusted_value: float = float(value)
	match stat_name:
		"cooldown":
			var attack_speed_multiplier: float = _get_effective_attack_speed_multiplier(caster, modifiers)
			adjusted_value /= attack_speed_multiplier
			if skill_has_tag(skill_instance, "trap"):
				adjusted_value *= maxf(1.0 + float(modifiers.get("trap_interval_multiplier_add", 0.0)), 0.05)
		"area_radius":
			adjusted_value *= maxf(_get_float_property(caster, "skill_area_multiplier", 1.0), 0.05)
		"status_duration":
			adjusted_value *= maxf(_get_float_property(caster, "status_duration_multiplier", 1.0), 0.05)

	return _match_number_type(adjusted_value, value)


static func _get_effective_attack_speed_multiplier(caster: Node, modifiers: Dictionary) -> float:
	var attack_speed_multiplier: float = maxf(_get_float_property(caster, "attack_speed_multiplier", 1.0), 0.05)
	attack_speed_multiplier *= maxf(float(modifiers.get("attack_speed_multiplier", 1.0)), 0.05)
	attack_speed_multiplier += float(modifiers.get("attack_speed_multiplier_add", 0.0))
	return maxf(attack_speed_multiplier, 0.1)


static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	if object == null:
		return fallback
	var value: Variant = object.get(property)
	if value == null:
		return fallback
	return float(value)


static func _get_definition(skill_instance: RefCounted) -> RefCounted:
	if skill_instance == null:
		return null

	return skill_instance.get("definition") as RefCounted


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary

	return {}


static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


static func _match_number_type(value: float, original_value: Variant) -> Variant:
	if typeof(original_value) == TYPE_INT:
		return roundi(value)

	return value
