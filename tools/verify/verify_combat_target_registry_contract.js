const fs = require("fs");
const path = require("path");

const root = process.cwd();

function read(relPath) {
  return fs.readFileSync(path.join(root, relPath), "utf8");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertNoGroupScan(relPath) {
  const source = read(relPath);
  assert(!source.includes("get_nodes_in_group(target_group)"), `${relPath} must not scan target_group directly`);
  assert(!source.includes("get_nodes_in_group(&\"enemies\")"), `${relPath} must not scan enemies directly`);
  assert(!source.includes("get_nodes_in_group(\"enemies\")"), `${relPath} must not scan enemies directly`);
}

const registryPath = "scripts/combat/combat_target_registry.gd";
assert(fs.existsSync(path.join(root, registryPath)), "CombatTargetRegistry script must exist");

const registry = read(registryPath);
[
  "class_name CombatTargetRegistry",
  "static func get_or_create",
  "func register_enemy",
  "func unregister_enemy",
  "func get_targets",
  "func get_targets_in_radius",
  "func find_nearest",
].forEach((needle) => assert(registry.includes(needle), `CombatTargetRegistry missing ${needle}`));

const enemyBase = read("scripts/enemies/enemy_base.gd");
assert(enemyBase.includes("CombatTargetRegistryScript"), "EnemyBase must preload CombatTargetRegistry");
assert(enemyBase.includes("register_enemy"), "EnemyBase must register enemies on spawn");
assert(enemyBase.includes("unregister_enemy"), "EnemyBase must unregister enemies on death/exit");

const targetingService = read("scripts/skills/targeting_service.gd");
assert(targetingService.includes("CombatTargetRegistryScript"), "TargetingService must use CombatTargetRegistry");
assertNoGroupScan("scripts/skills/targeting_service.gd");

const projectile = read("scripts/combat/projectile.gd");
assert(projectile.includes("PROJECTILE_RETARGET_INTERVAL: float = 0.1"), "Projectile retarget interval must default to 0.1s");
assert(projectile.includes("CombatTargetRegistryScript"), "Projectile must use CombatTargetRegistry");
assert(projectile.includes("_homing_retarget_timer"), "Projectile must cache homing retargets");
assertNoGroupScan("scripts/combat/projectile.gd");

const summonTargeting = read("scripts/summons/summon_targeting_component.gd");
assert(summonTargeting.includes("retarget_interval: float = 0.2"), "Summon target refresh must default to 0.2s");
assert(summonTargeting.includes("CombatTargetRegistryScript"), "Summon targeting must use CombatTargetRegistry");
assertNoGroupScan("scripts/summons/summon_targeting_component.gd");

const summonAttack = read("scripts/summons/summon_attack_component.gd");
assert(summonAttack.includes("CombatTargetRegistryScript"), "Summon attack pulse must use CombatTargetRegistry");
assertNoGroupScan("scripts/summons/summon_attack_component.gd");

const skillActionExecutor = read("scripts/skills/skill_action_executor.gd");
assert(skillActionExecutor.includes("CombatTargetRegistryScript"), "SkillActionExecutor must use CombatTargetRegistry");
assertNoGroupScan("scripts/skills/skill_action_executor.gd");

const areaEffect = read("scripts/combat/area_effect.gd");
assert(areaEffect.includes("CombatTargetRegistryScript"), "AreaEffect candidate seeding must use CombatTargetRegistry");
assert(areaEffect.includes("get_targets_in_radius"), "AreaEffect must query registry candidates by radius");

const enemyBaseNoDirect = enemyBase.replace(/for node: Node in targets:/g, "");
assert(!enemyBaseNoDirect.includes("get_nodes_in_group(&\"enemies\")"), "EnemyBase neighbor index must not scan enemies group directly");

console.log("Combat target registry contract verified.");
