const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");
const {
  ACTION_CONTRACTS,
  COMPONENT_CONTRACTS,
  COMPONENT_TYPES,
  DAMAGE_ORIGINS,
  EVENT_TRIGGERS,
  MODIFIER_KEYS,
  SPECIAL_RULE_KEYS,
  TARGETING_MODES,
  TARGETING_RULE_IDS,
} = require("./weapon_config_contracts");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");

const SUPPORTED_COMPONENT_TYPES = new Set(COMPONENT_TYPES);
const SUPPORTED_TARGETING_MODES = new Set(TARGETING_MODES);
const SUPPORTED_TARGETING_RULE_IDS = new Set(TARGETING_RULE_IDS);
const SUPPORTED_EVENT_TRIGGERS = new Set(EVENT_TRIGGERS);
const SUPPORTED_ACTION_TYPES = new Set(Object.keys(ACTION_CONTRACTS));
const SUPPORTED_DAMAGE_ORIGINS = new Set(DAMAGE_ORIGINS);
const SUPPORTED_MODIFIER_KEYS = new Set(MODIFIER_KEYS);
const SUPPORTED_SPECIAL_RULE_KEYS = new Set(SPECIAL_RULE_KEYS);

function readJson(fileName) {
  const filePath = path.join(dataDir, fileName);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing data file: data/${fileName}`);
  }
  return readJsonFile(filePath);
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
      errors.push(`${label} contains an item without id.`);
      continue;
    }
    if (result.has(id)) {
      errors.push(`${label} has duplicate id: ${id}`);
      continue;
    }
    result.set(id, item);
  }
  return result;
}

function collectStatusIds(value, result = []) {
  if (Array.isArray(value)) {
    for (const item of value) {
      collectStatusIds(item, result);
    }
    return result;
  }
  if (!asObject(value)) {
    return result;
  }

  for (const key of ["status_id", "status_on_hit"]) {
    if (value[key]) {
      result.push(String(value[key]));
    }
  }
  for (const key of ["statuses_on_hit", "status_ids"]) {
    for (const statusId of asArray(value[key])) {
      if (statusId) {
        result.push(String(statusId));
      }
    }
  }
  return result;
}

function validateScenePath(scenePath, label, errors) {
  if (!scenePath || typeof scenePath !== "string") {
    return;
  }
  if (!scenePath.startsWith("res://")) {
    errors.push(`${label} scene path must use res://: ${scenePath}`);
    return;
  }

  const diskPath = path.join(root, scenePath.slice("res://".length));
  if (!fs.existsSync(diskPath)) {
    errors.push(`${label} scene path does not exist: ${scenePath}`);
  }
}

function validateModifierKeys(modifiers, label, errors) {
  if (modifiers === undefined || modifiers === null) {
    return;
  }
  if (!Array.isArray(modifiers)) {
    errors.push(`${label} must be an Array of modifier effects.`);
    return;
  }
  modifiers.forEach((modifier, index) => {
    const itemLabel = `${label}[${index}]`;
    if (!modifier || typeof modifier !== "object" || Array.isArray(modifier)) {
      errors.push(`${itemLabel} must be an object.`);
      return;
    }
    for (const key of ["stat", "op", "value", "scope"]) {
      if (!Object.prototype.hasOwnProperty.call(modifier, key)) {
        errors.push(`${itemLabel} is missing ${key}.`);
      }
    }
    if (typeof modifier.stat !== "string" || modifier.stat.length === 0) {
      errors.push(`${itemLabel}.stat must be a non-empty string.`);
    }
    if (!["add", "multiplier_add", "multiplier", "override"].includes(modifier.op)) {
      errors.push(`${itemLabel}.op is unsupported: ${modifier.op}`);
    }
    if (typeof modifier.value !== "number") {
      errors.push(`${itemLabel}.value must be a number.`);
    }
    if (!modifier.scope || typeof modifier.scope !== "object" || Array.isArray(modifier.scope)) {
      errors.push(`${itemLabel}.scope must be an object.`);
    }
  });
}

function validateSpecialRules(specialRules, label, errors) {
  for (const key of Object.keys(asObject(specialRules))) {
    if (!SUPPORTED_SPECIAL_RULE_KEYS.has(key)) {
      errors.push(`${label} uses unsupported special rule key: ${key}`);
    }
  }
}

function validateContractParams(params, contract, label, errors) {
  const allowedParams = new Set(contract.allowedParams || []);
  for (const key of Object.keys(params)) {
    if (!allowedParams.has(key)) {
      errors.push(`${label} uses unsupported param: ${key}`);
    }
  }

  for (const key of contract.requiredParams || []) {
    if (!idOf(params[key])) {
      errors.push(`${label} is missing required param: ${key}`);
    }
  }

  for (const group of contract.requiredAnyParams || []) {
    if (!group.some((key) => idOf(params[key]))) {
      errors.push(`${label} must define one of: ${group.join(", ")}`);
    }
  }
}

