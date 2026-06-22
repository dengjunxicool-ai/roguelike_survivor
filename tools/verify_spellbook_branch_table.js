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

function requireSpecialRuleKey(key) {
  assert(SPECIAL_RULE_KEYS.includes(key), `SPECIAL_RULE_KEYS must include ${key}`);
}

function main() {
  const primary = findById(readJson("data/primary_attack.json").primary_attacks, "arcane_pages", "primary attack");
  assertEqual(primary.base.damage, 13, "arcane_pages base damage");
  assertEqual(primary.base.cooldown, 0.9, "arcane_pages attack interval");
  assertEqual(primary.base.range, 560, "arcane_pages range");
  const hitEvent = primary.events.find((event) => event.trigger === "on_projectile_hit");
  assert(hitEvent, "arcane_pages must have on_projectile_hit");
  const damage = actionByType(hitEvent, "deal_damage");
  assertEqual(damage.amount, 13, "arcane_pages hit damage");
  assert(!hitEvent.actions.some((entry) => entry.type === "apply_status"), "arcane_pages base must not apply status");

  findById(readJson("data/status_effects.json").statuses, "arcane_seal", "status");
  findById(readJson("data/combat_objects.json").combat_objects, "arcane_page_projectile", "combat object");

  const copyLv2 = branchLevel("spellbook_branch_copy", 2).special_rules.arcane_page_copy_on_hit;
  assert(copyLv2.chance === 0.25 && copyLv2.damage_multiplier === 0.45 && copyLv2.boss_damage_multiplier === 0.9, "Copy Lv2");
  assert(branchLevel("spellbook_branch_copy", 5).special_rules.arcane_double_page_every_n_casts.cast_interval === 5, "Copy Lv5");

  const sealLv2 = branchLevel("spellbook_branch_barrage", 2).special_rules.arcane_seal_on_elite_boss_hit;
  assert(sealLv2.status_id === "arcane_seal" && sealLv2.max_stacks === 5 && sealLv2.same_target_cooldown === 0.4, "Barrage Lv2 seal");
  const burstLv3 = branchLevel("spellbook_branch_barrage", 3).special_rules.arcane_seal_burst;
  assert(burstLv3.required_stacks === 5 && burstLv3.consume_stacks === 3 && burstLv3.amount === 20, "Barrage Lv3 burst");
  assert(burstLv3.boss_damage_multiplier === 0.75 && burstLv3.damage_origin === "reaction", "Barrage Boss modifier");
  const burstLv4 = branchLevel("spellbook_branch_barrage", 4).special_rules.arcane_seal_burst_elite_boss_bonus;
  assertEqual(burstLv4.damage_multiplier_add, 0.2, "Barrage Lv4 elite/Boss bonus");
  assertEqual(branchLevel("spellbook_branch_barrage", 4).special_rules.arcane_seal_duration_add, 1, "Barrage Lv4 duration");
  const burstLv5 = branchLevel("spellbook_branch_barrage", 5).special_rules.arcane_seal_burst_vulnerability;
  assert(burstLv5.duration === 2 && burstLv5.primary_attack_damage_taken_multiplier_add === 0.12, "Barrage Lv5 vulnerability");

  assert(branchLevel("spellbook_branch_forbidden", 2).special_rules.forbidden_page_risk.damage_multiplier_add === 0.15, "Forbidden Lv2");
  assert(branchLevel("spellbook_branch_guardian_page", 2).special_rules.page_spirit_spawn.max_spirits === 2, "Guardian Lv2");

  for (const key of [
    "arcane_page_copy_on_hit",
    "arcane_double_page_every_n_casts",
    "arcane_seal_on_elite_boss_hit",
    "arcane_seal_burst",
    "arcane_seal_burst_elite_boss_bonus",
    "arcane_seal_burst_vulnerability",
    "forbidden_page_risk",
    "forbidden_page_every_n_casts",
    "forbidden_page_upgrade",
    "forbidden_boss_stack",
    "page_spirit_spawn",
    "page_spirit_attack",
    "page_spirit_remote_damage_reduction",
    "page_spirit_intercept",
  ]) {
    requireSpecialRuleKey(key);
  }

  const branchesText = JSON.stringify(readJson("data/weapon_branches.json").branches);
  for (const oldKey of ["arcane_mark_tuning", "arcane_mark_burst", "arcane_mark_burst_elite_boss_bonus", "arcane_mark_burst_vulnerability"]) {
    assert(!branchesText.includes(`"${oldKey}"`), `old special rule ${oldKey} must be removed`);
  }

  const executor = fs.readFileSync(path.join(root, "scripts/skills/skill_special_rule_executor.gd"), "utf8");
  assert(executor.includes("arcane_seal_burst"), "SkillSpecialRuleExecutor must handle arcane_seal_burst");
  assert(!executor.includes("arcane_mark_burst"), "SkillSpecialRuleExecutor must not keep arcane_mark burst rule");
  const handler = fs.readFileSync(path.join(root, "scripts/skills/special_damage_rule_handler.gd"), "utf8");
  assert(handler.includes("arcane_seal_burst_intents"), "SpecialDamageRuleHandler must expose arcane_seal_burst_intents");

  console.log("Spellbook branch table verification passed.");
}

main();
