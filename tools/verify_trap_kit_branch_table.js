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
  const primary = findById(readJson("data/primary_attack.json").primary_attacks, "bear_trap", "primary attack");
  for (const definition of [primary]) {
    assertEqual(definition.base.damage, 30, "bear_trap base damage");
    assertEqual(definition.base.cooldown, 2.4, "bear_trap deploy interval");
    assertEqual(definition.base.area_radius, 90, "bear_trap trigger radius");
    assertEqual(definition.base.max_active_traps, 3, "bear_trap active trap cap");
    const targeting = definition.components.find((entry) => entry.type === "targeting");
    assert(!targeting, "bear_trap must not require a target before deploying");
    const castEvent = definition.events.find((event) => event.trigger === "on_cast");
    assert(castEvent, "bear_trap must have on_cast");
    const trap = actionByType(castEvent, "spawn_trap");
    assertEqual(trap.area_id, "bear_trap_area", "bear_trap area object");
    assertEqual(trap.position_mode, "caster", "bear_trap deploys at player feet");
    assertEqual(trap.damage, 30, "bear_trap trap damage");
    assertEqual(trap.radius, 90, "bear_trap trap radius");
    assertEqual(trap.max_active, 3, "bear_trap max active traps");
    assertEqual(trap.event_on_hit, "on_trap_hit", "bear_trap trap hit event");
    assertEqual(trap.finish_after_damage, true, "bear_trap consumes after trigger");
    assert(!Array.isArray(trap.statuses_on_hit) || trap.statuses_on_hit.length === 0, "bear_trap base trap must not apply status");
  }

  for (const statusId of ["root", "slow", "prey_mark"]) {
    findById(readJson("data/status_effects.json").statuses, statusId, "status");
  }
  findById(readJson("data/combat_objects.json").combat_objects, "bear_trap_area", "combat object");
  const contracts = fs.readFileSync(path.join(root, "tools/weapon_config_contracts.js"), "utf8");
  assert(contracts.includes("on_trap_hit") && contracts.includes("on_trap_expired"), "contracts must allow trap lifecycle events");

  const chainLv2 = branchLevel("trap_kit_branch_toxic_spike", 2);
  assertEqual(modifier(chainLv2, "max_active_traps", "add").value, 1, "Chain Lv2 trap cap");
  const chainLv3 = branchLevel("trap_kit_branch_toxic_spike", 3).special_rules.small_trap_on_trigger;
  assert(chainLv3.spawn_radius === 120 && chainLv3.damage_multiplier === 0.5 && chainLv3.count === 1, "Chain Lv3 small trap");
  const chainRootLv3 = branchLevel("trap_kit_branch_toxic_spike", 3).special_rules.chain_trap_root_on_hit;
  assert(chainRootLv3.status_id === "root" && chainRootLv3.normal_duration === 0.5 && chainRootLv3.elite_duration === 0.25 && chainRootLv3.boss_converts_to_poise === true, "Chain Lv3 root/control");
  const chainLv4 = branchLevel("trap_kit_branch_toxic_spike", 4).special_rules.small_trap_upgrade;
  assert(chainLv4.radius_multiplier_add === 0.2 && chainLv4.max_active === 2, "Chain Lv4 small trap upgrade");
  const chainLv5 = branchLevel("trap_kit_branch_toxic_spike", 5).special_rules.pincer_reaction_on_root;
  assert(chainLv5.required_status_id === "root" && chainLv5.amount === 16 && chainLv5.same_target_cooldown === 1.5, "Chain Lv5 pincer reaction");

  const hunterLv2 = branchLevel("trap_kit_branch_hunter_mark", 2).special_rules.hunter_trap_targeting;
  assert(hunterLv2.prefer_strong_targets === true, "Hunter Lv2 strong target preference");
  const hunterLv3 = branchLevel("trap_kit_branch_hunter_mark", 3).special_rules.prey_mark_on_strong_trap_hit;
  assert(hunterLv3.status_id === "prey_mark" && hunterLv3.duration === 5 && hunterLv3.trap_damage_multiplier_add === 0.15, "Hunter Lv3 prey mark");
  const hunterLv4 = branchLevel("trap_kit_branch_hunter_mark", 4).special_rules.boss_core_focus;
  assert(hunterLv4.target_weight_multiplier_add === 3 && hunterLv4.boss_core_damage_multiplier_add === 0.25, "Hunter Lv4 boss core focus");
  const hunterLv5 = branchLevel("trap_kit_branch_hunter_mark", 5).special_rules.boss_core_trap_bonus_damage;
  assert(hunterLv5.amount === 28 && hunterLv5.same_target_cooldown === 3, "Hunter Lv5 bonus damage");

  const blastLv2 = branchLevel("trap_kit_branch_blast", 2).special_rules.trap_radius_upgrade;
  assertClose(blastLv2.radius_multiplier_add, 0.25, "Blast Lv2 radius");
  const blastLv3 = branchLevel("trap_kit_branch_blast", 3).special_rules.trap_hit_explosion;
  assert(blastLv3.radius === 100 && blastLv3.max_targets === 6 && blastLv3.damage_type === "area_direct", "Blast Lv3 explosion");
  const blastLv4 = branchLevel("trap_kit_branch_blast", 4);
  assertClose(modifier(blastLv4, "trap_interval", "multiplier_add").value, -0.12, "Blast Lv4 deploy interval");
  assertClose(blastLv4.special_rules.trap_explosion_upgrade.damage_multiplier_add, 0.15, "Blast Lv4 explosion damage");
  const blastLv5 = branchLevel("trap_kit_branch_blast", 5).special_rules.trap_kill_fragment_field;
  assert(blastLv5.duration === 1.5 && blastLv5.tick_interval === 0.5 && blastLv5.amount === 4 && blastLv5.max_active === 4, "Blast Lv5 fragment field");

  const decoyLv2 = branchLevel("trap_kit_branch_ice_lock", 2).special_rules.decoy_trap_spawn;
  assert(decoyLv2.spawn_interval === 10 && decoyLv2.duration === 4, "Decoy Lv2 spawn");
  const decoyLv3 = branchLevel("trap_kit_branch_ice_lock", 3).special_rules.decoy_trap_explosion;
  assert(decoyLv3.attracts_normal === true && decoyLv3.explode_on_expire === true, "Decoy Lv3 attraction/explosion");
  const decoyLv4 = branchLevel("trap_kit_branch_ice_lock", 4).special_rules.decoy_trap_upgrade;
  assert(decoyLv4.hp_multiplier_add === 0.4 && decoyLv4.explosion_radius_multiplier_add === 0.2, "Decoy Lv4 upgrade");
  const decoyLv5 = branchLevel("trap_kit_branch_ice_lock", 5).special_rules.decoy_boss_core_bonus;
  assert(decoyLv5.boss_summon_prefer_decoy === true && decoyLv5.boss_core_damage_multiplier_add === 0.3, "Decoy Lv5 boss core bonus");

  for (const key of [
    "small_trap_on_trigger",
    "small_trap_upgrade",
    "chain_trap_root_on_hit",
    "pincer_reaction_on_root",
    "hunter_trap_targeting",
    "prey_mark_on_strong_trap_hit",
    "boss_core_focus",
    "boss_core_trap_bonus_damage",
    "trap_radius_upgrade",
    "trap_hit_explosion",
    "trap_explosion_upgrade",
    "trap_kill_fragment_field",
    "decoy_trap_spawn",
    "decoy_trap_explosion",
    "decoy_trap_upgrade",
    "decoy_boss_core_bonus",
  ]) {
    requireSpecialRuleKey(key);
  }

  const areaEffect = fs.readFileSync(path.join(root, "scripts/combat/area_effect.gd"), "utf8");
  assert(areaEffect.includes("event_on_hit") && areaEffect.includes("finish_after_damage"), "AreaEffect must emit trap hit events and consume traps");
  const executor = fs.readFileSync(path.join(root, "scripts/skills/skill_special_rule_executor.gd"), "utf8");
  for (const snippet of ["on_trap_hit", "small_trap_on_trigger", "chain_trap_root_on_hit", "pincer_reaction_on_root", "decoy_trap_spawn"]) {
    assert(executor.includes(snippet), `SkillSpecialRuleExecutor must handle ${snippet}`);
  }
  const handler = fs.readFileSync(path.join(root, "scripts/skills/special_damage_rule_handler.gd"), "utf8");
  for (const snippet of ["execute_small_trap_on_trigger", "pincer_reaction_intents", "execute_trap_hit_explosion", "execute_decoy_trap_spawn"]) {
    assert(handler.includes(snippet), `SpecialDamageRuleHandler must expose ${snippet}`);
  }

  console.log("Trap kit branch table verification passed.");
}

main();
