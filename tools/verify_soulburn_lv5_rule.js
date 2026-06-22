const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const branches = readJsonFile(path.join(root, "data", "weapon_branches.json")).branches || [];

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

const rule = level(branch("fire_staff_branch_soulburn"), 5).special_rules?.soulburn_burst_on_full_burn_direct_hit;

assert(rule, "Soulburn Lv5 burst rule must exist");
assert(rule.required_burn_stacks === 5, "Soulburn Lv5 must require 5 burn stacks");
assert(rule.consume_burn_stacks === "all", "Soulburn Lv5 must consume all burn stacks after triggering");
assertApprox(rule.normal_max_hp_damage, 0.03, "Soulburn Lv5 normal max HP percent");
assertApprox(rule.elite_max_hp_damage, 0.01, "Soulburn Lv5 elite max HP percent");
assertApprox(rule.boss_max_hp_damage, 0.0025, "Soulburn Lv5 Boss max HP percent");
assert(rule.can_crit === false, "Soulburn Lv5 burst must not crit");
assert(rule.uses_primary_attack_damage === false, "Soulburn Lv5 burst must not use primary attack damage");

const executorSource = fs.readFileSync(path.join(root, "scripts", "skills", "skill_special_rule_executor.gd"), "utf8");
assert(executorSource.includes("required_burn_stacks"), "Soulburn runtime must read required_burn_stacks");
assert(executorSource.includes("_consume_soulburn_burn_stacks"), "Soulburn runtime must consume burn stacks after triggering");

console.log("Soulburn Lv5 rule verified.");
