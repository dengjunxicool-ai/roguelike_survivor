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

const lv4 = level(branch("fire_staff_branch_soulburn"), 4);
const burnMax = modifier(lv4, {
  stat: "status_max_stacks",
  op: "add",
  scope: { domain: "status", status_id: ["burn"] }
});
const bossBurnMax = modifier(lv4, {
  stat: "status_max_stacks",
  op: "add",
  scope: { domain: "status", status_id: ["burn"], target_type: ["boss"] }
});
const duration = modifier(lv4, {
  stat: "status_duration",
  op: "add",
  scope: { domain: "status", status_id: ["burn"] }
});

assert(burnMax, "Soulburn Lv4 normal burn max stack modifier is missing");
assertApprox(burnMax.value, 2, "Soulburn Lv4 normal burn max stack add");
assert(bossBurnMax, "Soulburn Lv4 Boss burn max stack modifier is missing");
assertApprox(bossBurnMax.value, 1, "Soulburn Lv4 Boss burn max stack add");
assert(duration, "Soulburn Lv4 burn duration modifier is missing");
assertApprox(duration.value, 1, "Soulburn Lv4 burn duration add");

const executorSource = fs.readFileSync(path.join(root, "scripts", "skills", "skill_special_rule_executor.gd"), "utf8");
assert(executorSource.includes("func _get_burn_base_max_stacks"), "Soulburn runtime must use the burn base max stack when applying Lv4 additions");
assert(executorSource.includes("func _get_burn_base_damage"), "Soulburn runtime must use the burn base damage when applying burn damage modifiers");
assert(executorSource.includes("func _get_burn_status_params") && executorSource.includes("var burn_params: Dictionary = _get_burn_status_params"), "Soulburn conversion must route through burn status parameter adjustment");

console.log("Soulburn Lv4 rule verified.");
