extends SceneTree


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const DamageCalculationContextScript: Script = preload("res://scripts/combat/damage_calculation_context.gd")
const DamageTraceScript: Script = preload("res://scripts/combat/damage_trace.gd")
const DamageResultScript: Script = preload("res://scripts/combat/damage_result.gd")
const DamageStageScript: Script = preload("res://scripts/combat/damage_stage.gd")
const DamagePipelineScript: Script = preload("res://scripts/combat/damage_pipeline.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const DamagePacketValidatorScript: Script = preload("res://scripts/combat/damage_packet_validator.gd")
const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const DamageApplicationContextScript: Script = preload("res://scripts/combat/damage_application_context.gd")
const DamageApplicationPipelineScript: Script = preload("res://scripts/combat/damage_application_pipeline.gd")
const DamageIntentScript: Script = preload("res://scripts/combat/damage_intent.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageRoundingServiceScript: Script = preload("res://scripts/combat/damage_rounding_service.gd")
const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const DamageSourceContextFactoryScript: Script = preload("res://scripts/combat/damage_source_context_factory.gd")
const DamageSourceIdentityScript: Script = preload("res://scripts/combat/damage_source_identity.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const AreaEffectScript: Script = preload("res://scripts/combat/area_effect.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const ReactionServiceScript: Script = preload("res://scripts/combat/reaction_service.gd")
const ReactionDamageBuilderScript: Script = preload("res://scripts/combat/reaction_damage_builder.gd")
const ModifierKeyRegistryScript: Script = preload("res://scripts/modifiers/modifier_key_registry.gd")
const DamageModifierQueryScript: Script = preload("res://scripts/modifiers/damage_modifier_query.gd")
const HitEventResultScript: Script = preload("res://scripts/skills/hit_event_result.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const SkillSpecialRuleExecutorScript: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")
const EnemyDamagePacketBuilderScript: Script = preload("res://scripts/enemies/combat/enemy_damage_packet_builder.gd")


class FormulaNode:
	extends Node
	var max_health: int = 100
	var current_health: int = 100
	var armor: int = 0
	var defense: int = 0
	var resistances: Dictionary = {}
	var damage_multiplier: float = 1.0
	var damage_taken_multiplier: float = 1.0
	var crit_chance: float = 0.0
	var crit_damage: float = 1.5
	var fire_damage_multiplier_add: float = 0.0
	var enemy_id: StringName = &"formula_enemy"


class ApplicationEnemyNode:
	extends FormulaNode
	signal health_changed(current_health: int, max_health: int)
	var _is_dead: bool = false

	func _apply_damage_synergies(amount: int, _damage_type: Variant) -> int:
		return amount

	func _record_damage_done(amount: int, _damage_result: Dictionary, _source_packet: Variant) -> void:
		set_meta("recorded_damage_done", amount)

	func _show_debug_damage_number(_amount: int, _damage_result: Dictionary) -> void:
		pass

	func _update_debug_health_display() -> void:
		pass

	func _get_damage_source_key(_source_packet: Variant, _damage_result: Dictionary) -> String:
		return "application_service_test"

	func _die() -> void:
		_is_dead = true


class IntentTargetNode:
	extends FormulaNode
	var last_damage_packet: Variant = null

	func take_damage(packet: Variant, _damage_type: Variant = &"") -> void:
		last_damage_packet = packet


class TestStatusEffectManager:
	extends StatusEffectManager

	func _get_player() -> Node:
		return null

	func _get_skill_event_bus() -> Node:
		return null


func _init() -> void:
	var failed: bool = false
	failed = not _verify_player_primary_attack_hits_enemy() or failed
	failed = not _verify_enemy_hits_player() or failed
	failed = not _verify_dot_fractional_damage() or failed
	failed = not _verify_reaction_damage() or failed
	failed = not _verify_field_direct_uses_min_damage() or failed
	failed = not _verify_true_percent_stage_order() or failed
	failed = not _verify_reaction_limits() or failed
	failed = not _verify_special_rule_boundaries() or failed
	failed = not _verify_lightning_backflow_defense_cap() or failed
	failed = not _verify_shared_primary_attack_crit() or failed
	failed = not _verify_shared_primary_attack_noncrit_uses_neutral_multiplier() or failed
	failed = not _verify_damage_trace_contract() or failed
	failed = not _verify_damage_result_trace_object_contract() or failed
	failed = not _verify_damage_system_typed_result_contract() or failed
	failed = not _verify_damage_pipeline_contract() or failed
	failed = not _verify_damage_rule_registry_contract() or failed
	failed = not _verify_damage_policy_registry_contract() or failed
	failed = not _verify_damage_packet_object_contract() or failed
	failed = not _verify_damage_source_context_factory_contract() or failed
	failed = not _verify_damage_calculation_context_contract() or failed
	failed = not _verify_damage_validator_typed_contract() or failed
	failed = not _verify_damage_context_stage_helpers_contract() or failed
	failed = not _verify_damage_context_outgoing_helpers_contract() or failed
	failed = not _verify_damage_context_result_helpers_contract() or failed
	failed = not _verify_damage_rounding_context_contract() or failed
	failed = not _verify_target_profile_contract() or failed
	failed = not _verify_reaction_service_contract() or failed
	failed = not _verify_reaction_damage_builder_contract() or failed
	failed = not _verify_reaction_typed_contract() or failed
	failed = not _verify_hit_event_result_contract() or failed
	failed = not _verify_damage_application_service_enemy_contract() or failed
	failed = not _verify_damage_application_service_typed_contract() or failed
	failed = not _verify_damage_application_pipeline_contract() or failed
	failed = not _verify_damage_modifier_query_contract() or failed
	failed = not _verify_skill_packet_builder_contract() or failed
	failed = not _verify_status_dot_packet_builder_contract() or failed
	failed = not _verify_reaction_packet_builder_contract() or failed
	failed = not _verify_enemy_packet_builder_contract() or failed
	failed = not _verify_special_packet_builder_contract() or failed
	failed = not _verify_special_damage_rule_handler_contract() or failed
	failed = not _verify_combat_object_packet_builder_contract() or failed
	failed = not _verify_source_identity_helpers() or failed
	failed = not _verify_combat_object_template_source_stabilized() or failed
	failed = not _verify_fractional_pool_identity_includes_element() or failed
	failed = not _verify_status_effect_action_source_identity() or failed
	quit(1 if failed else 0)


func _verify_player_primary_attack_hits_enemy() -> bool:
	var attacker: FormulaNode = FormulaNode.new()
	attacker.damage_multiplier = 1.25
	attacker.fire_damage_multiplier_add = 0.10
	attacker.crit_chance = 0.0
	root.add_child(attacker)

	var enemy: FormulaNode = FormulaNode.new()
	enemy.defense = 12
	enemy.armor = 12
	enemy.resistances = {"magical_resistance": 0.20}
	root.add_child(enemy)

	var packet: Dictionary = {
		"raw_amount": 100,
		"amount": 100,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"fire",
		"source_origin_id": &"fire_staff",
		"source_skill_id": &"fireball",
		"source_instance_id": "formula_fireball",
		"attacker": attacker,
		"attacker_id": str(attacker.get_instance_id()),
		"target_id": str(enemy.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": true,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": true,
		"uses_skill_level_coefficient": true,
		"skill_level_coefficient": 1.2,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}

	var result: Dictionary = DamageSystemScript.calculate(packet, enemy)
	var expected_float: float = 100.0
	expected_float *= 1.25
	expected_float *= 1.2
	expected_float *= 1.10
	expected_float -= minf(12.0 * 0.6, expected_float * 0.45)
	expected_float *= 1.0 - 0.20
	var expected: int = roundi(expected_float)
	return _expect_equal("player primary attack -> enemy", int(result.get("amount", -1)), expected)


func _verify_enemy_hits_player() -> bool:
	var player: FormulaNode = FormulaNode.new()
	player.armor = 8
	player.defense = 8
	player.damage_taken_multiplier = 0.9
	player.add_to_group(&"player")
	root.add_child(player)

	var packet: Dictionary = {
		"raw_amount": 50,
		"amount": 50,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_origin_id": &"skeleton",
		"source_skill_id": &"contact",
		"source_instance_id": "formula_contact",
		"attacker_id": "formula_enemy",
		"target_id": str(player.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"wave_damage_multiplier": 1.1,
		"boss_phase_modifier": 1.2,
		"player_damage_reduction_total": 0.15
	}

	var result: Dictionary = DamageSystemScript.calculate(packet, player)
	var incoming: float = 50.0 * 1.1 * 1.2
	var after_defense: float = incoming - minf(8.0, incoming * 0.40)
	var after_reduction: float = after_defense * (1.0 - 0.15) * 0.9
	var expected: int = maxi(roundi(after_reduction), 1)
	var stage_order: Array = result.get("trace", {}).get("stage_order", [])
	var ok: bool = int(result.get("amount", -1)) == expected
	ok = ok and stage_order == ["raw_amount", "incoming_modifiers", "player_defense", "player_reduction", "damage_taken", "rounding"]
	return _expect_equal("enemy -> player", 1 if ok else 0, 1)


func _verify_dot_fractional_damage() -> bool:
	var attacker: FormulaNode = FormulaNode.new()
	attacker.damage_multiplier = 1.0
	root.add_child(attacker)

	var boss: FormulaNode = FormulaNode.new()
	boss.max_health = 1000
	boss.resistances = {"poison_resistance": 0.10}
	boss.set_meta("enemy_rank", "boss")
	root.add_child(boss)

	var packet: Dictionary = {
		"raw_amount": 0.8,
		"amount": 0.8,
		"damage_origin": "status_dot",
		"damage_type": &"status_dot",
		"element": &"poison",
		"source_origin_id": &"toxic_vial",
		"source_skill_id": &"poison",
		"source_instance_id": "formula_poison_dot",
		"attacker": attacker,
		"attacker_id": str(attacker.get_instance_id()),
		"target_id": str(boss.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": true,
		"uses_skill_level_coefficient": false,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}

	var tick_1: Dictionary = DamageSystemScript.calculate(packet, boss)
	var tick_2: Dictionary = DamageSystemScript.calculate(packet, boss)
	var tick_3: Dictionary = DamageSystemScript.calculate(packet, boss)
	var expected_float_per_tick: float = 0.8 * 0.65 * (1.0 - 0.10)
	var expected_total: int = floori(expected_float_per_tick * 3.0)
	return _expect_equal("dot fractional three ticks", int(tick_1.get("amount", 0)) + int(tick_2.get("amount", 0)) + int(tick_3.get("amount", 0)), expected_total)


func _verify_reaction_damage() -> bool:
	var attacker: FormulaNode = FormulaNode.new()
	attacker.damage_multiplier = 1.1
	root.add_child(attacker)

	var boss: FormulaNode = FormulaNode.new()
	boss.defense = 20
	boss.armor = 20
	boss.resistances = {"magical_resistance": 0.25}
	boss.set_meta("enemy_rank", "boss")
	root.add_child(boss)

	var packet: Dictionary = {
		"raw_amount": 80,
		"amount": 80,
		"damage_origin": "reaction",
		"damage_type": &"reaction_damage",
		"element": &"fire",
		"source_origin_id": &"fire_staff",
		"source_skill_id": &"combustion",
		"source_instance_id": "formula_reaction",
		"attacker": attacker,
		"attacker_id": str(attacker.get_instance_id()),
		"target_id": str(boss.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 1,
		"uses_character_damage_multiplier": true,
		"uses_skill_level_coefficient": false,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}

	var result: Dictionary = DamageSystemScript.calculate(packet, boss)
	var expected_float: float = 80.0 * 1.1 * 0.75
	expected_float -= minf(20.0 * 0.5, expected_float * 0.45)
	expected_float *= 1.0 - 0.25
	var expected: int = roundi(expected_float)
	return _expect_equal("reaction -> boss", int(result.get("amount", -1)), expected)


func _verify_field_direct_uses_min_damage() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)

	var packet: Dictionary = {
		"raw_amount": 0.4,
		"amount": 0.4,
		"damage_origin": "field",
		"damage_type": &"area_direct",
		"element": &"fire",
		"source_origin_id": &"",
		"source_skill_id": &"field_direct",
		"source_instance_id": "formula_field_direct",
		"attacker_id": "",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": [],
		"field_damage_model": "direct_tick"
	}

	var hit_1: Dictionary = DamageSystemScript.calculate(packet, target)
	var hit_2: Dictionary = DamageSystemScript.calculate(packet, target)
	return _expect_equal("field direct min damage twice", int(hit_1.get("amount", 0)) + int(hit_2.get("amount", 0)), 2)


func _verify_true_percent_stage_order() -> bool:
	var target: FormulaNode = FormulaNode.new()
	target.max_health = 1000
	root.add_child(target)
	var packet: Dictionary = {
		"raw_amount": 0.10,
		"amount": 0.10,
		"damage_origin": "special",
		"damage_type": &"true_percent_damage",
		"element": &"neutral",
		"source_origin_id": &"",
		"source_skill_id": &"true_percent_contract",
		"source_instance_id": "formula_true_percent",
		"attacker_id": "",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}
	var result: Dictionary = DamageSystemScript.calculate(packet, target)
	var trace: Dictionary = result.get("trace", {})
	var stage_order: Array = trace.get("stage_order", [])
	var ok: bool = int(result.get("amount", -1)) == 100
	ok = ok and stage_order == ["raw_amount", "true_percent", "cap", "rounding"]
	ok = ok and is_equal_approx(float(trace.get("percent", 0.0)), 0.10)
	return _expect_equal("true percent stage order", 1 if ok else 0, 1)


func _verify_reaction_limits() -> bool:
	var source: FormulaNode = FormulaNode.new()
	root.add_child(source)
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = {
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"lightning",
		"source_origin_id": &"test_primary_attack",
		"source_skill_id": &"test_lightning_chain",
		"source_instance_id": "formula_reaction_limit",
		"attacker_id": str(source.get_instance_id()),
		"target_id": str(target.get_instance_id()),
		"can_trigger_reaction": true,
		"reaction_depth": 0
	}

	var first: bool = ReactionLimiterScript.can_trigger(packet, "lightning_bounce", target)
	ReactionLimiterScript.record_trigger(packet, "lightning_bounce", target)
	var second: bool = ReactionLimiterScript.can_trigger(packet, "lightning_bounce", target)
	ReactionLimiterScript.record_trigger(packet, "lightning_bounce", target)
	var third: bool = ReactionLimiterScript.can_trigger(packet, "lightning_bounce", target)
	return _expect_equal("reaction max_bounces", 1 if first and second and not third else 0, 1)


func _verify_special_rule_boundaries() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)

	var packet: Dictionary = {
		"raw_amount": 100,
		"amount": 100,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_origin_id": &"",
		"source_skill_id": &"special_boundary",
		"source_instance_id": "formula_special_boundary",
		"attacker_id": "",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": [],
		"special_final_modifier": 0.1
	}

	var ignored: Dictionary = DamageSystemScript.calculate(packet, target)
	packet["special_final_modifier_source"] = "system_rule"
	var applied: Dictionary = DamageSystemScript.calculate(packet, target)
	var ok: bool = int(ignored.get("amount", -1)) == 100 and int(applied.get("amount", -1)) == 10
	return _expect_equal("special modifier boundary", 1 if ok else 0, 1)


func _verify_lightning_backflow_defense_cap() -> bool:
	var target: FormulaNode = FormulaNode.new()
	target.defense = 100
	target.armor = 100
	target.set_meta("enemy_rank", "boss")
	root.add_child(target)

	var packet: Dictionary = {
		"raw_amount": 100,
		"amount": 100,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"lightning",
		"source_origin_id": &"lightning_whip",
		"source_skill_id": &"lightning_orb",
		"source_instance_id": "formula_lightning_backflow",
		"attacker_id": "",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": false,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": ["lightning_orb_backflow"]
	}

	var result: Dictionary = DamageSystemScript.calculate(packet, target)
	return _expect_equal("lightning backflow boss defense cap", int(result.get("amount", -1)), 70)


func _verify_shared_primary_attack_crit() -> bool:
	var executor: RefCounted = SkillActionExecutorScript.new()
	var attacker: FormulaNode = FormulaNode.new()
	attacker.crit_chance = 1.0
	attacker.crit_damage = 2.0
	root.add_child(attacker)
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var context: Dictionary = {
		"caster": attacker,
		"target": target,
		"skill_id": &"formula_shared_crit"
	}

	var direct_packet: Dictionary = executor.call("_build_damage_packet", {
		"damage_origin": "primary_attack",
		"damage_type": "direct_physical",
		"element": "physical",
		"can_crit": true,
		"uses_skill_level_coefficient": false
	}, context, 10, "skill")
	var explosion_packet: Dictionary = executor.call("_build_damage_packet", {
		"damage_origin": "primary_attack",
		"damage_type": "area_direct",
		"element": "physical",
		"can_crit": true,
		"uses_skill_level_coefficient": false
	}, context, 10, "explosion")
	var ok: bool = bool(direct_packet.get("critical_resolved", false)) and bool(explosion_packet.get("critical_resolved", false))
	ok = ok and bool(direct_packet.get("is_critical", false)) == bool(explosion_packet.get("is_critical", false))
	ok = ok and float(direct_packet.get("crit_multiplier", 0.0)) == float(explosion_packet.get("crit_multiplier", 1.0))
	return _expect_equal("shared primary attack crit", 1 if ok else 0, 1)


func _verify_shared_primary_attack_noncrit_uses_neutral_multiplier() -> bool:
	var executor: RefCounted = SkillActionExecutorScript.new()
	var attacker: FormulaNode = FormulaNode.new()
	attacker.crit_chance = 0.0
	attacker.crit_damage = 2.0
	root.add_child(attacker)
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var context: Dictionary = {
		"caster": attacker,
		"target": target,
		"skill_id": &"formula_shared_noncrit"
	}

	var packet: Dictionary = executor.call("_build_damage_packet", {
		"damage_origin": "primary_attack",
		"damage_type": "direct_physical",
		"element": "physical",
		"can_crit": true,
		"uses_skill_level_coefficient": false
	}, context, 10, "skill")
	var result: Dictionary = DamageSystemScript.calculate(packet, target)
	var ok: bool = bool(packet.get("critical_resolved", false))
	ok = ok and not bool(packet.get("is_critical", true))
	ok = ok and is_equal_approx(float(packet.get("crit_multiplier", -1.0)), 1.0)
	ok = ok and int(result.get("amount", -1)) == 10
	ok = ok and not bool(result.get("is_critical", true))
	return _expect_equal("shared primary attack noncrit neutral multiplier", 1 if ok else 0, 1)


func _verify_damage_trace_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = {
		"raw_amount": 25,
		"amount": 25,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_origin_id": &"trace_primary_attack",
		"source_skill_id": &"trace_skill",
		"source_instance_id": "trace_skill:1",
		"attacker_id": "trace_attacker",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}
	var result: Dictionary = DamageSystemScript.calculate(packet, target)
	var trace: Dictionary = result.get("trace", {})
	var ok: bool = trace.has("raw_amount")
	ok = ok and trace.has("character_damage_multiplier")
	ok = ok and trace.has("skill_level_coefficient")
	ok = ok and trace.has("pre_mitigation_damage")
	ok = ok and trace.has("after_defense")
	ok = ok and trace.has("after_resistance")
	ok = ok and trace.has("after_vulnerability")
	ok = ok and trace.has("after_special")
	ok = ok and trace.has("rounded_amount")
	ok = ok and int(trace.get("rounded_amount", -1)) == int(result.get("amount", -2))
	var stage_order: Array = trace.get("stage_order", [])
	ok = ok and stage_order == ["raw_amount", "outgoing", "critical", "defense", "resistance", "vulnerability", "special", "rounding"]
	return _expect_equal("damage trace contract", 1 if ok else 0, 1)


func _verify_damage_result_trace_object_contract() -> bool:
	var trace_object: RefCounted = DamageTraceScript.create({"raw_amount": 12})
	trace_object.call("set_stage_order", ["raw_amount", "rounding"])
	trace_object.call("set_stage", "rounded_amount", 12)
	var result_object: RefCounted = DamageResultScript.make({
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical"
	}, 12, false, 12.0, 1.0, trace_object.call("to_dictionary"))
	var result: Dictionary = result_object.call("to_dictionary")
	var ok: bool = int(result.get("amount", 0)) == 12
	ok = ok and result.get("trace", {}).get("stage_order", []) == ["raw_amount", "rounding"]
	ok = ok and int(result.get("stages", {}).get("rounded_amount", 0)) == 12
	ok = ok and String(result.get("damage_type", "")) == "direct_physical"
	return _expect_equal("damage result trace object contract", 1 if ok else 0, 1)


func _verify_damage_system_typed_result_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = {
		"raw_amount": 13,
		"amount": 13,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_origin_id": &"typed_result_primary_attack",
		"source_skill_id": &"typed_result_skill",
		"source_instance_id": "typed_result:1",
		"attacker_id": "typed_result_attacker",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}
	var result_object: RefCounted = DamageSystemScript.calculate_result(packet, target)
	var result: Dictionary = result_object.call("to_dictionary")
	var legacy_result: Dictionary = DamageSystemScript.calculate(packet, target)
	var ok: bool = result_object != null and result_object.has_method("to_dictionary")
	ok = ok and int(result_object.get("amount")) == 13
	ok = ok and int(result.get("amount", -1)) == int(legacy_result.get("amount", -2))
	ok = ok and String(result.get("damage_type", "")) == "direct_physical"
	ok = ok and int(result.get("trace", {}).get("rounded_amount", -1)) == 13
	ok = ok and result.get("trace", {}).get("stage_order", []) == legacy_result.get("trace", {}).get("stage_order", [])
	return _expect_equal("damage system typed result contract", 1 if ok else 0, 1)


func _verify_damage_pipeline_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = {
		"raw_amount": 10,
		"amount": 10,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_skill_id": &"pipeline",
		"source_instance_id": "pipeline:1",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true
	}
	var context: RefCounted = DamageSystemScript.call("_create_calculation_context", packet, &"", null, target)
	var pipeline: RefCounted = DamagePipelineScript.create([
		DamageStageScript.create("outgoing", "_standard_outgoing_pipeline_stage"),
		DamageStageScript.create("rounding", "_standard_rounding_pipeline_stage")
	])
	var final_amount: int = int(pipeline.call("execute_with_host", DamageSystemScript, context, 10.0))
	var ok: bool = final_amount == 10
	ok = ok and pipeline.call("stage_names") == [&"outgoing", &"rounding"]
	ok = ok and int(context.get("stages").get("rounded_amount", 0)) == 10
	return _expect_equal("damage pipeline contract", 1 if ok else 0, 1)


func _verify_damage_rule_registry_contract() -> bool:
	var ok: bool = DamageRuleRegistryScript.normalize_origin("bad_origin") == "primary_attack"
	ok = ok and DamageRuleRegistryScript.normalize_damage_type("", "field") == "area_direct"
	ok = ok and DamageRuleRegistryScript.normalize_damage_type("status_dot", "primary_attack") == "status_dot"
	ok = ok and DamageRuleRegistryScript.infer_damage_type(&"fire", "projectile", "primary_attack") == &"direct_magical"
	ok = ok and DamageRuleRegistryScript.infer_damage_type(&"physical", "projectile", "primary_attack") == &"direct_physical"
	ok = ok and is_equal_approx(DamageRuleRegistryScript.defense_rate("reaction_damage"), 0.5)
	ok = ok and DamageRuleRegistryScript.default_can_crit("primary_attack", "direct_physical")
	ok = ok and not DamageRuleRegistryScript.default_can_crit("field", "area_direct")
	var crit_packet_object: RefCounted = DamagePacketScript.from_dictionary({"damage_origin": "primary_attack", "damage_type": &"direct_physical", "can_crit": true})
	var crit_context: RefCounted = DamageCalculationContextScript.create(crit_packet_object, null)
	ok = ok and DamageRuleRegistryScript.can_crit_for_packet_object(crit_packet_object)
	ok = ok and DamageRuleRegistryScript.can_crit_for_context(crit_context)
	ok = ok and not DamageRuleRegistryScript.default_uses_character_damage("special", "true_damage")
	ok = ok and DamageRuleRegistryScript.is_legal_origin_type("field", "status_dot")
	ok = ok and DamageRuleRegistryScript.is_legal_origin_type("primary_attack", "status_dot")
	ok = ok and DamageRuleRegistryScript.uses_fractional_buffer({"damage_type": &"status_dot"})
	ok = ok and DamageRuleRegistryScript.uses_fractional_buffer({"field_damage_model": "dot_tick"})
	ok = ok and not DamageRuleRegistryScript.uses_fractional_buffer({"damage_type": &"status_dot", "ignore_fractional_buffer": true})
	ok = ok and is_equal_approx(DamageRuleRegistryScript.true_percent_default_cap("boss"), 0.0025)
	ok = ok and is_equal_approx(float(DamageRuleRegistryScript.vulnerability_bounds("elite").get("cap", 0.0)), 0.20)
	ok = ok and DamageRuleRegistryScript.origin_bonus_keys("primary_attack").has("primary_attack_damage_multiplier_add")
	ok = ok and DamageRuleRegistryScript.enemy_type_bonus_key("boss") == "boss_damage_multiplier_add"
	ok = ok and is_equal_approx(DamageRuleRegistryScript.target_class_origin_modifier("boss", "status_dot", "status_dot"), 0.65)
	ok = ok and DamageRuleRegistryScript.resistance_keys("fire").has("magical_resistance")
	ok = ok and is_equal_approx(DamageRuleRegistryScript.resistance_scale("acid", {"poison_resistance": 0.4}), 0.5)
	ok = ok and is_equal_approx(DamageRuleRegistryScript.resistance_scale("acid", {"acid_resistance": 0.4}), 1.0)
	return _expect_equal("damage rule registry contract", 1 if ok else 0, 1)


func _verify_damage_policy_registry_contract() -> bool:
	var origin_policy: RefCounted = DamageRuleRegistryScript.origin_policy("primary_attack")
	var type_policy: RefCounted = DamageRuleRegistryScript.damage_type_policy("true_damage")
	var ok: bool = String(origin_policy.get("default_damage_type")) == "direct_physical"
	ok = ok and bool(origin_policy.get("uses_skill_level"))
	ok = ok and origin_policy.get("bonus_keys").has("primary_attack_damage_multiplier_add")
	ok = ok and bool(type_policy.get("ignores_resistance"))
	ok = ok and bool(type_policy.get("ignores_vulnerability"))
	ok = ok and type_policy.get("allowed_origins").has(&"special")
	ok = ok and is_equal_approx(float(DamageRuleRegistryScript.damage_type_policy("direct_magical").get("defense_rate")), 0.6)
	ok = ok and DamageRuleRegistryScript.damage_type_policy("status_dot").call("allows_origin", "field")
	ok = ok and DamageRuleRegistryScript.damage_type_policy("status_dot").call("allows_origin", "primary_attack")
	ok = ok and ModifierKeyRegistryScript.element_bonus_key(&"fire") == "fire_damage_multiplier_add"
	return _expect_equal("damage policy registry contract", 1 if ok else 0, 1)


func _verify_damage_packet_object_contract() -> bool:
	var packet_object: RefCounted = DamagePacketScript.from_dictionary({
		"raw_amount": 7,
		"amount": 7,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_type": "skill",
		"source_origin_id": &"wand",
		"source_skill_id": &"spark",
		"source_instance_id": "spark:1",
		"attacker_id": "attacker",
		"target_id": "target",
		"can_crit": true,
		"can_trigger_reaction": true,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": true,
		"uses_skill_level_coefficient": false,
		"skill_level_coefficient": 1.0,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"ignore_min_damage": false,
		"special_rule_tags": [&"contract"]
	})
	var packet: Dictionary = packet_object.call("to_dictionary")
	packet_object.call("set_value", "element", &"fire")
	packet_object.call("set_value", "custom_marker", "kept")
	var updated: Dictionary = packet_object.call("to_dictionary")
	var ok: bool = int(packet.get("raw_amount", 0)) == 7
	ok = ok and String(packet.get("source_skill_id", "")) == "spark"
	ok = ok and bool(packet.get("can_crit", false))
	ok = ok and String(packet_object.call("get_value", "source_instance_id", "")) == "spark:1"
	ok = ok and String(updated.get("element", "")) == "fire"
	ok = ok and String(updated.get("custom_marker", "")) == "kept"
	ok = ok and packet_object.call("validate").is_empty()
	return _expect_equal("damage packet object contract", 1 if ok else 0, 1)


func _verify_damage_source_context_factory_contract() -> bool:
	var attacker: FormulaNode = FormulaNode.new()
	root.add_child(attacker)
	var source_context: RefCounted = DamageSourceContextFactoryScript.from_packet({
		"source_origin_id": &"factory_primary_attack",
		"source_skill_id": &"factory_skill",
		"source_instance_id": "factory:1"
	}, attacker)
	var ok: bool = source_context.get("attacker") == attacker
	ok = ok and String(source_context.get("attacker_id")) == str(attacker.get_instance_id())
	ok = ok and String(source_context.get("source_skill_id")) == "factory_skill"
	return _expect_equal("damage source context factory contract", 1 if ok else 0, 1)


func _verify_damage_calculation_context_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	target.defense = 5
	root.add_child(target)
	var packet_object: RefCounted = DamagePacketScript.from_dictionary({
		"raw_amount": 11,
		"amount": 11,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_skill_id": &"context",
		"source_instance_id": "context:1",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false
	})
	var context: RefCounted = DamageCalculationContextScript.create(packet_object, target)
	var packet: Dictionary = context.call("packet_dict")
	var ok: bool = int(context.get("raw_amount")) == 11
	ok = ok and String(packet.get("source_instance_id", "")) == "context:1"
	ok = ok and int(context.get("target_profile").get("defense")) == 5
	context.get("stages")["contract_stage"] = 11
	var output: Dictionary = context.call("finish", 9, false, 9.0, {"amount": 9})
	ok = ok and int(output.get("amount", 0)) == 9
	ok = ok and int(context.get("final_amount")) == 9
	return _expect_equal("damage calculation context contract", 1 if ok else 0, 1)


func _verify_damage_validator_typed_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = {
		"raw_amount": 0.5,
		"amount": 0.5,
		"damage_origin": "status_dot",
		"damage_type": &"status_dot",
		"element": &"poison",
		"source_origin_id": &"",
		"source_skill_id": &"typed_validator",
		"source_instance_id": "typed_validator:1",
		"attacker_id": "",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"skill_level_coefficient": 1.0,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}
	var packet_object: RefCounted = DamagePacketScript.from_dictionary(packet, null, target)
	var context: RefCounted = DamageCalculationContextScript.create(packet_object, target)
	DamagePacketValidatorScript.validate_any(packet_object, target)
	DamagePacketValidatorScript.validate_for_context(context, target)
	var ok: bool = DamageRuleRegistryScript.uses_fractional_buffer(packet)
	ok = ok and DamageRuleRegistryScript.uses_fractional_buffer_for_packet_object(packet_object)
	ok = ok and DamageRuleRegistryScript.uses_fractional_buffer_for_context(context)
	return _expect_equal("damage validator typed contract", 1 if ok else 0, 1)


func _verify_damage_context_stage_helpers_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	target.defense = 20
	target.armor = 20
	target.resistances = {"fire_resistance": 0.25}
	target.damage_taken_multiplier = 1.10
	target.set_meta("enemy_rank", "boss")
	root.add_child(target)
	var packet: Dictionary = {
		"raw_amount": 100,
		"amount": 100,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"fire",
		"source_skill_id": &"context_stage",
		"source_instance_id": "context_stage:1",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"vulnerability_total": 0.05,
		"enemy_type_bonus_total": 0.05,
		"boss_damage_multiplier_add": 0.20
	}
	var context: RefCounted = DamageSystemScript.call("_create_calculation_context", packet, &"", null, target)
	var defended: float = DamageSystemScript.call("_apply_defense_stage", context, 100.0)
	var resisted: float = DamageSystemScript.call("_apply_resistance_stage", context, 100.0)
	var vulnerability_total: float = DamageSystemScript.call("_get_vulnerability_total_for_context", context)
	var enemy_type_bonus_total: float = DamageSystemScript.call("_get_enemy_type_bonus_total_for_context", context)
	var ok: bool = is_equal_approx(defended, 88.0)
	ok = ok and is_equal_approx(resisted, 75.0)
	ok = ok and is_equal_approx(vulnerability_total, 0.15)
	ok = ok and is_equal_approx(enemy_type_bonus_total, 0.25)
	return _expect_equal("damage context stage helpers contract", 1 if ok else 0, 1)


func _verify_damage_context_outgoing_helpers_contract() -> bool:
	var attacker: FormulaNode = FormulaNode.new()
	attacker.damage_multiplier = 1.5
	attacker.crit_chance = 1.0
	attacker.crit_damage = 2.0
	attacker.fire_damage_multiplier_add = 0.20
	root.add_child(attacker)
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = {
		"raw_amount": 40,
		"amount": 40,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"fire",
		"source_skill_id": &"context_outgoing",
		"source_instance_id": "context_outgoing:1",
		"attacker": attacker,
		"attacker_id": str(attacker.get_instance_id()),
		"target_id": str(target.get_instance_id()),
		"can_crit": true,
		"can_trigger_reaction": false,
		"uses_character_damage_multiplier": true,
		"uses_skill_level_coefficient": true,
		"skill_level_coefficient": 1.25,
		"origin_bonus_total": 0.10,
		"primary_attack_damage_multiplier_add": 0.20,
		"element_bonus_total": 0.05,
		"fire_damage_multiplier_add": 0.10,
		"critical_resolved": true,
		"is_critical": true,
		"crit_multiplier": 1.75
	}
	var context: RefCounted = DamageSystemScript.call("_create_calculation_context", packet, &"", attacker, target)
	var character_multiplier: float = DamageSystemScript.call("_get_character_damage_multiplier_for_context", context)
	var skill_level_coefficient: float = DamageSystemScript.call("_get_skill_level_coefficient_for_context", context)
	var origin_bonus_total: float = DamageSystemScript.call("_get_origin_bonus_total_for_context", context)
	var element_bonus_total: float = DamageSystemScript.call("_get_element_bonus_total_for_context", context)
	var can_crit: bool = DamageSystemScript.call("_can_crit_for_context", context)
	var critical_result: Dictionary = DamageSystemScript.call("_apply_critical_stage", context, 100.0)
	var ok: bool = is_equal_approx(character_multiplier, 1.5)
	ok = ok and is_equal_approx(skill_level_coefficient, 1.25)
	ok = ok and is_equal_approx(origin_bonus_total, 0.30)
	ok = ok and is_equal_approx(element_bonus_total, 0.35)
	ok = ok and can_crit
	ok = ok and bool(critical_result.get("is_critical", false))
	ok = ok and is_equal_approx(float(critical_result.get("crit_multiplier", 0.0)), 1.75)
	ok = ok and is_equal_approx(float(critical_result.get("pre_mitigation", 0.0)), 175.0)
	return _expect_equal("damage context outgoing helpers contract", 1 if ok else 0, 1)


func _verify_damage_context_result_helpers_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = {
		"raw_amount": 12.2,
		"amount": 12.2,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_skill_id": &"context_result",
		"source_instance_id": "context_result:1",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_min_damage": false,
		"special_final_modifier": 0.5,
		"special_final_modifier_source": "system_rule"
	}
	var context: RefCounted = DamageSystemScript.call("_create_calculation_context", packet, &"", null, target)
	var special_modifier: float = DamageSystemScript.call("_get_special_final_modifier_for_context", context)
	var rounded: int = DamageSystemScript.call("_apply_rounding_stage", context, 12.2)
	var stages: Dictionary = context.get("stages")
	var result: Dictionary = DamageSystemScript.call("_result_for_context", context, rounded, true, 12.2, 1.0, stages)
	var ok: bool = is_equal_approx(special_modifier, 0.5)
	ok = ok and rounded == 12
	ok = ok and int(stages.get("rounded_amount", -1)) == 12
	ok = ok and int(result.get("amount", -1)) == 12
	ok = ok and bool(result.get("is_critical", false))
	ok = ok and String(result.get("damage_origin", "")) == "primary_attack"
	ok = ok and String(result.get("damage_type", "")) == "direct_physical"
	ok = ok and String(result.get("element", "")) == "physical"
	ok = ok and result.get("trace", {}).has("rounded_amount")
	return _expect_equal("damage context result helpers contract", 1 if ok else 0, 1)


func _verify_damage_rounding_context_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	DamageRoundingServiceScript.clear_target(target)
	var packet: Dictionary = {
		"raw_amount": 0.6,
		"amount": 0.6,
		"damage_origin": "status_dot",
		"damage_type": &"status_dot",
		"element": &"poison",
		"source_skill_id": &"rounding_context",
		"source_instance_id": "rounding_context:1",
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false
	}
	var context: RefCounted = DamageSystemScript.call("_create_calculation_context", packet, &"", null, target)
	var old_key: String = DamageRoundingServiceScript.call("_buffer_key", context.get("packet_dictionary"), target)
	var context_key: String = DamageRoundingServiceScript.call("_buffer_key_for_context", context)
	var first: int = DamageRoundingServiceScript.resolve_for_context(0.6, context)
	var second: int = DamageRoundingServiceScript.resolve_for_context(0.6, context)
	packet["ignore_fractional_buffer"] = true
	packet["ignore_min_damage"] = true
	var no_buffer_context: RefCounted = DamageSystemScript.call("_create_calculation_context", packet, &"", null, target)
	var ignored_min: int = DamageRoundingServiceScript.resolve_for_context(0.2, no_buffer_context)
	DamageRoundingServiceScript.clear_target(target)
	var ok: bool = old_key == context_key
	ok = ok and first == 0
	ok = ok and second == 1
	ok = ok and ignored_min == 0
	return _expect_equal("damage rounding context contract", 1 if ok else 0, 1)


func _verify_target_profile_contract() -> bool:
	var boss: FormulaNode = FormulaNode.new()
	boss.defense = 17
	boss.armor = 19
	boss.resistances = {"fire_resistance": 0.25}
	boss.set_meta("enemy_rank", "boss")
	root.add_child(boss)
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(boss)
	var ok: bool = String(profile.get("target_type")) == "boss"
	ok = ok and is_equal_approx(float(profile.get("true_percent_cap")), 0.0025)
	ok = ok and is_equal_approx(float(profile.get("vulnerability_cap")), 0.15)
	ok = ok and int(profile.get("defense")) == 17
	ok = ok and is_equal_approx(float(profile.get("origin_taken_modifiers").get("status_dot", 0.0)), 0.65)
	ok = ok and is_equal_approx(DamageRuleRegistryScript.origin_taken_modifier_from_map(profile.get("origin_taken_modifiers"), "reaction", "reaction_damage"), 0.75)
	return _expect_equal("target profile contract", 1 if ok else 0, 1)


func _verify_reaction_service_contract() -> bool:
	var packet: Dictionary = {
		"raw_amount": 5,
		"amount": 5,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"fire",
		"source_skill_id": &"reaction_service",
		"source_instance_id": "reaction_service:1",
		"can_trigger_reaction": true,
		"reaction_depth": 0
	}
	var reaction_packet: Dictionary = ReactionServiceScript.make_reaction_packet(packet, "overload", 3.0, &"fire")
	var ok: bool = String(reaction_packet.get("damage_origin", "")) == "reaction"
	ok = ok and String(reaction_packet.get("reaction_type", "")) == "overload"
	ok = ok and not bool(reaction_packet.get("can_trigger_reaction", true))
	return _expect_equal("reaction service contract", 1 if ok else 0, 1)


func _verify_reaction_damage_builder_contract() -> bool:
	var base_packet: Dictionary = {
		"raw_amount": 12,
		"amount": 12,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"lightning",
		"source_origin_id": &"builder_skill_source",
		"source_skill_id": &"builder_reaction",
		"source_instance_id": "builder_reaction:1",
		"attacker_id": "attacker",
		"target_id": "target",
		"can_trigger_reaction": true,
		"reaction_depth": 0
	}
	var packet: Dictionary = ReactionDamageBuilderScript.build(base_packet, "shatter", 5.0, &"ice", "major")
	var ok: bool = int(packet.get("raw_amount", 0)) == 5
	ok = ok and String(packet.get("damage_origin", "")) == "reaction"
	ok = ok and String(packet.get("damage_type", "")) == "reaction_damage"
	ok = ok and String(packet.get("reaction_type", "")) == "shatter"
	ok = ok and String(packet.get("reaction_tier", "")) == "major"
	ok = ok and not bool(packet.get("can_trigger_reaction", true))
	ok = ok and int(packet.get("reaction_depth", 0)) == 1
	return _expect_equal("reaction damage builder contract", 1 if ok else 0, 1)


func _verify_reaction_typed_contract() -> bool:
	var source: FormulaNode = FormulaNode.new()
	root.add_child(source)
	var boss: FormulaNode = FormulaNode.new()
	boss.set_meta("enemy_rank", "boss")
	root.add_child(boss)
	var packet: Dictionary = {
		"raw_amount": 8,
		"amount": 8,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"lightning",
		"source_origin_id": &"typed_reaction_skill_source",
		"source_skill_id": &"typed_reaction_skill",
		"source_instance_id": "typed_reaction:1",
		"attacker_id": str(source.get_instance_id()),
		"target_id": str(boss.get_instance_id()),
		"can_trigger_reaction": true,
		"reaction_depth": 0,
		"defense_reduction_cap": 0.45,
		"special_rule_tags": ["lightning_orb_backflow"],
		"reaction_type": "overload"
	}
	var context: RefCounted = DamageSystemScript.call("_create_calculation_context", packet, &"", source, boss)
	var cap: float = ReactionLimiterScript.get_defense_reduction_cap_for_context(context, 0.45, boss)
	var special_modifier: float = ReactionLimiterScript.get_special_final_modifier_for_context(context, boss)
	var first: bool = ReactionLimiterScript.can_trigger_for_context(context, "lightning_bounce", boss)
	ReactionLimiterScript.record_trigger_for_context(context, "lightning_bounce", boss)
	var second: bool = ReactionLimiterScript.can_trigger_for_context(context, "lightning_bounce", boss)
	ReactionLimiterScript.record_trigger_for_context(context, "lightning_bounce", boss)
	var third: bool = ReactionLimiterScript.can_trigger_for_context(context, "lightning_bounce", boss)
	var reaction_packets: Array[Dictionary] = ReactionServiceScript.try_trigger_for_context(context, "death_explosion", boss, 3.0, &"fire")
	var ok: bool = is_equal_approx(cap, 0.30)
	ok = ok and is_equal_approx(special_modifier, 0.75)
	ok = ok and first and second and not third
	ok = ok and reaction_packets.size() == 1
	ok = ok and String(reaction_packets[0].get("damage_origin", "")) == "reaction"
	ok = ok and String(reaction_packets[0].get("reaction_type", "")) == "death_explosion"
	return _expect_equal("reaction typed contract", 1 if ok else 0, 1)


func _verify_hit_event_result_contract() -> bool:
	var consumed: Dictionary = HitEventResultScript.from_value(true).call("to_dictionary")
	var side_effect: Dictionary = HitEventResultScript.from_value({"side_effect_only": true}).call("to_dictionary")
	var ok: bool = bool(consumed.get("consume_base_damage", false))
	ok = ok and bool(side_effect.get("side_effect_only", false))
	return _expect_equal("hit event result contract", 1 if ok else 0, 1)


func _verify_damage_application_service_enemy_contract() -> bool:
	var enemy: ApplicationEnemyNode = ApplicationEnemyNode.new()
	enemy.max_health = 50
	enemy.current_health = 50
	root.add_child(enemy)
	var packet: Dictionary = {
		"raw_amount": 10,
		"amount": 10,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_origin_id": &"application",
		"source_skill_id": &"service",
		"source_instance_id": "application_service:1",
		"attacker_id": "",
		"target_id": str(enemy.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}
	var result: RefCounted = DamageApplicationServiceScript.apply_enemy_damage(enemy, packet)
	var ok: bool = bool(result.get("applied"))
	ok = ok and int(result.get("amount")) == 10
	ok = ok and enemy.current_health == 40
	ok = ok and int(enemy.get_meta("recorded_damage_done", 0)) == 10
	return _expect_equal("damage application service enemy contract", 1 if ok else 0, 1)


func _verify_damage_application_service_typed_contract() -> bool:
	var enemy: ApplicationEnemyNode = ApplicationEnemyNode.new()
	enemy.max_health = 50
	enemy.current_health = 50
	root.add_child(enemy)
	var packet_object: RefCounted = DamagePacketScript.from_dictionary({
		"raw_amount": 7,
		"amount": 7,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_origin_id": &"typed_application",
		"source_skill_id": &"service",
		"source_instance_id": "typed_application:1",
		"attacker_id": "",
		"target_id": str(enemy.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": []
	})
	var result: RefCounted = DamageApplicationServiceScript.apply_enemy_damage(enemy, packet_object)
	var intent_result: RefCounted = DamageIntentScript.create(enemy, packet_object).call("apply")
	var ok: bool = bool(result.get("applied"))
	ok = ok and int(result.get("amount")) == 7
	ok = ok and bool(intent_result.get("applied"))
	ok = ok and int(intent_result.get("amount")) == 7
	ok = ok and enemy.current_health == 36
	return _expect_equal("damage application service typed contract", 1 if ok else 0, 1)


func _verify_damage_application_pipeline_contract() -> bool:
	var enemy: ApplicationEnemyNode = ApplicationEnemyNode.new()
	enemy.max_health = 30
	enemy.current_health = 30
	root.add_child(enemy)
	var packet: Dictionary = {
		"raw_amount": 6,
		"amount": 6,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_origin_id": &"application_pipeline",
		"source_skill_id": &"pipeline",
		"source_instance_id": "application_pipeline:1",
		"attacker_id": "",
		"target_id": str(enemy.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}
	var context: RefCounted = DamageApplicationContextScript.create(enemy, packet)
	var result: RefCounted = DamageApplicationPipelineScript.apply(context)
	var ok: bool = bool(result.get("applied"))
	ok = ok and int(result.get("amount")) == 6
	ok = ok and enemy.current_health == 24
	ok = ok and DamageApplicationPipelineScript.packet_amount(packet) == 6
	ok = ok and DamageApplicationPipelineScript.enemy_stage_names() == [&"enemy_precheck", &"enemy_calculation", &"enemy_synergy", &"enemy_boss_core", &"enemy_health_apply"]
	ok = ok and DamageApplicationPipelineScript.player_stage_names().has(&"player_absorb")
	return _expect_equal("damage application pipeline contract", 1 if ok else 0, 1)


func _verify_damage_modifier_query_contract() -> bool:
	var attacker: FormulaNode = FormulaNode.new()
	root.add_child(attacker)
	var packet_object: RefCounted = DamagePacketScript.from_dictionary({
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"fire",
		"source_origin_id": &"modifier_skill_source",
		"source_skill_id": &"modifier_skill",
		"source_instance_id": "modifier:1"
	}, attacker)
	var damage_query: RefCounted = DamageModifierQueryScript.make(packet_object, attacker)
	var query: RefCounted = damage_query.call("to_modifier_query")
	var ok: bool = String(query.get("scope")) == "damage"
	ok = ok and String(query.get("source_origin_id")) == "modifier_skill_source"
	ok = ok and String(query.get("skill_id")) == "modifier_skill"
	ok = ok and String(query.get("damage_origin")) == "primary_attack"
	ok = ok and String(query.get("element")) == "fire"
	return _expect_equal("damage modifier query contract", 1 if ok else 0, 1)


func _verify_skill_packet_builder_contract() -> bool:
	var executor: RefCounted = SkillActionExecutorScript.new()
	var attacker: FormulaNode = FormulaNode.new()
	root.add_child(attacker)
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var context: Dictionary = {
		"caster": attacker,
		"target": target,
		"skill_id": &"builder_contract",
		"source_origin_id": &"builder_skill_source"
	}
	var packet: Dictionary = executor.call("_build_damage_packet", {
		"damage_origin": "reaction",
		"damage_type": "reaction_damage",
		"element": "lightning",
		"source_instance_id": "builder_contract:reaction",
		"uses_skill_level_coefficient": false
	}, context, 7, "skill")
	var ok: bool = int(packet.get("raw_amount", 0)) == 7
	ok = ok and String(packet.get("damage_origin", "")) == "reaction"
	ok = ok and String(packet.get("damage_type", "")) == "reaction_damage"
	ok = ok and String(packet.get("element", "")) == "lightning"
	ok = ok and String(packet.get("source_origin_id", "")) == "builder_skill_source"
	ok = ok and String(packet.get("source_skill_id", "")) == "builder_contract"
	ok = ok and String(packet.get("source_instance_id", "")) == "builder_contract:reaction"
	ok = ok and not bool(packet.get("can_crit", true))
	ok = ok and not bool(packet.get("can_trigger_reaction", true))
	var packet_object: RefCounted = DamagePacketBuilderScript.from_skill_action_object({
		"params": {
			"damage_origin": "primary_attack",
			"damage_type": "direct_physical",
			"source_instance_id": "builder_object:1",
			"uses_skill_level_coefficient": false
		},
		"context": context,
		"amount": 5,
		"source_type": "skill"
	})
	ok = ok and int(packet_object.call("get_value", "raw_amount", 0)) == 5
	ok = ok and String(packet_object.call("get_value", "source_instance_id", "")) == "builder_object:1"
	return _expect_equal("skill packet builder contract", 1 if ok else 0, 1)


func _verify_status_dot_packet_builder_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = DamagePacketBuilderScript.from_status_dot({
		"target": target,
		"status": {"id": &"poison"},
		"amount": 3.5,
		"element": &"poison"
	})
	var ok: bool = float(packet.get("raw_amount", 0.0)) == 3.5
	ok = ok and String(packet.get("damage_origin", "")) == "status_dot"
	ok = ok and String(packet.get("damage_type", "")) == "status_dot"
	ok = ok and String(packet.get("element", "")) == "poison"
	ok = ok and String(packet.get("source_skill_id", "")) == "poison"
	ok = ok and String(packet.get("source_instance_id", "")).find(str(target.get_instance_id())) == 0
	ok = ok and not bool(packet.get("can_crit", true))
	ok = ok and not bool(packet.get("can_trigger_reaction", true))
	ok = ok and not bool(packet.get("uses_skill_level_coefficient", true))
	return _expect_equal("status dot packet builder contract", 1 if ok else 0, 1)


func _verify_reaction_packet_builder_contract() -> bool:
	var base_packet: Dictionary = {
		"raw_amount": 10,
		"amount": 10,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_magical",
		"element": &"lightning",
		"source_origin_id": &"lightning_whip",
		"source_skill_id": &"lightning_orb",
		"source_instance_id": "reaction_builder_base",
		"attacker_id": "attacker",
		"target_id": "target",
		"can_trigger_reaction": true,
		"reaction_depth": 0,
		"special_rule_tags": [&"source_tag"]
	}
	var packet: Dictionary = ReactionLimiterScript.make_reaction_packet(base_packet, "shatter", 4.0, &"ice")
	var tags: Array = packet.get("special_rule_tags", [])
	var ok: bool = float(packet.get("raw_amount", 0.0)) == 4.0
	ok = ok and String(packet.get("damage_origin", "")) == "reaction"
	ok = ok and String(packet.get("damage_type", "")) == "reaction_damage"
	ok = ok and String(packet.get("element", "")) == "ice"
	ok = ok and String(packet.get("reaction_type", "")) == "shatter"
	ok = ok and int(packet.get("reaction_depth", 0)) == 1
	ok = ok and String(packet.get("source_instance_id", "")) == "reaction_builder_base:reaction:shatter:1"
	ok = ok and String(packet.get("reaction_tier", "")) == "major"
	ok = ok and not bool(packet.get("can_crit", true))
	ok = ok and not bool(packet.get("can_trigger_reaction", true))
	ok = ok and tags.has(&"source_tag") and (tags.has("system_reaction") or tags.has(&"system_reaction"))
	return _expect_equal("reaction packet builder contract", 1 if ok else 0, 1)


func _verify_enemy_packet_builder_contract() -> bool:
	var enemy: FormulaNode = FormulaNode.new()
	enemy.enemy_id = &"skeleton_archer"
	enemy.set_meta("enemy_rank", "boss")
	root.add_child(enemy)
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var packet: Dictionary = EnemyDamagePacketBuilderScript.build(enemy, 12, "projectile", &"enemy_projectile", {"target": target})
	var ok: bool = int(packet.get("raw_amount", 0)) == 12
	ok = ok and String(packet.get("damage_origin", "")) == "primary_attack"
	ok = ok and String(packet.get("damage_type", "")) == "direct_physical"
	ok = ok and String(packet.get("source_id", "")) == "boss"
	ok = ok and String(packet.get("source_origin_id", "")) == "skeleton_archer"
	ok = ok and String(packet.get("source_skill_id", "")) == "enemy_projectile"
	ok = ok and String(packet.get("target_id", "")) == str(target.get_instance_id())
	ok = ok and not bool(packet.get("can_crit", true))
	ok = ok and not bool(packet.get("uses_character_damage_multiplier", true))
	return _expect_equal("enemy packet builder contract", 1 if ok else 0, 1)


func _verify_special_packet_builder_contract() -> bool:
	var executor: RefCounted = SkillSpecialRuleExecutorScript.new()
	var direct_packet: Dictionary = executor.call("_build_special_packet", "special_direct", 9, "primary_attack", true)
	var true_packet: Dictionary = executor.call("_build_special_packet", "special_true", 5, "special", false)
	var ok: bool = String(direct_packet.get("damage_origin", "")) == "primary_attack"
	ok = ok and String(direct_packet.get("damage_type", "")) == "area_direct"
	ok = ok and bool(direct_packet.get("can_crit", false))
	ok = ok and bool(direct_packet.get("uses_character_damage_multiplier", false))
	ok = ok and String(true_packet.get("damage_origin", "")) == "special"
	ok = ok and String(true_packet.get("damage_type", "")) == "true_damage"
	ok = ok and bool(true_packet.get("ignore_defense", false))
	ok = ok and bool(true_packet.get("ignore_resistance", false))
	ok = ok and bool(true_packet.get("ignore_vulnerability", false))
	ok = ok and not bool(true_packet.get("can_trigger_reaction", true))
	return _expect_equal("special packet builder contract", 1 if ok else 0, 1)


func _verify_special_damage_rule_handler_contract() -> bool:
	var target: IntentTargetNode = IntentTargetNode.new()
	root.add_child(target)
	var intents: Array[RefCounted] = SpecialDamageRuleHandlerScript.direct_hit_extra_explosion_intents({
		"direct_hit_extra_explosion_bonus": 0.5
	}, {
		"target": target
	}, 20)
	var special_packet: Dictionary = SpecialDamageRuleHandlerScript.build_special_packet("handler_special", 4, "special", false)
	var area_target: Node2D = Node2D.new()
	area_target.global_position = Vector2(32, 16)
	root.add_child(area_target)
	var area: Node2D = SpecialDamageRuleHandlerScript.spawn_ground_fire_or_lava({
		"player_lava_on_nearby_fireball_hit": {"duration": 0.2, "tick_interval": 0.1, "damage_from_fireball_base": 0.5},
		"merge_lava_zones": {"enabled": false}
	}, {
		"parent": root,
		"target": area_target,
		"target_group": &"enemies"
	}, 20)
	var ok: bool = intents.size() == 1
	ok = ok and int(intents[0].get("packet").get("raw_amount", 0)) == 10
	ok = ok and str(intents[0].get("damage_type")) == "area_direct"
	ok = ok and str(special_packet.get("damage_origin", "")) == "special"
	ok = ok and str(special_packet.get("damage_type", "")) == "true_damage"
	ok = ok and area != null
	ok = ok and bool(area.get_meta("fireball_lava_zone", false))
	return _expect_equal("special damage rule handler contract", 1 if ok else 0, 1)


func _verify_combat_object_packet_builder_contract() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	var projectile_packet: Dictionary = DamagePacketBuilderScript.from_combat_object_hit({
		"template": {},
		"target": target,
		"amount": 6,
		"source_type": "projectile",
		"source_id": &"legacy_projectile",
		"source_instance_id": "projectile_instance",
		"default_damage_origin": "primary_attack",
		"default_damage_type": &"direct_physical"
	})
	var area_packet: Dictionary = DamagePacketBuilderScript.from_combat_object_hit({
		"template": {},
		"target": target,
		"amount": 3,
		"source_type": "area",
		"source_id": &"legacy_area",
		"source_instance_id": "area_instance",
		"default_damage_origin": "field",
		"default_damage_type": &"area_direct"
	})
	var damage_area_packet: Dictionary = DamagePacketBuilderScript.from_combat_object_hit({
		"template": {},
		"target": target,
		"amount": 4,
		"source_type": "area",
		"source_id": &"enemy_area",
		"source_instance_id": "damage_area_instance",
		"default_damage_origin": "field",
		"default_damage_type": &"area_direct",
		"can_trigger_reaction": false,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"overwrite_amount": false
	})
	var template_packet: Dictionary = DamagePacketBuilderScript.from_combat_object_hit({
		"template": {
			"raw_amount": 8,
			"amount": 8,
			"damage_origin": "status_dot",
			"damage_type": &"status_dot",
			"element": &"poison",
			"source_instance_id": "template_source"
		},
		"target": target,
		"amount": 2,
		"source_type": "area",
		"source_id": &"template_area",
		"default_damage_origin": "field",
		"default_damage_type": &"area_direct"
	})
	var ok: bool = String(projectile_packet.get("damage_origin", "")) == "primary_attack"
	ok = ok and String(projectile_packet.get("damage_type", "")) == "direct_physical"
	ok = ok and String(projectile_packet.get("source_instance_id", "")) == "projectile_instance"
	ok = ok and String(projectile_packet.get("target_id", "")) == str(target.get_instance_id())
	ok = ok and String(area_packet.get("damage_origin", "")) == "field"
	ok = ok and String(area_packet.get("damage_type", "")) == "area_direct"
	ok = ok and not bool(area_packet.get("can_crit", true))
	ok = ok and not bool(damage_area_packet.get("can_trigger_reaction", true))
	ok = ok and not bool(damage_area_packet.get("uses_character_damage_multiplier", true))
	ok = ok and not bool(damage_area_packet.get("uses_skill_level_coefficient", true))
	ok = ok and String(template_packet.get("damage_origin", "")) == "status_dot"
	ok = ok and String(template_packet.get("damage_type", "")) == "status_dot"
	ok = ok and String(template_packet.get("element", "")) == "poison"
	ok = ok and String(template_packet.get("source_instance_id", "")) == "template_source"
	ok = ok and int(template_packet.get("amount", 0)) == 2
	return _expect_equal("combat object packet builder contract", 1 if ok else 0, 1)


func _verify_source_identity_helpers() -> bool:
	var owner: FormulaNode = FormulaNode.new()
	root.add_child(owner)
	var projectile_id: String = DamageSourceIdentityScript.for_projectile("fireball:7", 2, &"spark")
	var area_id: String = DamageSourceIdentityScript.for_area("fireball:7", "area", &"burn_zone")
	var orbit_id: String = DamageSourceIdentityScript.for_orbit(owner, &"blade_orbit", &"blade")
	var reaction_id: String = DamageSourceIdentityScript.for_reaction("fireball:7:projectile:spark:2", "overload", 1)
	var status_id: String = DamageSourceIdentityScript.for_status_dot(owner, &"poison", "caster:1")
	var ok: bool = projectile_id == "fireball:7:projectile:spark:2"
	ok = ok and area_id == "fireball:7:area:burn_zone"
	ok = ok and orbit_id == "%s:orbit:blade_orbit:blade" % str(owner.get_instance_id())
	ok = ok and reaction_id == "fireball:7:projectile:spark:2:reaction:overload:1"
	ok = ok and status_id == "%s:poison:caster:1" % str(owner.get_instance_id())
	return _expect_equal("source identity helpers", 1 if ok else 0, 1)


func _verify_combat_object_template_source_stabilized() -> bool:
	var area: AreaEffect = AreaEffectScript.new()
	root.add_child(area)
	area.setup({
		"source_id": &"manual_zone",
		"visual_style": "poison_zone",
		"damage_packet": {
			"damage_origin": "field",
			"damage_type": &"status_dot",
			"element": &"poison",
			"source_skill_id": &"manual_zone"
		}
	})
	var packet: Dictionary = area.damage_packet
	var ok: bool = String(packet.get("source_instance_id", "")) == str(area.get_instance_id())
	ok = ok and String(packet.get("source_type", "")) == "area"
	ok = ok and String(packet.get("source_skill_id", "")) == "manual_zone"
	ok = ok and packet.has("source_origin_id")
	return _expect_equal("combat object template source stabilized", 1 if ok else 0, 1)


func _verify_fractional_pool_identity_includes_element() -> bool:
	var target: FormulaNode = FormulaNode.new()
	root.add_child(target)
	DamageRoundingServiceScript.clear_target(target)
	var poison_packet: Dictionary = {
		"raw_amount": 0.6,
		"amount": 0.6,
		"damage_origin": "status_dot",
		"damage_type": &"status_dot",
		"element": &"poison",
		"source_skill_id": &"identity_dot",
		"source_origin_id": &"",
		"source_instance_id": "shared_dot_source",
		"ignore_defense": true,
		"ignore_resistance": true,
		"ignore_vulnerability": true,
		"uses_character_damage_multiplier": false,
		"can_crit": false
	}
	var fire_packet: Dictionary = poison_packet.duplicate(true)
	fire_packet["element"] = &"fire"
	var first_poison: Dictionary = DamageSystemScript.calculate(poison_packet, target)
	var first_fire: Dictionary = DamageSystemScript.calculate(fire_packet, target)
	var second_poison: Dictionary = DamageSystemScript.calculate(poison_packet, target)
	DamageRoundingServiceScript.clear_target(target)
	var ok: bool = int(first_poison.get("amount", -1)) == 0
	ok = ok and int(first_fire.get("amount", -1)) == 0
	ok = ok and int(second_poison.get("amount", -1)) == 1
	return _expect_equal("fractional pool identity includes element", 1 if ok else 0, 1)


func _verify_status_effect_action_source_identity() -> bool:
	var target: IntentTargetNode = IntentTargetNode.new()
	root.add_child(target)
	var manager: Node = TestStatusEffectManager.new()
	target.add_child(manager)
	var status: Dictionary = {
		"id": &"burn",
		"source_origin_id": &"mage",
		"source_skill_id": &"fireball",
		"source_instance_id": "fireball:projectile:0:burn"
	}
	var context: Dictionary = manager.call("_build_status_event_context", &"burn", status)
	var executor: RefCounted = SkillActionExecutorScript.new()
	executor.call("execute_actions", [{
		"type": "deal_damage",
		"params": {
			"amount": 1,
			"damage_origin": "status_dot",
			"damage_type": "status_dot",
			"element": "fire",
			"uses_skill_level_coefficient": false
		}
	}], context)
	var packet: Dictionary = target.last_damage_packet if target.last_damage_packet is Dictionary else {}
	var ok: bool = String(packet.get("source_origin_id", "")) == "mage"
	ok = ok and String(packet.get("source_skill_id", "")) == "fireball"
	ok = ok and String(packet.get("source_instance_id", "")) == "fireball:projectile:0:burn"
	return _expect_equal("status effect action source identity", 1 if ok else 0, 1)


func _expect_equal(label: String, actual: int, expected: int) -> bool:
	if actual == expected:
		print("[DamageFormula] OK %s = %d" % [label, actual])
		return true
	push_error("[DamageFormula] FAIL %s actual=%d expected=%d" % [label, actual, expected])
	return false
