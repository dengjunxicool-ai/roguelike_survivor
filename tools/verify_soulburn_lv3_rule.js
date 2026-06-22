const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const branches = readJsonFile(path.join(root, "data", "weapon_branches.json")).branches || [];
const statuses = readJsonFile(path.join(root, "data", "status_effects.json")).statuses || [];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertApprox(actual, expected, message, tolerance = 0.0001) {
  if (Math.abs(Number(actual) - expected) > tolerance) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

function branch(id) {
  const result = branches.find((item) => item.id === id);
  assert(result, `Missing branch ${id}`);
  return result;
}

function level(branchDefinition, levelNumber) {
  const result = branchDefinition.level_path?.[String(levelNumber)];
  assert(result, `Missing ${branchDefinition.id} Lv${levelNumber}`);
  return result;
}

function modifier(config, expected) {
  return (config.modifiers || []).find((item) => {
    if (!item || item.stat !== expected.stat || item.op !== expected.op) return false;
    const scope = item.scope || {};
    for (const [key, value] of Object.entries(expected.scope || {})) {
      const actual = scope[key];
      if (Array.isArray(value)) {
        if (!Array.isArray(actual) || value.some((entry) => !actual.includes(entry))) return false;
      } else if (actual !== value) {
        return false;
      }
    }
    return true;
  }) || null;
}

const soul = branch("fire_staff_branch_soulburn");
const lv3 = level(soul, 3);
const conversion = lv3.special_rules?.soul_ember_to_burn_on_full_stack_hit;

assert(conversion, "Soulburn Lv3 conversion rule must exist");
assert(conversion.status_id === "soul_ember", "Soulburn Lv3 converts soul_ember");
assert(conversion.required_stacks === 2, "Soulburn Lv3 must convert every 2 soul_ember");
assert(conversion.consume_stacks === 2, "Soulburn Lv3 must consume 2 soul_ember per conversion");
assert(conversion.apply_burn_stacks === 1, "Soulburn Lv3 must apply 1 burn per conversion");
assert(conversion.burn_max_stacks === 5, "Soulburn Lv3 burn cap must be 5");

const directPenalty = modifier(lv3, {
  stat: "damage",
  op: "multiplier_add",
  scope: { domain: "damage", damage_origin: ["primary_attack"] }
});
assert(directPenalty, "Soulburn Lv3 direct damage penalty modifier is missing");
assertApprox(directPenalty.value, -0.15, "Soulburn Lv3 direct damage penalty");

const burnDamage = modifier(lv3, {
  stat: "status_damage",
  op: "multiplier_add",
  scope: { domain: "status", status_id: ["burn"] }
});
assert(burnDamage, "Soulburn Lv3 burn damage modifier is missing");
assertApprox(burnDamage.value, 0.3, "Soulburn Lv3 burn damage bonus");

const burn = statuses.find((item) => item.id === "burn");
assert(burn && burn.max_stacks === 5, "Global burn max stacks must stay 5 for Soulburn Lv3");

const executorSource = fs.readFileSync(path.join(root, "scripts", "skills", "skill_special_rule_executor.gd"), "utf8");
assert(executorSource.includes("conversion_count"), "Soulburn runtime must convert every full pair, not only once");
assert(executorSource.includes("burn_max_stacks"), "Soulburn runtime must pass the configured burn cap");

console.log("Soulburn Lv3 rule verified.");
