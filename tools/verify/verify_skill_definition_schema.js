const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const definition = read("scripts/skills/skill_definition.gd");
const instance = read("scripts/skills/skill_instance.gd");

for (const field of ["display_name", "slot_category", "school", "fusion_school", "skill_type", "rarity", "exclusive_group", "mechanic_family", "offer_rule", "trigger_rules", "effects"]) {
  assert(definition.includes(`var ${field}`), `SkillDefinition must expose ${field}`);
}

assert(definition.includes('data.get("display_name"'), "SkillDefinition must read display_name");
assert(definition.includes('data.get("school"'), "SkillDefinition must read school");
assert(definition.includes('data.get("fusion_school"'), "SkillDefinition must read fusion_school");
assert(definition.includes('data.get("skill_type"'), "SkillDefinition must read skill_type");
assert(!definition.includes('data.get("type"'), "SkillDefinition must reject type alias");
assert(definition.includes('data.get("rarity"'), "SkillDefinition must read rarity");
assert(definition.includes('data.get("exclusive_group"'), "SkillDefinition must read exclusive_group");
assert(definition.includes('data.get("mechanic_family"'), "SkillDefinition must read mechanic_family");
assert(definition.includes('data.get("offer_rule"'), "SkillDefinition must read offer_rule");
assert(definition.includes('data.get("trigger_rules"'), "SkillDefinition must read trigger_rules");
assert(definition.includes('data.get("effects"'), "SkillDefinition must read effects");
assert(definition.includes('data.get("slot_category"'), "SkillDefinition must read explicit slot_category");
assert(!definition.includes("func _category_to_skill_type"), "SkillDefinition must not infer skill_type from category");

for (const field of ["school", "fusion_school", "skill_type", "exclusive_group"]) {
  assert(instance.includes(`var ${field}`), `SkillInstance must expose ${field}`);
  assert(instance.includes(`${field} = `), `SkillInstance must assign ${field}`);
  assert(instance.includes(`definition.get("${field}")`), `SkillInstance must mirror ${field} from definition`);
}

console.log("[verify_skill_definition_schema] PASS");
