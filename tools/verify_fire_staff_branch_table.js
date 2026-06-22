const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const branches = readJsonFile(path.join(root, "data", "weapon_branches.json")).branches || [];
const attacks = readJsonFile(path.join(root, "data", "primary_attack.json")).primary_attacks || [];
const statuses = readJsonFile(path.join(root, "data", "status_effects.json")).statuses || [];

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertApprox(actual, expected, message, tolerance = 0.0001) {
  if (Math.abs(Number(actual) - expected) > tolerance) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

function branch(id) {
  const result = branches.find((item) => item.id === id);
  assert(result, `Missing branch ${id}`);
  return result;
}

function level(branchDefinition, levelNumber) {
  const result = ((branchDefinition.level_path || {})[String(levelNumber)]) || {};
  assert(Object.keys(result).length > 0, `Missing ${branchDefinition.id} Lv${levelNumber}`);
  return result;
}

function modifier(config, expected) {
  return (config.modifiers || []).find((item) => {
    if (!item || item.stat !== expected.stat || item.op !== expected.op) return false;
    const scope = item.scope || {};
    for (const [key, value] of Object.entries(expected.scope || {})) {
      const actual = scope[key];
      if (Array.isArray(value)) {
        if (!Array.isArray(actual) || value.some((entry) => !actual.includes(entry))) return false;
      } else if (actual !== value) {
        return false;
      }
    }
    return true;
  }) || null;
}

function expectModifier(config, expected, label) {
  const result = modifier(config, expected);
  assert(result, `${label} modifier is missing`);
  return result;
}

function action(config, type) {
  for (const event of config.events_added || []) {
    const found = (event.actions || []).find((item) => item.type === type);
    if (found) return found;
  }
  return null;
}

function status(id) {
  return statuses.find((item) => item.id === id);
}

function assertNoRule(key) {
  const text = JSON.stringify(branches);
  assert(!text.includes(`"${key}"`), `old special rule ${key} must be removed from weapon_branches.json`);
}

const fireball = attacks.find((item) => item.id === "fireball");
assert(fireball, "fireball must exist");
assertApprox(fireball.base.damage, 16, "fireball base damage");
assertApprox(fireball.base.cooldown, 1.1, "fireball attack interval");
assertApprox(fireball.base.range, 540, "fireball range");

const burst = branch("fire_staff_branch_burst");
assertApprox(expectModifier(level(burst, 2), { stat: "radius", op: "multiplier_add", scope: { domain: "object", object_type: ["explosion"] } }, "Burst Lv2 radius").value, 0.15, "Burst Lv2 radius");
assert(action(level(burst, 2), "create_explosion"), "Burst Lv2 must create fireball explosion");
const burstLv2Burn = level(burst, 2).special_rules.explosion_multi_hit_burn;
assert(burstLv2Burn && burstLv2Burn.min_targets_hit === 3 && burstLv2Burn.status_id === "burn", "Burst Lv2 multi-hit burn");
assertApprox(burstLv2Burn.duration, 3, "Burst Lv2 burn duration");
const burstLv3Burn = level(burst, 3).special_rules.explosion_direct_hit_burn_on_elite_boss;
assert(burstLv3Burn && burstLv3Burn.same_target_cooldown === 1.5, "Burst Lv3 elite/Boss burn");
const burstLv4 = level(burst, 4).special_rules.burn_target_burst_explosion_damage_bonus;
assertApprox(burstLv4.damage_multiplier_add, 0.10, "Burst Lv4 burning target explosion bonus");
	const burstLv5 = level(burst, 5).special_rules.burning_target_death_explosion;
	assert(burstLv5 && burstLv5.max_targets === 6 && burstLv5.same_source_cooldown === 0.25, "Burst Lv5 death explosion limits");
	assertApprox(burstLv5.radius, 80, "Burst Lv5 death explosion radius");
	assertApprox(burstLv5.damage_multiplier, 0.35, "Burst Lv5 death explosion damage");
assertApprox(burstLv5.boss_damage_multiplier, 0.75, "Burst Lv5 death explosion Boss modifier");
assert(burstLv5.can_trigger_self === false, "Burst Lv5 death explosion must not recurse");

const core = branch("fire_staff_branch_rapid");
assertApprox(expectModifier(level(core, 2), { stat: "damage", op: "multiplier_add", scope: { domain: "damage", damage_origin: ["primary_attack"] } }, "Core Lv2 direct hit damage").value, 0.12, "Core Lv2 direct hit damage");
assertApprox(expectModifier(level(core, 2), { stat: "radius", op: "multiplier_add", scope: { domain: "object", object_type: ["explosion"] } }, "Core Lv2 explosion radius tradeoff").value, -0.10, "Core Lv2 explosion radius tradeoff");
assert(action(level(core, 2), "create_explosion"), "Core Lv2 must keep a smaller explosion");
const coreLv3 = level(core, 3).special_rules.flame_core_on_elite_boss_direct_hit;
assert(coreLv3 && coreLv3.max_stacks === 5, "Core Lv3 flame_core max stacks");
assertApprox(coreLv3.direct_damage_multiplier_add_per_stack, 0.03, "Core Lv3 per-stack direct damage");
assertApprox(level(core, 4).special_rules.flame_core_duration_add, 2, "Core Lv4 duration add");
assertApprox(level(core, 4).special_rules.flame_core_full_stack_explosion_vulnerability.explosion_damage_taken_multiplier_add, 0.6, "Core Lv4 full-stack explosion vulnerability");
const coreLv5 = level(core, 5).special_rules.flame_core_boss_burst;
assert(coreLv5.required_stacks === 5 && coreLv5.hit_interval === 4 && coreLv5.amount === 32, "Core Lv5 boss burst");
assertApprox(coreLv5.same_target_cooldown, 2, "Core Lv5 boss burst cooldown");

const soul = branch("fire_staff_branch_soulburn");
const soulLv2 = level(soul, 2).special_rules.soul_ember_on_direct_hit;
assert(soulLv2 && soulLv2.status_id === "soul_ember" && soulLv2.max_stacks === 4, "Soulburn Lv2 soul_ember stacking");
assertApprox(soulLv2.duration, 4, "Soulburn Lv2 soul_ember duration");
assertApprox(soulLv2.same_target_cooldown, 0.4, "Soulburn Lv2 soul_ember cooldown");
const soulLv3 = level(soul, 3).special_rules.soul_ember_to_burn_on_full_stack_hit;
assert(soulLv3 && soulLv3.required_stacks === 2 && soulLv3.consume_stacks === 2 && soulLv3.apply_burn_stacks === 1 && soulLv3.burn_max_stacks === 5, "Soulburn Lv3 soul_ember conversion");
assertApprox(expectModifier(level(soul, 3), { stat: "damage", op: "multiplier_add", scope: { domain: "damage", damage_origin: ["primary_attack"] } }, "Soulburn Lv3 direct damage penalty").value, -0.15, "Soulburn Lv3 direct damage penalty");
assertApprox(expectModifier(level(soul, 3), { stat: "status_damage", op: "multiplier_add", scope: { domain: "status", status_id: ["burn"] } }, "Soulburn Lv3 burn damage").value, 0.30, "Soulburn Lv3 burn damage");
assertApprox(expectModifier(level(soul, 4), { stat: "status_duration", op: "add", scope: { domain: "status", status_id: ["burn"] } }, "Soulburn Lv4 burn duration").value, 1.0, "Soulburn Lv4 burn duration");
const soulLv5 = level(soul, 5).special_rules.soulburn_burst_on_full_burn_direct_hit;
assert(soulLv5.required_burn_stacks === 5 && soulLv5.consume_burn_stacks === "all", "Soulburn Lv5 burn trigger and consumption");
assert(soulLv5.same_target_cooldown === 2, "Soulburn Lv5 burst cooldown");

const lava = branch("fire_staff_branch_lava");
assertApprox(level(lava, 2).special_rules.ground_fire_on_hit.duration, 1, "Lava Lv2 duration");
const lavaLv3 = level(lava, 3).special_rules.player_lava_on_nearby_fireball_hit;
assert(lavaLv3 && lavaLv3.spawn_position === "player" && lavaLv3.near_player_radius === 160, "Lava Lv3 player lava");
assertApprox(lavaLv3.duration, 2.0, "Lava Lv3 player lava duration");
assertApprox(lavaLv3.tick_interval, 0.5, "Lava Lv3 player lava tick interval");
assertApprox(lavaLv3.damage_from_fireball_base, 0.2, "Lava Lv3 player lava damage ratio");
assertApprox(lavaLv3.same_source_cooldown, 3, "Lava Lv3 cooldown");
const lavaLv4 = level(lava, 4).special_rules.lava_slow;
assert(lavaLv4 && lavaLv4.slow_percent === 0.30 && lavaLv4.boss_slow_percent === 0.15, "Lava Lv4 slow");
const lavaLv5 = level(lava, 5).special_rules.protective_lava_ring_on_player_damaged;
assert(lavaLv5 && lavaLv5.radius === 130 && lavaLv5.duration === 3 && lavaLv5.same_source_cooldown === 12, "Lava Lv5 protective ring");
assertApprox(lavaLv5.damage_taken_multiplier_add, -0.50, "Lava Lv5 damage reduction");

for (const id of ["flame_core", "soul_ember", "burn"]) {
  assert(status(id), `${id} status must exist`);
}
for (const oldKey of ["heat_on_direct_hit", "heat_to_burn_on_full_heat_hit", "same_target_explosion_hits_required", "merge_lava_zones", "burn_damage_multiplier_add_in_lava", "boss_burn_stack_to_poise"]) {
  assertNoRule(oldKey);
}

const specialExecutor = read("scripts/skills/skill_special_rule_executor.gd");
assert(specialExecutor.includes("soul_ember_on_direct_hit"), "SkillSpecialRuleExecutor must execute soul_ember stacking");
assert(specialExecutor.includes("soul_ember_to_burn_on_full_stack_hit"), "SkillSpecialRuleExecutor must execute soul_ember conversion");
assert(!specialExecutor.includes("heat_on_direct_hit"), "SkillSpecialRuleExecutor must not keep heat branch rule");

const specialHandler = read("scripts/skills/special_damage_rule_handler.gd");
assert(specialHandler.includes("player_lava_on_nearby_fireball_hit"), "SpecialDamageRuleHandler must support player lava on nearby hit");
assert(specialHandler.includes("protective_lava_ring_on_player_damaged"), "SpecialDamageRuleHandler must support protective lava rings");

console.log("Fire staff branch table verification passed.");
