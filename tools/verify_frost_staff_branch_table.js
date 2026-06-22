const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, ""));
}

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertApprox(actual, expected, message, epsilon = 0.0001) {
  assert(Math.abs(Number(actual) - expected) <= epsilon, `${message}: expected ${expected}, got ${actual}`);
}

function branch(id) {
  const result = branches.find((item) => item.id === id);
  assert(result, `Missing branch ${id}`);
  return result;
}

function level(branchData, value) {
  const result = branchData.level_path?.[String(value)];
  assert(result, `Missing ${branchData.id} Lv${value}`);
  return result;
}

function modifier(levelData, stat, op, predicate = () => true) {
  return (levelData.modifiers || []).find((item) => item.stat === stat && item.op === op && predicate(item));
}

function action(levelData, actionType) {
  for (const event of levelData.events_added || []) {
    const found = (event.actions || []).find((item) => item.type === actionType);
    if (found) return found;
  }
  return null;
}

function status(id) {
  return statuses.find((item) => item.id === id);
}

const branches = readJson("data/weapon_branches.json").branches || [];
const attacks = readJson("data/primary_attack.json").primary_attacks || [];
const statuses = readJson("data/status_effects.json").statuses || [];

const primary = attacks.find((item) => item.id === "hailstorm");
assert(primary, "hailstorm must exist");
assertApprox(primary.base.damage, 10, "hailstorm base damage");
assertApprox(primary.base.cooldown, 1.5, "hailstorm attack interval");
assertApprox(primary.base.range, 540, "hailstorm range");
assertApprox(primary.base.projectile_count, 3, "hailstorm projectile count");
const projectile = primary.events[0].actions.find((entry) => entry.type === "spawn_projectiles_at_targets");
assert(projectile, "hailstorm must spawn target-selected projectiles");
assert(projectile.params.trajectory_mode === "curve", "hailstorm projectiles must arc to selected targets");
assert(!projectile.params.status_on_hit, "hailstorm base must not apply a status");

const storm = branch("frost_staff_branch_dense");
assertApprox(modifier(level(storm, 2), "projectile_count", "add").value, 1, "Storm Lv2 hail count add");
assert(!modifier(level(storm, 2), "damage", "multiplier_add"), "Storm Lv2 must not reduce hail damage");
const splash = action(level(storm, 3), "create_explosion");
assert(splash && splash.params.radius === 82 && splash.params.max_targets === 4, "Storm Lv3 splash");
assertApprox(splash.params.damage_multiplier, 0.35, "Storm Lv3 splash damage");
assertApprox(modifier(level(storm, 4), "attack_speed", "multiplier_add").value, 0.1111, "Storm Lv4 interval");
const stormLv5 = level(storm, 5).special_rules.storm_hail_every_n_casts;
assert(stormLv5 && stormLv5.cast_interval === 4 && stormLv5.max_targets_add === 2 && stormLv5.boss_damage_multiplier === 0.8, "Storm Lv5");

const core = branch("frost_staff_branch_lockdown");
const coreLv2 = level(core, 2).special_rules.frost_lock_on_elite_boss_direct_hit;
assert(coreLv2 && coreLv2.status_id === "frost_lock" && coreLv2.max_stacks === 4, "Core Lv2 frost_lock");
assertApprox(coreLv2.duration, 5, "Core Lv2 frost_lock duration");
assertApprox(coreLv2.same_target_cooldown, 0.6, "Core Lv2 frost_lock cooldown");
const coreLv3 = level(core, 3).special_rules.frost_lock_bonus_hit;
assert(coreLv3 && coreLv3.required_stacks === 4 && coreLv3.consume_stacks === 4 && coreLv3.amount === 14, "Core Lv3 frost_lock bonus");
assertApprox(coreLv3.same_target_cooldown, 2, "Core Lv3 cooldown");
assert(coreLv3.boss_converts_to_poise === true, "Core Lv3 Boss poise");
assert(level(core, 4).special_rules.boss_poise_upgrade.duration_add === 2, "Core Lv4 poise duration");
assert(level(core, 5).special_rules.frost_core_crack_on_boss_poise.amount === 30, "Core Lv5 crack");

