const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function branch(id) {
  const branches = readJsonFile(path.join(root, "data", "weapon_branches.json")).branches || [];
  const result = branches.find((item) => item.id === id);
  assert(result, `Missing branch ${id}`);
  return result;
}

function level(branchDefinition, levelNumber) {
  const result = ((branchDefinition.level_path || {})[String(levelNumber)]) || {};
  assert(Object.keys(result).length > 0, `Missing ${branchDefinition.id} Lv${levelNumber}`);
  return result;
}

function createExplosion(config) {
  for (const event of config.events_added || []) {
    for (const action of event.actions || []) {
      if (action.type === "create_explosion") return action.params || {};
    }
  }
  return null;
}

for (const branchId of ["fire_staff_branch_burst", "fire_staff_branch_rapid"]) {
  const params = createExplosion(level(branch(branchId), 2));
  assert(params, `${branchId} Lv2 must create fireball explosion`);
  assert(
    Number(params.impact_target_damage_multiplier) === 0.5,
    `${branchId} fireball explosion must deal 50% explosion damage to the directly hit target`
  );
}

const contracts = read("tools/weapon_config_contracts.js");
assert(contracts.includes('"impact_target_damage_multiplier"'), "create_explosion config contract must allow impact_target_damage_multiplier");

const actionExecutor = read("scripts/skills/skill_action_executor.gd");
assert(
  actionExecutor.includes('"impact_target_id"') && actionExecutor.includes('"impact_target_damage_multiplier"'),
  "SkillActionExecutor must pass impact target identity and multiplier to AreaEffect"
);

const areaEffect = read("scripts/combat/area_effect.gd");
assert(areaEffect.includes("var impact_target_id: String"), "AreaEffect must store impact target id");
assert(areaEffect.includes("var impact_target_damage_multiplier: float"), "AreaEffect must store impact target damage multiplier");
assert(
  areaEffect.includes("func _get_adjusted_damage_for_target") &&
    areaEffect.includes("str(target.get_instance_id()) == impact_target_id") &&
    areaEffect.includes("impact_target_damage_multiplier"),
  "AreaEffect must scale damage only for the directly hit target"
);

console.log("Fireball impact target explosion half damage verified.");
