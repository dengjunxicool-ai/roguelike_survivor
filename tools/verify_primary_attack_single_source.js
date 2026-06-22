const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");

const skillsPath = path.join(dataDir, "skills.json");
const primaryAttackPath = path.join(dataDir, "primary_attack.json");
const characterRunInitializerPath = path.join(root, "scripts", "characters", "character_run_initializer.gd");
const characterLoadoutServicePath = path.join(root, "scripts", "characters", "character_loadout_service.gd");
const skillManagerPath = path.join(root, "scripts", "skills", "skill_manager.gd");
const weaponSkillBindingPath = path.join(root, "scripts", "weapons", "weapon_skill_binding.gd");
const errors = [];

const primaryAttackDocument = readJsonFile(primaryAttackPath);
const primaryAttacks = Array.isArray(primaryAttackDocument.primary_attacks)
  ? primaryAttackDocument.primary_attacks
  : [];

for (const attack of primaryAttacks) {
  const id = String((attack && attack.id) || "");
  const maxLevel = Number(attack && attack.max_level);
  if (!Number.isInteger(maxLevel) || maxLevel < 2) {
    errors.push(`primary_attack ${id || "<missing id>"} must define max_level >= 2.`);
  }
}

if (fs.existsSync(skillsPath)) {
  validateSkillsDocument(readJsonFile(skillsPath));
}
validateStartingSkillRuntimeSource();

if (errors.length) {
  for (const error of errors) {
    console.error(`ERROR ${error}`);
  }
  process.exit(1);
}

console.log(
  `Primary attack legacy source verified with god skill data allowed. primary_attacks=${primaryAttacks.length}`
);

function validateSkillsDocument(skillsDocument) {
  if (!isPlainObject(skillsDocument)) {
    errors.push("data/skills.json must be an object when present.");
    return;
  }

  const learnableSkills = Array.isArray(skillsDocument.skills)
    ? skillsDocument.skills
    : [];
  const startingSkills = Array.isArray(skillsDocument.starting_skills)
    ? skillsDocument.starting_skills
    : [];

  const fireballLearnableEntries = learnableSkills.filter((skill) => {
    return isPlainObject(skill) && skill.id === "fireball";
  });
  if (fireballLearnableEntries.length > 0) {
    errors.push('data/skills.json.skills must not contain "fireball"; it belongs in starting_skills.');
  }

  const fireballStartingEntries = startingSkills.filter((skill) => {
    return isPlainObject(skill) && skill.id === "fireball";
  });
  if (fireballStartingEntries.length !== 1) {
    errors.push(
      `data/skills.json.starting_skills must contain exactly one fireball entry, got ${fireballStartingEntries.length}.`
    );
    return;
  }

  const fireball = fireballStartingEntries[0];
  if ("weapon_id" in fireball) {
    errors.push("data/skills.json.starting_skills fireball must not contain weapon_id.");
  }
  if (fireball.offer_in_upgrade_pool !== false) {
    errors.push("data/skills.json.starting_skills fireball must set offer_in_upgrade_pool: false.");
  }
}

function validateStartingSkillRuntimeSource() {
  const initializer = fs.readFileSync(characterRunInitializerPath, "utf8");
  const loadoutService = fs.readFileSync(characterLoadoutServicePath, "utf8");
  const skillManager = fs.readFileSync(skillManagerPath, "utf8");
  const weaponSkillBinding = fs.readFileSync(weaponSkillBindingPath, "utf8");
  const configureBody = extractFunctionBody(initializer, "func configure_starting_skills(player: Node) -> void:");

  if (!configureBody.includes("starting_skill_id")) {
    errors.push("CharacterRunInitializer.configure_starting_skills must resolve a character starting_skill_id.");
  }
  if (!configureBody.includes('skill_manager.call("add_skill", starting_skill_id)')) {
    errors.push("CharacterRunInitializer.configure_starting_skills must add the resolved starting_skill_id directly.");
  }
  if (/WeaponSkillBinding|bind_starting_skill/.test(configureBody)) {
    errors.push("CharacterRunInitializer.configure_starting_skills must not bind starting skills through WeaponSkillBinding.");
  }

  if (/weapon\.get\("starting_skill_id"/.test(loadoutService)) {
    errors.push("CharacterLoadoutService validation must not require weapon.starting_skill_id for run starting skills.");
  }
  if (/get_equipped_weapon_skill_id/.test(skillManager)) {
    errors.push("SkillManager must not authorize starting skills by current/equipped weapon skill id.");
  }
  if (/get_equipped_weapon_skill_id/.test(weaponSkillBinding)) {
    errors.push("WeaponSkillBinding compatibility path must not bind starting skills from equipped weapon skill id.");
  }
  if (!/starting_skill_id/.test(weaponSkillBinding) || !/is_starting_skill/.test(weaponSkillBinding)) {
    errors.push("WeaponSkillBinding compatibility path must resolve character/data starting skills.");
  }
}

function extractFunctionBody(text, signature) {
  const start = text.indexOf(signature);
  if (start < 0) return "";
  const bodyStart = text.indexOf("\n", start);
  if (bodyStart < 0) return "";
  const rest = text.slice(bodyStart + 1);
  const next = rest.search(/^func\s+/m);
  return next >= 0 ? rest.slice(0, next) : rest;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
