extends RefCounted
class_name DamageSystem


const DamageRoundingServiceScript: Script = preload("res://scripts/combat/damage_rounding_service.gd")
const DamageCalculationContextScript: Script = preload("res://scripts/combat/damage_calculation_context.gd")
const DamagePacketNormalizerScript: Script = preload("res://scripts/combat/damage_packet_normalizer.gd")
const DamageResultScript: Script = preload("res://scripts/combat/damage_result.gd")
const DamageStageScript: Script = preload("res://scripts/combat/damage_stage.gd")
const DamagePipelineScript: Script = preload("res://scripts/combat/damage_pipeline.gd")
const OutgoingDamageStageScript: Script = preload("res://scripts/combat/stages/outgoing_damage_stage.gd")
const CriticalDamageStageScript: Script = preload("res://scripts/combat/stages/critical_damage_stage.gd")
const DefenseDamageStageScript: Script = preload("res://scripts/combat/stages/defense_damage_stage.gd")
const ResistanceDamageStageScript: Script = preload("res://scripts/combat/stages/resistance_damage_stage.gd")
const VulnerabilityDamageStageScript: Script = preload("res://scripts/combat/stages/vulnerability_damage_stage.gd")
const SpecialFinalDamageStageScript: Script = preload("res://scripts/combat/stages/special_final_damage_stage.gd")
const RoundingDamageStageScript: Script = preload("res://scripts/combat/stages/rounding_damage_stage.gd")
const TruePercentDamageStageScript: Script = preload("res://scripts/combat/stages/true_percent_damage_stage.gd")
const TruePercentCapStageScript: Script = preload("res://scripts/combat/stages/true_percent_cap_stage.gd")
const PlayerIncomingModifierStageScript: Script = preload("res://scripts/combat/stages/player_incoming_modifier_stage.gd")
const PlayerDefenseStageScript: Script = preload("res://scripts/combat/stages/player_defense_stage.gd")
const PlayerReductionStageScript: Script = preload("res://scripts/combat/stages/player_reduction_stage.gd")
const PlayerDamageTakenStageScript: Script = preload("res://scripts/combat/stages/player_damage_taken_stage.gd")
const PlayerRoundingStageScript: Script = preload("res://scripts/combat/stages/player_rounding_stage.gd")
const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const DamageTargetMitigationScript: Script = preload("res://scripts/combat/damage_target_mitigation.gd")
const DamageOutputScalingScript: Script = preload("res://scripts/combat/damage_output_scaling.gd")
const DamageCriticalResolverScript: Script = preload("res://scripts/combat/damage_critical_resolver.gd")
const DamageSpecialFinalResolverScript: Script = preload("res://scripts/combat/damage_special_final_resolver.gd")
const DamagePlayerIncomingResolverScript: Script = preload("res://scripts/combat/damage_player_incoming_resolver.gd")
const DamageDefenseResolverScript: Script = preload("res://scripts/combat/damage_defense_resolver.gd")
const DamageTruePercentResolverScript: Script = preload("res://scripts/combat/damage_true_percent_resolver.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const DamageModifierQueryScript: Script = preload("res://scripts/modifiers/damage_modifier_query.gd")

const ELEMENT_NAMES: Array[String] = ["physical", "fire", "ice", "lightning", "poison", "holy", "acid", "arcane", "neutral"]
const ORIGIN_PRIMARY_ATTACK: String = "primary_attack"
const ORIGIN_STATUS_DOT: String = "status_dot"
const ORIGIN_REACTION: String = "reaction"
const ORIGIN_FIELD: String = "field"
const ORIGIN_TRAP: String = "trap"
const ORIGIN_SPECIAL: String = "special"
const TYPE_DIRECT_PHYSICAL: String = "direct_physical"
const TYPE_DIRECT_MAGICAL: String = "direct_magical"
const TYPE_PROJECTILE_SMALL: String = "projectile_small"
const TYPE_PROJECTILE_HEAVY: String = "projectile_heavy"
const TYPE_AREA_DIRECT: String = "area_direct"
const TYPE_STATUS_DOT: String = "status_dot"
const TYPE_REACTION_DAMAGE: String = "reaction_damage"
const TYPE_TRAP_DAMAGE: String = "trap_damage"
const TYPE_SUMMON_DAMAGE: String = "summon_damage"
const TYPE_TRUE_DAMAGE: String = "true_damage"
const TYPE_TRUE_PERCENT_DAMAGE: String = "true_percent_damage"
static func calculate(amount_or_packet: Variant, target: Node, legacy_damage_type: Variant = &"", attacker: Node = null) -> Dictionary:
	var calculation_context: RefCounted = _create_calculation_context(amount_or_packet, legacy_damage_type, attacker, target)
	return _calculate_context(calculation_context)


static func calculate_result(amount_or_packet: Variant, target: Node, legacy_damage_type: Variant = &"", attacker: Node = null) -> RefCounted:
	var calculation_context: RefCounted = _create_calculation_context(amount_or_packet, legacy_damage_type, attacker, target)
	var result: Dictionary = _calculate_context(calculation_context)
	var result_object: RefCounted = calculation_context.get("result_object") as RefCounted
	if result_object != null:
		return result_object
	return DamageResultScript.from_dictionary(result)


static func _calculate_context(calculation_context: RefCounted) -> Dictionary:
	var target: Node = calculation_context.get("target") as Node
	var raw_amount: float = maxf(float(calculation_context.get("raw_amount")), 0.0)
	if raw_amount <= 0.0:
		var zero_result: Dictionary = _result_for_context(calculation_context, 0, false, raw_amount, 1.0, {})
		calculation_context.call("finish", 0, false, 0.0, zero_result)
		return zero_result

	if _is_player_target(target):
		return _calculate_player_incoming(calculation_context)
	if String(calculation_context.call("packet_value", "damage_type", "")) == TYPE_TRUE_PERCENT_DAMAGE:
		return _calculate_true_percent(calculation_context)

	return _calculate_standard_damage(calculation_context)


static func _calculate_standard_damage(calculation_context: RefCounted) -> Dictionary:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var source_attacker: Node = calculation_context.call("packet_value", "attacker", calculation_context.get("attacker")) as Node
	var damage_modifiers: Dictionary = _get_attacker_damage_modifiers_for_context(calculation_context, source_attacker)
	calculation_context.set("attacker", source_attacker)
	calculation_context.set("damage_modifiers", damage_modifiers)
	var stages: Dictionary = calculation_context.get("stages")
	calculation_context.call("set_stage_order", [
		"raw_amount",
		"outgoing",
		"critical",
		"defense",
		"resistance",
		"vulnerability",
		"special",
		"rounding"
	])
	var pipeline: RefCounted = _standard_damage_pipeline()
	var final_amount: int = int(pipeline.call("execute_with_host", load("res://scripts/combat/damage_system.gd"), calculation_context, raw_amount))
	var after_special: float = float(stages.get("after_special", final_amount))
	var critical: bool = bool(calculation_context.get("critical"))
	var result: Dictionary = _result_for_context(calculation_context, final_amount, critical, raw_amount, after_special / raw_amount if raw_amount > 0.0 else 1.0, stages)
	calculation_context.call("finish", final_amount, critical, after_special, result)
	return result


static func _standard_damage_pipeline() -> RefCounted:
	return DamagePipelineScript.create([
		OutgoingDamageStageScript.new(),
		CriticalDamageStageScript.new(),
		DefenseDamageStageScript.new(),
		ResistanceDamageStageScript.new(),
		VulnerabilityDamageStageScript.new(),
		SpecialFinalDamageStageScript.new(),
		RoundingDamageStageScript.new()
	])


static func _standard_outgoing_pipeline_stage(calculation_context: RefCounted, _input_value: Variant) -> Variant:
	return _apply_outgoing_stage(calculation_context)


static func _standard_critical_pipeline_stage(calculation_context: RefCounted, input_value: Variant) -> Variant:
	var critical_result: Dictionary = _apply_critical_stage(calculation_context, float(input_value))
	calculation_context.set("critical", bool(critical_result.get("is_critical", false)))
	return float(critical_result.get("pre_mitigation", input_value))


static func _standard_rounding_pipeline_stage(calculation_context: RefCounted, input_value: Variant) -> Variant:
	return _apply_rounding_stage(calculation_context, float(input_value))


static func _apply_outgoing_stage(calculation_context: RefCounted) -> float:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	var outgoing: float = raw_amount
	var character_multiplier: float = _get_character_damage_multiplier_for_context(calculation_context)
	var skill_level_coefficient: float = _get_skill_level_coefficient_for_context(calculation_context)
	var origin_bonus_total: float = _get_origin_bonus_total_for_context(calculation_context)
	var origin_multiplier: float = maxf(1.0 + origin_bonus_total, 0.0)
	var element_bonus_total: float = _get_element_bonus_total_for_context(calculation_context)
	var element_multiplier: float = maxf(1.0 + element_bonus_total, 0.0)
	var enemy_type_bonus_total: float = _get_enemy_type_bonus_total_for_context(calculation_context)
	var enemy_type_multiplier: float = maxf(1.0 + enemy_type_bonus_total, 0.0)
	var target_class_modifier: float = DamageTargetMitigationScript.target_class_origin_modifier_for_context(calculation_context)
	stages["raw_amount"] = raw_amount
	stages["character_damage_multiplier"] = character_multiplier
	stages["skill_level_coefficient"] = skill_level_coefficient
	stages["origin_bonus_total"] = origin_bonus_total
	stages["origin_multiplier"] = origin_multiplier
	stages["element_bonus_total"] = element_bonus_total
	stages["element_multiplier"] = element_multiplier
	stages["enemy_type_bonus_total"] = enemy_type_bonus_total
	stages["enemy_type_multiplier"] = enemy_type_multiplier
	stages["target_class_origin_modifier"] = target_class_modifier
	outgoing *= character_multiplier
	outgoing *= skill_level_coefficient
	outgoing *= origin_multiplier
	outgoing *= element_multiplier
	outgoing *= enemy_type_multiplier
	outgoing *= target_class_modifier
	stages["outgoing_damage"] = outgoing
	return outgoing


static func _apply_critical_stage(calculation_context: RefCounted, outgoing: float) -> Dictionary:
	return DamageCriticalResolverScript.apply_critical_stage(calculation_context, outgoing)


static func _apply_mitigation_stages(calculation_context: RefCounted, pre_mitigation: float) -> float:
	var pipeline: RefCounted = DamagePipelineScript.create([
		DefenseDamageStageScript.new(),
		ResistanceDamageStageScript.new(),
		VulnerabilityDamageStageScript.new(),
		SpecialFinalDamageStageScript.new()
	])
	return float(pipeline.call("execute_with_host", load("res://scripts/combat/damage_system.gd"), calculation_context, pre_mitigation))


static func _apply_defense_stage(calculation_context: RefCounted, pre_mitigation: float) -> float:
	return DamageDefenseResolverScript.apply_defense_stage(calculation_context, pre_mitigation)


static func _apply_resistance_stage(calculation_context: RefCounted, after_defense: float) -> float:
	return DamageTargetMitigationScript.apply_resistance_stage(calculation_context, after_defense)


static func _apply_vulnerability_stage(calculation_context: RefCounted, after_resistance: float) -> float:
	return DamageTargetMitigationScript.apply_vulnerability_stage(calculation_context, after_resistance)


static func _apply_special_stage(calculation_context: RefCounted, after_vulnerability: float) -> float:
	return DamageSpecialFinalResolverScript.apply_special_stage(calculation_context, after_vulnerability)


static func _apply_rounding_stage(calculation_context: RefCounted, amount: float) -> int:
	var stages: Dictionary = calculation_context.get("stages")
	var final_amount: int = DamageRoundingServiceScript.resolve_for_context(amount, calculation_context)
	stages["rounded_amount"] = final_amount
	return final_amount


static func _calculate_true_percent(calculation_context: RefCounted) -> Dictionary:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	calculation_context.call("set_stage_order", ["raw_amount", "true_percent", "cap", "rounding"])
	stages["raw_amount"] = raw_amount
	var pipeline: RefCounted = DamagePipelineScript.create([
		TruePercentDamageStageScript.new(),
		TruePercentCapStageScript.new(),
		RoundingDamageStageScript.new()
	])
	var final_amount: int = int(pipeline.call("execute_with_host", load("res://scripts/combat/damage_system.gd"), calculation_context, raw_amount))
	var damage: float = float(stages.get("after_special", final_amount))
	var result: Dictionary = _result_for_context(calculation_context, final_amount, false, raw_amount, damage / raw_amount if raw_amount > 0.0 else 1.0, stages)
	calculation_context.call("finish", final_amount, false, damage, result)
	return result


static func _resolve_true_percent(calculation_context: RefCounted) -> float:
	return DamageTruePercentResolverScript.resolve_true_percent(calculation_context)


static func _apply_true_percent_stage(calculation_context: RefCounted, max_health: float, percent: float) -> float:
	return DamageTruePercentResolverScript.apply_true_percent_stage(calculation_context, max_health, percent)


static func _apply_true_percent_cap_stage(calculation_context: RefCounted, damage: float, max_health: float) -> float:
	return DamageTruePercentResolverScript.apply_true_percent_cap_stage(calculation_context, damage, max_health)


static func _calculate_player_incoming(calculation_context: RefCounted) -> Dictionary:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	calculation_context.call("set_stage_order", ["raw_amount", "incoming_modifiers", "player_defense", "player_reduction", "damage_taken", "rounding"])
	stages["raw_amount"] = raw_amount
	var pipeline: RefCounted = DamagePipelineScript.create([
		PlayerIncomingModifierStageScript.new(),
		PlayerDefenseStageScript.new(),
		PlayerReductionStageScript.new(),
		PlayerDamageTakenStageScript.new(),
		PlayerRoundingStageScript.new()
	])
	var final_amount: int = int(pipeline.call("execute_with_host", load("res://scripts/combat/damage_system.gd"), calculation_context, raw_amount))
	var after_reduction: float = float(stages.get("after_reduction", final_amount))
	var result: Dictionary = _result_for_context(calculation_context, final_amount, false, raw_amount, after_reduction / raw_amount if raw_amount > 0.0 else 1.0, stages)
	calculation_context.call("finish", final_amount, false, after_reduction, result)
	return result


static func _apply_player_incoming_modifier_stage(calculation_context: RefCounted) -> float:
	return DamagePlayerIncomingResolverScript.apply_player_incoming_modifier_stage(calculation_context)


static func _apply_player_defense_stage(calculation_context: RefCounted, incoming: float) -> float:
	return DamagePlayerIncomingResolverScript.apply_player_defense_stage(calculation_context, incoming)


static func _apply_player_reduction_stage(calculation_context: RefCounted, after_defense: float) -> float:
	return DamagePlayerIncomingResolverScript.apply_player_reduction_stage(calculation_context, after_defense)


static func _apply_player_damage_taken_stage(calculation_context: RefCounted, after_reduction: float) -> float:
	return DamagePlayerIncomingResolverScript.apply_player_damage_taken_stage(calculation_context, after_reduction)


static func _apply_player_rounding_stage(calculation_context: RefCounted, after_reduction: float) -> int:
	return DamagePlayerIncomingResolverScript.apply_player_rounding_stage(calculation_context, after_reduction)


static func _normalize_packet(amount_or_packet: Variant, legacy_damage_type: Variant, attacker: Node, target: Node = null) -> Dictionary:
	return DamagePacketNormalizerScript.normalize_to_dictionary(amount_or_packet, legacy_damage_type, attacker, target)


static func _create_calculation_context(amount_or_packet: Variant, legacy_damage_type: Variant, attacker: Node, target: Node = null) -> RefCounted:
	var packet_object: RefCounted = _normalize_packet_object(amount_or_packet, legacy_damage_type, attacker, target)
	var packet: Dictionary = packet_object.call("to_dictionary")
	var source_attacker: Node = packet.get("attacker", attacker) as Node
	return DamageCalculationContextScript.create(packet_object, target, source_attacker)


static func _normalize_packet_object(amount_or_packet: Variant, legacy_damage_type: Variant, attacker: Node, target: Node = null) -> RefCounted:
	return DamagePacketNormalizerScript.normalize_to_packet(amount_or_packet, legacy_damage_type, attacker, target)


static func _normalize_element(value: String, packet: Dictionary) -> String:
	return DamagePacketNormalizerScript.normalize_element(value, packet)


static func _normalize_damage_type(value: String, origin: String) -> String:
	return DamagePacketNormalizerScript.normalize_damage_type(value, origin)


static func _normalize_origin(value: String, packet: Dictionary) -> String:
	return DamagePacketNormalizerScript.normalize_origin(value, packet)


static func _apply_defense(pre_mitigation: float, packet: Dictionary, target: Node) -> float:
	return DamageDefenseResolverScript.apply_defense(pre_mitigation, packet, target)


static func _apply_defense_for_context(calculation_context: RefCounted, pre_mitigation: float) -> float:
	return DamageDefenseResolverScript.apply_defense_for_context(calculation_context, pre_mitigation)


static func _get_defense_rate(damage_type: String) -> float:
	return DamageDefenseResolverScript.defense_rate(damage_type)


static func _get_resistance_multiplier(target: Node, element: String) -> float:
	return DamageTargetMitigationScript.resistance_multiplier(target, element)


static func _get_resistance_multiplier_for_context(calculation_context: RefCounted) -> float:
	return DamageTargetMitigationScript.resistance_multiplier_for_context(calculation_context)


static func _get_vulnerability_total(target: Node, packet: Dictionary) -> float:
	return DamageTargetMitigationScript.vulnerability_total(target, packet)


static func _get_vulnerability_total_for_context(calculation_context: RefCounted) -> float:
	return DamageTargetMitigationScript.vulnerability_total_for_context(calculation_context)


static func _get_target_class_origin_modifier(packet: Dictionary, target: Node) -> float:
	return DamageTargetMitigationScript.target_class_origin_modifier(packet, target)


static func _get_target_class_origin_modifier_for_context(calculation_context: RefCounted) -> float:
	return DamageTargetMitigationScript.target_class_origin_modifier_for_context(calculation_context)


static func _get_attacker_damage_modifiers(packet: Dictionary, attacker: Node) -> Dictionary:
	if attacker == null:
		return {}
	return ModifierAggregatorScript.collect(ModifierQueryScript.for_damage(packet, attacker))


static func _get_attacker_damage_modifiers_for_context(calculation_context: RefCounted, attacker: Node) -> Dictionary:
	if attacker == null:
		return {}
	var damage_query: RefCounted = DamageModifierQueryScript.make(calculation_context, attacker)
	return ModifierAggregatorScript.collect(damage_query.call("to_modifier_query"))


static func _get_character_damage_multiplier(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	return DamageOutputScalingScript.character_damage_multiplier(packet, attacker, damage_modifiers)


static func _get_character_damage_multiplier_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.character_damage_multiplier_for_context(calculation_context)


static func _get_skill_level_coefficient(packet: Dictionary) -> float:
	return DamageOutputScalingScript.skill_level_coefficient(packet)


static func _get_skill_level_coefficient_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.skill_level_coefficient_for_context(calculation_context)


static func _get_origin_bonus_total(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	return DamageOutputScalingScript.origin_bonus_total(packet, attacker, damage_modifiers)


static func _get_origin_bonus_total_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.origin_bonus_total_for_context(calculation_context)


static func _get_element_bonus_total(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	return DamageOutputScalingScript.element_bonus_total(packet, attacker, damage_modifiers)


static func _get_element_bonus_total_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.element_bonus_total_for_context(calculation_context)


static func _get_enemy_type_bonus_total(packet: Dictionary, attacker: Node, target: Node, damage_modifiers: Dictionary = {}) -> float:
	return DamageOutputScalingScript.enemy_type_bonus_total(packet, attacker, target, damage_modifiers)


static func _get_enemy_type_bonus_total_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.enemy_type_bonus_total_for_context(calculation_context)


static func _default_uses_character_damage(origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_uses_character_damage(origin, damage_type)


static func _default_can_crit(origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_can_crit(origin, damage_type)


static func _can_crit(packet: Dictionary) -> bool:
	return DamageCriticalResolverScript.can_crit(packet)


static func _can_crit_for_context(calculation_context: RefCounted) -> bool:
	return DamageCriticalResolverScript.can_crit_for_context(calculation_context)


static func _get_special_final_modifier(packet: Dictionary, target: Node) -> float:
	return DamageSpecialFinalResolverScript.special_final_modifier(packet, target)


static func _get_special_final_modifier_for_context(calculation_context: RefCounted) -> float:
	return DamageSpecialFinalResolverScript.special_final_modifier_for_context(calculation_context)


static func _warn_invalid_origin_type(packet: Dictionary) -> void:
	DamagePacketNormalizerScript.warn_invalid_origin_type(packet)


static func _is_legal_origin_type(origin: String, damage_type: String) -> bool:
	return DamagePacketNormalizerScript.is_legal_origin_type(origin, damage_type)


static func _is_player_target(target: Node) -> bool:
	return target != null and target.is_in_group(&"player")


static func _get_target_class(target: Node) -> String:
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	return String(profile.get("target_type"))


static func _result(packet: Dictionary, final_amount: int, critical: bool, raw_amount: float, multiplier: float, stages: Dictionary) -> Dictionary:
	var result_object: RefCounted = DamageResultScript.make(packet, final_amount, critical, raw_amount, multiplier, stages)
	return result_object.call("to_dictionary")


static func _result_for_context(calculation_context: RefCounted, final_amount: int, critical: bool, raw_amount: float, multiplier: float, stages: Dictionary) -> Dictionary:
	var result_object: RefCounted = DamageResultScript.make_for_context(calculation_context, final_amount, critical, raw_amount, multiplier, stages)
	calculation_context.set("result_object", result_object)
	return result_object.call("to_dictionary")


static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	var value: Variant = _get_property(object, property, fallback)
	if value == null:
		return fallback
	return float(value)


static func _get_modifier_float(modifiers: Dictionary, key: String, fallback: float) -> float:
	if modifiers.is_empty() or not modifiers.has(key):
		return fallback
	return float(modifiers.get(key, fallback))


static func _get_property(object: Object, property: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return object.get(property)
	return fallback
