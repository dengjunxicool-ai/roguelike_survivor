const fs = require("fs");
const path = require("path");
const { SPECIAL_RULE_KEYS } = require("./weapon_config_contracts");

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
function assertEqual(actual, expected, message) {
  assert(Object.is(actual, expected), `${message}: expected ${expected}, got ${actual}`);
}
function assertClose(actual, expected, message, epsilon = 0.0001) {
  assert(Math.abs(Number(actual) - expected) <= epsilon, `${message}: expected ${expected}, got ${actual}`);
}
function findById(items, id, label) {
  const item = items.find((entry) => entry.id === id);
  assert(item, `${label} ${id} must exist`);
  return item;
}

const branches = readJson("data/weapon_branches.json").branches || [];
const attacks = readJson("data/primary_attack.json").primary_attacks || [];
const statuses = readJson("data/status_effects.json").statuses || [];

function branchLevel(branchId, level) {
  const branch = findById(branches, branchId, "branch");
  const config = branch.level_path[String(level)];
  assert(config, `${branchId} Lv${level} must exist`);
  return config;
}
function requireSpecialRuleKey(key) {
  assert(SPECIAL_RULE_KEYS.includes(key), `SPECIAL_RULE_KEYS must include ${key}`);
}

function main() {
  const primary = findById(attacks, "burning_oil_pot", "primary attack");
  assertEqual(primary.display_name, "\u71c3\u70e7\u6cb9\u7f50", "burning_oil_pot display name");
  assertEqual(primary.base.damage, 7, "burning_oil_pot tick damage");
  assertEqual(primary.base.cooldown, 2.4, "burning_oil_pot deploy interval");
  assertEqual(primary.base.tick_interval, 0.5, "burning_oil_pot tick interval");
  assertEqual(primary.base.duration, 2.5, "burning_oil_pot duration");
  assertEqual(primary.base.area_radius, 110, "burning_oil_pot radius");
  const cast = primary.events.find((event) => event.trigger === "on_cast");
  const projectile = (cast.actions || []).find((action) => action.type === "spawn_projectile");
  assert(projectile.params.projectile_id === "fire_oil_pot_projectile" && projectile.params.trajectory_mode === "linear", "fire oil projectile values");
  const hit = primary.events.find((event) => event.trigger === "on_projectile_hit" && event.source_id === "fire_oil_pot_projectile");
  const area = (hit.actions || []).find((action) => action.type === "spawn_area");
  assert(area.params.area_id === "fire_oil_area" && area.params.radius === 110 && area.params.damage === 7, "fire oil area values");
  assert(area.params.damage_origin === "field" && area.params.damage_type === "status_dot", "fire oil damage model");
  assert(!area.params.status_on_hit && !area.params.statuses_on_hit, "burning_oil_pot base area must not apply status");
  assert(primary.base_special_rules && primary.base_special_rules.fire_oil_canister_base, "burning_oil_pot keeps base carrier constants");
  assert(!("oil_status_id" in primary.base_special_rules.fire_oil_canister_base), "old oil status must leave base carrier");

  assertEqual(findById(statuses, "flammable_mark", "status").max_stacks, 5, "flammable_mark max stacks");
  assertEqual(findById(statuses, "oil_stack", "status").max_stacks, 3, "oil_stack max stacks");

  assertEqual(branchLevel("fire_oil_canister_branch_carpet", 2).special_rules.fire_oil_duration_tuning.duration_add, 1, "Carpet Lv2 duration");
  const carpetLv3 = branchLevel("fire_oil_canister_branch_carpet", 3).special_rules.fire_oil_merge_zones;
  assert(carpetLv3.enabled === true && carpetLv3.max_active === 4, "Carpet Lv3 merge/cap");
  assertEqual(branchLevel("fire_oil_canister_branch_carpet", 3).special_rules.burn_in_merged_oil.interval, 1.5, "Carpet Lv3 burn interval");
  assertClose(branchLevel("fire_oil_canister_branch_carpet", 4).special_rules.fire_oil_merge_upgrade.tick_damage_multiplier_add, 0.15, "Carpet Lv4 tick damage");
  assertClose(branchLevel("fire_oil_canister_branch_carpet", 5).special_rules.fire_oil_burn_damage_in_big_oil.burn_damage_multiplier_add, 0.3, "Carpet Lv5 burn damage");

  const stickyLv2 = branchLevel("fire_oil_canister_branch_sticky", 2).special_rules.flammable_mark_on_strong_oil_tick;
  assert(stickyLv2.status_id === "flammable_mark" && stickyLv2.max_stacks === 5 && stickyLv2.elite_boss_only === true, "Sticky Lv2 flammable mark");
  assertClose(branchLevel("fire_oil_canister_branch_sticky", 2).special_rules.flammable_mark_fire_vulnerability.fire_damage_taken_multiplier_add_per_stack, 0.01, "Sticky Lv2 vulnerability");
  const stickyLv3 = branchLevel("fire_oil_canister_branch_sticky", 3).special_rules.flammable_mark_burst_on_full_mark_tick;
  assert(stickyLv3.amount === 14 && stickyLv3.same_target_cooldown === 1.5, "Sticky Lv3 flammable burst");
  const stickyLv4 = branchLevel("fire_oil_canister_branch_sticky", 4).special_rules.flammable_mark_boss_tuning;
  assert(stickyLv4.duration_add === 1 && stickyLv4.burst_boss_damage_multiplier_add === 0.15, "Sticky Lv4 boss tuning");
  assert(branchLevel("fire_oil_canister_branch_sticky", 5).special_rules.flammable_burst_boss_poise.same_target_cooldown === 2.5, "Sticky Lv5 boss poise");

  const detonateLv2Stack = branchLevel("fire_oil_canister_branch_detonate", 2).special_rules.oil_stack_on_fire_oil_tick;
  assert(detonateLv2Stack.status_id === "oil_stack" && detonateLv2Stack.max_stacks === 3, "Detonate Lv2 oil_stack");
  assertClose(branchLevel("fire_oil_canister_branch_detonate", 2).special_rules.oil_fire_deflagration.damage_multiplier_add, 0.15, "Detonate Lv2 damage");
  assert(branchLevel("fire_oil_canister_branch_detonate", 3).special_rules.deflagration_apply_burn.max_targets === 5, "Detonate Lv3 burn");
  assertEqual(branchLevel("fire_oil_canister_branch_detonate", 4).special_rules.deflagration_upgrade.same_source_cooldown, 1, "Detonate Lv4 cooldown");
  assert(branchLevel("fire_oil_canister_branch_detonate", 5).special_rules.full_oil_secondary_deflagration.can_trigger_self === false, "Detonate Lv5 no recursion");

  assertEqual(branchLevel("fire_oil_canister_branch_blackfire", 2).special_rules.smoke_cloud_on_oil_expire.duration, 1.2, "Smoke Lv2 duration");
  assertClose(branchLevel("fire_oil_canister_branch_blackfire", 3).special_rules.smoke_enemy_damage_down.damage_multiplier_add, -0.15, "Smoke Lv3 damage down");
  assertClose(branchLevel("fire_oil_canister_branch_blackfire", 4).special_rules.smoke_player_speed_buff.move_speed_multiplier_add, 0.08, "Smoke Lv4 speed");
  assertEqual(branchLevel("fire_oil_canister_branch_blackfire", 5).special_rules.smoke_cloud_on_player_damaged.same_source_cooldown, 16, "Smoke Lv5 damage cooldown");

  for (const key of [
    "burn_in_merged_oil",
    "flammable_mark_on_strong_oil_tick",
    "flammable_mark_fire_vulnerability",
    "flammable_mark_burst_on_full_mark_tick",
    "flammable_mark_boss_tuning",
    "flammable_burst_boss_poise",
    "oil_stack_on_fire_oil_tick",
    "fire_oil_duration_tuning",
    "fire_oil_merge_zones",
    "fire_oil_merge_upgrade",
    "fire_oil_burn_damage_in_big_oil",
    "oil_fire_deflagration",
    "deflagration_apply_burn",
    "deflagration_upgrade",
    "full_oil_secondary_deflagration",
    "smoke_cloud_on_oil_expire",
    "smoke_enemy_damage_down",
    "smoke_player_speed_buff",
    "smoke_cloud_on_player_damaged",
  ]) requireSpecialRuleKey(key);

  const executor = read("scripts/skills/skill_special_rule_executor.gd");
  for (const snippet of ["flammable_mark_on_strong_oil_tick", "flammable_mark_burst_on_full_mark_tick", "oil_stack_on_fire_oil_tick"]) {
    assert(executor.includes(snippet), `SkillSpecialRuleExecutor must handle ${snippet}`);
  }
  assert(!executor.includes("oil_fire_vulnerability"), "old oil vulnerability runtime must be removed");
  console.log("Fire oil canister branch table verification passed.");
}

main();