function collectCombatObjectRefs(params, contract) {
  const keys = contract.combatObjectParam || [];
  return keys.map((key) => idOf(params[key])).filter(Boolean);
}

function validateAction(action, label, indexes, errors) {
  const actionType = idOf(action.type);
  if (!SUPPORTED_ACTION_TYPES.has(actionType)) {
    errors.push(`${label} uses unsupported action type: ${actionType || "<empty>"}`);
    return;
  }

  const params = asObject(action.params);
  const contract = ACTION_CONTRACTS[actionType] || {};
  validateContractParams(params, contract, label, errors);

  for (const objectId of collectCombatObjectRefs(params, contract)) {
    if (!indexes.combatObjects.has(objectId)) {
      errors.push(`${label} references missing combat object: ${objectId}`);
    }
  }

  for (const statusId of collectStatusIds(params)) {
    if (!indexes.statuses.has(statusId)) {
      errors.push(`${label} references missing status: ${statusId}`);
    }
  }

  if (params.damage_origin && !SUPPORTED_DAMAGE_ORIGINS.has(String(params.damage_origin))) {
    errors.push(`${label} uses unsupported damage_origin: ${params.damage_origin}`);
  }
}

function validateEvents(events, label, indexes, errors) {
  for (const [eventIndex, event] of asArray(events).entries()) {
    const eventLabel = `${label}.events[${eventIndex}]`;
    const trigger = idOf(event.trigger);
    if (!SUPPORTED_EVENT_TRIGGERS.has(trigger)) {
      errors.push(`${eventLabel} uses unsupported trigger: ${trigger || "<empty>"}`);
    }
    for (const [actionIndex, action] of asArray(event.actions).entries()) {
      validateAction(action, `${eventLabel}.actions[${actionIndex}]`, indexes, errors);
    }
  }
}

function validatePrimaryAttack(attack, indexes, errors) {
  const attackId = idOf(attack.id);
  if (String(attack.category || "") !== "active") {
    errors.push(`Primary attack ${attackId} must use category=active.`);
  }

  const weaponId = idOf(attack.weapon_id);
  if (weaponId && !indexes.weapons.has(weaponId)) {
    errors.push(`Primary attack ${attackId} references missing weapon_id: ${weaponId}`);
  }

  for (const [componentIndex, component] of asArray(attack.components).entries()) {
    const componentLabel = `Primary attack ${attackId}.components[${componentIndex}]`;
    const componentType = idOf(component.type);
    if (!SUPPORTED_COMPONENT_TYPES.has(componentType)) {
      errors.push(`${componentLabel} uses unsupported component type: ${componentType || "<empty>"}`);
      continue;
    }

    const params = asObject(component.params);
    const contract = COMPONENT_CONTRACTS[componentType] || {};
    validateContractParams(params, contract, componentLabel, errors);
    for (const objectId of collectCombatObjectRefs(params, contract)) {
      if (!indexes.combatObjects.has(objectId)) {
        errors.push(`${componentLabel} references missing combat object: ${objectId}`);
      }
    }
    if (componentType === "targeting") {
      const mode = String(params.mode || "nearest_enemy");
      if (!SUPPORTED_TARGETING_MODES.has(mode)) {
        errors.push(`${componentLabel} uses unsupported targeting mode: ${mode}`);
      }
    }
  }

  validateEvents(attack.events, `Primary attack ${attackId}`, indexes, errors);
}

