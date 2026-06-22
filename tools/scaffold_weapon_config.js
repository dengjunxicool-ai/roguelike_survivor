const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { readJsonFile, writeJsonFile } = require("./json_file");
const { buildWeaponScaffold, listArchetypes } = require("./weapon_authoring_templates");

const root = path.resolve(__dirname, "..");
const DATA_FILES = {
  characters: "data/characters.json",
  characterTexts: "data/character_texts.json",
  weapons: "data/weapons.json",
  primaryAttacks: "data/primary_attack.json",
  branches: "data/weapon_branches.json",
  combatObjects: "data/combat_objects.json",
};

process.stdout.on("error", (error) => {
  if (error.code === "EPIPE") process.exit(0);
  throw error;
});

function parseArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith("--")) continue;
    const key = toCamelCase(arg.slice(2));
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      result[key] = true;
      continue;
    }
    result[key] = next;
    index += 1;
  }
  return result;
}

function toCamelCase(value) {
  return value.replace(/-([a-z])/g, (_, char) => char.toUpperCase());
}

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function writeJson(relativePath, value) {
  writeJsonFile(path.join(root, relativePath), value);
}

function readRawFiles(filesByKey) {
  const result = {};
  for (const [key, relativePath] of Object.entries(filesByKey)) {
    result[key] = fs.readFileSync(path.join(root, relativePath), "utf8");
  }
  return result;
}

function restoreRawFiles(rawFiles) {
  for (const [key, content] of Object.entries(rawFiles)) {
    fs.writeFileSync(path.join(root, DATA_FILES[key]), content, "utf8");
  }
}

function validateOptions(options) {
  const errors = [];
  if (!options.weaponId) errors.push("Missing --weapon-id.");
  if (!options.characterId) errors.push("Missing --character-id.");
  if (!options.displayName) errors.push("Missing --display-name.");
  if (!options.archetype) options.archetype = "projectile";
  if (!listArchetypes().includes(options.archetype)) {
    errors.push(`Unknown --archetype ${options.archetype}. Use one of: ${listArchetypes().join(", ")}`);
  }
  if (options.weaponId && !/^[a-z0-9_]+$/.test(options.weaponId)) {
    errors.push("--weapon-id must use lowercase snake_case.");
  }
  if (options.startingSkillId && !/^[a-z0-9_]+$/.test(options.startingSkillId)) {
    errors.push("--starting-skill-id must use lowercase snake_case.");
  }
  return errors;
}

function readDataDocuments() {
  return {
    characters: readJson(DATA_FILES.characters),
    characterTexts: readJson(DATA_FILES.characterTexts),
    weapons: readJson(DATA_FILES.weapons),
    primaryAttacks: readJson(DATA_FILES.primaryAttacks),
    branches: readJson(DATA_FILES.branches),
    combatObjects: readJson(DATA_FILES.combatObjects),
  };
}

function collectExistingIds(documents) {
  const weapons = documents.weapons.weapons || [];
  const primaryAttacks = documents.primaryAttacks.primary_attacks || [];
  const branches = documents.branches.branches || [];
  const combatObjects = documents.combatObjects.combat_objects || [];
  const characters = documents.characters.characters || [];
  return {
    weapons: new Set(weapons.map((item) => String(item.id))),
    primaryAttacks: new Set(primaryAttacks.map((item) => String(item.id))),
    branches: new Set(branches.map((item) => String(item.id))),
    combatObjects: new Set(combatObjects.map((item) => String(item.id))),
    characters: new Map(characters.map((item) => [String(item.id), item])),
  };
}

function collectIssues(scaffold, indexes) {
  const issues = [];
  if (indexes.weapons.has(scaffold.weapon.id)) issues.push(`Weapon already exists: ${scaffold.weapon.id}`);
  if (!indexes.characters.has(scaffold.weapon.character_id)) issues.push(`Character does not exist yet: ${scaffold.weapon.character_id}`);
  if (indexes.primaryAttacks.has(scaffold.primaryAttack.id)) issues.push(`Primary attack already exists: ${scaffold.primaryAttack.id}`);
  if (indexes.combatObjects.has(scaffold.combatObject.id)) issues.push(`Combat object already exists: ${scaffold.combatObject.id}`);
  for (const branch of scaffold.branches) {
    if (indexes.branches.has(branch.id)) issues.push(`Branch already exists: ${branch.id}`);
  }
  return issues;
}

function applyScaffold(scaffold, documents) {
  const character = (documents.characters.characters || []).find((item) => String(item.id) === scaffold.weapon.character_id);
  if (character) {
    if (!Array.isArray(character.allowed_weapon_ids)) character.allowed_weapon_ids = [];
    if (!character.allowed_weapon_ids.map(String).includes(scaffold.weapon.id)) {
      character.allowed_weapon_ids.push(scaffold.weapon.id);
    }
  }

  documents.weapons.weapons.push(scaffold.weapon);
  if (!documents.characterTexts.weapons) documents.characterTexts.weapons = {};
  documents.characterTexts.weapons[scaffold.weapon.id] = scaffold.weaponText;
  documents.combatObjects.combat_objects.push(scaffold.combatObject);
  documents.primaryAttacks.primary_attacks.push(scaffold.primaryAttack);
  documents.branches.branches.push(...scaffold.branches);
}

