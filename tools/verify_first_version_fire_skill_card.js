const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, ""));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function findById(items, id, label) {
  const item = (items || []).find((entry) => entry && entry.id === id);
  assert(item, `${label} ${id} must exist`);
  return item;
}

const skills = readJson("data/skills.json").skills || [];
const firstSkill = findById(skills, "fire_attack_searing", "fire skill");
assert(firstSkill.school === "fire", "fire_attack_searing must be a fire school skill");
assert(firstSkill.type === "attack", "fire_attack_searing must use the new attack type");
assert(firstSkill.exclusive_group === "attack_school", "fire_attack_searing must occupy attack_school");
assert(firstSkill.offer_rule && firstSkill.offer_rule.required_schools?.includes("fire"), "fire_attack_searing must require fire school access");
assert((firstSkill.trigger_rules || []).some((rule) => rule.trigger === "attack_hit"), "fire_attack_searing must react to attack_hit");
assert((firstSkill.effects || []).some((effect) => effect.type === "add_modifier"), "fire_attack_searing must carry its passive attack modifier");

const fusion = findById(skills, "fusion_fire_frost_steam_mist", "fire fusion skill");
assert(fusion.type === "fusion", "fusion_fire_frost_steam_mist must use fusion type");
assert(fusion.offer_rule?.required_min_skill_count?.fire >= 2, "fire-led fusions must require at least two fire skills");
assert(fusion.offer_rule?.required_min_skill_count?.frost >= 1, "fire+frost fusion must require frost access");

for (const obsoleteId of ["mars_spark_missile", "fire_tornado", "soulburn"]) {
  assert(!skills.some((skill) => skill.id === obsoleteId), `${obsoleteId} must not remain as a first-version fire skill card`);
}

console.log("[verify_first_version_fire_skill_card] PASS");
