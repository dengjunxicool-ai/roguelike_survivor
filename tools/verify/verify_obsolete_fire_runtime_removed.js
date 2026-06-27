const fs = require("fs");
const path = require("path");
const { readJsonFile, readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const skills = readJson("data/skills.json").skills || [];
for (const obsoleteId of ["mars_spark_missile", "fire_tornado", "soulburn"]) {
  assert(!skills.some((skill) => skill && skill.id === obsoleteId), `${obsoleteId} must not remain in data/skills.json`);
}

assert(!fs.existsSync(path.join(root, "tools", "verify_mars_spark_missile_skill_card.js")), "old mars spark missile skill-card verifier must be removed");

const devToolsCards = read("tools/verify/verify_devtools_god_skill_cards_static.js");
const upgradePool = read("tools/verify/verify_fire_skill_upgrade_pool.js");
const devToolsEntry = read("tools/verify/verify_fire_skill_dev_tools_entry_static.js");
for (const [label, text] of [
  ["devtools god skill cards", devToolsCards],
  ["fire skill upgrade pool", upgradePool],
  ["fire skill devtools entry", devToolsEntry],
]) {
  assert(!text.includes("60 fire"), `${label} must not assert old 60-card fire data`);
  assert(!text.includes("must include mars_spark_missile"), `${label} must not require mars_spark_missile`);
  assert(!text.includes("must remain the first fire learnable skill"), `${label} must not preserve old first-card ordering`);
}

console.log("[verify_obsolete_fire_runtime_removed] PASS");
