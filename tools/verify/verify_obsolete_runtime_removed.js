const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

const forbiddenExistingPaths = [
  "data/primary_attack.json",
  "data/weapons.json",
  "data/weapon_branches.json",
  "assets/weapon",
  "scripts/weapons",
  "scripts/ui/weapon_branch_modal.gd",
  "scripts/ui/weapon_branch_modal.gd.uid",
  "scripts/debug/full_weapon_branch_matrix_check.gd",
  "scripts/debug/full_weapon_branch_matrix_check.gd.uid",
  "scripts/debug/weapon_combat_scene_check.gd",
  "scripts/debug/weapon_combat_scene_check.gd.uid",
];

const scannedRoots = [
  "data",
  "scripts",
  "package.json",
];

const ignoredPathParts = [
  `${path.sep}tools${path.sep}archive${path.sep}`,
  `${path.sep}tools${path.sep}verify_obsolete_runtime_removed.js`,
];

const forbiddenPatterns = [
  /\bWEAPONS_PATH\b/,
  /\bWEAPON_BRANCHES_PATH\b/,
  /\bPRIMARY_ATTACK_PATH\b/,
  /\bget_weapon\b/,
  /\bget_weapon_pool\b/,
  /\bget_weapon_branch\b/,
  /\bget_weapon_branch_pool\b/,
  /\bget_weapons_for_character\b/,
  /\bselected_weapon_id\b/,
  /\bweapon_id\b/,
  /\ballowed_weapon_ids\b/,
  /\bWeaponEquipSystem\b/,
  /\bWeaponBranchSystem\b/,
  /\bWeaponSkillBinding\b/,
  /\bWeaponVisual\b/,
  /\bWeaponDefinition\b/,
  /\bWeaponRuntimeSlot\b/,
  /\bweapon_cast_stack\b/,
  /\bbranch_choice\b/,
  /\bgenerate_debug_full_weapon_options\b/,
  /res:\/\/scripts\/weapons\//,
  /res:\/\/data\/primary_attack\.json/,
  /res:\/\/data\/weapons\.json/,
  /res:\/\/data\/weapon_branches\.json/,
];

function exists(relativePath) {
  return fs.existsSync(path.join(root, relativePath));
}

function walk(target) {
  const absolute = path.join(root, target);
  if (!fs.existsSync(absolute)) return [];
  const stats = fs.statSync(absolute);
  if (stats.isFile()) return [absolute];
  const files = [];
  for (const entry of fs.readdirSync(absolute, { withFileTypes: true })) {
    const child = path.join(absolute, entry.name);
    if (entry.isDirectory()) {
      files.push(...walk(path.relative(root, child)));
    } else if (entry.isFile()) {
      files.push(child);
    }
  }
  return files;
}

function shouldScan(absolutePath) {
  if (ignoredPathParts.some((part) => absolutePath.includes(part))) return false;
  return [".gd", ".json", ".js"].includes(path.extname(absolutePath));
}

const errors = [];

for (const relativePath of forbiddenExistingPaths) {
  if (exists(relativePath)) {
    errors.push(`Obsolete weapon runtime path still exists: ${relativePath}`);
  }
}

for (const scanRoot of scannedRoots) {
  for (const absolutePath of walk(scanRoot)) {
    if (!shouldScan(absolutePath)) continue;
    const relativePath = path.relative(root, absolutePath).replaceAll(path.sep, "/");
    const text = readTextFile(absolutePath);
    const lines = text.split(/\r?\n/);
    lines.forEach((line, index) => {
      for (const pattern of forbiddenPatterns) {
        if (pattern.test(line)) {
          errors.push(`${relativePath}:${index + 1} contains obsolete weapon runtime token ${pattern}: ${line.trim()}`);
        }
      }
    });
  }
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}

console.log("Weapon runtime removal check passed.");
