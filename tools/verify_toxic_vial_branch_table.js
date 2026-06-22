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

function modifier(config, stat, op) {
  const found = (config.modifiers || []).find((entry) => entry.stat === stat && entry.op === op);
  assert(found, `${config.display_name} must include ${stat}/${op} modifier`);
  return found;
}

function requireSpecialRuleKey(key) {
  assert(SPECIAL_RULE_KEYS.includes(key), `SPECIAL_RULE_KEYS must include ${key}`);
}

function status(id) {
  return findById(statuses, id, "status");
}

function main() {
  const primary = findById(attacks, "poison_bottle", "primary attack");
  assertEqual(primary.display_name, "\u6bd2\u74f6", "poison_bottle display name");
  assertEqual(primary.base.damage, 6, "poison_bottle tick damage");
  assertEqual(primary.base.cooldown, 2.2, "poison_bottle deploy interval");
  assertEqual(primary.base.tick_interval, 0.5, "poison_bottle tick interval");
  assertEqual(primary.base.duration, 2.5, "poison_bottle duration");
  assertEqual(primary.base.area_radius, 105, "poison_bottle radius");
  const cast = primary.events.find((event) => event.trigger === "on_cast");
  const projectile = (cast.actions || []).find((action) => action.type === "spawn_projectile");
  assert(projectile && projectile.params.projectile_id === "poison_bottle_projectile", "poison_bottle casts a bottle projectile");
  const hit = primary.events.find((event) => event.trigger === "on_projectile_hit");
  const area = (hit.actions || []).find((action) => action.type === "spawn_area");
  assert(area.params.area_id === "poison_cloud_area" && area.params.radius === 105 && area.params.damage === 6, "poison cloud values");
  assert(area.params.damage_origin === "field" && area.params.damage_type === "status_dot", "poison cloud damage model");
  assert(!area.params.status_on_hit && !area.params.statuses_on_hit, "poison_bottle base cloud must not apply status");
  assert(primary.base_special_rules && primary.base_special_rules.toxic_vial_base, "poison_bottle keeps base carrier constants");
  assert(!("residue_to_poison_threshold" in primary.base_special_rules.toxic_vial_base), "old residue threshold must leave base carrier");

  assertEqual(status("toxin_seed").max_stacks, 4, "toxin_seed max stacks");
  assertEqual(status("toxic_core").max_stacks, 4, "toxic_core max stacks");
  assertEqual(status("poison").max_stacks, 3, "poison base max stacks");

  const spreadLv2 = branchLevel("toxic_vial_branch_spread", 2);
  assertClose(modifier(spreadLv2, "radius", "multiplier_add").value, 0.15, "Spread Lv2 cloud radius");
  const seed = spreadLv2.special_rules.toxin_seed_on_poison_cloud_tick;
  assert(seed && seed.status_id === "toxin_seed" && seed.max_stacks === 4 && seed.normal_only === true, "Spread Lv2 toxin_seed");
  assertEqual(seed.duration, 5, "Spread Lv2 toxin_seed duration");
  const spreadLv3Seed = branchLevel("toxic_vial_branch_spread", 3).special_rules.toxin_seed_to_poison;
  assert(spreadLv3Seed && spreadLv3Seed.required_stacks === 4 && spreadLv3Seed.consume_all === true, "Spread Lv3 toxin_seed conversion");
  const spreadLv3Cloud = branchLevel("toxic_vial_branch_spread", 3).special_rules.toxic_vial_small_cloud_on_poison_kill;
  assert(spreadLv3Cloud.duration === 1.5 && spreadLv3Cloud.radius === 75 && spreadLv3Cloud.same_source_cooldown === 0.5, "Spread Lv3 small cloud");
  assertEqual(branchLevel("toxic_vial_branch_spread", 4).special_rules.toxic_vial_small_cloud_upgrade.max_active, 4, "Spread Lv4 small cloud cap");
  assertClose(branchLevel("toxic_vial_branch_spread", 5).special_rules.toxic_vial_small_cloud_cooldown.damage_multiplier_add, -0.2, "Spread Lv5 small cloud damage");

  const coreLv2 = branchLevel("toxic_vial_branch_corrosion", 2).special_rules.toxic_core_on_strong_cloud_tick;
  assert(coreLv2 && coreLv2.status_id === "toxic_core" && coreLv2.max_stacks === 4 && coreLv2.elite_boss_only === true, "Core Lv2 toxic_core");
  const coreLv3Convert = branchLevel("toxic_vial_branch_corrosion", 3).special_rules.toxic_core_to_poison;
  assert(coreLv3Convert && coreLv3Convert.required_stacks === 4 && coreLv3Convert.apply_status_id === "poison", "Core Lv3 toxic_core conversion");
  assertClose(branchLevel("toxic_vial_branch_corrosion", 3).special_rules.poison_elite_boss_tuning.elite_boss_dot_multiplier_add, 0.1, "Core Lv3 elite/boss poison modifier");
  assertEqual(branchLevel("toxic_vial_branch_corrosion", 4).special_rules.poison_max_stack_tuning.max_stacks_add, 1, "Core Lv4 poison stack tuning");
  assertEqual(branchLevel("toxic_vial_branch_corrosion", 5).special_rules.toxic_core_boss_pulse.same_target_cooldown, 2, "Core Lv5 boss pulse cooldown");

  const burstLv2 = branchLevel("toxic_vial_branch_toxic_burst", 2).special_rules.poison_on_cloud_tick_chance;
  assertClose(burstLv2.chance, 0.2, "Burst Lv2 poison chance");
  assertEqual(burstLv2.same_target_cooldown, 1, "Burst Lv2 poison chance cooldown");
  const burstLv3 = branchLevel("toxic_vial_branch_toxic_burst", 3).special_rules.poison_death_explosion;
  assert(burstLv3.radius === 90 && burstLv3.max_targets === 6 && burstLv3.apply_poison === false, "Burst Lv3 explosion");
  assertEqual(branchLevel("toxic_vial_branch_toxic_burst", 4).special_rules.poison_death_explosion_upgrade.same_source_cooldown, 0.4, "Burst Lv4 cooldown");
  assert(branchLevel("toxic_vial_branch_toxic_burst", 5).special_rules.full_poison_death_explosion.can_trigger_self === false, "Burst Lv5 no recursive burst");

  assertClose(branchLevel("toxic_vial_branch_paralyze", 2).special_rules.poison_cloud_enemy_damage_down.damage_multiplier_add, -0.08, "Stable Lv2 enemy damage down");
  assertClose(branchLevel("toxic_vial_branch_paralyze", 3).special_rules.poison_cloud_edge_speed_buff.move_speed_multiplier_add, 0.08, "Stable Lv3 speed");
  assertClose(branchLevel("toxic_vial_branch_paralyze", 4).special_rules.poison_cloud_slow.slow_percent, 0.15, "Stable Lv4 slow");
  assertEqual(branchLevel("toxic_vial_branch_paralyze", 5).special_rules.antidote_cloud_on_low_hp.same_source_cooldown, 18, "Stable Lv5 antidote cooldown");

  for (const key of [
    "toxin_seed_on_poison_cloud_tick",
    "toxin_seed_to_poison",
    "toxic_core_on_strong_cloud_tick",
    "toxic_core_to_poison",
    "poison_on_cloud_tick_chance",
    "toxic_vial_small_cloud_on_poison_kill",
    "toxic_vial_small_cloud_upgrade",
    "toxic_vial_small_cloud_cooldown",
    "poison_elite_boss_tuning",
    "poison_max_stack_tuning",
    "toxic_core_boss_pulse",
    "poison_death_explosion",
    "poison_death_explosion_upgrade",
    "full_poison_death_explosion",
    "poison_cloud_enemy_damage_down",
    "poison_cloud_edge_speed_buff",
    "poison_cloud_slow",
    "antidote_cloud_on_low_hp",
  ]) requireSpecialRuleKey(key);

  const executor = read("scripts/skills/skill_special_rule_executor.gd");
  for (const snippet of ["toxin_seed_on_poison_cloud_tick", "toxic_core_on_strong_cloud_tick", "poison_on_cloud_tick_chance"]) {
    assert(executor.includes(snippet), `SkillSpecialRuleExecutor must handle ${snippet}`);
  }
  assert(!executor.includes("residue_to_poison_tuning"), "old residue tuning must leave toxic vial runtime");

  console.log("Toxic vial branch table verification passed.");
}

main();
