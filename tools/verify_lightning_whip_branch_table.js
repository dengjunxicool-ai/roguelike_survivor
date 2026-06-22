const fs = require("fs");
const path = require("path");
const { buildMatrix } = require("./full_weapon_branch_matrix");

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

function rule(branchData, value, key) {
  const result = level(branchData, value).special_rules?.[key];
  assert(result, `Missing ${branchData.id} Lv${value} special rule ${key}`);
  return result;
}

function status(id) {
  return statuses.find((item) => item.id === id);
}

const branches = readJson("data/weapon_branches.json").branches || [];
const attacks = readJson("data/primary_attack.json").primary_attacks || [];
const statuses = readJson("data/status_effects.json").statuses || [];
const combatObjects = readJson("data/combat_objects.json").combat_objects || [];

const primary = attacks.find((item) => item.id === "lightning_orb");
assert(primary, "lightning_orb must exist");
assertApprox(primary.base.damage, 12, "lightning_orb base damage");
assertApprox(primary.base.cooldown, 0.95, "lightning_orb attack interval");
assertApprox(primary.base.bounce_count, 2, "lightning_orb base bounces");
const hit = primary.events.find((event) => event.trigger === "on_projectile_hit" && event.source_id === "lightning_orb_projectile");
assert(hit, "lightning_orb must resolve projectile hit events");
assert(!hit.actions.some((action) => action.type === "apply_status"), "lightning_orb base hit must not apply status");
assert(status("voltage") && status("shock") && status("charge"), "voltage, shock, and charge statuses must exist");
assert(combatObjects.some((item) => item.id === "lightning_orb_projectile"), "lightning_orb_projectile combat object must exist");

const chain = branch("lightning_whip_branch_chain");
assert(rule(chain, 2, "lightning_chain_bounce").bounce_count_add === 1, "Chain Lv2 bounce count");
assert(rule(chain, 3, "lightning_chain_bounce").range_add === 50, "Chain Lv3 range");
assertApprox(rule(chain, 3, "lightning_chain_bounce").bounce_damage_multiplier, 0.82, "Chain Lv3 decay");
assertApprox(rule(chain, 4, "chain_new_target_damage_ramp").damage_multiplier_add_per_new_target, 0.04, "Chain Lv4 ramp");
const chainLv5 = rule(chain, 5, "chain_end_burst");
assert(chainLv5.unique_targets_required === 4 && chainLv5.amount === 12 && chainLv5.max_targets === 6 && chainLv5.can_trigger_reaction === false, "Chain Lv5 burst");
const chainLv3Case = buildMatrix().cases.find((item) => item.character_id === "mage" && item.weapon_id === "lightning_whip" && item.branch_id === "lightning_whip_branch_chain" && item.level === 3);
assert(chainLv3Case && chainLv3Case.template === "multi_target_area", "Chain Lv3 must use multi_target_area scene with multiple slimes");
assert(chainLv3Case.target_enemy_ids.length === 8 && chainLv3Case.target_enemy_ids.every((id) => id === "small_slime"), "Chain Lv3 scene must target 8 small slimes");

const overload = branch("lightning_whip_branch_overload_core");
const voltageLv2 = rule(overload, 2, "voltage_on_elite_boss_hit");
assert(voltageLv2.status_id === "voltage" && voltageLv2.max_stacks === 5 && voltageLv2.same_target_cooldown === 0.45, "Overload Lv2 voltage");
const overloadLv3 = rule(overload, 3, "overload_on_voltage");
assert(overloadLv3.required_stacks === 5 && overloadLv3.consume_all === true && overloadLv3.amount === 18, "Overload Lv3 voltage reaction");
assert(overloadLv3.apply_status_id === "shock", "Overload Lv3 applies shock");
assertApprox(overloadLv3.same_target_cooldown, 1.2, "Overload Lv3 cooldown");
const overloadLv4 = rule(overload, 4, "unused_bounce_to_elite_boss_damage");
assertApprox(overloadLv4.damage_per_unused_bounce, 0.30, "Overload Lv4 unused bounce damage");
assertApprox(overloadLv4.boss_cap, 0.45, "Overload Lv4 Boss cap");
assert(rule(overload, 5, "overload_shock_lightning").amount === 26, "Overload Lv5 lightning");

const storm = branch("lightning_whip_branch_lash");
const stormLv2 = rule(storm, 2, "shock_on_lightning_orb_hit");
assert(stormLv2.chance === 0.20 && stormLv2.same_target_cooldown === 0.8, "Storm Lv2 shock chance");
const stormLv3 = rule(storm, 3, "shock_consume_reaction");
assert(stormLv3.amount === 8 && stormLv3.spread_shock_targets === 1 && stormLv3.spread_shock_stacks === 1, "Storm Lv3 shock spread");
assertApprox(rule(storm, 4, "shock_upgrade").damage_multiplier_add, 0.2, "Storm Lv4 damage");
const stormLv5 = rule(storm, 5, "magnetic_storm_on_shock_consume");
assert(stormLv5.radius === 120 && stormLv5.duration === 1.2 && stormLv5.tick_interval === 0.4 && stormLv5.damage === 4, "Storm Lv5 magnetic field");

const guard = branch("lightning_whip_branch_dual_orb");
assert(rule(guard, 2, "orbit_before_launch").duration === 0.6, "Guard Lv2 orbit");
assert(rule(guard, 3, "orbit_contact_damage").max_targets === 3, "Guard Lv3 target cap");
assert(rule(guard, 4, "orbit_contact_slow").slow_percent === 0.15, "Guard Lv4 slow");
assert(rule(guard, 5, "orbit_guard_extra_orb").orbit_only_applies_charge === true, "Guard Lv5 charge only");

const branchText = JSON.stringify(branches);
for (const oldKey of ["charge_overload_tuning", "overload_on_charge", "shock_on_charged_first_hit", "magnetic_storm_on_full_charge"]) {
  assert(!branchText.includes(`"${oldKey}"`), `old special rule ${oldKey} must be removed`);
}

const contracts = read("tools/weapon_config_contracts.js");
for (const key of ["voltage_on_elite_boss_hit", "overload_on_voltage", "shock_on_lightning_orb_hit", "magnetic_storm_on_shock_consume"]) {
  assert(contracts.includes(key), `Special rule contract must include ${key}`);
}

const specialExecutor = read("scripts/skills/skill_special_rule_executor.gd");
assert(specialExecutor.includes("overload_on_voltage"), "SkillSpecialRuleExecutor must execute voltage overload");
assert(specialExecutor.includes("shock_on_lightning_orb_hit"), "SkillSpecialRuleExecutor must execute shock on hit");
assert(!specialExecutor.includes("overload_on_charge"), "SkillSpecialRuleExecutor must not keep charge overload");

const specialHandler = read("scripts/skills/special_damage_rule_handler.gd");
assert(specialHandler.includes("magnetic_storm_on_shock_consume"), "SpecialDamageRuleHandler must support magnetic storm from shock consume");
assert(specialHandler.includes("_apply_context_source_identity(packet, context, projectile)") && specialHandler.includes('build_special_packet("lightning_chain_bounce"'), "Lightning chain bounce must preserve source weapon in debug trace");

console.log("Lightning whip branch table verification passed.");
