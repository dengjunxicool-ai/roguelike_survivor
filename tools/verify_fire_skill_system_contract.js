const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, ""));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const FIRE_BASE_IDS = [
  "fire_attack_searing",
  "fire_dash_blazing_run",
  "fire_cast_meteor_rain",
  "fire_cast_lava_rift",
  "fire_cast_scorching_vortex",
  "fire_summon_crimson_dragon",
  "fire_summon_ember_fox_pack",
  "fire_passive_burning_focus",
  "fire_passive_overheated_casting",
  "fire_passive_scorched_ground_affinity",
  "fire_power_combustion_chain",
  "fire_power_ember_attachment",
  "fire_power_ignite_core",
  "fire_core_inferno_cycle",
];

const FIRE_FUSION_IDS = [
  "fusion_fire_frost_steam_mist",
  "fusion_fire_frost_shattered_ember",
  "fusion_fire_thunder_plasma_fire_path",
  "fusion_fire_thunder_thunderburn_meteor",
  "fusion_fire_curse_ash_curse_rune",
  "fusion_fire_curse_blackflame_serpents",
  "fusion_fire_holy_holy_flame_absolution",
  "fusion_fire_holy_burning_light_barrier",
  "fusion_fire_chaos_ember_echo",
  "fusion_fire_chaos_molten_split",
  "fusion_frost_fire_crystalized_flame",
  "fusion_frost_fire_frostburn_shards",
  "fusion_thunder_fire_arc_ignition",
  "fusion_thunder_fire_thunderfire_circuit",
  "fusion_curse_fire_ash_soul_pact",
  "fusion_curse_fire_burning_soul_minion",
  "fusion_holy_fire_holy_flame_purification",
  "fusion_holy_fire_solar_hammer",
  "fusion_chaos_fire_riftfire_fork",
  "fusion_chaos_fire_lava_refraction",
];

const REQUIRED_SKILL_FIELDS = [
  "id",
  "name",
  "school",
  "fusion_school",
  "type",
  "rarity",
  "max_level",
  "exclusive_group",
  "tags",
  "mechanic_family",
  "offer_rule",
  "trigger_rules",
  "effects",
];

const ALLOWED_TYPES = new Set(["attack", "dash", "cast", "summon", "passive", "power", "core", "fusion"]);
const ALLOWED_SCHOOLS = new Set(["fire", "frost", "thunder", "curse", "holy", "chaos"]);
const ALLOWED_RARITIES = new Set(["normal", "rare", "epic", "legendary"]);
const SUPPORTED_TRIGGERS = new Set([
  "attack_hit",
  "dash_start",
  "dash_end",
  "cast_skill",
  "projectile_hit",
  "area_tick",
  "enemy_death",
  "status_applied",
  "status_tick",
  "status_expired",
  "status_max_stack_reached",
  "shield_gained",
  "shield_broken",
  "player_damage_taken",
  "summon_attack_hit",
  "always",
]);
const SUPPORTED_CONDITIONS = new Set([
  "target_has_status",
  "target_has_tag",
  "owner_has_skill",
  "owner_has_relic",
  "skill_has_tag",
  "random_chance",
  "target_hp_below",
  "is_critical_hit",
  "enemy_count_in_radius",
  "always",
  "",
]);
const SUPPORTED_EFFECTS = new Set([
  "damage",
  "apply_status",
  "spawn_area",
  "spawn_projectile",
  "spawn_summon",
  "add_modifier",
  "grant_shield",
  "heal",
  "pull",
  "knockback",
  "repeat_skill",
  "transform_area",
  "transfer_status",
  "consume_status_duration",
  "trigger_overload",
  "shatter_frozen",
  "spawn_projectile_burst",
  "repeat_area_path",
  "spawn_area_from_existing_area",
]);
const OBSOLETE_FIRE_IDS = new Set(["mars_spark_missile", "fire_tornado", "soulburn"]);
const NESTED_EFFECT_ARRAY_FIELDS = new Set([
  "effects",
  "effects_on_tick",
  "effects_on_expire",
  "effects_on_apply",
  "effects_on_remove",
  "effects_on_death",
  "effects_on_status_applied",
  "effects_on_status_tick",
  "effects_on_status_expired",
  "effects_on_status_max_stack_reached",
  "on_hit",
  "on_tick_effects",
  "on_expire",
  "on_apply",
  "on_death",
]);

function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validateEffectArray(effects, skillId, location) {
  assert(Array.isArray(effects), `${skillId} ${location} must be an array`);
  effects.forEach((effect, index) => {
    validateEffect(effect, skillId, `${location}[${index}]`);
  });
}

function validateEffect(effect, skillId, location) {
  assert(isObject(effect), `${skillId} ${location} effect must be an object`);
  assert(SUPPORTED_EFFECTS.has(effect.type), `${skillId} unsupported effect ${effect.type} at ${location}`);
  validateNestedEffectArrays(effect, skillId, location);
}

