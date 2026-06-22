const fs = require("fs");
const path = require("path");
const { SPECIAL_RULE_KEYS } = require("./weapon_config_contracts");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
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

function actionByType(event, type) {
  const action = (event.actions || []).find((entry) => entry.type === type);
  assert(action, `${event.trigger} must include ${type}`);
  return action.params || {};
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
  const primary = findById(readJson("data/primary_attack.json").primary_attacks, "throwing_knife", "primary attack");
  for (const definition of [primary]) {
    assertEqual(definition.base.damage, 10, "throwing_knife base damage");
    assertEqual(definition.base.cooldown, 0.62, "throwing_knife attack interval");
    assertEqual(definition.base.range, 580, "throwing_knife range");
    assertEqual(definition.base.projectile_count, 1, "throwing_knife base projectile count");
    const targeting = definition.components.find((entry) => entry.type === "targeting");
    assert(targeting && targeting.params.range === 580, "throwing_knife targeting range must be 580");
    const castEvent = definition.events.find((event) => event.trigger === "on_cast");
    assert(castEvent, "throwing_knife must have on_cast");
    const spawn = actionByType(castEvent, "spawn_projectile");
    assertEqual(spawn.projectile_id, "throwing_knife_projectile", "throwing_knife projectile object");
    assertEqual(spawn.count, 1, "throwing_knife spawn count");
    const hitEvent = definition.events.find((event) => event.trigger === "on_projectile_hit");
    assert(hitEvent, "throwing_knife must have on_projectile_hit");
    assertEqual(hitEvent.source_id, "throwing_knife_projectile", "throwing_knife hit source");
    const damage = actionByType(hitEvent, "deal_damage");
    assertEqual(damage.amount, 10, "throwing_knife hit damage");
    assertEqual(damage.damage_origin, "primary_attack", "throwing_knife damage origin");
    assert(!(hitEvent.actions || []).some((entry) => entry.type === "apply_status"), "throwing_knife base attack must not apply status");
  }

  findById(readJson("data/status_effects.json").statuses, "wound", "status");
  findById(readJson("data/status_effects.json").statuses, "bleed", "status");

  const rainLv2 = branchLevel("throwing_knife_belt_branch_thousand", 2);
  assertClose(modifier(rainLv2, "attack_speed", "multiplier_add").value, 0.1364, "Rain Lv2 attack speed");
  const rainLv3 = branchLevel("throwing_knife_belt_branch_thousand", 3).special_rules.extra_knife_every_n_casts;
  assert(rainLv3.cast_interval === 4 && rainLv3.extra_projectile_count === 1 && rainLv3.damage_multiplier_add === -0.35, "Rain Lv3 extra knife");
  const rainLv4 = branchLevel("throwing_knife_belt_branch_thousand", 4);
  assertClose(modifier(rainLv4, "projectile_speed", "multiplier_add").value, 0.25, "Rain Lv4 speed");
  assertClose(modifier(rainLv4, "range", "multiplier_add").value, 0.1, "Rain Lv4 range");
  const rainLv5 = branchLevel("throwing_knife_belt_branch_thousand", 5);
  assertEqual(modifier(rainLv5, "projectile_count", "add").value, 1, "Rain Lv5 knife count");
  assertClose(modifier(rainLv5, "damage", "multiplier_add").value, -0.25, "Rain Lv5 damage penalty");
  const rainLv5Decay = rainLv5.special_rules.same_target_short_window_decay;
  assert(rainLv5Decay.window === 0.25 && rainLv5Decay.second_hit_multiplier === 0.6, "Rain Lv5 same target decay");

  const execLv2 = branchLevel("throwing_knife_belt_branch_execution", 2).special_rules.low_hp_damage_bonus;
  assert(execLv2.hp_threshold === 0.35 && execLv2.damage_multiplier_add === 0.15, "Execution Lv2 low hp bonus");
  const execLv3 = branchLevel("throwing_knife_belt_branch_execution", 3).special_rules.execution_mark_on_strong_target;
  assert(execLv3.required_consecutive_hits === 5 && execLv3.strong_targets.includes("elite") && execLv3.strong_targets.includes("boss"), "Execution Lv3 mark");
  const execLv4 = branchLevel("throwing_knife_belt_branch_execution", 4).special_rules.execution_mark_crit_damage_taken;
  assertEqual(execLv4.crit_damage_taken_add, 0.25, "Execution Lv4 crit damage taken");
  const execLv5 = branchLevel("throwing_knife_belt_branch_execution", 5).special_rules.boss_low_hp_execution_burst;
  assert(execLv5.hp_threshold === 0.2 && execLv5.amount === 22 && execLv5.same_target_cooldown === 1.5, "Execution Lv5 burst");

  const ruptureLv2 = branchLevel("throwing_knife_belt_branch_bloodshadow", 2).special_rules.wound_on_throwing_knife_hit;
  assert(ruptureLv2.status_id === "wound" && ruptureLv2.duration === 4 && ruptureLv2.max_stacks === 5 && ruptureLv2.same_target_cooldown === 0.3, "Rupture Lv2 wound on hit");
  const ruptureLv3 = branchLevel("throwing_knife_belt_branch_bloodshadow", 3).special_rules.bleed_on_crit_wound;
  assert(ruptureLv3.required_status_id === "wound" && ruptureLv3.same_target_cooldown === 1, "Rupture Lv3 bleed trigger");
  const ruptureLv4Config = branchLevel("throwing_knife_belt_branch_bloodshadow", 4);
  const ruptureLv4 = ruptureLv4Config.special_rules.bleed_moving_target_bonus;
  assertEqual(ruptureLv4.damage_multiplier_add, 0.2, "Rupture Lv4 moving bleed bonus");
  assertEqual(ruptureLv4Config.special_rules.wound_tuning.duration_add, 1, "Rupture Lv4 wound duration");
  const ruptureLv5 = branchLevel("throwing_knife_belt_branch_bloodshadow", 5).special_rules.rupture_on_full_wound_crit;
  assert(ruptureLv5.required_wound_stacks === 5 && ruptureLv5.amount === 18 && ruptureLv5.same_target_cooldown === 1.5 && ruptureLv5.boss_damage_multiplier === 0.75, "Rupture Lv5 reaction");

  const recycleLv2 = branchLevel("throwing_knife_belt_branch_cloudpiercer", 2).special_rules.next_knife_damage_after_kill;
  assertEqual(recycleLv2.damage_multiplier_add, 0.2, "Recycle Lv2 next knife damage");
  const recycleLv3 = branchLevel("throwing_knife_belt_branch_cloudpiercer", 3).special_rules.recycle_knife_on_normal_kill;
  assert(recycleLv3.chance === 0.35 && recycleLv3.can_trigger_self === false, "Recycle Lv3 extra knife");
  const recycleLv4 = branchLevel("throwing_knife_belt_branch_cloudpiercer", 4).special_rules.recycle_knife_upgrade;
  assert(recycleLv4.prefer_low_hp_target === true && recycleLv4.damage_multiplier === 0.7, "Recycle Lv4 target/damage");
  const recycleLv5 = branchLevel("throwing_knife_belt_branch_cloudpiercer", 5).special_rules.recycle_dash_buff;
  assert(recycleLv5.window === 3 && recycleLv5.required_recycles === 3 && recycleLv5.move_speed_multiplier_add === 0.12 && recycleLv5.dodge_chance_add === 0.08, "Recycle Lv5 buff");
  assert(recycleLv5.boss_hit_interval === 6, "Recycle Lv5 Boss hit trigger");

  for (const key of [
    "extra_knife_every_n_casts",
    "same_target_short_window_decay",
    "low_hp_damage_bonus",
    "execution_mark_on_strong_target",
    "execution_mark_crit_damage_taken",
    "boss_low_hp_execution_burst",
    "wound_on_throwing_knife_hit",
    "wound_tuning",
    "bleed_on_crit_wound",
    "bleed_moving_target_bonus",
    "rupture_on_full_wound_crit",
    "next_knife_damage_after_kill",
    "recycle_knife_on_normal_kill",
    "recycle_knife_upgrade",
    "recycle_dash_buff",
  ]) {
    requireSpecialRuleKey(key);
  }

  const executor = fs.readFileSync(path.join(root, "scripts/skills/skill_special_rule_executor.gd"), "utf8");
  for (const snippet of [
    "extra_knife_every_n_casts",
    "boss_low_hp_execution_burst",
    "wound_on_throwing_knife_hit",
    "bleed_on_crit_wound",
    "recycle_knife_on_normal_kill",
  ]) {
    assert(executor.includes(snippet), `SkillSpecialRuleExecutor must handle ${snippet}`);
  }
  const handler = fs.readFileSync(path.join(root, "scripts/skills/special_damage_rule_handler.gd"), "utf8");
  for (const snippet of [
    "execute_extra_knife_throw",
    "execution_burst_intents",
    "rupture_on_full_wound_crit",
    "execute_recycle_knife",
  ]) {
    assert(handler.includes(snippet), `SpecialDamageRuleHandler must expose ${snippet}`);
  }

  console.log("Throwing knife belt branch table verification passed.");
}

main();
