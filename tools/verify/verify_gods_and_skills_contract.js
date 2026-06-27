const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("../lib/json_file");

const ROOT = path.resolve(__dirname, "../..");
const GODS_PATH = path.join(ROOT, "data", "gods.json");
const SKILLS_PATH = path.join(ROOT, "data", "skills.json");
const CHARACTERS_PATH = path.join(ROOT, "data", "characters.json");
const UNREADABLE_JSON = Symbol("unreadable_json");

const ALLOWED_SKILL_TYPES = new Set([
  "attack",
  "cast",
  "core",
  "dash",
  "fusion",
  "passive",
  "power",
  "summon",
]);

const ALLOWED_RARITIES = new Set(["normal", "common", "rare", "epic", "legendary"]);
const EXCLUSIVE_GROUP_BY_TYPE = {
  attack: "attack_school",
  core: "core_school",
  dash: "dash_school",
};

function loadJson(relativePath, absolutePath, errors) {
  if (!fs.existsSync(absolutePath)) {
    errors.push(`Missing file: ${relativePath}`);
    return UNREADABLE_JSON;
  }

  try {
    return readJsonFile(absolutePath);
  } catch (error) {
    errors.push(`Invalid JSON in ${relativePath}: ${error.message}`);
    return UNREADABLE_JSON;
  }
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim() !== "";
}

function requiredArray(document, key, relativePath, errors) {
  if (Array.isArray(document[key])) return document[key];
  errors.push(`${relativePath} must contain a top-level "${key}" array`);
  return [];
}

function assertUniqueIds(items, label, errors) {
  const seen = new Set();
  for (const item of items) {
    if (!isObject(item) || !isNonEmptyString(item.id)) continue;
    if (seen.has(item.id)) errors.push(`${label} id must be unique: ${item.id}`);
    seen.add(item.id);
  }
}

function validateGods(godsDocument, errors) {
  if (godsDocument === UNREADABLE_JSON) return { gods: [], godIds: new Set(), implementedGodIds: new Set() };
  if (!isObject(godsDocument)) {
    errors.push('data/gods.json root must be an object with a top-level "gods" array');
    return { gods: [], godIds: new Set(), implementedGodIds: new Set() };
  }

  const gods = requiredArray(godsDocument, "gods", "data/gods.json", errors);
  assertUniqueIds(gods, "data/gods.json god", errors);

  const godIds = new Set();
  const implementedGodIds = new Set();
  for (const [index, god] of gods.entries()) {
    if (!isObject(god)) {
      errors.push(`data/gods.json gods[${index}] must be an object`);
      continue;
    }

    for (const field of ["id", "display_name", "title", "description"]) {
      if (!isNonEmptyString(god[field])) errors.push(`data/gods.json god ${god.id || index} missing ${field}`);
    }
    if (!Array.isArray(god.tags) || god.tags.length === 0) {
      errors.push(`data/gods.json god ${god.id || index} tags must be a non-empty array`);
    }
    if (!isObject(god.color)) {
      errors.push(`data/gods.json god ${god.id || index} color must be an object`);
    }
    if (typeof god.implemented !== "boolean") {
      errors.push(`data/gods.json god ${god.id || index} implemented must be boolean`);
    }

    if (isNonEmptyString(god.id)) {
      godIds.add(god.id);
      if (god.implemented === true) implementedGodIds.add(god.id);
    }
  }

  return { gods, godIds, implementedGodIds };
}

function validateOfferRule(skill, godIds, errors) {
  if (!isObject(skill.offer_rule)) {
    errors.push(`${skill.id} offer_rule must be an object`);
    return;
  }

  const requiredSchools = skill.offer_rule.required_schools;
  if (!Array.isArray(requiredSchools) || requiredSchools.length === 0) {
    errors.push(`${skill.id} offer_rule.required_schools must be a non-empty array`);
  } else {
    for (const school of requiredSchools) {
      if (!godIds.has(school)) errors.push(`${skill.id} offer_rule.required_schools invalid school: ${school}`);
    }
  }

  const blockedGroups = skill.offer_rule.blocked_by_exclusive_group;
  if (blockedGroups !== undefined && !Array.isArray(blockedGroups)) {
    errors.push(`${skill.id} offer_rule.blocked_by_exclusive_group must be an array when present`);
  }

  const minCounts = skill.offer_rule.required_min_skill_count;
  if (minCounts !== undefined) {
    if (!isObject(minCounts)) {
      errors.push(`${skill.id} offer_rule.required_min_skill_count must be an object when present`);
    } else {
      for (const [school, count] of Object.entries(minCounts)) {
        if (!godIds.has(school)) errors.push(`${skill.id} required_min_skill_count invalid school: ${school}`);
        if (!Number.isInteger(count) || count <= 0) {
          errors.push(`${skill.id} required_min_skill_count.${school} must be a positive integer`);
        }
      }
    }
  }
}

function validateTriggerRules(skill, errors) {
  if (!Array.isArray(skill.trigger_rules)) {
    errors.push(`${skill.id} trigger_rules must be an array`);
    return 0;
  }

  let effectCount = 0;
  for (const [ruleIndex, rule] of skill.trigger_rules.entries()) {
    if (!isObject(rule)) {
      errors.push(`${skill.id} trigger_rules[${ruleIndex}] must be an object`);
      continue;
    }
    if (!isNonEmptyString(rule.trigger)) {
      errors.push(`${skill.id} trigger_rules[${ruleIndex}].trigger must be a non-empty string`);
    }
    if (rule.conditions !== undefined && !Array.isArray(rule.conditions)) {
      errors.push(`${skill.id} trigger_rules[${ruleIndex}].conditions must be an array when present`);
    }
    if (rule.effects !== undefined) {
      if (!Array.isArray(rule.effects)) {
        errors.push(`${skill.id} trigger_rules[${ruleIndex}].effects must be an array when present`);
      } else {
        effectCount += rule.effects.length;
      }
    }
  }

  return effectCount;
}

