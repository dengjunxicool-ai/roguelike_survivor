const fs = require("fs");
const path = require("path");
const { readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function main() {
  const helperPath = "scripts/combat/damage_target_runtime_modifiers.gd";
  const mitigationPath = "scripts/combat/damage_target_mitigation.gd";
  const outputScalingPath = "scripts/combat/damage_output_scaling.gd";
  const criticalResolverPath = "scripts/combat/damage_critical_resolver.gd";
  const specialFinalResolverPath = "scripts/combat/damage_special_final_resolver.gd";
  const playerIncomingResolverPath = "scripts/combat/damage_player_incoming_resolver.gd";
  const defenseResolverPath = "scripts/combat/damage_defense_resolver.gd";
  const truePercentResolverPath = "scripts/combat/damage_true_percent_resolver.gd";
  assert(fs.existsSync(path.join(root, helperPath)), `${helperPath} must exist`);
  assert(fs.existsSync(path.join(root, mitigationPath)), `${mitigationPath} must exist`);
  assert(fs.existsSync(path.join(root, outputScalingPath)), `${outputScalingPath} must exist`);
  assert(fs.existsSync(path.join(root, criticalResolverPath)), `${criticalResolverPath} must exist`);
  assert(fs.existsSync(path.join(root, specialFinalResolverPath)), `${specialFinalResolverPath} must exist`);
  assert(fs.existsSync(path.join(root, playerIncomingResolverPath)), `${playerIncomingResolverPath} must exist`);
  assert(fs.existsSync(path.join(root, defenseResolverPath)), `${defenseResolverPath} must exist`);
  assert(fs.existsSync(path.join(root, truePercentResolverPath)), `${truePercentResolverPath} must exist`);

  const helper = read(helperPath);
  for (const snippet of [
    "class_name DamageTargetRuntimeModifiers",
    "static func acid_boss_defense",
    "static func protective_lava_player_multiplier",
    "static func holy_shield_player_multiplier",
    "static func cross_relic_field_player_multiplier",
    "static func toxic_vial_enemy_damage_multiplier",
    "static func fire_oil_smoke_enemy_damage_multiplier",
  ]) {
    assert(helper.includes(snippet), `helper must expose ${snippet}`);
  }

  const mitigation = read(mitigationPath);
  for (const snippet of [
    "class_name DamageTargetMitigation",
    "static func resistance_multiplier",
    "static func resistance_multiplier_for_context",
    "static func vulnerability_total",
    "static func vulnerability_total_for_context",
    "static func target_class_origin_modifier",
    "static func target_class_origin_modifier_for_context",
    "static func apply_resistance_stage",
    "static func apply_vulnerability_stage",
  ]) {
    assert(mitigation.includes(snippet), `mitigation helper must expose ${snippet}`);
  }

  const outputScaling = read(outputScalingPath);
  for (const snippet of [
    "class_name DamageOutputScaling",
    "static func character_damage_multiplier",
    "static func character_damage_multiplier_for_context",
    "static func skill_level_coefficient",
    "static func skill_level_coefficient_for_context",
    "static func origin_bonus_total",
    "static func origin_bonus_total_for_context",
    "static func element_bonus_total",
    "static func element_bonus_total_for_context",
    "static func enemy_type_bonus_total",
    "static func enemy_type_bonus_total_for_context",
  ]) {
    assert(outputScaling.includes(snippet), `output scaling helper must expose ${snippet}`);
  }

  const criticalResolver = read(criticalResolverPath);
  for (const snippet of [
    "class_name DamageCriticalResolver",
    "static func apply_critical_stage",
    "static func can_crit",
    "static func can_crit_for_context",
  ]) {
    assert(criticalResolver.includes(snippet), `critical resolver must expose ${snippet}`);
  }

  const specialFinalResolver = read(specialFinalResolverPath);
  for (const snippet of [
    "class_name DamageSpecialFinalResolver",
    "ALLOWED_SPECIAL_MODIFIER_SOURCES",
    "static func apply_special_stage",
    "static func special_final_modifier",
    "static func special_final_modifier_for_context",
  ]) {
    assert(specialFinalResolver.includes(snippet), `special final resolver must expose ${snippet}`);
  }

  const playerIncomingResolver = read(playerIncomingResolverPath);
  for (const snippet of [
    "class_name DamagePlayerIncomingResolver",
    "PLAYER_DEFENSE_REDUCTION_CAP",
    "static func apply_player_incoming_modifier_stage",
    "static func apply_player_defense_stage",
    "static func apply_player_reduction_stage",
    "static func apply_player_damage_taken_stage",
    "static func apply_player_rounding_stage",
    "DamageTargetRuntimeModifiersScript.protective_lava_player_multiplier",
    "DamageTargetRuntimeModifiersScript.holy_shield_player_multiplier",
    "DamageTargetRuntimeModifiersScript.cross_relic_field_player_multiplier",
    "DamageTargetRuntimeModifiersScript.toxic_vial_enemy_damage_multiplier",
    "DamageTargetRuntimeModifiersScript.fire_oil_smoke_enemy_damage_multiplier",
  ]) {
    assert(playerIncomingResolver.includes(snippet), `player incoming resolver must expose ${snippet}`);
  }

  const defenseResolver = read(defenseResolverPath);
  for (const snippet of [
    "class_name DamageDefenseResolver",
    "DEFAULT_DEFENSE_REDUCTION_CAP",
    "static func apply_defense_stage",
    "static func apply_defense",
    "static func apply_defense_for_context",
    "static func defense_rate",
    "ReactionLimiterScript.get_defense_reduction_cap",
    "ReactionLimiterScript.get_defense_reduction_cap_for_context",
    "DamageTargetRuntimeModifiersScript.acid_boss_defense",
  ]) {
    assert(defenseResolver.includes(snippet), `defense resolver must expose ${snippet}`);
  }

  const truePercentResolver = read(truePercentResolverPath);
  for (const snippet of [
    "class_name DamageTruePercentResolver",
    "static func resolve_true_percent",
    "static func apply_true_percent_stage",
    "static func apply_true_percent_cap_stage",
    "percent_of_max_health",
    "true_percent_damage_cap",
  ]) {
    assert(truePercentResolver.includes(snippet), `true percent resolver must expose ${snippet}`);
  }

  const truePercentStage = read("scripts/combat/stages/true_percent_damage_stage.gd");
  assert(truePercentStage.includes("DamageTruePercentResolverScript"), "TruePercentDamageStage must preload true percent resolver");
  assert(truePercentStage.includes("DamageTruePercentResolverScript.resolve_true_percent"), "TruePercentDamageStage must resolve percent through resolver");
  assert(truePercentStage.includes("DamageTruePercentResolverScript.apply_true_percent_stage"), "TruePercentDamageStage must apply damage through resolver");
  assert(!truePercentStage.includes('host.call("_resolve_true_percent"'), "TruePercentDamageStage must not call DamageSystem _resolve_true_percent through host");
  assert(!truePercentStage.includes('host.call("_apply_true_percent_stage"'), "TruePercentDamageStage must not call DamageSystem _apply_true_percent_stage through host");

  const truePercentCapStage = read("scripts/combat/stages/true_percent_cap_stage.gd");
  assert(truePercentCapStage.includes("DamageTruePercentResolverScript"), "TruePercentCapStage must preload true percent resolver");
  assert(truePercentCapStage.includes("DamageTruePercentResolverScript.apply_true_percent_cap_stage"), "TruePercentCapStage must apply cap through resolver");
  assert(!truePercentCapStage.includes('host.call("_apply_true_percent_cap_stage"'), "TruePercentCapStage must not call DamageSystem _apply_true_percent_cap_stage through host");

  const damageSystem = read("scripts/combat/damage_system.gd");
  assert(damageSystem.includes("DamageTargetMitigationScript"), "DamageSystem must preload target mitigation helper");
  assert(damageSystem.includes("DamageOutputScalingScript"), "DamageSystem must preload output scaling helper");
  assert(damageSystem.includes("DamageCriticalResolverScript"), "DamageSystem must preload critical resolver helper");
  assert(damageSystem.includes("DamageSpecialFinalResolverScript"), "DamageSystem must preload special final resolver helper");
  assert(damageSystem.includes("DamagePlayerIncomingResolverScript"), "DamageSystem must preload player incoming resolver helper");
  assert(damageSystem.includes("DamageDefenseResolverScript"), "DamageSystem must preload defense resolver helper");
  assert(damageSystem.includes("DamageTruePercentResolverScript"), "DamageSystem must preload true percent resolver helper");
  for (const removed of [
    "static func _apply_acid_boss_defense_reduction",
    "static func _get_protective_lava_player_multiplier",
    "static func _get_holy_shield_player_multiplier",
    "static func _get_cross_relic_field_player_multiplier",
    "static func _get_toxic_vial_enemy_damage_multiplier",
    "static func _get_fire_oil_smoke_enemy_damage_multiplier",
  ]) {
    assert(!damageSystem.includes(removed), `DamageSystem should not own ${removed}`);
  }
  assert(!damageSystem.includes("randf() < crit_chance"), "DamageSystem should not own critical roll logic");
  assert(!damageSystem.includes("ALLOWED_SPECIAL_MODIFIER_SOURCES"), "DamageSystem should not own special final source whitelist");
  assert(!damageSystem.includes("ReactionLimiterScript.get_special_final_modifier"), "DamageSystem should not own special final limiter lookup");
  assert(!damageSystem.includes("PLAYER_DEFENSE_REDUCTION_CAP"), "DamageSystem should not own player defense cap");
  assert(!damageSystem.includes("wave_damage_multiplier"), "DamageSystem should not own player incoming multiplier logic");
  assert(!damageSystem.includes("DEFAULT_DEFENSE_REDUCTION_CAP"), "DamageSystem should not own enemy defense cap");
  assert(!damageSystem.includes("ReactionLimiterScript.get_defense_reduction_cap"), "DamageSystem should not own defense limiter lookup");
  assert(!damageSystem.includes("DamageTargetRuntimeModifiersScript.acid_boss_defense"), "DamageSystem should not own acid boss defense modifier");
  assert(!damageSystem.includes("percent_of_max_health"), "DamageSystem should not own true percent parsing");
  assert(!damageSystem.includes("true_percent_damage_cap"), "DamageSystem should not own true percent cap logic");

  assert(damageSystem.includes("DamageTargetMitigationScript.resistance_multiplier"), "DamageSystem must delegate resistance");
  assert(damageSystem.includes("DamageTargetMitigationScript.vulnerability_total"), "DamageSystem must delegate vulnerability");
  assert(damageSystem.includes("DamageTargetMitigationScript.target_class_origin_modifier"), "DamageSystem must delegate target origin modifier");
  assert(damageSystem.includes("DamageCriticalResolverScript.apply_critical_stage"), "DamageSystem must delegate critical stage");
  assert(damageSystem.includes("DamageSpecialFinalResolverScript.apply_special_stage"), "DamageSystem must delegate special final stage");
  assert(damageSystem.includes("DamagePlayerIncomingResolverScript.apply_player_incoming_modifier_stage"), "DamageSystem must delegate player incoming stage");
  assert(damageSystem.includes("DamageDefenseResolverScript.apply_defense_stage"), "DamageSystem must delegate defense stage");
  assert(damageSystem.includes("DamageTruePercentResolverScript.resolve_true_percent"), "DamageSystem must delegate true percent parsing");
  for (const wrapper of [
    ["_get_resistance_multiplier", "DamageTargetMitigationScript.resistance_multiplier"],
    ["_get_resistance_multiplier_for_context", "DamageTargetMitigationScript.resistance_multiplier_for_context"],
    ["_get_vulnerability_total", "DamageTargetMitigationScript.vulnerability_total"],
    ["_get_vulnerability_total_for_context", "DamageTargetMitigationScript.vulnerability_total_for_context"],
    ["_get_target_class_origin_modifier", "DamageTargetMitigationScript.target_class_origin_modifier"],
    ["_get_target_class_origin_modifier_for_context", "DamageTargetMitigationScript.target_class_origin_modifier_for_context"],
    ["_apply_resistance_stage", "DamageTargetMitigationScript.apply_resistance_stage"],
    ["_apply_vulnerability_stage", "DamageTargetMitigationScript.apply_vulnerability_stage"],
    ["_get_character_damage_multiplier", "DamageOutputScalingScript.character_damage_multiplier"],
    ["_get_character_damage_multiplier_for_context", "DamageOutputScalingScript.character_damage_multiplier_for_context"],
    ["_get_skill_level_coefficient", "DamageOutputScalingScript.skill_level_coefficient"],
    ["_get_skill_level_coefficient_for_context", "DamageOutputScalingScript.skill_level_coefficient_for_context"],
    ["_get_origin_bonus_total", "DamageOutputScalingScript.origin_bonus_total"],
    ["_get_origin_bonus_total_for_context", "DamageOutputScalingScript.origin_bonus_total_for_context"],
    ["_get_element_bonus_total", "DamageOutputScalingScript.element_bonus_total"],
    ["_get_element_bonus_total_for_context", "DamageOutputScalingScript.element_bonus_total_for_context"],
    ["_get_enemy_type_bonus_total", "DamageOutputScalingScript.enemy_type_bonus_total"],
    ["_get_enemy_type_bonus_total_for_context", "DamageOutputScalingScript.enemy_type_bonus_total_for_context"],
    ["_apply_critical_stage", "DamageCriticalResolverScript.apply_critical_stage"],
    ["_can_crit", "DamageCriticalResolverScript.can_crit"],
    ["_can_crit_for_context", "DamageCriticalResolverScript.can_crit_for_context"],
    ["_apply_special_stage", "DamageSpecialFinalResolverScript.apply_special_stage"],
    ["_get_special_final_modifier", "DamageSpecialFinalResolverScript.special_final_modifier"],
    ["_get_special_final_modifier_for_context", "DamageSpecialFinalResolverScript.special_final_modifier_for_context"],
    ["_apply_player_incoming_modifier_stage", "DamagePlayerIncomingResolverScript.apply_player_incoming_modifier_stage"],
    ["_apply_player_defense_stage", "DamagePlayerIncomingResolverScript.apply_player_defense_stage"],
    ["_apply_player_reduction_stage", "DamagePlayerIncomingResolverScript.apply_player_reduction_stage"],
    ["_apply_player_damage_taken_stage", "DamagePlayerIncomingResolverScript.apply_player_damage_taken_stage"],
    ["_apply_player_rounding_stage", "DamagePlayerIncomingResolverScript.apply_player_rounding_stage"],
    ["_apply_defense_stage", "DamageDefenseResolverScript.apply_defense_stage"],
    ["_apply_defense", "DamageDefenseResolverScript.apply_defense"],
    ["_apply_defense_for_context", "DamageDefenseResolverScript.apply_defense_for_context"],
    ["_get_defense_rate", "DamageDefenseResolverScript.defense_rate"],
    ["_resolve_true_percent", "DamageTruePercentResolverScript.resolve_true_percent"],
    ["_apply_true_percent_stage", "DamageTruePercentResolverScript.apply_true_percent_stage"],
    ["_apply_true_percent_cap_stage", "DamageTruePercentResolverScript.apply_true_percent_cap_stage"],
  ]) {
    const [name, delegate] = wrapper;
    const pattern = new RegExp(`static func ${name}[\\s\\S]{0,300}${delegate.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`);
    assert(pattern.test(damageSystem), `DamageSystem ${name} wrapper must delegate to ${delegate}`);
  }

  console.log("Combat structure refactor verified.");
}

main();