const shatter = branch("frost_staff_branch_shatter");
const shatterLv2 = level(shatter, 2).special_rules.frostbite_on_hail_hit;
assert(shatterLv2 && shatterLv2.status_id === "frostbite" && shatterLv2.max_stacks === 3, "Shatter Lv2 frostbite");
assertApprox(shatterLv2.duration, 4, "Shatter Lv2 frostbite duration");
assertApprox(shatterLv2.same_target_cooldown, 0.4, "Shatter Lv2 frostbite cooldown");
const shatterLv3Setup = level(shatter, 3).special_rules.frostbite_freeze_or_poise;
assert(shatterLv3Setup && shatterLv3Setup.required_stacks === 3 && shatterLv3Setup.normal_freeze_duration === 0.6 && shatterLv3Setup.elite_freeze_duration === 0.3, "Shatter Lv3 frostbite freeze");
const shatterLv3 = level(shatter, 3).special_rules.shatter_on_freeze_or_frost_hit;
assert(shatterLv3 && shatterLv3.amount === 14 && shatterLv3.radius === 80, "Shatter Lv3 reaction");
assertApprox(level(shatter, 4).special_rules.shatter_upgrade.radius_multiplier_add, 0.2, "Shatter Lv4 radius");
assert(level(shatter, 5).special_rules.shatter_kill_spawn_icicle.can_trigger_shatter === false, "Shatter Lv5 icicle no chain");

const guard = branch("frost_staff_branch_icicle");
assert(level(guard, 2).special_rules.frost_aura_slow.radius === 120, "Guard Lv2 aura");
const guardLv3 = level(guard, 3).special_rules.frost_ring_on_player_damaged;
assert(guardLv3 && guardLv3.same_source_cooldown === 12 && guardLv3.status_id === "frostbite", "Guard Lv3 frostbite ring");
const guardLv4 = level(guard, 4).special_rules.frost_ring_on_player_damaged;
assert(guardLv4 && guardLv4.same_source_cooldown === 9, "Guard Lv4 cooldown");
assert(level(guard, 4).special_rules.frost_aura_slow.radius_multiplier_add === 0.2, "Guard Lv4 aura range");
const guardLv5 = level(guard, 5).special_rules.freeze_frostbite_near_player;
assert(guardLv5 && guardLv5.status_id === "frostbite" && guardLv5.radius === 90 && guardLv5.same_target_cooldown === 5, "Guard Lv5 frostbite freeze");

for (const id of ["frost_lock", "frostbite", "freeze"]) {
  assert(status(id), `${id} status must exist`);
}

const branchText = JSON.stringify(branches);
for (const oldKey of ["elite_boss_chill_duration_add", "chill_stack_efficiency", "freeze_full_chill_near_player"]) {
  assert(!branchText.includes(`"${oldKey}"`), `old special rule ${oldKey} must be removed`);
}

const contracts = read("tools/weapon_config_contracts.js");
for (const key of ["frost_lock_on_elite_boss_direct_hit", "frost_lock_bonus_hit", "frostbite_on_hail_hit", "frostbite_freeze_or_poise", "freeze_frostbite_near_player"]) {
  assert(contracts.includes(key), `Special rule contract must include ${key}`);
}

const specialExecutor = read("scripts/skills/skill_special_rule_executor.gd");
assert(specialExecutor.includes("frost_lock_on_elite_boss_direct_hit"), "SkillSpecialRuleExecutor must handle frost_lock");
assert(specialExecutor.includes("frostbite_on_hail_hit"), "SkillSpecialRuleExecutor must handle frostbite");
assert(!specialExecutor.includes("chilled_elite_boss_bonus_hit"), "SkillSpecialRuleExecutor must not keep old chill bonus rule");

console.log("Frost staff branch table verification passed.");
