const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const branches = readJsonFile(path.join(root, "data", "weapon_branches.json")).branches || [];
const design = readJsonFile(path.join(root, "docs", "weapon_design_configs", "fire_staff.json"));

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

const lavaLv4 = level(branch("fire_staff_branch_lava"), 4).special_rules?.lava_slow;
assert(lavaLv4, "Lava Lv4 slow rule must exist");
assert(lavaLv4.status_id === "slow", "Lava Lv4 must apply slow");
assertApprox(lavaLv4.slow_percent, 0.30, "Lava Lv4 slow percent");
assertApprox(lavaLv4.boss_slow_percent, 0.15, "Lava Lv4 Boss slow percent");

const designBranch = (design.branches || []).find((item) => item.branch_id === "fire_staff_branch_lava_ring");
assert(designBranch, "Fire staff lava ring design branch must exist");
const designText = [
  designBranch.levels?.["4"],
  designBranch.level_path?.["4"]?.summary,
  designBranch.level_path?.["4"]?.ui_feedback?.readable_effect
].join("\n");
for (const fragment of ["-30%", "Boss 转为 -15% slow"]) {
  assert(designText.includes(fragment), `Lava Lv4 design text must mention ${fragment}`);
}

const handlerSource = fs.readFileSync(path.join(root, "scripts", "skills", "special_damage_rule_handler.gd"), "utf8");
assert(handlerSource.includes('slow_rule.get("slow_percent", 0.18)'), "Lava runtime must pass slow_percent from lava_slow");
assert(handlerSource.includes('slow_rule.get("boss_slow_percent", 0.08)'), "Lava runtime must pass boss_slow_percent from lava_slow");

console.log("Lava Lv4 slow rule verified.");
