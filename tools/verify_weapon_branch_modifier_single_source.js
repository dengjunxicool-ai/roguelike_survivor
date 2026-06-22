const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function readJson(relativePath) {
  return JSON.parse(readText(relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function main() {
  const branchSystem = readText("scripts/weapons/weapon_branch_system.gd");
  assert(
    branchSystem.includes('skill_instance.set("runtime_modifiers", runtime_modifiers)'),
    "WeaponBranchSystem must keep branch modifiers on the weapon skill instance"
  );
  assert(
    !branchSystem.includes('runtime.call("add_runtime_modifiers", modifiers)'),
    "WeaponBranchSystem must not also register the same flat branch modifiers on CharacterRuntime"
  );

  const branches = readJson("data/weapon_branches.json").branches || [];
  const globalDomains = new Set(["player", "movement", "pickup", "economy", "enemy_spawn", "progression"]);
  for (const branch of branches) {
    for (const [level, config] of Object.entries(branch.level_path || {})) {
      for (const modifier of config.modifiers || []) {
        const domain = modifier?.scope?.domain || "";
        assert(
          !globalDomains.has(domain),
          `${branch.id} Lv${level} uses global modifier domain ${domain}; route it explicitly instead of duplicating skill modifiers`
        );
      }
    }
  }

  console.log("Weapon branch modifier single-source contract verified.");
}

main();
