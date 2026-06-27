const path = require("path");
const { readJsonFile, readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");
const skillsPath = path.join(root, "data", "skills.json");
const runtimeFamiliesPath = path.join(root, "docs", "skills", "runtime_families.md");
const actionExecutorPath = path.join(root, "scripts", "skills", "skill_action_executor.gd");
const fireRuntimePath = path.join(root, "scripts", "skills", "fire_skill_runtime.gd");
const playerHealthStagePath = path.join(root, "scripts", "combat", "application_stages", "player_health_application_stage.gd");

const FIRST_BATCH_RUNTIME_RULE_NAMES = new Set([
  "fire_stack_mark",
  "fire_kill_spawn",
  "fire_cooldown_refund",
  "fire_damage_taken_retaliation",
  "fire_shield",
  "fire_empower_next",
  "fire_delayed_echo",
  "fire_revive_once",
  "fire_skill_count_scaling",
  "fire_status_expire_damage",
  "fire_projectile_split",
  "fire_burning_bonus",
  "fire_high_health_bonus",
]);

const CURRENT_DATA_RULE_VALUES = new Set([
  "black_sun_fire_spreads_blackflame_on_kill",
  "bonus_fire_damage_against_high_health_ratio_targets",
  "burning_targets_lose_armor",
  "chance_convert_burn_to_blackflame",
  "chance_reignite_after_burn_expires",
  "chance_return_fire_projectile_at_max_range",
  "chance_spawn_weak_flamelet_on_fire_projectile_hit",
  "charge_then_empower_next_fire",
  "delayed_fire_reckoning",
  "grant_shield_from_fire_hits",
  "grant_shield_on_low_health",
  "nearby_fire_aura_and_player_damage_reduction",
  "on_fire_related_kill",
  "on_player_damage_taken",
  "reduce_fire_cooldown_near_burning_enemies",
  "reduce_fire_cooldown_on_burning_kill",
  "revive_once_per_run",
  "scale_with_owned_fire_skill_count",
  "splash_fire_damage_on_fire_critical_hit",
  "stack_mark_then_consume",
]);

const CURRENT_DATA_RULE_PARAMETER_KEYS = new Set([
  "actions",
  "armor_multiplier_add",
  "aura_damage",
  "aura_radius",
  "aura_tick_interval",
  "blackflame_damage_multiplier",
  "blackflame_duration_multiplier",
  "boss_conversion_chance_multiplier",
  "boss_effect_multiplier",
  "boss_multiplier",
  "cap_fire_skill_count",
  "chance",
  "charges_required",
  "consume_damage",
  "consume_effect",
  "conversion_chance",
  "cooldown",
  "damage",
  "damage_multiplier",
  "damage_multiplier_add",
  "damage_taken_multiplier_add",
  "delay_seconds",
  "duration",
  "effect",
  "element",
  "explosion_damage",
  "explosion_radius",
  "first_version_simplification",
  "flamelet_damage_multiplier",
  "flamelet_projectile_id",
  "flamelet_speed",
  "internal_cooldown",
  "max_extra_projectiles_per_hit",
  "max_reignites_per_target",
  "max_returns",
  "max_spread_targets",
  "max_stacks",
  "max_targets_per_tick",
  "min_health_ratio",
  "non_fire_offer_weight_multiplier",
  "per_fire_skill_damage_multiplier_add",
  "per_fire_skill_radius_multiplier_add",
  "per_fire_skill_trigger_chance_add",
  "post_revive_fire_damage_multiplier_add",
  "projectile_count_add",
  "radius",
  "radius_multiplier_add",
  "reduction_seconds",
  "refresh_on_fire_hit",
  "reignite_duration_multiplier",
  "retaliate_damage",
  "return_chance",
  "return_damage_multiplier",
  "revive_health_ratio",
  "shield_amount",
  "source_damage_portion",
  "splash_damage_multiplier",
  "splash_radius",
  "spread_damage_multiplier",
  "spread_radius",
  "stack_id",
  "stacks_required",
  "trigger_scope",
]);

const FAMILY_TO_FIRST_BATCH_RULE_NAME = {
  cooldown_reducer: "fire_cooldown_refund",
  damage_taken_trigger: "fire_damage_taken_retaliation",
  delayed_damage: "fire_delayed_echo",
  empower_next_fire: "fire_empower_next",
  fire_skill_count_scaling: "fire_skill_count_scaling",
  kill_trigger: "fire_kill_spawn",
  revive_once: "fire_revive_once",
  shield: "fire_shield",
  stack_mark: "fire_stack_mark",
};

function readText(filePath) {
  return readTextFile(filePath);
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function asObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function isNonEmptyObject(value) {
  return Object.keys(asObject(value)).length > 0;
}

function isNonEmptyPayload(value) {
  if (Array.isArray(value)) return value.length > 0;
  return isNonEmptyObject(value);
}

function hasEventActions(skill) {
  return asArray(skill.events).some((event) => asArray(event && event.actions).length > 0);
}

function hasDocumentedHeading(markdown, identifier) {
  if (!identifier) return false;
  const escaped = identifier.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const heading = new RegExp(`^#{2,6}[ \\t]+(?:\`${escaped}\`|${escaped})(?:[ \\t#]|$)`, "m");
  return heading.test(markdown);
}

function hasDocumentedRuleIdentifier(markdown, identifier) {
  if (!identifier) return false;
  const escaped = identifier.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const backticked = new RegExp(`\`${escaped}\``);
  return hasDocumentedHeading(markdown, identifier) || backticked.test(markdown);
}

function validateRuntimeRules(skill, markdown) {
  const runtimeRules = asObject(skill.runtime_rules);
  if (!isNonEmptyObject(runtimeRules)) return [];

  const errors = [];
  const skillId = String(skill.id || "<missing id>");
  const configuredRule = String(runtimeRules.rule || "").trim();
  const parameterKeys = Object.keys(runtimeRules).filter((key) => key !== "rule");

  if (configuredRule !== "") {
    const ruleAllowed =
      FIRST_BATCH_RUNTIME_RULE_NAMES.has(configuredRule) ||
      CURRENT_DATA_RULE_VALUES.has(configuredRule) ||
      hasDocumentedRuleIdentifier(markdown, configuredRule);
    if (!ruleAllowed) {
      errors.push(`${skillId}: runtime_rules.rule "${configuredRule}" is not in the first supported batch and is not documented`);
    }
  } else if (parameterKeys.length === 0) {
    const familyRuleName = FAMILY_TO_FIRST_BATCH_RULE_NAME[String(skill.runtime_family || "")];
    if (!FIRST_BATCH_RUNTIME_RULE_NAMES.has(familyRuleName)) {
      errors.push(`${skillId}: runtime_rules has no explicit rule and runtime_family "${String(skill.runtime_family || "")}" has no legacy fallback`);
    }
  }

  for (const key of parameterKeys) {
    const keyAllowed =
      FIRST_BATCH_RUNTIME_RULE_NAMES.has(key) ||
      CURRENT_DATA_RULE_PARAMETER_KEYS.has(key) ||
      hasDocumentedRuleIdentifier(markdown, key);
    if (!keyAllowed) {
      errors.push(`${skillId}: runtime_rules key "${key}" is not in the first supported batch and is not documented`);
    }
  }

  return errors;
}

function collectSkills(document) {
  return asArray(document.skills).filter(
    (skill) =>
      skill &&
      (skill.school === "fire" || skill.fusion_school === "fire" || asArray(skill.tags).includes("fire")) &&
      (skill.offer_rule || skill.offer_in_upgrade_pool !== false)
  );
}

function validateDocument(document, markdown) {
  const errors = [];
  const executor = readText(actionExecutorPath);
  const fireRuntime = readText(fireRuntimePath);
  const playerHealthStage = readText(playerHealthStagePath);

  for (const skill of collectSkills(document)) {
    const skillId = String(skill.id || "<missing id>");
    const runtimeFamily = String(skill.runtime_family || "");
    const usesNewSchema = isNonEmptyObject(skill.offer_rule) || asArray(skill.trigger_rules).length > 0 || asArray(skill.effects).length > 0;

    if (!usesNewSchema && runtimeFamily === "") {
      errors.push(`${skillId}: missing runtime_family`);
    } else if (runtimeFamily !== "" && !hasDocumentedHeading(markdown, runtimeFamily)) {
      errors.push(`${skillId}: runtime_family "${runtimeFamily}" is not documented in docs/skills/runtime_families.md`);
    }

    if (!usesNewSchema && !hasEventActions(skill) && !isNonEmptyPayload(skill.skill_modifiers) && !isNonEmptyObject(skill.runtime_rules)) {
      errors.push(`${skillId}: has no effective runtime payload (events.actions, skill_modifiers, or runtime_rules)`);
    }

    if (!usesNewSchema && (!skill.particle || typeof skill.particle.profile !== "string" || skill.particle.profile.trim() === "")) {
      errors.push(`${skillId}: missing particle.profile`);
    }

    errors.push(...validateRuntimeRules(skill, markdown));
  }

  errors.push(...validateFireActionTypes(document, executor));
  errors.push(...validateExecutorRuntimeSafety(executor));
  errors.push(...validateFireRuntimeConsumers(fireRuntime));
  errors.push(...validatePlayerReviveHealthApplication(playerHealthStage));

  return errors;
}

function collectActionTypesFromActions(actions, result) {
  for (const action of asArray(actions)) {
    if (!isNonEmptyObject(action)) continue;
    const type = String(action.type || "").trim();
    if (type) result.add(type);
    const params = asObject(action.params);
    collectActionTypesFromActions(params.actions, result);
  }
}

function collectFireActionTypes(document) {
  const result = new Set();
  const allFireSkills = [
    ...asArray(document.starting_skills).filter((skill) => skill && skill.god_id === "fire"),
    ...asArray(document.skills).filter((skill) => skill && skill.god_id === "fire"),
  ];
  for (const skill of allFireSkills) {
    for (const event of asArray(skill.events)) {
      collectActionTypesFromActions(event && event.actions, result);
    }
  }
  return [...result].sort();
}

function validateFireActionTypes(document, executor) {
  const errors = [];
  for (const actionType of collectFireActionTypes(document)) {
    if (!executor.includes(`"${actionType}"`)) {
      errors.push(`fire action type "${actionType}" is present in data/skills.json but missing from SkillActionExecutor.execute_action`);
    }
  }
  return errors;
}

function validateExecutorRuntimeSafety(executor) {
  const errors = [];
  const summonBody = extractGdFunctionBody(executor, "func _summon_tick");
  if (!summonBody.includes('damage_params["damage_type"] = "summon_damage"')) {
    errors.push("spawn_summon must default to summon_damage.");
  }
  if (!summonBody.includes('damage_params["damage_origin"] = "special"')) {
    errors.push("spawn_summon summon_damage must use damage_origin special, not primary_attack/skill.");
  }
  if (summonBody.includes('damage_params["damage_origin"] = "skill"')) {
    errors.push("spawn_summon must not use unsupported damage_origin skill.");
  }
  return errors;
}

function validateFireRuntimeConsumers(fireRuntime) {
  const errors = [];
  if (/fire_runtime_blackflame_chance|fire_runtime_armor_multiplier_add/.test(fireRuntime)) {
    errors.push("FireSkillRuntime must not implement blackflame/armor melting as target meta-only writes.");
  }
  if (!fireRuntime.includes("_apply_blackflame_conversion") || !fireRuntime.includes('"status_id": "blackfire"')) {
    errors.push("chance_convert_burn_to_blackflame must apply a real blackfire status.");
  }
  if (!fireRuntime.includes("_apply_armor_melting_burn") || !fireRuntime.includes("fire_damage_taken_multiplier_add_per_stack")) {
    errors.push("burning_targets_lose_armor must feed the existing status vulnerability damage path.");
  }
  if (!fireRuntime.includes("set_run_modifier_source") || !fireRuntime.includes("post_revive_fire_damage_multiplier_add")) {
    errors.push("post_revive_fire_damage_multiplier_add must be written to a player/SkillManager-visible modifier source.");
  }
  const fireContextBody = extractGdFunctionBody(fireRuntime, "static func _is_fire_context");
  if (!fireContextBody.includes("source_packet") || !fireContextBody.includes("damage_result")) {
    errors.push("_is_fire_context must inspect source_packet and damage_result for player damage/source context.");
  }
  if (!fireContextBody.includes("on_player_damaged")) {
    errors.push("_is_fire_context must not block on_player_damaged survival rules behind fire-only context.");
  }
  for (const functionName of ["_apply_charge_empower", "_apply_kill_trigger", "_apply_high_health_bonus"]) {
    const body = extractGdFunctionBody(fireRuntime, `static func ${functionName}`);
    if (body.includes("_add_runtime_modifier")) {
      errors.push(`${functionName} must use namespaced _set_runtime_modifier or a capped/consumed modifier, not unbounded _add_runtime_modifier.`);
    }
  }
  const shieldBody = extractGdFunctionBody(fireRuntime, "static func _grant_fire_passive_shield");
  if (!shieldBody.includes("fire_passive_shield_expires_at") || !shieldBody.includes("shield_cap") || !shieldBody.includes("mini(")) {
    errors.push("_grant_fire_passive_shield must clear expired shield and cap refreshed shield instead of reviving/stacking without limit.");
  }
  return errors;
}

function validatePlayerReviveHealthApplication(playerHealthStage) {
  const errors = [];
  const body = extractGdFunctionBody(playerHealthStage, "func apply_with_host");
  if (!body.includes("_record_damage_taken")) {
    errors.push("PlayerHealthApplicationStage must record damage before death resolution.");
  }
  const recordIndex = body.indexOf("_record_damage_taken");
  const rereadIndex = body.indexOf("final_health", recordIndex);
  const diedIndex = body.indexOf('emit_signal("died")');
  if (rereadIndex < 0 || (diedIndex >= 0 && rereadIndex > diedIndex)) {
    errors.push("PlayerHealthApplicationStage must re-read player.current_health after _record_damage_taken before emitting died.");
  }
  if (!/if\s+final_health\s*==\s*0/.test(body)) {
    errors.push("PlayerHealthApplicationStage death branch must use final_health after revive/passive processing.");
  }
  if (!body.includes('emit_signal("health_changed", final_health')) {
    errors.push("PlayerHealthApplicationStage health_changed must emit final health after passive processing.");
  }
  return errors;
}

function extractGdFunctionBody(text, signaturePrefix) {
  const signatureIndex = text.indexOf(signaturePrefix);
  if (signatureIndex < 0) return "";
  const bodyStart = text.indexOf("\n", signatureIndex);
  if (bodyStart < 0) return "";
  const rest = text.slice(bodyStart + 1);
  const next = rest.search(/^(?:static\s+)?func\s+/m);
  return next >= 0 ? rest.slice(0, next) : rest;
}

function main() {
  const document = readJsonFile(skillsPath);
  const markdown = readText(runtimeFamiliesPath);
  const errors = validateDocument(document, markdown);

  if (errors.length > 0) {
    console.error("[verify_skill_runtime_no_dead_cards] FAIL");
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exit(1);
  }

  console.log("[verify_skill_runtime_no_dead_cards] PASS");
}

if (require.main === module) {
  main();
}

module.exports = {
  validateDocument,
};
