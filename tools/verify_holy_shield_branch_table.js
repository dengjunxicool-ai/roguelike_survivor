const fs = require("fs");
const path = require("path");
const { SPECIAL_RULE_KEYS } = require("./weapon_config_contracts");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}
function assert(condition, message) {
  if (!condition) throw new Error(message);
}
function assertEqual(actual, expected, message) {
  assert(Object.is(actual, expected), `${message}: expected ${expected}, got ${actual}`);
}
function assertClose(actual, expected, message, epsilon = 0.0001) {
  assert(Math.abs(actual - expected) <= epsilon, `${message}: expected ${expected}, got ${actual}`);
}
function findById(items, id, label) {
  const item = items.find((entry) => entry.id === id);
  assert(item, `${label} ${id} must exist`);
  return item;
}
function branchLevel(branchId, level) {
  const branch = findById(readJson("data/weapon_branches.json").branches, branchId, "branch");
  const config = branch.level_path[String(level)];
  assert(config, `${branchId} Lv${level} must exist`);
  return config;
}
function modifier(config, stat, op) {
  const found = (config.modifiers || []).find((entry) => entry.stat === stat && entry.op === op);
  assert(found, `${config.display_name} must include ${stat}/${op} modifier`);
  return found;
}
function requireSpecialRuleKey(key) {
  assert(SPECIAL_RULE_KEYS.includes(key), `SPECIAL_RULE_KEYS must include ${key}`);
}