function writeDataDocuments(documents) {
  writeJson(DATA_FILES.characters, documents.characters);
  writeJson(DATA_FILES.characterTexts, documents.characterTexts);
  writeJson(DATA_FILES.weapons, documents.weapons);
  writeJson(DATA_FILES.combatObjects, documents.combatObjects);
  writeJson(DATA_FILES.primaryAttacks, documents.primaryAttacks);
  writeJson(DATA_FILES.branches, documents.branches);
}

function runWeaponAuthoringPipeline() {
  return spawnSync(process.execPath, ["tools/validate_weapon_authoring_pipeline.js"], {
    cwd: root,
    encoding: "utf8",
  });
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function runSelfTest() {
  const documents = clone(readDataDocuments());
  const initialCounts = {
    weapons: documents.weapons.weapons.length,
    weaponTexts: Object.keys(documents.characterTexts.weapons || {}).length,
    primaryAttacks: documents.primaryAttacks.primary_attacks.length,
    branches: documents.branches.branches.length,
    combatObjects: documents.combatObjects.combat_objects.length,
  };

  for (const archetype of listArchetypes()) {
    const scaffold = buildWeaponScaffold({
      weaponId: `self_test_${archetype}`,
      characterId: "mage",
      displayName: `Self Test ${archetype}`,
      archetype,
      element: "arcane",
    });
    const issues = collectIssues(scaffold, collectExistingIds(documents));
    if (issues.length) {
      throw new Error(`${archetype} self-test scaffold has issues: ${issues.join("; ")}`);
    }
    applyScaffold(scaffold, documents);
  }

  const archetypeCount = listArchetypes().length;
  assertCount(documents.weapons.weapons.length, initialCounts.weapons + archetypeCount, "weapons");
  assertCount(Object.keys(documents.characterTexts.weapons || {}).length, initialCounts.weaponTexts + archetypeCount, "weapon texts");
  assertCount(documents.primaryAttacks.primary_attacks.length, initialCounts.primaryAttacks + archetypeCount, "primary_attacks");
  assertCount(documents.branches.branches.length, initialCounts.branches + archetypeCount * 4, "branches");
  assertCount(documents.combatObjects.combat_objects.length, initialCounts.combatObjects + archetypeCount, "combat_objects");

  console.log(`Weapon scaffold write self-test passed. archetypes=${archetypeCount}`);
}

function assertCount(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label} count mismatch: expected ${expected}, got ${actual}`);
  }
}

function printUsage() {
  console.log(`Usage:
node tools\\scaffold_weapon_config.js --weapon-id crystal_wand --character-id mage --display-name "Crystal Wand" --archetype projectile --element arcane --on-hit-status arcane_mark
node tools\\scaffold_weapon_config.js --weapon-id crystal_wand --character-id mage --display-name "Crystal Wand" --archetype projectile --element arcane --on-hit-status arcane_mark --write
node tools\\scaffold_weapon_config.js --self-test

Archetypes: ${listArchetypes().join(", ")}

Common options:
  --starting-skill-id <id>
  --description <text>
  --damage <number>
  --cooldown <number>
  --range <number>
  --targeting <mode>
  --damage-type <type>
  --color <r,g,b,a>
  --write
`);
}

function printSection(title, value) {
  console.log(`\n## ${title}`);
  console.log(JSON.stringify(value, null, 2));
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help || options.h) {
    printUsage();
    return;
  }
  if (options.listArchetypes) {
    console.log(listArchetypes().join("\n"));
    return;
  }
  if (options.selfTest) {
    runSelfTest();
    return;
  }

  const errors = validateOptions(options);
  if (errors.length) {
    for (const error of errors) console.error(`ERROR ${error}`);
    printUsage();
    process.exitCode = 1;
    return;
  }

  const scaffold = buildWeaponScaffold(options);
  const documents = readDataDocuments();
  const issues = collectIssues(scaffold, collectExistingIds(documents));
  for (const issue of issues) console.warn(`WARN ${issue}`);

  if (options.write) {
    if (issues.length) {
      console.error("ERROR Refusing to write scaffold while blocking issues exist.");
      process.exitCode = 1;
      return;
    }

    const rawFiles = readRawFiles(DATA_FILES);
    applyScaffold(scaffold, documents);
    writeDataDocuments(documents);
    const validation = runWeaponAuthoringPipeline();
    if (validation.status !== 0) {
      restoreRawFiles(rawFiles);
      process.stdout.write(validation.stdout || "");
      process.stderr.write(validation.stderr || "");
      console.error("ERROR Validation failed after writing scaffold. Restored original data files.");
      process.exitCode = validation.status || 1;
      return;
    }

    process.stdout.write(validation.stdout || "");
    console.log(`Weapon scaffold written: ${scaffold.weapon.id}`);
    return;
  }

  console.log("# Weapon Config Scaffold");
  console.log("Paste these snippets into the matching data files, then run node tools\\validate_weapon_authoring_pipeline.js.");
  console.log(`\nCharacter allowlist: add "${scaffold.characterAllowedWeaponId}" to data/characters.json ${options.characterId}.allowed_weapon_ids.`);
  printSection("data/weapons.json item", scaffold.weapon);
  printSection("data/character_texts.json weapons item", { [scaffold.weapon.id]: scaffold.weaponText });
  printSection("data/combat_objects.json item", scaffold.combatObject);
  printSection("data/primary_attack.json base item", scaffold.primaryAttack);
  printSection("data/weapon_branches.json items", scaffold.branches);
}

main();
