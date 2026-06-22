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
  const primary = findById(readJson("data/primary_attack.json").primary_attacks, "judgement_hammer", "primary attack");
  assertEqual(primary.base.damage, 40, "judgement_hammer base damage");
  assertEqual(primary.base.cooldown, 2.55, "judgement_hammer attack interval");
  assertEqual(primary.base.area_radius, 90, "judgement_hammer impact radius");
  assertEqual(primary.base.max_targets, 4, "judgement_hammer max targets");
  const cast = primary.events.find((event) => event.trigger === "on_cast");
  const area = (cast.actions || []).find((action) => action.type === "spawn_area");
  assert(area, "judgement_hammer casts an impact area");
  assert(!area.params.status_on_hit && !area.params.statuses_on_hit, "judgement_hammer base impact must not apply status");
  assert(primary.base_special_rules && primary.base_special_rules.warhammer_base, "judgement_hammer must define base special rule");
  assert(!primary.base_special_rules.warhammer_base.status_id, "warhammer base rule must not apply status");

  const judgment = findById(readJson("data/status_effects.json").statuses, "judgment", "status");
  assertEqual(judgment.max_stacks, 4, "judgment max stacks for branch-created status");
  findById(readJson("data/status_effects.json").statuses, "stun", "status");

  const quakeLv2 = branchLevel("warhammer_branch_quake", 2);
  assertClose(modifier(quakeLv2, "radius", "multiplier_add").value, 0.2, "Quake Lv2 radius");
  assert(branchLevel("warhammer_branch_quake", 3).special_rules.warhammer_crack_field.amount === 5, "Quake Lv3 crack field");
  assert(branchLevel("warhammer_branch_quake", 4).special_rules.warhammer_crack_upgrade.max_targets === 6, "Quake Lv4 crack upgrade");
  assert(branchLevel("warhammer_branch_quake", 5).special_rules.warhammer_quake_slam_every_n_casts.cast_interval === 3, "Quake Lv5 quake slam");

  const judgeLv2 = branchLevel("warhammer_branch_heaven", 2).special_rules.judgment_on_strong_hit;
  assert(judgeLv2.status_id === "judgment" && judgeLv2.max_stacks === 4 && judgeLv2.duration === 5 && judgeLv2.same_target_cooldown === 1, "Judgement Lv2 status");
  const judgeLv3 = branchLevel("warhammer_branch_heaven", 3).special_rules.warhammer_judgement_shock;
  assert(judgeLv3.required_stacks === 4 && judgeLv3.amount === 22 && judgeLv3.same_target_cooldown === 2 && judgeLv3.boss_poise_stacks === 1, "Judgement Lv3 shock");
  const judgeLv4 = branchLevel("warhammer_branch_heaven", 4).special_rules.warhammer_judgement_shock_upgrade;
  assertClose(judgeLv4.elite_boss_damage_multiplier_add, 0.25, "Judgement Lv4 elite/boss bonus");
  assertEqual(judgeLv4.boss_poise_duration_add, 1, "Judgement Lv4 boss poise duration");
  const judgeLv5 = branchLevel("warhammer_branch_heaven", 5).special_rules.warhammer_boss_poise_judgement_bonus;
  assert(judgeLv5.amount === 34 && judgeLv5.same_target_cooldown === 2.5, "Judgement Lv5 poise bonus");

  const executeLv2 = branchLevel("warhammer_branch_punish", 2);
  assertClose(modifier(executeLv2, "damage", "multiplier_add").value, 0.18, "Execute Lv2 damage");
  assertClose(modifier(executeLv2, "attack_speed", "multiplier_add").value, -0.074074, "Execute Lv2 interval cost");
  assert(branchLevel("warhammer_branch_punish", 3).special_rules.warhammer_low_hp_damage_bonus.hp_threshold === 0.4, "Execute Lv3 low hp bonus");
  assertClose(modifier(branchLevel("warhammer_branch_punish", 4), "crit_damage", "add").value, 0.25, "Execute Lv4 crit damage");
  assert(branchLevel("warhammer_branch_punish", 5).special_rules.warhammer_boss_low_hp_shockwave.same_target_cooldown === 3, "Execute Lv5 boss shockwave");

  assertClose(branchLevel("warhammer_branch_combo", 2).special_rules.warhammer_knockback_multiplier.multiplier_add, 0.25, "Control Lv2 knockback");
  assert(branchLevel("warhammer_branch_combo", 3).special_rules.warhammer_stun_on_hit.boss_converts_to_poise === true, "Control Lv3 stun");
  assertClose(branchLevel("warhammer_branch_combo", 4).special_rules.warhammer_stun_target_damage_taken.primary_attack_damage_taken_multiplier_add, 0.15, "Control Lv4 stunned target damage");
  assert(branchLevel("warhammer_branch_combo", 5).special_rules.warhammer_forced_shock_every_n_seconds.boss_poise_stacks === 1, "Control Lv5 forced shock");

  for (const key of [
    "warhammer_base",
    "warhammer_crack_field",
    "warhammer_crack_upgrade",
    "warhammer_quake_slam_every_n_casts",
    "judgment_on_strong_hit",
    "warhammer_judgement_shock",
    "warhammer_judgement_shock_upgrade",
    "warhammer_boss_poise_judgement_bonus",
    "warhammer_low_hp_damage_bonus",
    "warhammer_boss_low_hp_shockwave",
    "warhammer_knockback_multiplier",
    "warhammer_stun_on_hit",
    "warhammer_stun_target_damage_taken",
    "warhammer_forced_shock_every_n_seconds",
  ]) requireSpecialRuleKey(key);

  const executor = fs.readFileSync(path.join(root, "scripts/skills/skill_special_rule_executor.gd"), "utf8");
  for (const snippet of ["judgment_on_strong_hit", "warhammer_stun_target_damage_taken", "warhammer_quake_slam_every_n_casts"]) {
    assert(executor.includes(snippet), `SkillSpecialRuleExecutor must handle ${snippet}`);
  }
  console.log("Warhammer branch table verification passed.");
}

main();
