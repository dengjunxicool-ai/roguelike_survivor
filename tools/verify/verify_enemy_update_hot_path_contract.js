const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..", "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function extractFunction(source, name) {
  const marker = `func ${name}`;
  const start = source.indexOf(marker);
  assert(start >= 0, `Missing function ${name}`);
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next >= 0 ? next : source.length);
}

const enemyBase = read("scripts/enemies/enemy_base.gd");
const enemyBehavior = read("scripts/enemies/behaviors/enemy_behavior.gd");
const profiler = read("scripts/debug/real_full_run_profiler.gd");

for (const section of [
  "enemy_movement",
  "enemy_ai_update",
  "enemy_attack_update",
  "enemy_animation_update",
  "enemy_status_visual_update",
]) {
  assert(profiler.includes(`"${section}"`), `RealFullRunProfiler must include ${section}.`);
  assert(enemyBase.includes(`&"${section}"`), `EnemyBase must record ${section}.`);
}

assert(enemyBase.includes("ENEMY_NEIGHBOR_CHECK_INTERVAL: float = 0.1"), "Enemy neighbor check interval must default to 0.1s.");
assert(enemyBase.includes("MAX_ENEMY_NEIGHBOR_CHECKS_PER_FRAME"), "EnemyBase must cap neighbor checks per frame.");
assert(enemyBase.includes("_neighbor_check_timer"), "EnemyBase must keep a per-enemy neighbor timer.");
assert(enemyBase.includes("_reset_neighbor_check_timer"), "EnemyBase must stagger neighbor checks after each run.");
assert(enemyBase.includes("_try_consume_neighbor_check_budget"), "EnemyBase must enforce a shared per-frame neighbor budget.");
assert(enemyBase.includes("_should_run_neighbor_check"), "EnemyBase must gate neighbor checks through a low-frequency scheduler.");
assert(enemyBase.includes("MAX_NEARBY_ENEMY_CANDIDATES"), "EnemyBase must cap nearby enemy candidates.");

const nearbyEnemies = extractFunction(enemyBase, "_nearby_enemies");
assert(nearbyEnemies.includes("max_results"), "_nearby_enemies must accept max_results.");
assert(nearbyEnemies.includes("result.size() >= max_results"), "_nearby_enemies must stop after max_results.");

const limitActorMotion = extractFunction(enemyBase, "_limit_actor_motion");
assert(limitActorMotion.includes("MAX_NEARBY_ENEMY_CANDIDATES"), "Motion limit must cap nearby enemies.");

const separationDirection = extractFunction(enemyBehavior, "_get_separation_direction");
assert(separationDirection.includes("max_neighbors"), "Enemy separation should request a capped neighbor list.");

assert(enemyBase.includes("_is_offscreen_for_visual_update"), "EnemyBase must detect offscreen enemies for visual throttling.");
assert(enemyBase.includes("VISUAL_UPDATE_OFFSCREEN_INTERVAL"), "EnemyBase must use a longer offscreen visual interval.");

console.log("[verify_enemy_update_hot_path_contract] PASS");
