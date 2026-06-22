const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");
const REPORT_DIR = path.join(root, "reports", "combat-scene-checks");
const MATRIX_JSON = path.join(REPORT_DIR, "full_weapon_branch_matrix.json");
const MATRIX_TEXT = path.join(REPORT_DIR, "full_weapon_branch_matrix.txt");

const EXPECTED_COUNTS = Object.freeze({
  characters: 4,
  weapons: 13,
  branches: 52,
  levelsPerBranch: 5,
  cases: 260,
});

const LEVELS = Object.freeze([1, 2, 3, 4, 5]);
const MODIFIER_OPS = Object.freeze(["add", "multiplier_add", "multiplier", "multiply", "override"]);
const ACTION_OBJECT_KEYS = Object.freeze(["area_id", "projectile_id", "trap_id", "object_id"]);
const ACTION_STATUS_KEYS = Object.freeze(["status_id", "required_status_id"]);
const STATUS_REF_KEYS = Object.freeze([
  "status_id",
  "required_status_id",
  "consume_status_id",
  "from_status_id",
  "to_status_id",
]);

function readJson(fileName) {
  return readJsonFile(path.join(dataDir, fileName));
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function asObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function idOf(value) {
  return String(value || "").trim();
}

function byId(items, label, errors) {
  const result = new Map();
  for (const item of asArray(items)) {
    const id = idOf(item && item.id);
    if (!id) {
      errors.push(`${label} contains item without id`);
      continue;
    }
    if (result.has(id)) {
      errors.push(`${label} duplicate id: ${id}`);
      continue;
    }
    result.set(id, item);
  }
  return result;
}

function loadDocuments() {
  return {
    characters: readJson("characters.json"),
    weapons: readJson("weapons.json"),
    primaryAttacks: readJson("primary_attack.json"),
    branches: readJson("weapon_branches.json"),
    combatObjects: readJson("combat_objects.json"),
    statuses: readJson("status_effects.json"),
    enemies: readJson("enemies.json"),
  };
}

function documentArray(document, primaryKey, fallbackKey) {
  return asArray(document && (document[primaryKey] || document[fallbackKey]));
}

function buildIndexes(documents, errors = []) {
  return {
    characters: byId(documentArray(documents.characters, "characters"), "characters", errors),
    weapons: byId(documentArray(documents.weapons, "weapons"), "weapons", errors),
    primaryAttacks: byId(documentArray(documents.primaryAttacks, "primary_attacks"), "primary_attacks", errors),
    branches: byId(documentArray(documents.branches, "branches"), "branches", errors),
    combatObjects: byId(documentArray(documents.combatObjects, "combat_objects"), "combat_objects", errors),
    statuses: byId(documentArray(documents.statuses, "statuses"), "statuses", errors),
    enemies: byId(documentArray(documents.enemies, "enemies", "monsters"), "enemies", errors),
  };
}

function caseId(characterId, weaponId, branchId, level, template) {
  return `${characterId}__${weaponId}__${branchId}__lv${level}__${template}`;
}

function isEveryNCastsTemplate(text) {
  if (/cast_interval|hit_interval/i.test(text)) return true;
  return /every_n/i.test(text) && /cast|hit/i.test(text) && !/tick|pulse/i.test(text);
}

function classifyTemplate(levelConfig, level) {
  if (level === 1) return "base_attack";

  const config = asObject(levelConfig);
  const specialRules = asObject(config.special_rules);
  const events = asArray(config.events_added);
  const modifiers = asArray(config.modifiers);
  const text = JSON.stringify({ specialRules, events, modifiers });

  if (/lightning_chain_bounce|bounce_count_add|bounce_damage_multiplier/i.test(text)) return "multi_target_area";
  if (/death|kill/i.test(text)) return "death_trigger";
  if (isEveryNCastsTemplate(text)) return "every_n_casts";
  if (/shield|damage_taken|heal|player_damaged|low_hp/i.test(text)) return "player_defense";
  if (/explosion|radius|max_targets|splash|area_direct|area_damage/i.test(text)) return "multi_target_area";
  if (/field|cloud|oil|lava|trap|zone|area_tick|tick_damage|duration/i.test(text)) return "field_tick";
  if (/elite|boss|poise|mark|core|strong/i.test(text)) return "elite_boss_rule";
  if (/consume|required_stacks|required_status_id|convert/i.test(text)) return "stack_conversion";
  if (/reaction|burst|deflagration|shatter/i.test(text)) return "reaction_burst";
  if (/status_id|stacks|stack|duration/i.test(text)) return "direct_hit_status";
  if (/projectile|orb|page|wall|spawn/i.test(text)) return "spawn_object";
  return "base_attack";
}

function buildMatrix(documents = loadDocuments()) {
  const errors = [];
  const indexes = buildIndexes(documents, errors);
  const cases = [];

  for (const character of indexes.characters.values()) {
    const characterId = idOf(character.id);
    const allowedWeaponIds = asArray(character.allowed_weapon_ids).map(String);
    for (const weaponId of allowedWeaponIds) {
      const weapon = indexes.weapons.get(weaponId);
      if (!weapon) {
        errors.push(`character ${characterId} allows missing weapon ${weaponId}`);
        continue;
      }

      const startingSkillId = idOf(weapon.starting_skill_id);
      for (const branchId of asArray(weapon.branch_ids).map(String)) {
        const branch = indexes.branches.get(branchId);
        if (!branch) {
          errors.push(`weapon ${weaponId} references missing branch ${branchId}`);
          continue;
        }

        for (const level of LEVELS) {
          const levelConfig = level === 1 ? {} : asObject(asObject(branch.level_path)[String(level)]);
          const template = classifyTemplate(levelConfig, level);
          cases.push({
            id: caseId(characterId, weaponId, branchId, level, template),
            character_id: characterId,
            weapon_id: weaponId,
            starting_skill_id: startingSkillId,
            branch_id: branchId,
            level,
            template,
            target_enemy_ids: selectTargetEnemyIds(template, indexes, { weapon_id: weaponId, branch_id: branchId }),
            source: {
              character: `data/characters.json characters.${characterId}`,
              weapon: `data/weapons.json weapons.${weaponId}`,
              branch: `data/weapon_branches.json branches.${branchId}`,
              level: level === 1 ? "base weapon state" : `data/weapon_branches.json ${branchId}.level_path.${level}`,
            },
          });
        }
      }
    }
  }

  return { cases, indexes, documents, errors };
}

function selectTargetEnemyIds(template, indexes, caseData = {}) {
  const normal = indexes.enemies.has("small_slime") ? "small_slime" : firstEnemyId(indexes);
  const boss = indexes.enemies.has("giant_slime") ? "giant_slime" : normal;

  if (caseData.weapon_id === "lightning_whip" && caseData.branch_id === "lightning_whip_branch_chain" && template === "multi_target_area") {
    return Array(8).fill(normal).filter(Boolean);
  }
  if (template === "multi_target_area" || template === "reaction_burst" || template === "death_trigger") {
    return [normal, normal, normal].filter(Boolean);
  }
  if (template === "elite_boss_rule") return [boss].filter(Boolean);
  return [normal].filter(Boolean);
}

function firstEnemyId(indexes) {
  const first = indexes.enemies.keys().next();
  return first.done ? "" : first.value;
}

function validateStaticMatrix(matrixResult) {
  const errors = [...asArray(matrixResult && matrixResult.errors)];
  const cases = asArray(matrixResult && matrixResult.cases);
  const indexes = asObject(matrixResult && matrixResult.indexes);

  if (!indexes.characters || !indexes.weapons || !indexes.branches || !indexes.primaryAttacks) {
    errors.push("matrixResult.indexes is incomplete");
    return errors;
  }

  if (indexes.characters.size !== EXPECTED_COUNTS.characters) errors.push(`expected ${EXPECTED_COUNTS.characters} characters, got ${indexes.characters.size}`);
  if (indexes.weapons.size !== EXPECTED_COUNTS.weapons) errors.push(`expected ${EXPECTED_COUNTS.weapons} weapons, got ${indexes.weapons.size}`);
  if (indexes.branches.size !== EXPECTED_COUNTS.branches) errors.push(`expected ${EXPECTED_COUNTS.branches} branches, got ${indexes.branches.size}`);
  if (cases.length !== EXPECTED_COUNTS.cases) errors.push(`expected ${EXPECTED_COUNTS.cases} matrix cases, got ${cases.length}`);

  const seen = new Set();
  const levelCoverage = new Map();
  for (const item of cases) {
    if (seen.has(item.id)) errors.push(`duplicate matrix case id: ${item.id}`);
    seen.add(item.id);

    const character = indexes.characters.get(item.character_id);
    const weapon = indexes.weapons.get(item.weapon_id);
    const branch = indexes.branches.get(item.branch_id);
    const attack = indexes.primaryAttacks.get(item.starting_skill_id);

    if (!character) errors.push(`${item.id}: missing character ${item.character_id}`);
    if (!weapon) errors.push(`${item.id}: missing weapon ${item.weapon_id}`);
    if (!branch) errors.push(`${item.id}: missing branch ${item.branch_id}`);
    if (!attack) errors.push(`${item.id}: missing starting skill ${item.starting_skill_id}`);

    if (character && !asArray(character.allowed_weapon_ids).map(String).includes(item.weapon_id)) {
      errors.push(`${item.id}: weapon is not allowed by character`);
    }
    if (weapon && idOf(weapon.character_id) !== item.character_id) {
      errors.push(`${item.id}: weapon.character_id expected ${item.character_id}, got ${weapon.character_id || "<empty>"}`);
    }
    if (weapon && !asArray(weapon.branch_ids).map(String).includes(item.branch_id)) {
      errors.push(`${item.id}: branch is not listed on weapon`);
    }
    if (branch && idOf(branch.weapon_id) !== item.weapon_id) {
      errors.push(`${item.id}: branch.weapon_id expected ${item.weapon_id}, got ${branch.weapon_id || "<empty>"}`);
    }

    const coverageKey = `${item.character_id}/${item.weapon_id}/${item.branch_id}`;
    if (!levelCoverage.has(coverageKey)) levelCoverage.set(coverageKey, new Set());
    levelCoverage.get(coverageKey).add(item.level);

    if (item.level === 1) continue;

    const levelConfig = asObject(asObject(branch && branch.level_path)[String(item.level)]);
    if (Object.keys(levelConfig).length === 0) {
      errors.push(`${item.id}: missing branch level_path.${item.level}`);
      continue;
    }
    validateLevelConfigShape(item, levelConfig, indexes, errors);
  }

  for (const [key, levels] of levelCoverage) {
    for (const level of LEVELS) {
      if (!levels.has(level)) errors.push(`${key}: missing Lv${level} matrix case`);
    }
  }

  return errors;
}

function validateLevelConfigShape(item, levelConfig, indexes, errors) {
  for (const [index, modifier] of asArray(levelConfig.modifiers).entries()) {
    const modifierObject = asObject(modifier);
    const label = `${item.id}.modifiers[${index}]`;
    if (!modifierObject.stat) errors.push(`${label}: missing stat`);
    if (!MODIFIER_OPS.includes(String(modifierObject.op || ""))) errors.push(`${label}: unsupported op ${modifierObject.op}`);
    if (typeof modifierObject.value !== "number") errors.push(`${label}: value must be number`);
    if (Object.keys(asObject(modifierObject.scope)).length === 0) errors.push(`${label}: missing scope`);
  }

  for (const [eventIndex, event] of asArray(levelConfig.events_added).entries()) {
    const eventObject = asObject(event);
    if (!eventObject.trigger) errors.push(`${item.id}.events_added[${eventIndex}]: missing trigger`);
    for (const [actionIndex, action] of asArray(eventObject.actions).entries()) {
      const actionObject = asObject(action);
      const label = `${item.id}.events_added[${eventIndex}].actions[${actionIndex}]`;
      if (!actionObject.type) errors.push(`${label}: missing type`);
      const params = asObject(actionObject.params);
      for (const key of ACTION_OBJECT_KEYS) {
        if (params[key] && !indexes.combatObjects.has(String(params[key]))) {
          errors.push(`${label}: missing combat object ${params[key]}`);
        }
      }
      for (const key of ACTION_STATUS_KEYS) {
        if (params[key] && !indexes.statuses.has(String(params[key]))) {
          errors.push(`${label}: missing status ${params[key]}`);
        }
      }
    }
  }

  for (const statusId of collectStatusRefs(levelConfig.special_rules)) {
    if (!indexes.statuses.has(statusId)) {
      errors.push(`${item.id}: missing status referenced by special_rules: ${statusId}`);
    }
  }
}

function collectStatusRefs(value, result = []) {
  if (Array.isArray(value)) {
    value.forEach((item) => collectStatusRefs(item, result));
    return result;
  }
  const object = asObject(value);
  if (!Object.keys(object).length) return result;

  for (const key of STATUS_REF_KEYS) {
    if (object[key]) result.push(String(object[key]));
  }
  for (const child of Object.values(object)) collectStatusRefs(child, result);
  return result;
}

function writeMatrixReports(matrixResult, staticErrors = []) {
  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const summary = summarize(matrixResult.cases, staticErrors);
  fs.writeFileSync(MATRIX_JSON, `${JSON.stringify({ summary, cases: matrixResult.cases, static_errors: staticErrors }, null, 2)}\n`, "utf8");
  fs.writeFileSync(MATRIX_TEXT, formatTextReport(summary, matrixResult.cases, staticErrors), "utf8");
}

function summarize(cases, staticErrors) {
  const byCharacter = {};
  const byTemplate = {};
  for (const item of asArray(cases)) {
    if (!byCharacter[item.character_id]) {
      byCharacter[item.character_id] = { cases: 0, weapons: new Set(), branches: new Set() };
    }
    byCharacter[item.character_id].cases += 1;
    byCharacter[item.character_id].weapons.add(item.weapon_id);
    byCharacter[item.character_id].branches.add(item.branch_id);

    if (!byTemplate[item.template]) {
      byTemplate[item.template] = { cases: 0, characters: new Set(), weapons: new Set() };
    }
    byTemplate[item.template].cases += 1;
    byTemplate[item.template].characters.add(item.character_id);
    byTemplate[item.template].weapons.add(item.weapon_id);
  }

  return {
    total_cases: asArray(cases).length,
    expected_cases: EXPECTED_COUNTS.cases,
    passed_cases: 0,
    failed_cases: 0,
    skipped_cases: 0,
    static_failures: asArray(staticErrors).length,
    runtime_failures: 0,
    rule_template_failures: 0,
    duration_ms: 0,
    by_character: Object.fromEntries(Object.entries(byCharacter).map(([id, value]) => [id, {
      cases: value.cases,
      weapons: value.weapons.size,
      branches: value.branches.size,
    }])),
    by_template: Object.fromEntries(Object.entries(byTemplate).map(([id, value]) => [id, {
      cases: value.cases,
      characters: value.characters.size,
      weapons: value.weapons.size,
    }])),
  };
}

function formatTextReport(summary, cases, staticErrors) {
  const lines = [];
  lines.push("[FullWeaponBranchMatrix] START");
  lines.push(`total_cases=${summary.total_cases} expected_cases=${summary.expected_cases} static_failures=${summary.static_failures}`);
  for (const [characterId, entry] of Object.entries(summary.by_character)) {
    lines.push(`CHARACTER ${characterId} weapons=${entry.weapons} branches=${entry.branches} cases=${entry.cases}`);
  }
  for (const [template, entry] of Object.entries(summary.by_template)) {
    lines.push(`TEMPLATE ${template} characters=${entry.characters} weapons=${entry.weapons} cases=${entry.cases}`);
  }
  for (const item of asArray(cases)) {
    lines.push(`CASE ${item.id} character=${item.character_id} weapon=${item.weapon_id} skill=${item.starting_skill_id} branch=${item.branch_id} level=${item.level} template=${item.template} targets=${asArray(item.target_enemy_ids).join(",")}`);
  }
  for (const error of asArray(staticErrors)) {
    lines.push(`ERROR ${error}`);
  }
  lines.push(staticErrors.length ? "[FullWeaponBranchMatrix] FAIL" : "[FullWeaponBranchMatrix] PASS");
  return `${lines.join("\n")}\n`;
}

module.exports = {
  EXPECTED_COUNTS,
  MATRIX_JSON,
  MATRIX_TEXT,
  buildMatrix,
  validateStaticMatrix,
  writeMatrixReports,
};
