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
  const primary = findById(attacks, "acid_spray", "primary attack");
  assertEqual(primary.display_name, "\u9178\u6db2\u55b7\u5c04", "acid_spray display name");
  assertEqual(primary.base.damage, 8, "acid_spray tick damage");
  assertEqual(primary.base.cooldown, 1.4, "acid_spray deploy interval");
  assertEqual(primary.base.duration, 0.6, "acid_spray duration");
  assertEqual(primary.base.tick_interval, 0.3, "acid_spray hit tick");
  assertEqual(primary.base.range, 320, "acid_spray range");
  assertEqual(primary.base.cone_width_degrees, 70, "acid_spray cone width");
  const cast = primary.events.find((event) => event.trigger === "on_cast");
  const area = (cast.actions || []).find((action) => action.type === "spawn_area");
  assert(area.params.area_id === "acid_spray_cone_area" && area.params.radius === 320 && area.params.damage === 8, "acid cone values");
  assert(area.params.position_mode === "caster", "acid cone originates from weapon/player position");
  assert(area.params.damage_origin === "primary_attack" && area.params.damage_type === "status_dot", "acid cone damage model");
  assert(!area.params.status_on_hit && !area.params.statuses_on_hit, "acid_spray base cone must not apply status");
  assert(primary.base_special_rules && primary.base_special_rules.acid_sprayer_base, "acid_spray keeps base carrier constants");
  assert(!("corrosion_status_id" in primary.base_special_rules.acid_sprayer_base), "old corrosion status must leave base carrier");

  assertEqual(findById(statuses, "acid_mark", "status").max_stacks, 5, "acid_mark max stacks");
  assertEqual(findById(statuses, "acid_residue", "status").max_stacks, 5, "acid_residue max stacks");

  assertEqual(branchLevel("acid_sprayer_branch_pressure", 2).special_rules.acid_pressure_range_width.range_add, 60, "Pressure Lv2 range");
  assertClose(branchLevel("acid_sprayer_branch_pressure", 3).special_rules.acid_pressure_duration_damage.tick_damage_multiplier_add, -0.15, "Pressure Lv3 damage");
  assertClose(branchLevel("acid_sprayer_branch_pressure", 4).special_rules.acid_pressure_tick_interval.tick_interval_override, 0.25, "Pressure Lv4 tick interval");
  assertEqual(branchLevel("acid_sprayer_branch_pressure", 5).special_rules.acid_pressure_every_n_casts.max_targets, 8, "Pressure Lv5 max targets");

  const armorLv2Mark = branchLevel("acid_sprayer_branch_melt_armor", 2).special_rules.acid_mark_on_strong_acid_tick;
  assert(armorLv2Mark.status_id === "acid_mark" && armorLv2Mark.max_stacks === 5 && armorLv2Mark.elite_boss_only === true, "Armor Lv2 acid_mark");
  assertClose(branchLevel("acid_sprayer_branch_melt_armor", 2).special_rules.acid_mark_vulnerability.damage_taken_multiplier_add_per_stack, 0.005, "Armor Lv2 vulnerability");
  const armorLv3 = branchLevel("acid_sprayer_branch_melt_armor", 3).special_rules.acid_burst_on_full_acid_mark_hit;
  assert(armorLv3.required_status_id === "acid_mark" && armorLv3.amount === 18 && armorLv3.same_target_cooldown === 2, "Armor Lv3 acid burst");
  assertClose(branchLevel("acid_sprayer_branch_melt_armor", 4).special_rules.acid_burst_high_defense_bonus.damage_multiplier_add, 0.2, "Armor Lv4 high defense bonus");
  const armorLv5 = branchLevel("acid_sprayer_branch_melt_armor", 5).special_rules.boss_acid_mark_armor_break_pulse;
  assert(armorLv5.required_status_id === "acid_mark" && armorLv5.tick_interval === 3 && armorLv5.stackable === false, "Armor Lv5 boss defense pulse");

  const burstLv2 = branchLevel("acid_sprayer_branch_acid_burst", 2).special_rules.acid_residue_on_acid_tick;
  assert(burstLv2.status_id === "acid_residue" && burstLv2.max_stacks === 5, "Burst Lv2 acid_residue");
  const burstLv3 = branchLevel("acid_sprayer_branch_acid_burst", 3).special_rules.acid_burst_on_full_acid_residue_hit;
  assert(burstLv3.required_status_id === "acid_residue" && burstLv3.radius === 85 && burstLv3.max_targets === 6, "Burst Lv3 area");
  assertClose(branchLevel("acid_sprayer_branch_acid_burst", 4).special_rules.acid_burst_damage_tuning.damage_multiplier_add, 0.2, "Burst Lv4 damage");
  assertClose(branchLevel("acid_sprayer_branch_acid_burst", 4).special_rules.acid_burst_cooldown_tuning.same_target_cooldown, 1.6, "Burst Lv4 cooldown");
  const burstLv5 = branchLevel("acid_sprayer_branch_acid_burst", 5).special_rules.acid_burst_spread_residue;
  assert(burstLv5.status_id === "acid_residue" && burstLv5.can_trigger_self === false, "Burst Lv5 spread no recursion");

  assertEqual(branchLevel("acid_sprayer_branch_fan", 2).special_rules.acid_hit_shield.shield_value, 8, "Film Lv2 shield");
  const filmLv3 = branchLevel("acid_sprayer_branch_fan", 3).special_rules.corrosive_film_nearby_acid_mark;
  assert(filmLv3.status_id === "acid_mark" && filmLv3.max_stacks === 3, "Film Lv3 nearby acid_mark");
  assertEqual(branchLevel("acid_sprayer_branch_fan", 4).special_rules.corrosive_film_upgrade.shield_cap_add, 6, "Film Lv4 upgrade");
  const filmLv5 = branchLevel("acid_sprayer_branch_fan", 5).special_rules.corrosive_film_on_boss_skill_hit;
  assert(filmLv5.same_source_cooldown === 18 && filmLv5.boss_contact_damage_taken_multiplier_add === -0.15, "Film Lv5 boss skill hit");

  for (const key of [
    "acid_mark_on_strong_acid_tick",
    "acid_mark_vulnerability",
    "acid_burst_on_full_acid_mark_hit",
    "boss_acid_mark_armor_break_pulse",
    "acid_residue_on_acid_tick",
    "acid_burst_on_full_acid_residue_hit",
    "acid_burst_spread_residue",
    "acid_burst_damage_tuning",
    "acid_burst_cooldown_tuning",
    "acid_burst_high_defense_bonus",
    "acid_hit_shield",
    "corrosive_film_nearby_acid_mark",
    "corrosive_film_upgrade",
    "corrosive_film_on_boss_skill_hit",
  ]) requireSpecialRuleKey(key);

  const executor = read("scripts/skills/skill_special_rule_executor.gd");
  for (const snippet of ["acid_mark_on_strong_acid_tick", "acid_residue_on_acid_tick", "corrosive_film_nearby_acid_mark"]) {
    assert(executor.includes(snippet), `SkillSpecialRuleExecutor must handle ${snippet}`);
  }
  assert(!executor.includes("corrosion_vulnerability_tuning"), "old corrosion vulnerability runtime must be removed");
  console.log("Acid sprayer branch table verification passed.");
}

main();
