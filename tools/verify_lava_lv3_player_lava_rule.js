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

const lavaLv3 = level(branch("fire_staff_branch_lava"), 3).special_rules?.player_lava_on_nearby_fireball_hit;
assert(lavaLv3, "Lava Lv3 player lava rule must exist");
assert(lavaLv3.spawn_position === "player", "Lava Lv3 small lava must spawn at player");
assertApprox(lavaLv3.near_player_radius, 160, "Lava Lv3 nearby trigger radius");
assertApprox(lavaLv3.duration, 2.0, "Lava Lv3 small lava duration");
assertApprox(lavaLv3.tick_interval, 0.5, "Lava Lv3 small lava tick interval");
assertApprox(lavaLv3.damage_from_fireball_base, 0.2, "Lava Lv3 small lava fireball damage ratio");
assertApprox(lavaLv3.same_source_cooldown, 3.0, "Lava Lv3 small lava cooldown");

const designBranch = (design.branches || []).find((item) => item.branch_id === "fire_staff_branch_lava_ring");
assert(designBranch, "Fire staff lava ring design branch must exist");
const designText = [
  designBranch.levels?.["3"],
  designBranch.level_path?.["3"]?.summary,
  designBranch.level_path?.["3"]?.ui_feedback?.readable_effect
].join("\n");
for (const fragment of ["持续 2s", "0.5s tick", "火球伤害 20%", "3.0s CD"]) {
  assert(designText.includes(fragment), `Lava Lv3 design text must mention ${fragment}`);
}

const handlerSource = fs.readFileSync(path.join(root, "scripts", "skills", "special_damage_rule_handler.gd"), "utf8");
assert(handlerSource.includes('active_rule.get("duration"'), "Lava runtime must read duration from the active rule");
assert(handlerSource.includes('active_rule.get("tick_interval"'), "Lava runtime must read tick_interval from the active rule");
assert(handlerSource.includes('active_rule.get("damage_from_fireball_base"'), "Lava runtime must read damage ratio from the active rule");
assert(handlerSource.includes('lava_packet["source_type"] = "area"'), "Lava runtime must put source_type on the lava damage packet");
assert(handlerSource.includes('lava.get("same_source_cooldown"'), "Lava runtime must read cooldown from the lava rule");
assert(handlerSource.includes('player_lava_on_nearby_fireball_hit" %'), "Lava runtime cooldown must be keyed by the effect");
assert(!handlerSource.includes('String(context.get("skill_id", "fire_staff"))'), "Lava Lv3 effect cooldown must not be keyed by skill_id/source");

console.log("Lava Lv3 player lava rule verified.");
