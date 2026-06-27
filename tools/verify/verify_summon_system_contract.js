const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

const requiredFiles = [
  "scripts/summons/summon_definition.gd",
  "scripts/summons/summon_manager.gd",
  "scripts/summons/summon_controller.gd",
  "scripts/summons/summon_targeting_component.gd",
  "scripts/summons/summon_movement_component.gd",
  "scripts/summons/summon_attack_component.gd",
  "scripts/summons/summon_formation_service.gd",
  "scenes/summons/summon_controller.tscn",
  "data/summons/summons.json",
];

for (const relativePath of requiredFiles) {
  assert(fs.existsSync(path.join(root, relativePath)), `${relativePath} must exist`);
}

const summons = readJson("data/summons/summons.json").summons || [];
const byId = new Map(summons.map((summon) => [summon.id, summon]));
assert(byId.has("summon_frost_wolf"), "data/summons/summons.json must include frost wolf example");
assert(byId.has("crimson_dragon"), "data/summons/summons.json must include crimson dragon summon definition");

const dragon = byId.get("crimson_dragon");
assert(dragon.movement && Number(dragon.movement.leash_distance) >= 540, "crimson dragon leash/activity range must support a 540px player attack radius");
assert(dragon.attack && dragon.attack.on_hit_effects.some((effect) => effect.type === "apply_status" && effect.status === "burning"), "crimson dragon must apply Burning through summon attack config");
assert(dragon.visual && dragon.visual.texture === "res://assets/effect/crimson_dragon.png", "crimson dragon must keep the generated dragon visual");

const skills = readJson("data/skills/skills.json").skills || [];
const fireDragon = skills.find((skill) => skill.id === "fire_summon_crimson_dragon");
assert(fireDragon, "fire_summon_crimson_dragon skill must exist");
const spawnRule = (fireDragon.trigger_rules || []).flatMap((rule) => rule.effects || []).find((effect) => effect.type === "spawn_summon");
assert(spawnRule, "fire_summon_crimson_dragon must spawn a summon");
assert(spawnRule.summon_definition_id === "crimson_dragon", "fire_summon_crimson_dragon must use data-driven crimson_dragon summon definition");

console.log("[verify_summon_system_contract] PASS");
