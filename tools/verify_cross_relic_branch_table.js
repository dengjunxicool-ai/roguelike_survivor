const fs = require("fs");
const path = require("path");
const { SPECIAL_RULE_KEYS } = require("./weapon_config_contracts");

const root = path.resolve(__dirname, "..");
function readJson(relativePath) { return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8")); }
function assert(condition, message) { if (!condition) throw new Error(message); }
function assertEqual(actual, expected, message) { assert(Object.is(actual, expected), `${message}: expected ${expected}, got ${actual}`); }
function assertClose(actual, expected, message, epsilon = 0.0001) { assert(Math.abs(actual - expected) <= epsilon, `${message}: expected ${expected}, got ${actual}`); }
function findById(items, id, label) { const item = items.find((entry) => entry.id === id); assert(item, `${label} ${id} must exist`); return item; }
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
function requireSpecialRuleKey(key) { assert(SPECIAL_RULE_KEYS.includes(key), `SPECIAL_RULE_KEYS must include ${key}`); }

function main() {
  const primary = findById(readJson("data/primary_attack.json").primary_attacks, "holy_field", "primary attack");
  assertEqual(primary.base.damage, 6, "holy_field tick damage");
  assertEqual(primary.base.heal, 1, "holy_field tick heal");
  assertEqual(primary.base.cooldown, 6.0, "holy_field deploy interval");
  assertEqual(primary.base.tick_interval, 0.5, "holy_field tick interval");
  assertEqual(primary.base.area_radius, 130, "holy_field radius");
  const cast = primary.events.find((event) => event.trigger === "on_cast");
  const area = (cast.actions || []).find((action) => action.type === "spawn_area");
  assert(area, "holy_field casts an area");
  assert(area.params.area_id === "holy_field_area" && area.params.radius === 130 && area.params.damage === 6, "holy_field area values");
  assert(area.params.tick_interval === 0.5 && area.params.damage_origin === "field", "holy_field tick wiring");
  assert(!area.params.status_on_hit && !area.params.statuses_on_hit, "holy_field base area must not apply status");
  assert(primary.base_special_rules && primary.base_special_rules.cross_relic_base, "holy_field must define base special rule");
  assert(!primary.base_special_rules.cross_relic_base.status_id, "cross relic base rule must not apply status");

  findById(readJson("data/combat_objects.json").combat_objects, "holy_field_area", "combat object");
  const impurity = findById(readJson("data/status_effects.json").statuses, "impurity", "status");
  assertEqual(impurity.max_stacks, 3, "impurity max stacks");

  assertClose(modifier(branchLevel("cross_relic_branch_pulse", 2), "radius", "multiplier_add").value, 0.15, "Field Lv2 radius");
  assert(branchLevel("cross_relic_branch_pulse", 3).special_rules.cross_relic_field_capacity.max_active_add === 1, "Field Lv3 capacity");
  assert(branchLevel("cross_relic_branch_pulse", 4).special_rules.cross_relic_field_heal_upgrade.heal_add === 1, "Field Lv4 heal");
  assert(branchLevel("cross_relic_branch_pulse", 5).special_rules.cross_relic_stand_shield.shield_value === 12, "Field Lv5 stand shield");

  assert(branchLevel("cross_relic_branch_judgement", 2).special_rules.cross_relic_echo_every_n_ticks.amount === 5, "Judgement Lv2 echo");
  assert(branchLevel("cross_relic_branch_judgement", 3).special_rules.cross_relic_echo_targeting.prefer_strong_targets === true, "Judgement Lv3 targeting");
  assertClose(branchLevel("cross_relic_branch_judgement", 4).special_rules.cross_relic_echo_upgrade.damage_multiplier_add, 0.3, "Judgement Lv4 echo damage");
  assert(branchLevel("cross_relic_branch_judgement", 5).special_rules.cross_relic_faith_judgement.amount === 28, "Judgement Lv5 faith judgement");

  const impurityLv2 = branchLevel("cross_relic_branch_purify_field", 2).special_rules.cross_relic_impurity_on_field_tick;
  assert(impurityLv2.status_id === "impurity" && impurityLv2.max_stacks === 3 && impurityLv2.duration === 4, "Purify Lv2 impurity");
  const purifyLv3 = branchLevel("cross_relic_branch_purify_field", 3).special_rules.cross_relic_purify_impurity;
  assert(purifyLv3.required_stacks === 3 && purifyLv3.amount === 12 && purifyLv3.consume_all === true, "Purify Lv3 reaction");
  const purifyLv4 = branchLevel("cross_relic_branch_purify_field", 4).special_rules.cross_relic_purify_upgrade;
  assertClose(purifyLv4.elite_boss_damage_multiplier_add, 0.2, "Purify Lv4 elite/boss");
  assertClose(purifyLv4.radius_multiplier_add, 0.1, "Purify Lv4 radius");
  const purifyLv5 = branchLevel("cross_relic_branch_purify_field", 5).special_rules.cross_relic_purify_boss_poise;
  assert(purifyLv5.stacks === 1 && purifyLv5.same_target_cooldown === 2, "Purify Lv5 boss poise");

  assertClose(branchLevel("cross_relic_branch_shelter", 2).special_rules.cross_relic_field_damage_reduction.damage_taken_multiplier_add, -0.08, "Shelter Lv2 reduction");
  assert(branchLevel("cross_relic_branch_shelter", 3).special_rules.cross_relic_periodic_shield.shield_value === 5, "Shelter Lv3 shield");
  assertClose(branchLevel("cross_relic_branch_shelter", 4).special_rules.cross_relic_shelter_upgrade.heal_multiplier_add, 0.4, "Shelter Lv4 heal");
  assert(branchLevel("cross_relic_branch_shelter", 5).special_rules.cross_relic_low_hp_rescue.same_source_cooldown === 20, "Shelter Lv5 rescue");

  for (const key of [
    "cross_relic_base",
    "cross_relic_field_capacity",
    "cross_relic_field_heal_upgrade",
    "cross_relic_stand_shield",
    "cross_relic_echo_every_n_ticks",
    "cross_relic_echo_targeting",
    "cross_relic_echo_upgrade",
    "cross_relic_faith_judgement",
    "cross_relic_impurity_on_field_tick",
    "cross_relic_purify_impurity",
    "cross_relic_purify_upgrade",
    "cross_relic_purify_boss_poise",
    "cross_relic_purify_small_pulse",
    "cross_relic_field_damage_reduction",
    "cross_relic_periodic_shield",
    "cross_relic_shelter_upgrade",
    "cross_relic_low_hp_rescue",
  ]) requireSpecialRuleKey(key);

  const executor = fs.readFileSync(path.join(root, "scripts/skills/skill_special_rule_executor.gd"), "utf8");
  for (const snippet of ["cross_relic_impurity_on_field_tick", "cross_relic_purify_impurity", "_apply_cross_relic_on_field_tick"]) {
    assert(executor.includes(snippet), `SkillSpecialRuleExecutor must handle ${snippet}`);
  }
  console.log("Cross relic branch table verification passed.");
}

main();
