const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const branches = readJsonFile(path.join(root, "data", "weapon_branches.json")).branches || [];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertClose(actual, expected, message, epsilon = 0.0001) {
  assert(Math.abs(Number(actual) - expected) <= epsilon, `${message}: expected ${expected}, got ${actual}`);
}

const lava = branches.find((item) => item.id === "fire_staff_branch_lava");
assert(lava, "Missing fire_staff_branch_lava");

const levelFive = lava.level_path?.["5"] || {};
const rule = levelFive.special_rules?.protective_lava_ring_on_player_damaged;
assert(rule, "Missing Lava Lv5 protective lava ring rule");

assertClose(rule.radius, 130, "Lava Lv5 protective ring radius");
assertClose(rule.duration, 3, "Lava Lv5 protective ring duration");
assertClose(rule.same_source_cooldown, 12, "Lava Lv5 protective ring cooldown");
assertClose(rule.damage_taken_multiplier_add, -0.5, "Lava Lv5 protective ring damage reduction");
assert(String(levelFive.description || "").includes("持续 3s"), "Lava Lv5 description must mention 3s duration");
assert(String(levelFive.description || "").includes("伤害 -50%"), "Lava Lv5 description must mention -50% damage taken");

console.log("Lava Lv5 protective ring rule verified.");