function validateNestedEffectArrays(value, skillId, location) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => validateNestedEffectArrays(item, skillId, `${location}[${index}]`));
    return;
  }
  if (!isObject(value)) {
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    const childLocation = `${location}.${key}`;
    if (NESTED_EFFECT_ARRAY_FIELDS.has(key)) {
      validateEffectArray(child, skillId, childLocation);
    } else if (key === "conditions") {
      validateConditionArray(child, skillId, childLocation);
    } else if (isObject(child) || Array.isArray(child)) {
      validateNestedEffectArrays(child, skillId, childLocation);
    }
  }
}

function buildExpectedSkillMetadata() {
  assert(FIRE_BASE_IDS.length === 14, `FIRE_BASE_IDS must contain exactly 14 ids, got ${FIRE_BASE_IDS.length}`);
  assert(FIRE_FUSION_IDS.length === 20, `FIRE_FUSION_IDS must contain exactly 20 ids, got ${FIRE_FUSION_IDS.length}`);

  const fireBaseIds = new Set(FIRE_BASE_IDS);
  const fireFusionIds = new Set(FIRE_FUSION_IDS);

  assert(fireBaseIds.size === FIRE_BASE_IDS.length, "FIRE_BASE_IDS must not contain duplicate ids");
  assert(fireFusionIds.size === FIRE_FUSION_IDS.length, "FIRE_FUSION_IDS must not contain duplicate ids");
  for (const id of FIRE_BASE_IDS) {
    assert(!fireFusionIds.has(id), `fire skill id must not be both base and fusion: ${id}`);
  }

  const metadata = new Map();
  for (const id of FIRE_BASE_IDS) {
    metadata.set(id, { school: "fire", fusion_school: null, required_min_skill_count: null });
  }
  for (const id of FIRE_FUSION_IDS) {
    const match = /^fusion_(fire|frost|thunder|curse|holy|chaos)_(fire|frost|thunder|curse|holy|chaos)_/.exec(id);
    assert(match, `fusion skill id must encode school pair: ${id}`);
    const school = match[1];
    const fusionSchool = match[2];
    assert(school !== fusionSchool, `fusion skill id must encode two different schools: ${id}`);
    metadata.set(id, {
      school,
      fusion_school: fusionSchool,
      required_min_skill_count: { [school]: 2, [fusionSchool]: 1 },
    });
  }

  assert(metadata.size === FIRE_BASE_IDS.length + FIRE_FUSION_IDS.length, "expected fire skill metadata must cover every unique id");
  return metadata;
}

function validateOfferRuleArrays(skill) {
  const offerRule = skill.offer_rule;
  if (Object.prototype.hasOwnProperty.call(offerRule, "required_schools")) {
    assert(Array.isArray(offerRule.required_schools), `${skill.id} offer_rule.required_schools must be an array`);
    offerRule.required_schools.forEach((school, index) => {
      assert(typeof school === "string", `${skill.id} offer_rule.required_schools[${index}] must be a string`);
      assert(ALLOWED_SCHOOLS.has(school), `${skill.id} offer_rule.required_schools[${index}] invalid school ${school}`);
    });
  }
  if (Object.prototype.hasOwnProperty.call(offerRule, "required_skills")) {
    assert(Array.isArray(offerRule.required_skills), `${skill.id} offer_rule.required_skills must be an array`);
    offerRule.required_skills.forEach((requiredSkill, index) => {
      assert(typeof requiredSkill === "string", `${skill.id} offer_rule.required_skills[${index}] must be a string`);
    });
  }
  if (Object.prototype.hasOwnProperty.call(offerRule, "blocked_by_exclusive_group")) {
    assert(Array.isArray(offerRule.blocked_by_exclusive_group), `${skill.id} offer_rule.blocked_by_exclusive_group must be an array`);
    offerRule.blocked_by_exclusive_group.forEach((group, index) => {
      assert(typeof group === "string", `${skill.id} offer_rule.blocked_by_exclusive_group[${index}] must be a string`);
    });
  }
}

function validateRequiredMinSkillCount(skill, expectedMetadata) {
  const requiredMinSkillCount = skill.offer_rule.required_min_skill_count;
  assert(isObject(requiredMinSkillCount), `${skill.id} offer_rule.required_min_skill_count must be a non-array object`);
  const entries = Object.entries(requiredMinSkillCount);
  assert(entries.length > 0, `${skill.id} offer_rule.required_min_skill_count must not be empty`);
  const expectedCounts = expectedMetadata.required_min_skill_count;
  const expectedSchools = Object.keys(expectedCounts);
  assert(entries.length === expectedSchools.length, `${skill.id} offer_rule.required_min_skill_count must not contain extra schools`);
  for (const [school, count] of entries) {
    assert(ALLOWED_SCHOOLS.has(school), `${skill.id} offer_rule.required_min_skill_count invalid school ${school}`);
    assert(Number.isInteger(count) && count > 0, `${skill.id} offer_rule.required_min_skill_count.${school} must be a positive integer`);
    assert(Object.prototype.hasOwnProperty.call(expectedCounts, school), `${skill.id} offer_rule.required_min_skill_count unexpected school ${school}`);
    assert(expectedCounts[school] === count, `${skill.id} offer_rule.required_min_skill_count.${school} must equal ${expectedCounts[school]}`);
  }
}

