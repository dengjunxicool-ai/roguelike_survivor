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
  const primary = findById(readJson("data/primary_attack.json").primary_attacks, "piercing_arrow", "primary attack");
  assertEqual(primary.base.damage, 28, "piercing_arrow base damage");
  assertEqual(primary.base.cooldown, 2.2, "piercing_arrow attack interval");
  assertEqual(primary.base.range, 720, "piercing_arrow range");
  assertEqual(primary.base.pierce, 3, "piercing_arrow base pierce");
  const targeting = primary.components.find((entry) => entry.type === "targeting");
  assert(targeting && targeting.params.mode === "highest_hp_enemy", "piercing_arrow should target high-value enemies");
  assertEqual(targeting.params.range, 720, "piercing_arrow targeting range");
  const castEvent = primary.events.find((event) => event.trigger === "on_cast");
  assert(castEvent, "piercing_arrow must have on_cast");
  const spawn = actionByType(castEvent, "spawn_projectile");
  assertEqual(spawn.projectile_id, "hunter_arrow_projectile", "piercing_arrow projectile object");
  assertEqual(spawn.count, 1, "piercing_arrow spawn count");
  assertEqual(spawn.damage, 28, "piercing_arrow projectile damage");
  assertEqual(spawn.pierce, 3, "piercing_arrow projectile pierce");
  const hitEvent = primary.events.find((event) => event.trigger === "on_projectile_hit");
  assert(hitEvent, "piercing_arrow must have on_projectile_hit");
  assertEqual(hitEvent.source_id, "hunter_arrow_projectile", "piercing_arrow hit source");
  const damage = actionByType(hitEvent, "deal_damage");
  assertEqual(damage.amount, 28, "piercing_arrow hit damage");
  assertEqual(damage.damage_origin, "primary_attack", "piercing_arrow damage origin");
  assert(!(hitEvent.actions || []).some((entry) => entry.type === "apply_status"), "piercing_arrow base attack must not apply status");

  findById(readJson("data/status_effects.json").statuses, "eagle_mark", "status");
  findById(readJson("data/status_effects.json").statuses, "burst_mark", "status");
  findById(readJson("data/combat_objects.json").combat_objects, "hunter_arrow_projectile", "combat object");

  const volleyLv2 = branchLevel("hunter_bow_branch_volley", 2);
  assertEqual(modifier(volleyLv2, "pierce", "add").value, 1, "Volley Lv2 pierce");
  assertClose(volleyLv2.special_rules.hunter_arrow_pierce_tuning.pierce_damage_multiplier_per_extra_hit, 0.88, "Volley Lv2 pierce decay");
  const volleyLv3 = branchLevel("hunter_bow_branch_volley", 3).special_rules.hunter_arrow_shards_after_pierce_hits;
  assert(volleyLv3.required_hits === 3 && volleyLv3.shard_count === 3 && volleyLv3.amount === 6, "Volley Lv3 shards");
  const volleyLv4 = branchLevel("hunter_bow_branch_volley", 4);
  assertClose(modifier(volleyLv4, "attack_speed", "multiplier_add").value, 0.1111, "Volley Lv4 attack interval");
  assertClose(modifier(volleyLv4, "projectile_speed", "multiplier_add").value, 0.2, "Volley Lv4 arrow speed");
  const volleyLv5 = branchLevel("hunter_bow_branch_volley", 5).special_rules.cloud_arrow_every_n_casts;
  assert(volleyLv5.cast_interval === 3 && volleyLv5.pierce_override === 7 && volleyLv5.max_targets === 8 && volleyLv5.pierce_damage_multiplier_per_extra_hit === 0.82, "Volley Lv5 cloud arrow");

  const eagleLv2 = branchLevel("hunter_bow_branch_snipe", 2).special_rules.eagle_mark_on_strong_hit;
  assert(eagleLv2.status_id === "eagle_mark" && eagleLv2.duration === 6 && eagleLv2.max_active_targets === 2, "Eagle Lv2 mark on strong target");
  const eagleLv3 = branchLevel("hunter_bow_branch_snipe", 3).special_rules.eagle_mark_primary_damage_taken;
  assert(eagleLv3.status_id === "eagle_mark", "Eagle Lv3 uses eagle_mark");
  assertClose(eagleLv3.primary_attack_damage_taken_multiplier_add, 0.15, "Eagle Lv3 mark damage taken");
  const eagleLv4 = branchLevel("hunter_bow_branch_snipe", 4).special_rules.eagle_marked_hit_cooldown_refund;
  assert(eagleLv4.status_id === "eagle_mark" && eagleLv4.chance === 0.25 && eagleLv4.same_source_cooldown === 2, "Eagle Lv4 cooldown refund");
  const eagleLv5 = branchLevel("hunter_bow_branch_snipe", 5).special_rules.eagle_shot_on_boss_eagle_mark_hits;
  assert(eagleLv5.status_id === "eagle_mark" && eagleLv5.required_hits === 6 && eagleLv5.amount === 36 && eagleLv5.damage_type === "projectile_heavy", "Eagle Lv5 shot");

  const explosiveLv2 = branchLevel("hunter_bow_branch_explosive", 2).special_rules.hunter_arrow_hit_explosion;
  assert(explosiveLv2.radius === 75 && explosiveLv2.damage_multiplier === 0.35, "Explosive Lv2 hit explosion");
  const explosiveLv3 = branchLevel("hunter_bow_branch_explosive", 3).special_rules.burst_mark_on_arrow_explosion;
  assert(explosiveLv3.status_id === "burst_mark" && explosiveLv3.duration === 3 && explosiveLv3.max_targets === 3 && explosiveLv3.normal_only === true, "Explosive Lv3 explosion mark");
  const explosiveLv4 = branchLevel("hunter_bow_branch_explosive", 4).special_rules.hunter_arrow_explosion_upgrade;
  assert(explosiveLv4.radius_multiplier_add === 0.2 && explosiveLv4.max_targets === 6, "Explosive Lv4 explosion upgrade");
  const explosiveLv5 = branchLevel("hunter_bow_branch_explosive", 5).special_rules.burst_mark_death_explosion;
  assert(explosiveLv5.required_status_id === "burst_mark" && explosiveLv5.same_source_cooldown === 0.25 && explosiveLv5.can_trigger_self === false && explosiveLv5.boss_damage_multiplier === 0.75, "Explosive Lv5 death explosion");

  const windLv2 = branchLevel("hunter_bow_branch_boomerang", 2).special_rules.windstep_projectile_speed;
  assertClose(windLv2.projectile_speed_multiplier_add, 0.2, "Windstep Lv2 moving speed");
  const windLv3 = branchLevel("hunter_bow_branch_boomerang", 3).special_rules.windstep_state;
  assert(windLv3.required_moving_seconds === 2.5 && windLv3.attack_speed_multiplier_add === 0.1364, "Windstep Lv3 state");
  const windLv4 = branchLevel("hunter_bow_branch_boomerang", 4).special_rules.windstep_state;
  assertEqual(windLv4.keep_after_stop, 0.6, "Windstep Lv4 grace");
  const windLv5 = branchLevel("hunter_bow_branch_boomerang", 5).special_rules.windstep_double_arrow;
  assert(windLv5.cast_interval === 4 && windLv5.extra_projectile_count === 1 && windLv5.damage_multiplier_add === -0.25, "Windstep Lv5 double arrow");

  for (const key of [
    "hunter_arrow_pierce_tuning",
    "hunter_arrow_shards_after_pierce_hits",
    "cloud_arrow_every_n_casts",
    "eagle_mark_on_strong_hit",
    "eagle_mark_primary_damage_taken",
    "eagle_marked_hit_cooldown_refund",
    "eagle_shot_on_boss_eagle_mark_hits",
    "hunter_arrow_hit_explosion",
    "burst_mark_on_arrow_explosion",
    "hunter_arrow_explosion_upgrade",
    "burst_mark_death_explosion",
    "windstep_projectile_speed",
    "windstep_state",
    "windstep_double_arrow",
  ]) {
    requireSpecialRuleKey(key);
  }

  const executor = fs.readFileSync(path.join(root, "scripts/skills/skill_special_rule_executor.gd"), "utf8");
  for (const snippet of [
    "cloud_arrow_every_n_casts",
    "eagle_mark_on_strong_hit",
    "eagle_mark_primary_damage_taken",
    "eagle_marked_hit_cooldown_refund",
    "windstep_state",
  ]) {
    assert(executor.includes(snippet), `SkillSpecialRuleExecutor must handle ${snippet}`);
  }
  const handler = fs.readFileSync(path.join(root, "scripts/skills/special_damage_rule_handler.gd"), "utf8");
  for (const snippet of [
    "execute_hunter_arrow_shards",
    "eagle_shot_intents",
    "execute_hunter_arrow_hit_explosion",
    "execute_burst_mark_death_explosion",
    "execute_windstep_double_arrow",
  ]) {
    assert(handler.includes(snippet), `SpecialDamageRuleHandler must expose ${snippet}`);
  }

  console.log("Hunter bow branch table verification passed.");
}

main();
