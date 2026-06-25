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
assert(definition.includes('data.get("fusion_school"'), "SkillDefinition must read fusion_school");
assert(definition.includes('data.get("skill_type"'), "SkillDefinition must read skill_type");
assert(definition.includes('data.get("type"'), "SkillDefinition must preserve type fallback");
assert(definition.includes('data.get("rarity"'), "SkillDefinition must read rarity");
assert(definition.includes('data.get("exclusive_group"'), "SkillDefinition must read exclusive_group");
assert(definition.includes('data.get("mechanic_family"'), "SkillDefinition must read mechanic_family");
assert(definition.includes('data.get("offer_rule"'), "SkillDefinition must read offer_rule");
assert(definition.includes('data.get("trigger_rules"'), "SkillDefinition must read trigger_rules");
assert(definition.includes('data.get("effects"'), "SkillDefinition must read effects");
assert(definition.includes("func _category_to_skill_type"), "SkillDefinition must preserve category fallback");
assert(definition.includes('"active":') && definition.includes('return "cast"'), "SkillDefinition must map active category to cast");
assert(definition.includes('"passive":') && definition.includes('return "passive"'), "SkillDefinition must map passive category to passive");
assert(definition.includes("return value"), "SkillDefinition must pass through unknown categories");

for (const field of ["school", "fusion_school", "skill_type", "exclusive_group"]) {
  assert(instance.includes(`var ${field}`), `SkillInstance must expose ${field}`);
  assert(instance.includes(`${field} = `), `SkillInstance must assign ${field}`);
  assert(instance.includes(`definition.get("${field}")`), `SkillInstance must mirror ${field} from definition`);
}

console.log("[verify_skill_definition_schema] PASS");