function validateConditionArray(conditions, skillId, location) {
  assert(Array.isArray(conditions), `${skillId} ${location} must be an array`);
  conditions.forEach((condition, conditionIndex) => {
    const conditionLocation = `${location}[${conditionIndex}]`;
    assert(isObject(condition), `${skillId} ${conditionLocation} must be a non-array object`);
    assert(Object.prototype.hasOwnProperty.call(condition, "type"), `${skillId} ${conditionLocation} missing type`);
    const conditionType = condition.type;
    assert(SUPPORTED_CONDITIONS.has(conditionType), `${skillId} unsupported condition ${conditionType} at ${conditionLocation}`);
  });
}

function validateTriggerRuleConditions(rule, skillId, ruleIndex) {
  if (!Object.prototype.hasOwnProperty.call(rule, "conditions")) {
    return;
  }
  validateConditionArray(rule.conditions, skillId, `trigger_rules[${ruleIndex}].conditions`);
}

function validateSkill(skill, expectedIds, fireBaseIds, fireFusionIds, expectedMetadataById) {
  for (const field of REQUIRED_SKILL_FIELDS) {
    assert(Object.prototype.hasOwnProperty.call(skill, field), `${skill.id || "missing id"} missing field ${field}`);
  }
  assert(!OBSOLETE_FIRE_IDS.has(skill.id), `obsolete fire card id still present: ${skill.id}`);
  assert(expectedIds.has(skill.id), `unexpected first-version fire skill id: ${skill.id}`);
  assert(Array.isArray(skill.trigger_rules), `${skill.id} trigger_rules must be an array`);
  assert(Array.isArray(skill.effects), `${skill.id} effects must be an array`);
  assert(ALLOWED_SCHOOLS.has(skill.school), `${skill.id} invalid school`);
  if (skill.fusion_school !== null) {
    assert(ALLOWED_SCHOOLS.has(skill.fusion_school), `${skill.id} invalid fusion_school`);
  }
  assert(ALLOWED_TYPES.has(skill.type), `${skill.id} invalid type`);
  assert(ALLOWED_RARITIES.has(skill.rarity), `${skill.id} invalid rarity`);
  assert(Number.isInteger(skill.max_level) && skill.max_level >= 1, `${skill.id} invalid max_level`);
  assert(Array.isArray(skill.tags) && skill.tags.length > 0, `${skill.id} must have non-empty tags`);
  assert(isObject(skill.offer_rule), `${skill.id} invalid offer_rule`);
  validateOfferRuleArrays(skill);
  const expectedMetadata = expectedMetadataById.get(skill.id);
  assert(skill.school === expectedMetadata.school, `${skill.id} must set school ${expectedMetadata.school}`);
  assert(skill.fusion_school === expectedMetadata.fusion_school, `${skill.id} must set fusion_school ${expectedMetadata.fusion_school}`);
  if (fireFusionIds.has(skill.id)) {
    assert(skill.type === "fusion", `${skill.id} fusion skill id must set type fusion`);
    assert(skill.fusion_school !== null, `${skill.id} fusion skill must set fusion_school`);
    validateRequiredMinSkillCount(skill, expectedMetadata);
  }
  if (fireBaseIds.has(skill.id)) {
    assert(skill.type !== "fusion", `${skill.id} base skill id must not set type fusion`);
    assert(skill.fusion_school === null, `${skill.id} base skill id must set fusion_school null`);
  }

  skill.trigger_rules.forEach((rule, index) => {
    assert(isObject(rule), `${skill.id} trigger_rules[${index}] must be an object`);
    assert(SUPPORTED_TRIGGERS.has(rule.trigger), `${skill.id} unsupported trigger ${rule.trigger}`);
    validateTriggerRuleConditions(rule, skill.id, index);
    validateEffectArray(rule.effects, skill.id, `trigger_rules[${index}].effects`);
  });
  validateEffectArray(skill.effects, skill.id, "effects");

  assert(skill.trigger_rules.length > 0 || skill.effects.length > 0, `${skill.id} has no runtime payload`);
}

function main() {
  const expectedMetadataById = buildExpectedSkillMetadata();

  const document = readJson("data/skills.json");
  assert(Array.isArray(document.skills), "data/skills.json skills must be an array");
  const skills = document.skills;
  skills.forEach((skill, index) => {
    assert(isObject(skill), `data/skills.json skills[${index}] must be a non-array object`);
  });
  const fireBaseIds = new Set(FIRE_BASE_IDS);
  const fireFusionIds = new Set(FIRE_FUSION_IDS);
  const expectedIds = new Set(expectedMetadataById.keys());
  const actualIds = new Set(skills.map((skill) => skill.id));

  assert(skills.length === 34, `data/skills.json must contain exactly 34 first-version skills, got ${skills.length}`);
  for (const id of expectedIds) {
    assert(actualIds.has(id), `missing skill ${id}`);
  }
  for (const skill of skills) {
    validateSkill(skill, expectedIds, fireBaseIds, fireFusionIds, expectedMetadataById);
  }

  console.log("[verify_fire_skill_system_contract] PASS");
}

main();
