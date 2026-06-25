const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const skillsPath = path.join(root, "data", "skills.json");
const combatObjectsPath = path.join(root, "data", "combat_objects.json");

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function findById(items, id, label) {
  const result = (items || []).find((item) => item && item.id === id);
  assert(result, `Missing ${label} ${id}`);
  return result;
}

function findAction(skill, trigger, type) {
  for (const event of skill.events || []) {
    if (event.trigger !== trigger) continue;
    for (const action of event.actions || []) {
      if (action.type === type) return action;
    }
  }
  return null;
}

assert(fs.existsSync(skillsPath), "data/skills.json must exist");
assert(fs.existsSync(combatObjectsPath), "data/combat_objects.json must exist");

const skillsDocument = readJsonFile(skillsPath);
const combatObjectsDocument = readJsonFile(combatObjectsPath);
const skill = findById(skillsDocument.skills, "mars_spark_missile", "skill");
const projectile = findById(combatObjectsDocument.combat_objects, "mars_spark_missile_projectile", "combat object");

assert(skill.category === "active", "mars_spark_missile must be an active skill");
assert(skill.offer_in_upgrade_pool === true, "mars_spark_missile must opt into normal skill-pool learning");
assert(skill.god_id === "fire", "mars_spark_missile must belong to the fire god");
assert((skill.tags || []).includes("fire"), "mars_spark_missile must be tagged fire");
assert((skill.tags || []).includes("projectile"), "mars_spark_missile must be tagged projectile");
assert(skill.runtime_family === "projectile", "mars_spark_missile must use the projectile runtime family");

const castAction = findAction(skill, "on_cast", "spawn_projectile");
assert(castAction, "mars_spark_missile must spawn projectiles on cast");
assert(castAction.params.projectile_id === "mars_spark_missile_projectile", "mars_spark_missile must spawn mars_spark_missile_projectile");
assert(castAction.params.count === 2, "mars_spark_missile must fire two missiles per learned cast");
assert(castAction.params.homing_enabled === true, "mars_spark_missile projectile action must enable homing");
assert(Number(castAction.params.spread_angle || 0) >= 24, "mars_spark_missile must fire from visibly different launch angles");
assert(castAction.params.trajectory_mode === "curve", "mars_spark_missile must use curved projectile trajectories");
assert(Number(castAction.params.curve_height || 0) > 0, "mars_spark_missile must configure visible curve height");

const hitEvent = (skill.events || []).find((event) => event.trigger === "on_projectile_hit" && event.source_id === "mars_spark_missile_projectile");
assert(hitEvent, "mars_spark_missile must deal damage from mars_spark_missile_projectile hits");

assert(projectile.type === "projectile", "mars_spark_missile_projectile must be a projectile combat object");
assert(projectile.scene === "res://scenes/fireball_projectile.tscn", "mars_spark_missile_projectile must use the gameplay projectile scene");
assert(projectile.visual_effect_scene === "res://scenes/effects/mars_spark_missile_effect.tscn", "mars_spark_missile_projectile must attach mars_spark_missile_effect");

const dataManager = readText("scripts/core/data_manager.gd");
assert(dataManager.includes('const SKILLS_PATH: String = "res://data/skills.json"'), "DataManager must load data/skills.json");
assert(dataManager.includes("get_level_up_upgrade_definitions"), "DataManager must expose merged level-up upgrade definitions");

const gameData = readText("scripts/game/game_data.gd");
assert(gameData.includes('get_level_up_upgrade_definitions'), "GameData.get_level_up_upgrade_pool must read the merged DataManager level-up pool");
assert(gameData.includes('GOD_SKILL_LEARN_UPGRADE_PREFIX'), "GameData must synthesize god skill learn cards");
assert(gameData.includes("_make_god_skill_learn_upgrade"), "GameData must synthesize mars_spark_missile learn upgrade data");

const skillManager = readText("scripts/skills/skill_manager.gd");
assert(skillManager.includes("offer_in_upgrade_pool"), "SkillManager must allow upgrade-pool active skills");

const playerController = readText("scripts/player/player_controller.gd");
assert(playerController.includes('"learn_skill_id"'), "PlayerController must apply level-up cards that learn active skills");
assert(playerController.includes("add_skill"), "PlayerController learn-skill path must call SkillManager.add_skill");

const upgradePool = readText("scripts/upgrades/upgrade_pool.gd");
assert(upgradePool.includes('"learn_skill_id"'), "UpgradePool must filter learn-skill cards by current skill ownership");

const factory = readText("scripts/combat/combat_object_factory.gd");
assert(factory.includes('"visual_effect_scene"'), "CombatObjectFactory must merge visual_effect_scene from combat object definitions");

const projectileSource = readText("scripts/combat/projectile.gd");
assert(projectileSource.includes("homing_enabled"), "Projectile must support homing_enabled");
assert(projectileSource.includes("visual_effect_scene"), "Projectile must support visual_effect_scene");
assert(projectileSource.includes("_attach_visual_effect_scene"), "Projectile must attach configured visual effect scenes");

console.log("Mars Spark Missile skill card verified.");
