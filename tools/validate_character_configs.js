const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");

const TRAIT_SCHEMAS = {
  weapon_cast_stack: ["casts_per_stack", "max_stacks", "modifiers_per_stack"],
  moving_bonus: ["moving_seconds_required", "active_modifiers", "penalty_duration", "penalty_modifiers"],
  passive_with_periodic_shield: ["shield_amount", "shield_interval", "shield_duration"],
  status_kill_random_area: ["kill_chance", "area_damage", "area_duration", "area_tick_interval", "area_radius"],
  hp_lost_stack: ["hp_step_percent", "max_stacks", "modifiers_per_stack"],
};

const VALID_UNLOCK_TYPES = new Set(["default", "soul_cost", "achievement"]);
const LEGACY_CHARACTER_FIELDS = new Set([
  "character_id",
  "name_zh",
  "name_en",
  "role_zh",
  "role_en",
  "description_zh",
  "description_en",
  "stats",
  "talent",
  "allowed_weapons",
  "unlock_condition",
]);
const LEGACY_CHARACTER_MODIFIER_KEYS = new Set([
  "crit_rate_add",
  "pickup_range_multiplier_add",
  "pickup_range_add",
]);

function readJson(fileName, required = true) {
  const filePath = path.join(dataDir, fileName);
  if (!fs.existsSync(filePath)) {
    if (required) {
      throw new Error(`Missing data file: data/${fileName}`);
    }
    return {};
  }
  return readJsonFile(filePath);
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function byId(items, label, errors) {
  const result = new Map();
  for (const item of asArray(items)) {
    const id = String(item && item.id ? item.id : "");
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

function hasObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function validateCharacter(character, indexes, errors, warnings) {
  const id = String(character.id || "");
  const allowedWeapons = asArray(character.allowed_weapon_ids).map(String);
  validateNoLegacyCharacterFields(character, id || "<missing id>", errors);

  if (!hasObject(character.base_stats)) {
    errors.push(`Character ${id} is missing base_stats.`);
  }
  if (!allowedWeapons.length) {
    errors.push(`Character ${id} has no allowed_weapon_ids.`);
  }

  for (const weaponId of allowedWeapons) {
    const weapon = indexes.weapons.get(weaponId);
    if (!weapon) {
      errors.push(`Character ${id} allows missing weapon: ${weaponId}`);
      continue;
    }
    if (String(weapon.character_id || "") !== id) {
      warnings.push(`Weapon ${weaponId} is allowed by ${id}, but weapons.json character_id is ${weapon.character_id || "<empty>"}.`);
    }
    const startingSkillId = String(weapon.starting_skill_id || "");
    if (!startingSkillId) {
      errors.push(`Weapon ${weaponId} has no starting_skill_id.`);
    } else if (!indexes.skills.has(startingSkillId)) {
      errors.push(`Weapon ${weaponId} references missing starting_skill_id: ${startingSkillId}`);
    }
  }

  validateTrait(character, errors);
  validateUnlock(character, errors);
  validateCharacterText(character, indexes.characterTexts, errors);
}

function validateNoLegacyCharacterFields(character, id, errors) {
  for (const field of Object.keys(character || {})) {
    if (LEGACY_CHARACTER_FIELDS.has(field)) {
      errors.push(`Character ${id} uses legacy field ${field}; use the current character schema only.`);
    }
  }
  validateNoLegacyModifierKeys(character, `Character ${id}`, errors);
}

function validateNoLegacyModifierKeys(value, pathLabel, errors) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => validateNoLegacyModifierKeys(item, `${pathLabel}[${index}]`, errors));
    return;
  }
  if (!hasObject(value)) {
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    if (LEGACY_CHARACTER_MODIFIER_KEYS.has(key)) {
      errors.push(`${pathLabel} uses legacy modifier key ${key}; use crit_chance_add or pickup_radius_* instead.`);
    }
    validateNoLegacyModifierKeys(child, `${pathLabel}.${key}`, errors);
  }
}

function validateTrait(character, errors) {
  const id = String(character.id || "");
  if (!hasObject(character.trait)) {
    errors.push(`Character ${id} is missing trait.`);
    return;
  }

  const traitType = String(character.trait.type || "");
  if (!TRAIT_SCHEMAS[traitType]) {
    errors.push(`Character ${id} uses unknown trait.type: ${traitType || "<empty>"}`);
    return;
  }

  const params = character.trait.params;
  if (!hasObject(params)) {
    errors.push(`Character ${id} trait ${traitType} is missing params.`);
    return;
  }

  for (const field of TRAIT_SCHEMAS[traitType]) {
    if (!(field in params)) {
      errors.push(`Character ${id} trait ${traitType} is missing params.${field}.`);
    }
  }
}

