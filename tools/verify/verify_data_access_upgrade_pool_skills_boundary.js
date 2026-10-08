const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..", "..");
const source = fs.readFileSync(path.join(root, "scripts", "upgrades", "upgrade_pool.gd"), "utf8");

function assert(condition, message) {
  if (!condition) {
    console.error(`[verify_data_access_upgrade_pool_skills_boundary] FAIL ${message}`);
    process.exitCode = 1;
  }
}

function functionBody(name) {
  const marker = `func ${name}`;
  const start = source.indexOf(marker);
  if (start < 0) return "";
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next < 0 ? source.length : next);
}

const eligibility = functionBody("_is_learn_skill_upgrade_available(");
const debugLookup = functionBody("_is_debug_god_skill(");
const debugPool = functionBody("_get_debug_god_skill_definitions(");

assert(eligibility.includes("GameData.get_skill(skill_id)"), "normal eligibility must use GameData.get_skill");
assert(!eligibility.includes("_get_debug_skill_definition_from_file"), "normal eligibility must not repeat the skill JSON fallback");
assert(debugLookup.includes("GameData.get_skill(skill_id)"), "debug single-skill lookup must use GameData.get_skill");
assert(!debugLookup.includes("_get_debug_skill_definition_from_file"), "debug single-skill lookup must not repeat the skill JSON fallback");
assert(debugPool.includes("GameData.get_skill_pool()"), "debug skill pool must use GameData.get_skill_pool");
assert(!source.includes("JsonDataLoaderScript"), "UpgradePool must not depend on JsonDataLoader");
assert(!source.includes("DataPathsScript"), "UpgradePool must not own data paths");
assert(!source.includes("SKILLS_DATA_PATH"), "UpgradePool must not own the skills JSON path");
assert(!source.includes("_load_debug_skills_document"), "UpgradePool must not retain a direct debug document loader");
assert(!source.includes("_get_debug_skill_definition_from_file"), "UpgradePool must not retain a duplicate skill lookup");

if (!process.exitCode) {
  console.log("[verify_data_access_upgrade_pool_skills_boundary] PASS");
}
