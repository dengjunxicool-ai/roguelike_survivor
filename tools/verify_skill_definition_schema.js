const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const definition = read("scripts/skills/skill_definition.gd");
const instance = read("scripts/skills/skill_instance.gd");

for (const field of ["name", "school", "fusion_school", "skill_type", "rarity", "exclusive_group", "mechanic_family", "offer_rule", "trigger_rules", "effects"]) {
  assert(definition.includes(`var ${field}`), `SkillDefinition must expose ${field}`);
}

assert(definition.includes('data.get("name"'), "SkillDefinition must read name");
assert(definition.includes('data.get("school"'), "SkillDefinition must read school");
assert(definition.includes('data.get("trigger_rules"'), "SkillDefinition must read trigger_rules");
assert(definition.includes('data.get("effects"'), "SkillDefinition must read effects");
assert(definition.includes("func _category_to_skill_type"), "SkillDefinition must preserve category fallback");

for (const field of ["school", "fusion_school", "skill_type", "exclusive_group"]) {
  assert(instance.includes(`var ${field}`), `SkillInstance must expose ${field}`);
}

console.log("[verify_skill_definition_schema] PASS");