function validateUnlock(character, errors) {
  const id = String(character.id || "");
  const unlock = hasObject(character.unlock) ? character.unlock : { type: "default" };
  const type = String(unlock.type || "default");
  if (!VALID_UNLOCK_TYPES.has(type)) {
    errors.push(`Character ${id} has invalid unlock.type: ${type}`);
  }
  if (type === "soul_cost" && Number(unlock.cost || 0) <= 0) {
    errors.push(`Character ${id} uses soul_cost unlock without positive cost.`);
  }
  if (type === "achievement" && !hasText(unlock.achievement_id)) {
    errors.push(`Character ${id} uses achievement unlock without achievement_id.`);
  }
}

function validateCharacterText(character, characterTexts, errors) {
  const id = String(character.id || "");
  const text = characterTexts.characters && characterTexts.characters[id];
  if (!hasObject(text)) {
    errors.push(`Character ${id} is missing data/character_texts.json entry.`);
    return;
  }

  for (const field of ["role", "difficulty", "drawback", "trait_display_name", "trait_description"]) {
    if (!hasText(text[field])) {
      errors.push(`Character ${id} text is missing ${field}.`);
    }
  }
}

function validateProgressionGoals(characters, goals, errors) {
  const seen = new Set();
  for (const entry of asArray(goals.character_specializations)) {
    const characterId = String(entry.character_id || "");
    if (!characters.has(characterId)) {
      errors.push(`progression_goals references missing character_id: ${characterId || "<empty>"}`);
    }
    seen.add(characterId);
  }
  for (const characterId of characters.keys()) {
    if (!seen.has(characterId)) {
      errors.push(`progression_goals is missing character_specializations entry for ${characterId}.`);
    }
  }
}

function validateChallenges(indexes, challenges, errors) {
  for (const poolName of ["daily_challenges", "weekly_challenges"]) {
    for (const challenge of asArray(challenges[poolName])) {
      const challengeId = String(challenge.challenge_id || "<missing challenge_id>");
      const characterId = String(challenge.character_id || "");
      const weaponId = String(challenge.weapon_id || "");
      const mapId = String(challenge.map_id || "");
      if (!indexes.characters.has(characterId)) {
        errors.push(`${poolName}.${challengeId} references missing character_id: ${characterId || "<empty>"}`);
      }
      if (!indexes.weapons.has(weaponId)) {
        errors.push(`${poolName}.${challengeId} references missing weapon_id: ${weaponId || "<empty>"}`);
      }
      if (!indexes.maps.has(mapId)) {
        errors.push(`${poolName}.${challengeId} references missing map_id: ${mapId || "<empty>"}`);
      }
      const character = indexes.characters.get(characterId);
      if (character && weaponId && !asArray(character.allowed_weapon_ids).map(String).includes(weaponId)) {
        errors.push(`${poolName}.${challengeId} uses weapon ${weaponId}, which is not allowed by character ${characterId}.`);
      }
    }
  }
}

function validateWeaponTexts(weapons, characterTexts, errors) {
  const weaponTexts = characterTexts.weapons || {};
  for (const weaponId of weapons.keys()) {
    if (!hasObject(weaponTexts[weaponId]) || !hasText(weaponTexts[weaponId].role)) {
      errors.push(`Weapon ${weaponId} is missing data/character_texts.json weapons.${weaponId}.role.`);
    }
  }
}

function main() {
  const errors = [];
  const warnings = [];
  const charactersDocument = readJson("characters.json");
  const weaponsDocument = readJson("weapons.json");
  const skillsDocument = readJson("primary_attack.json");
  const mapsDocument = readJson("maps.json");
  const goalsDocument = readJson("progression_goals.json");
  const challengesDocument = readJson("challenges.json");
  const characterTexts = readJson("character_texts.json", false);

  const indexes = {
    characters: byId(charactersDocument.characters, "characters", errors),
    weapons: byId(weaponsDocument.weapons, "weapons", errors),
    skills: byId(skillsDocument.primary_attacks, "primary_attacks", errors),
    maps: byId(mapsDocument.maps, "maps", errors),
    characterTexts,
  };

  for (const character of indexes.characters.values()) {
    validateCharacter(character, indexes, errors, warnings);
  }
  validateProgressionGoals(indexes.characters, goalsDocument, errors);
  validateChallenges(indexes, challengesDocument, errors);
  validateWeaponTexts(indexes.weapons, characterTexts, errors);

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

  console.log(`Character config validation passed. characters=${indexes.characters.size} weapons=${indexes.weapons.size}`);
}

main();
