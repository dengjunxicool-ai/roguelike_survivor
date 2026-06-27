const path = require("path");
const { readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");

function readProjectFile(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const areaEffect = readProjectFile("scripts/combat/area_effect.gd");
assert(areaEffect.includes("var max_targets: int"), "AreaEffect must store a max_targets limit.");
assert(areaEffect.includes('params.get("max_targets"'), "AreaEffect.setup must read max_targets from params.");
assert(areaEffect.includes("damaged_count >= max_targets"), "AreaEffect tick damage must stop when max_targets is reached.");

const actionExecutor = readProjectFile("scripts/skills/skill_action_executor.gd");
assert(actionExecutor.includes('"max_targets": max_targets'), "SkillActionExecutor must pass max_targets to AreaEffect.");
assert(actionExecutor.includes('"%s_max_targets" % source_type'), "SkillActionExecutor must resolve source-specific max target modifiers.");

const modifierSource = readProjectFile("scripts/modifiers/modifier_source.gd");
assert(modifierSource.includes('if stat == "max_targets"'), "ModifierSource must support max_targets structured modifiers.");
assert(modifierSource.includes('"%s_max_targets" % object_type_for_targets'), "ModifierSource must map object max_targets modifiers.");

const specialRules = readProjectFile("scripts/skills/special_damage_rule_handler.gd");
assert(specialRules.includes('"max_targets": maxi(int(rule.get("max_targets"'), "Burning death explosion must pass max_targets to AreaEffect.");
assert(!specialRules.includes("16.0 * maxf(float(rule.get(\"damage_multiplier\""), "Burning death explosion must not hard-code fireball base damage.");

console.log("Area effect max target wiring verified.");
