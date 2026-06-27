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

const skillsDocument = readJson("data/skills/skills.json");
const skills = Array.isArray(skillsDocument.skills) ? skillsDocument.skills : [];
const summonsDocument = readJson("data/summons.json");
const summons = Array.isArray(summonsDocument.summons) ? summonsDocument.summons : [];
const vortex = firstEffect(findSkill(skills, "fire_cast_scorching_vortex"), "spawn_area");
assert(vortex, "fire_cast_scorching_vortex must spawn an area");
assert(vortex.position_mode === "caster", "scorching vortex must spawn from the player/caster instead of the enemy target");
assert(vortex.move_direction === "towards_target", "scorching vortex must drift toward the target direction");
assert(Number(vortex.move_speed) > 0, "scorching vortex must define a positive drift speed");
assert(
  [...(vortex.effects_on_tick || []), ...(vortex.actions_on_tick || [])].every((action) => !action || action.type !== "pull"),
  "scorching vortex must blow outward and not pull enemies back toward the player"
);

const dragonSummon = firstEffect(findSkill(skills, "fire_summon_crimson_dragon"), "spawn_summon");
assert(dragonSummon, "fire_summon_crimson_dragon must spawn a summon");
assert(dragonSummon.summon_definition_id === "crimson_dragon", "fire_summon_crimson_dragon must use the crimson_dragon summon definition");
const dragonDefinition = summons.find((summon) => summon && summon.id === "crimson_dragon");
assert(dragonDefinition, "crimson_dragon summon definition must exist");
assert(dragonDefinition.visual.texture === "res://assets/effect/crimson_dragon.png", "crimson dragon must use the generated project dragon effect asset");
assert(!String(dragonDefinition.visual.texture || "").includes("codex-clipboard"), "crimson dragon must not reference the pasted source image");
assert(fs.existsSync(path.join(root, "assets", "effect", "crimson_dragon.png")), "generated crimson dragon effect asset must exist");

const executor = read("scripts/skills/skill_action_executor.gd");
assert(executor.includes("SummonManager"), "SkillActionExecutor must route configured summons through SummonManager");
assert(executor.includes("summon_definition_id"), "SkillActionExecutor must read summon_definition_id");

console.log("[verify_fire_vortex_dragon_contract] PASS");
