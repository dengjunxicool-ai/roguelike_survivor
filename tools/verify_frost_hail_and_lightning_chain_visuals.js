const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function findAttack(id) {
  return (readJson("data/primary_attack.json").primary_attacks || []).find((attack) => attack.id === id);
}

function findAction(attack, trigger, type) {
  for (const event of attack.events || []) {
    if (event.trigger !== trigger) continue;
    for (const action of event.actions || []) {
      if (action.type === type) return action;
    }
  }
  return null;
}

function main() {
  const hailstorm = findAttack("hailstorm");
  assert(hailstorm, "hailstorm primary attack must exist");
  assert(Number(hailstorm.base?.projectile_count) === 3, "hailstorm base projectile_count must be 3");
  assert(Number(hailstorm.base?.spread_angle || 0) === 0, "hailstorm must not use angle spread for its base volley");
  const hailProjectile = findAction(hailstorm, "on_cast", "spawn_projectiles_at_targets");
  assert(hailProjectile, "hailstorm must spawn one projectile per selected target on cast");
  assert(Number(hailProjectile.params?.count) === 3, "hailstorm target projectile count must be 3");
  assert(Number(hailProjectile.params?.range) === 540, "hailstorm target selection must use attack range");
  assert(String(hailProjectile.params?.targeting_mode) === "around_player", "hailstorm must select targets around the player");
  assert(String(hailProjectile.params?.trajectory_mode) === "curve", "hailstorm projectiles must use curved trajectories");
  assert(Number(hailProjectile.params?.curve_height) > 0, "hailstorm curve trajectory must have visible arc height");
  assert(Number(hailProjectile.params?.spread_angle || 0) === 0, "hailstorm target projectiles must not use spread_angle");
  assert(JSON.stringify(hailProjectile.params?.damage_multiplier_sequence || []) === JSON.stringify([1, 0.7, 0.5]), "hailstorm projectiles must use 100%/70%/50% damage sequence");

  const actionExecutor = readText("scripts/skills/skill_action_executor.gd");
  assert(actionExecutor.includes('"spawn_projectiles_at_targets"'), "SkillActionExecutor must support multi-target projectile spawning");
  assert(actionExecutor.includes("func _spawn_projectiles_at_targets"), "SkillActionExecutor must implement the multi-target projectile action");
  assert(actionExecutor.includes("TargetingServiceScript.find_targets"), "multi-target projectile action must ask TargetingService for multiple targets");
  assert(actionExecutor.includes('"curve_target_position"'), "multi-target projectile action must pass curve target positions into projectiles");

  const projectileScript = readText("scripts/combat/projectile.gd");
  assert(projectileScript.includes("func _update_curve_trajectory"), "Projectile must implement curved trajectory movement");
  assert(projectileScript.includes("_curve_target_position"), "Projectile must store the curve target position");

  const specialHandler = readText("scripts/skills/special_damage_rule_handler.gd");
  assert(specialHandler.includes("func _spawn_lightning_chain_path_visual"), "lightning chain must have a path visual helper");
  assert(specialHandler.includes("_spawn_lightning_chain_path_visual(parent, current_origin.global_position, next_target.global_position"), "lightning chain bounce must spawn a path visual for every hop");
  assert(specialHandler.includes("Line2D.new()"), "lightning chain path visual must use Line2D");
  assert(specialHandler.includes('"LightningChainPathVisual"'), "lightning chain path visual must be named for debug inspection");

  console.log("Frost hail and lightning chain visuals verified.");
}

main();
