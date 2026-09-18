const fs = require("fs");
const path = require("path");
const { readJsonFile, readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function approx(actual, expected, message, epsilon = 0.0001) {
  assert(Math.abs(Number(actual) - expected) <= epsilon, `${message}: expected ${expected}, got ${actual}`);
}

function isObject(value) {
  return value && typeof value === "object" && !Array.isArray(value);
}

function hasDamageTickWork(value) {
  if (!isObject(value)) {
    return false;
  }
  const type = String(value.type || "");
  if (["damage", "deal_damage", "damage_area"].includes(type)) {
    return true;
  }
  if (
    value.damage !== undefined ||
    value.tick_damage !== undefined ||
    value.power_scale !== undefined ||
    value.power_scale_per_stack !== undefined ||
    isObject(value.damage_packet) ||
    isObject(value.damage_packet_template)
  ) {
    return true;
  }
  for (const key of [
    "effects_on_tick",
    "actions_on_tick",
    "on_tick_effects",
    "on_tick",
    "effects",
    "actions",
    "on_hit",
    "actions_on_hit",
    "status_params",
    "params",
  ]) {
    const child = value[key];
    if (Array.isArray(child) && child.some(hasDamageTickWork)) {
      return true;
    }
    if (isObject(child) && hasDamageTickWork(child)) {
      return true;
    }
  }
  return false;
}

function collectLegacyDamageTicks(value, location, results) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => collectLegacyDamageTicks(item, `${location}[${index}]`, results));
    return;
  }
  if (!isObject(value)) {
    return;
  }
  if (Number(value.tick_interval) === 0.5 && hasDamageTickWork(value)) {
    results.push(location);
  }
  for (const [key, child] of Object.entries(value)) {
    collectLegacyDamageTicks(child, `${location}.${key}`, results);
  }
}

function assertNoLegacyDamageTicks(relativePath) {
  const legacyTicks = [];
  collectLegacyDamageTicks(readJson(relativePath), relativePath, legacyTicks);
  assert(
    legacyTicks.length === 0,
    `${relativePath} still has 0.5s damage tick intervals:\n${legacyTicks.join("\n")}`
  );
}

function assertNoSourceDefault(relativePath, forbiddenPatterns) {
  const source = read(relativePath);
  for (const pattern of forbiddenPatterns) {
    assert(!pattern.test(source), `${relativePath} still has a 0.5s tick damage default matching ${pattern}`);
  }
}

const statuses = readJson("data/combat/status_effects.json").statuses || [];
const byId = new Map(statuses.map((status) => [status.id, status]));

const expectedStatusTicks = {
  burning: { interval: 1.0, powerScale: 0.36 },
  poison: { interval: 1.0, damage: 12.0 },
  bleed: { interval: 1.0, damage: 8.0 },
  blackfire: { interval: 1.0, damage: 12.0 },
  radiance: { interval: 1.0, damage: 12.0 },
};

for (const [id, expected] of Object.entries(expectedStatusTicks)) {
  const status = byId.get(id);
  assert(status, `missing status ${id}`);
  approx(status.tick_interval, expected.interval, `${id} tick interval`);
  if (expected.damage !== undefined) {
    approx(status.damage, expected.damage, `${id} tick damage`);
  }
  if (expected.powerScale !== undefined) {
    assert(Array.isArray(status.on_tick_effects), `${id} must define on_tick_effects`);
    const damageEffect = status.on_tick_effects.find((effect) => effect.type === "damage");
    assert(damageEffect, `${id} must define a damage tick effect`);
    approx(damageEffect.power_scale, expected.powerScale, `${id} tick power scale`);
  }
}

for (const file of [
  "data/skills/skills.json",
  "data/combat/status_effects.json",
  "data/enemies/enemy_skills.json",
  "data/enemies/enemies.json",
  "data/characters/characters.json",
]) {
  assertNoLegacyDamageTicks(file);
}

for (const file of [
  "scripts/combat/area_effect.gd",
  "scripts/combat/damage_area.gd",
  "scripts/combat/status_effect_manager.gd",
  "scripts/combat/status_tick_scheduler.gd",
  "scripts/enemies/actions/enemy_action_registry.gd",
  "scripts/enemies/enemy_action_executor.gd",
  "scripts/enemies/behaviors/chase_and_cast_pool_behavior.gd",
  "scripts/characters/traits/status_kill_random_area_trait.gd",
  "scripts/skills/skill_action_area_builder.gd",
  "scripts/skills/special_damage_rule_handler.gd",
  "scripts/skills/skill_special_rule_executor.gd",
  "scripts/skills/fire_skill_runtime.gd",
  "scripts/maps/map_variable_runtime.gd",
]) {
  assertNoSourceDefault(file, [
    /tick_interval"\s*,\s*0\.5/g,
    /tick_interval"\s*:\s*0\.5/g,
    /tick_interval:\s*float\s*=\s*0\.5/g,
    /area_tick_interval"\s*,\s*0\.5/g,
    /pool_tick_interval"\s*,\s*0\.5/g,
    /poison_tick_interval"\s*,\s*0\.5/g,
  ]);
}

console.log("[verify_tick_damage_interval_contract] PASS");