function main() {
  const primary = findById(readJson("data/primary_attack.json").primary_attacks, "holy_shield", "primary attack");
  assertEqual(primary.base.shield_value, 30, "holy_shield base shield value");
  assertEqual(primary.base.break_damage, 30, "holy_shield break damage");
  assertEqual(primary.base.damage, 5, "holy_shield pulse damage");
  assertEqual(primary.base.cooldown, 7.0, "holy_shield deploy interval");
  assertEqual(primary.base.tick_interval, 1.0, "holy_shield pulse interval");
  assert(primary.base_special_rules && primary.base_special_rules.holy_shield_base, "holy_shield must define base special rule");
  const base = primary.base_special_rules.holy_shield_base;
  assert(base.shield_value === 30 && base.pulse_damage === 5 && base.break_damage === 30, "holy_shield base rule values");
  assert(base.deploy_interval === 7 && base.pulse_interval === 1, "holy_shield base rule cadence");
  assert(!base.status_id, "holy_shield base rule must not apply status");

  findById(readJson("data/status_effects.json").statuses, "holy_mark", "status");

  const shockLv2 = branchLevel("holy_shield_branch_charge", 2).special_rules.holy_pulse_radius;
  assertClose(shockLv2.radius_multiplier_add, 0.2, "Shock Lv2 pulse radius");
  const shockLv3 = branchLevel("holy_shield_branch_charge", 3).special_rules.holy_shockwave_every_n_pulses;
  assert(shockLv3.pulse_interval === 3 && shockLv3.radius === 160 && shockLv3.amount === 8 && shockLv3.max_targets === 6, "Shock Lv3 shockwave");
  const shockLv4 = branchLevel("holy_shield_branch_charge", 4).special_rules.holy_pulse_interval;
  assertClose(shockLv4.multiplier, 0.8, "Shock Lv4 pulse interval");
  const shockLv5 = branchLevel("holy_shield_branch_charge", 5).special_rules.holy_shield_break_shockwave;
  assert(shockLv5.radius === 210 && shockLv5.amount === 28 && shockLv5.max_targets === 8 && shockLv5.boss_damage_multiplier === 0.85, "Shock Lv5 break shockwave");

  const judgementLv2 = branchLevel("holy_shield_branch_purify", 2).special_rules.holy_mark_on_strong_pulse_hit;
  assert(judgementLv2.status_id === "holy_mark" && judgementLv2.duration === 5, "Judgement Lv2 holy mark on pulse");
  const judgementLv3 = branchLevel("holy_shield_branch_purify", 3).special_rules.holy_mark_pulse_focus;
  assertClose(judgementLv3.damage_multiplier_add, 0.2, "Judgement Lv3 pulse focus");
  const judgementLv4 = branchLevel("holy_shield_branch_purify", 4).special_rules.holy_mark_holy_vulnerability;
  assertClose(judgementLv4.holy_damage_taken_multiplier_add, 0.08, "Judgement Lv4 holy vulnerability");
  const judgementLv5 = branchLevel("holy_shield_branch_purify", 5).special_rules.judgement_beam_on_boss_mark_pulses;
  assert(judgementLv5.required_pulses === 5 && judgementLv5.amount === 30 && judgementLv5.damage_type === "direct_magical", "Judgement Lv5 beam");

  const counterLv2 = branchLevel("holy_shield_branch_counter", 2);
  assertClose(modifier(counterLv2, "break_damage", "multiplier_add").value, 0.2, "Counter Lv2 break damage");
  const counterLv3 = branchLevel("holy_shield_branch_counter", 3);
  assert(counterLv3.special_rules.holy_mark_nearest_pulse_target.status_id === "holy_mark", "Counter Lv3 marks nearest pulse target");
  assert(counterLv3.special_rules.holy_counter_on_marked_break_hit.amount === 20, "Counter Lv3 reaction");
  const counterLv4 = branchLevel("holy_shield_branch_counter", 4).special_rules.holy_pulse_interval;
  assertClose(counterLv4.multiplier, 0.8, "Counter Lv4 pulse interval");
  const counterLv5 = branchLevel("holy_shield_branch_counter", 5).special_rules.holy_counter_boss_poise;
  assert(counterLv5.stacks === 1 && counterLv5.same_target_cooldown === 2.5, "Counter Lv5 boss poise");

  const wallLv2 = branchLevel("holy_shield_branch_wall", 2);
  assertEqual(modifier(wallLv2, "shield_value", "add").value, 12, "Wall Lv2 shield value");
  assertClose(branchLevel("holy_shield_branch_wall", 3).special_rules.holy_shield_contact_damage_reduction.damage_taken_multiplier_add, -0.15, "Wall Lv3 contact reduction");
  assertEqual(branchLevel("holy_shield_branch_wall", 4).special_rules.holy_shield_expire_heal.amount, 5, "Wall Lv4 expire heal");
  assertEqual(branchLevel("holy_shield_branch_wall", 5).special_rules.holy_shield_break_damage_reduction.duration, 1, "Wall Lv5 break reduction duration");

  for (const key of [
    "holy_shield_base",
    "holy_pulse_radius",
    "holy_shockwave_every_n_pulses",
    "holy_pulse_interval",
    "holy_shield_break_shockwave",
    "holy_mark_on_strong_pulse_hit",
    "holy_mark_nearest_pulse_target",
    "holy_mark_pulse_focus",
    "holy_mark_holy_vulnerability",
    "judgement_beam_on_boss_mark_pulses",
    "holy_counter_on_marked_break_hit",
    "holy_counter_boss_poise",
    "holy_shield_contact_damage_reduction",
    "holy_shield_expire_heal",
    "holy_shield_break_damage_reduction",
  ]) requireSpecialRuleKey(key);

  const handler = fs.readFileSync(path.join(root, "scripts/skills/special_damage_rule_handler.gd"), "utf8");
  for (const snippet of ["holy_mark_on_strong_pulse_hit", "holy_mark_nearest_pulse_target"]) {
    assert(handler.includes(snippet), `SpecialDamageRuleHandler must handle ${snippet}`);
  }
  const executor = fs.readFileSync(path.join(root, "scripts/skills/skill_special_rule_executor.gd"), "utf8");
  assert(executor.includes("holy_mark_holy_vulnerability"), "SkillSpecialRuleExecutor must handle holy_mark_holy_vulnerability");
  console.log("Holy shield branch table verification passed.");
}

main();