function validateWeapon(weapon, indexes, errors, warnings) {
  const weaponId = idOf(weapon.id);
  const characterId = idOf(weapon.character_id);
  const startingSkillId = idOf(weapon.starting_skill_id);

  const character = indexes.characters.get(characterId);
  if (!character) {
    errors.push(`Weapon ${weaponId} references missing character_id: ${characterId || "<empty>"}`);
  } else if (!asArray(character.allowed_weapon_ids).map(String).includes(weaponId)) {
    errors.push(`Weapon ${weaponId} is not listed in character ${characterId}.allowed_weapon_ids.`);
  }

  if (!indexes.primaryAttacks.has(startingSkillId)) {
    errors.push(`Weapon ${weaponId} references missing starting_skill_id: ${startingSkillId || "<empty>"}`);
  } else {
    const startingSkill = indexes.primaryAttacks.get(startingSkillId);
    const startingSkillWeaponId = idOf(startingSkill.weapon_id);
    if (startingSkillWeaponId && startingSkillWeaponId !== weaponId) {
      errors.push(`Weapon ${weaponId} starting skill ${startingSkillId} belongs to ${startingSkillWeaponId}.`);
    }
  }

  if (Object.prototype.hasOwnProperty.call(weapon, "weapon_base_status")) {
    errors.push(`Weapon ${weaponId} still uses removed field weapon_base_status; use explicit skill apply_status instead.`);
  }

  if (Object.prototype.hasOwnProperty.call(weapon, "on_hit_status")) {
    errors.push(`Weapon ${weaponId} still uses removed field on_hit_status; use explicit skill apply_status instead.`);
  }

  const targetingRuleId = idOf(weapon.targeting_rule_id);
  if (targetingRuleId && !SUPPORTED_TARGETING_RULE_IDS.has(targetingRuleId)) {
    warnings.push(`Weapon ${weaponId} has unknown targeting_rule_id: ${targetingRuleId}`);
  }

  validateModifierKeys(asObject(weapon.weapon_trait).modifiers, `Weapon ${weaponId}.weapon_trait.modifiers`, errors);
  validateModifierKeys(asObject(weapon.weapon_trait).penalties, `Weapon ${weaponId}.weapon_trait.penalties`, errors);

  const branchIds = asArray(weapon.branch_ids).map(String);
  if (branchIds.length === 0) {
    errors.push(`Weapon ${weaponId} has no branch_ids.`);
  }

  const seenBranchIds = new Set();
  for (const branchId of branchIds) {
    if (seenBranchIds.has(branchId)) {
      errors.push(`Weapon ${weaponId} repeats branch_id: ${branchId}`);
    }
    seenBranchIds.add(branchId);

    const branch = indexes.branches.get(branchId);
    if (!branch) {
      errors.push(`Weapon ${weaponId} references missing branch_id: ${branchId}`);
      continue;
    }
    if (idOf(branch.weapon_id) !== weaponId) {
      errors.push(`Weapon ${weaponId} references branch ${branchId}, but branch.weapon_id is ${branch.weapon_id || "<empty>"}.`);
    }
  }
}

function validateBranch(branch, indexes, errors) {
  const branchId = idOf(branch.id);
  const weaponId = idOf(branch.weapon_id);
  if (!indexes.weapons.has(weaponId)) {
    errors.push(`Branch ${branchId} references missing weapon_id: ${weaponId || "<empty>"}`);
  } else if (!asArray(indexes.weapons.get(weaponId).branch_ids).map(String).includes(branchId)) {
    errors.push(`Branch ${branchId} is not listed in weapon ${weaponId}.branch_ids.`);
  }

  const levelPath = asObject(branch.level_path);
  for (const level of [2, 3, 4, 5]) {
    const config = asObject(levelPath[String(level)]);
    if (Object.keys(config).length === 0) {
      errors.push(`Branch ${branchId} is missing level_path.${level}.`);
      continue;
    }
    validateModifierKeys(config.modifiers, `Branch ${branchId}.level_path.${level}.modifiers`, errors);
    validateSpecialRules(config.special_rules, `Branch ${branchId}.level_path.${level}.special_rules`, errors);
    validateEvents(config.events_added, `Branch ${branchId}.level_path.${level}.events_added`, indexes, errors);
  }
}

function validateCombatObjects(combatObjects, errors) {
  for (const object of combatObjects.values()) {
    const objectId = idOf(object.id);
    validateScenePath(object.scene, `Combat object ${objectId}`, errors);
  }
}

function main() {
  const errors = [];
  const warnings = [];

  const documents = {
    characters: readJson("characters.json"),
    weapons: readJson("weapons.json"),
    primaryAttacks: readJson("primary_attack.json"),
    branches: readJson("weapon_branches.json"),
    combatObjects: readJson("combat_objects.json"),
    statuses: readJson("status_effects.json"),
  };

  const indexes = {
    characters: byId(documents.characters.characters, "characters", errors),
    weapons: byId(documents.weapons.weapons, "weapons", errors),
    primaryAttacks: byId(documents.primaryAttacks.primary_attacks, "primary_attacks", errors),
    branches: byId(documents.branches.branches, "branches", errors),
    combatObjects: byId(documents.combatObjects.combat_objects, "combat_objects", errors),
    statuses: byId(documents.statuses.statuses, "statuses", errors),
  };

  for (const weapon of indexes.weapons.values()) {
    validateWeapon(weapon, indexes, errors, warnings);
  }
  for (const attack of indexes.primaryAttacks.values()) {
    validatePrimaryAttack(attack, indexes, errors);
  }
  for (const branch of indexes.branches.values()) {
    validateBranch(branch, indexes, errors);
  }
  validateCombatObjects(indexes.combatObjects, errors);

  for (const warning of warnings) {
    console.warn(`WARN ${warning}`);
  }
  if (errors.length) {
    for (const error of errors) {
      console.error(`ERROR ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log(
    `Weapon graph validation passed. weapons=${indexes.weapons.size} primary_attacks=${indexes.primaryAttacks.size} branches=${indexes.branches.size} combat_objects=${indexes.combatObjects.size}`
  );
}

main();
