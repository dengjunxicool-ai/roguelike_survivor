const fs = require("fs");
const path = require("path");
const { readJsonFile, readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function findSkill(skills, id) {
  const skill = skills.find((entry) => entry && entry.id === id);
  assert(skill, `${id} must exist`);
  return skill;
}

function firstEffect(skill, type) {
  for (const rule of skill.trigger_rules || []) {
    for (const effect of rule.effects || []) {
      if (effect && effect.type === type) {
        return effect;
      }
    }
  }
  return null;
}

const skills = readJson("data/skills.json").skills || [];
const combatObjects = readJson("data/combat_objects.json").combat_objects || [];
const summons = readJson("data/summons.json").summons || [];

const dragonSummon = firstEffect(findSkill(skills, "fire_summon_crimson_dragon"), "spawn_summon");
assert(dragonSummon.summon_definition_id === "crimson_dragon", "crimson dragon must use the data-driven Summon system");
const dragonDefinition = summons.find((summon) => summon && summon.id === "crimson_dragon");
assert(dragonDefinition, "crimson dragon summon definition must exist");
assert(Number(dragonDefinition.attack.attack_range) >= 336, "crimson dragon attack range must cover the configured 4R breath range");
assert(Number(dragonDefinition.movement.follow_distance) > 0, "crimson dragon must define a follow distance near the player");

const vortexObject = combatObjects.find((object) => object && object.id === "scorching_vortex");
assert(vortexObject, "scorching_vortex combat object must exist");
assert(vortexObject.scene === "res://scenes/scorching_vortex_area.tscn", "scorching_vortex must use the specialized scene");
assert(fs.existsSync(path.join(root, "scripts", "summons", "summon_controller.gd")), "SummonController script file must exist");
assert(fs.existsSync(path.join(root, "scripts", "summons", "summon_manager.gd")), "SummonManager script file must exist");
assert(fs.existsSync(path.join(root, "scripts", "combat", "scorching_vortex_area.gd")), "ScorchingVortexArea script file must exist");
assert(fs.existsSync(path.join(root, "scenes", "scorching_vortex_area.tscn")), "ScorchingVortexArea scene file must exist");

console.log("[verify_fire_specialized_scripts_contract] PASS");