function validateSkill(skill, index, godIds, errors) {
  if (!isObject(skill)) {
    errors.push(`data/skills.json skills[${index}] must be an object`);
    return null;
  }

  const label = skill.id || `skills[${index}]`;
  for (const field of ["id", "name", "school", "type", "rarity", "mechanic_family"]) {
    if (!isNonEmptyString(skill[field])) errors.push(`${label} missing ${field}`);
  }
  if (!Number.isInteger(skill.max_level) || skill.max_level <= 0) {
    errors.push(`${label} max_level must be a positive integer`);
  }
  if (!godIds.has(skill.school)) {
    errors.push(`${label} school must reference a god id: ${skill.school}`);
  }
  if (skill.fusion_school !== null && skill.fusion_school !== undefined) {
    if (!godIds.has(skill.fusion_school)) errors.push(`${label} fusion_school must reference a god id: ${skill.fusion_school}`);
    if (skill.fusion_school === skill.school) errors.push(`${label} fusion_school must differ from school`);
  }
  if (!ALLOWED_SKILL_TYPES.has(skill.type)) {
    errors.push(`${label} type is not recognized: ${skill.type}`);
  }
  if (!ALLOWED_RARITIES.has(skill.rarity)) {
    errors.push(`${label} rarity is not recognized: ${skill.rarity}`);
  }
  if (!Array.isArray(skill.tags) || skill.tags.length === 0) {
    errors.push(`${label} tags must be a non-empty array`);
  } else if (godIds.has(skill.school) && !skill.tags.includes(skill.school)) {
    errors.push(`${label} tags must include its primary school: ${skill.school}`);
  }

  const expectedExclusiveGroup = EXCLUSIVE_GROUP_BY_TYPE[skill.type];
  if (expectedExclusiveGroup && skill.exclusive_group !== expectedExclusiveGroup) {
    errors.push(`${label} exclusive_group must be ${expectedExclusiveGroup}`);
  }

  validateOfferRule(skill, godIds, errors);
  const triggerEffectCount = validateTriggerRules(skill, errors);
  if (!Array.isArray(skill.effects)) {
    errors.push(`${label} effects must be an array`);
  }
  const topLevelEffectCount = Array.isArray(skill.effects) ? skill.effects.length : 0;
  if (triggerEffectCount + topLevelEffectCount <= 0) {
    errors.push(`${label} must define at least one runtime effect`);
  }

  return skill;
}

function validateSkills(skillsDocument, godIds, implementedGodIds, errors) {
  if (skillsDocument === UNREADABLE_JSON) return;
  if (!isObject(skillsDocument)) {
    errors.push('data/skills.json root must be an object with top-level "skills" and "starting_skills" arrays');
    return;
  }

  const startingSkills = requiredArray(skillsDocument, "starting_skills", "data/skills.json", errors);
  const skills = requiredArray(skillsDocument, "skills", "data/skills.json", errors);
  assertUniqueIds([...startingSkills, ...skills], "data/skills.json skill", errors);

  if (!startingSkills.some((skill) => isObject(skill) && skill.id === "fireball")) {
    errors.push('data/skills.json starting_skills must include "fireball"');
  }

  const schoolCounts = new Map();
  for (const [index, skill] of skills.entries()) {
    const validSkill = validateSkill(skill, index, godIds, errors);
    if (validSkill && isNonEmptyString(validSkill.school)) {
      schoolCounts.set(validSkill.school, (schoolCounts.get(validSkill.school) || 0) + 1);
    }
  }

  for (const godId of implementedGodIds) {
    if ((schoolCounts.get(godId) || 0) <= 0) {
      errors.push(`data/gods.json god ${godId} is implemented but has no skills in data/skills.json`);
    }
  }
}

function validateCharacters(charactersDocument, errors) {
  if (charactersDocument === UNREADABLE_JSON) return;
  if (!isObject(charactersDocument)) {
    errors.push('data/characters.json root must be an object with a top-level "characters" array');
    return;
  }

  const characters = requiredArray(charactersDocument, "characters", "data/characters.json", errors);
  for (const character of characters) {
    if (!isObject(character)) continue;
    if (character.starting_skill_id !== "fireball") {
      errors.push(`data/characters.json character ${character.id || "missing id"} must set starting_skill_id: "fireball"`);
    }
  }
}

function main() {
  const errors = [];
  const godsDocument = loadJson("data/gods.json", GODS_PATH, errors);
  const skillsDocument = loadJson("data/skills.json", SKILLS_PATH, errors);
  const charactersDocument = loadJson("data/characters.json", CHARACTERS_PATH, errors);

  const { godIds, implementedGodIds } = validateGods(godsDocument, errors);
  validateSkills(skillsDocument, godIds, implementedGodIds, errors);
  validateCharacters(charactersDocument, errors);

  if (errors.length > 0) {
    console.error("[verify_gods_and_skills_contract] FAIL");
    for (const error of errors) console.error(`- ${error}`);
    process.exit(1);
  }

  console.log("[verify_gods_and_skills_contract] PASS");
}

main();
