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

function findSkill(skills, id) {
  const skill = skills.find((entry) => entry && entry.id === id);
  assert(skill, `${id} must exist`);
  return skill;
}

function flatEffects(skill) {
  return [
    ...(skill.effects || []),
    ...(skill.trigger_rules || []).flatMap((rule) => rule.effects || []),
  ];
}

const skills = readJson("data/skills/skills.json").skills || [];
const frostSkills = skills.filter((skill) => skill && skill.school === "frost" && (skill.fusion_school ?? null) === null);
assert(frostSkills.length === 14, "first frost version must contain exactly 14 frost skills");
for (const skill of frostSkills) {
  assert(!Object.prototype.hasOwnProperty.call(skill, "effect_description"), `${skill.id} must use description instead of effect_description`);
  assert(Array.isArray(skill.trigger_rules), `${skill.id} must define trigger_rules`);
  assert(Array.isArray(skill.effects), `${skill.id} must define effects`);
  assert(flatEffects(skill).length > 0, `${skill.id} must have runtime effects`);
}

const attack = findSkill(skills, "frost_attack_frostbite");
assert(attack.type === "attack", "frost attack must be an attack skill");
assert(attack.exclusive_group === "attack_school", "frost attack must replace the starting attack school");
const attackModifierCount = flatEffects(attack).filter((effect) => effect && effect.type === "add_modifier" && String(effect.modifier || "").includes("attack_damage")).length;
assert(attackModifierCount === 1, "frost attack must not stack multiple attack damage modifiers");
assert(JSON.stringify(attack).includes("chilled"), "frost attack must apply chilled");

const dash = findSkill(skills, "frost_dash_ice_shard_assault");
assert(dash.type === "dash", "frost dash must be a dash skill");
assert(dash.exclusive_group === "dash_school", "frost dash must replace the dash school");
assert((dash.trigger_rules || []).some((rule) => rule.trigger === "dash_start" || rule.trigger === "dash_tick" || rule.trigger === "dash_end"), "frost dash must use dash trigger rules");
assert(!JSON.stringify(dash).includes("collision_mask") && !JSON.stringify(dash).includes("collision_layer"), "frost dash data must not alter collision settings");

const godotTexts = [
  "scripts/debug/dev_debug_panel.gd",
  "scripts/upgrades/upgrade_pool.gd",
  "scripts/game/game_data.gd",
  "scripts/summons/summon_definition.gd",
  "scripts/summons/summon_targeting_component.gd",
  "scripts/summons/summon_movement_component.gd",
  "scripts/summons/summon_attack_component.gd",
].map(read).join("\n");
assert(!godotTexts.includes('String(skill.get("'), "shared runtime must not use known bad String(skill.get(...)) conversion pattern");
assert(!godotTexts.includes('StringName(String(skill.get("'), "shared runtime must not wrap skill.get(...) with StringName(String(...))");
assert(!godotTexts.includes('String(god_id)'), "shared runtime must not use known bad String(god_id) conversion pattern");

console.log("[verify_frost_no_fire_regression_contract] PASS");
