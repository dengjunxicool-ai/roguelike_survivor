const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function extractFunction(source, name) {
  const marker = `func ${name}`;
  const start = source.indexOf(marker);
  assert(start >= 0, `Missing function ${name}`);
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next >= 0 ? next : source.length);
}

const expGem = read("scripts/drops/exp_gem.gd");
const enemyBase = read("scripts/enemies/enemy_base.gd");
const cleanupService = read("scripts/enemies/timeline/enemy_cleanup_service.gd");
const runSceneCoordinator = read("scripts/game/run_scene_coordinator.gd");

const dropExperience = extractFunction(enemyBase, "_drop_experience_crystal");
const collectToPlayer = extractFunction(expGem, "collect_to_player");
const collectInternal = extractFunction(expGem, "_collect");
const collectAllCrystals = extractFunction(cleanupService, "collect_all_experience_crystals");
const clearRuntimeNodes = extractFunction(runSceneCoordinator, "clear_runtime_nodes");

assert(
  enemyBase.includes("RuntimePoolRegistry") &&
    dropExperience.includes("_spawn_experience_crystal") &&
    enemyBase.includes(".call(\"spawn\""),
  "EnemyBase._drop_experience_crystal() must spawn experience_crystal scene roots through RuntimeObjectPool."
);
assert(
  !dropExperience.includes("experience_crystal_scene.instantiate()"),
  "EnemyBase._drop_experience_crystal() must not directly instantiate experience crystal roots."
);
assert(
  expGem.includes("func prepare_for_pool_spawn") &&
    expGem.includes("func prepare_for_pool_despawn") &&
    expGem.includes("func despawn_or_free"),
  "ExpGem must expose pool spawn/despawn hooks and a despawn_or_free fallback."
);
assert(
  expGem.includes("runtime_pool_owner") && expGem.includes("runtime_pool_key"),
  "ExpGem must use runtime pool metadata when returning to the pool."
);
assert(
  collectInternal.includes("despawn_or_free()") && !collectInternal.includes("queue_free()"),
  "ExpGem collection must despawn_or_free() instead of queue_free()."
);
assert(
  collectToPlayer.includes("_collect"),
  "ExpGem.collect_to_player() must keep awarding experience through the existing _collect path."
);
for (const token of [
  "_is_collected = false",
  "target =",
  "set_deferred(\"monitoring\", true)",
  "set_deferred(\"monitorable\", true)",
  "disabled\", false",
]) {
  assert(expGem.includes(token), `ExpGem pool spawn reset must include ${token}.`);
}
assert(
  collectAllCrystals.includes("collect_to_player") && !collectAllCrystals.includes("crystal.queue_free()"),
  "EnemyCleanupService.collect_all_experience_crystals() must collect via ExpGem and avoid direct crystal queue_free()."
);
assert(
  clearRuntimeNodes.includes("despawn_or_free") &&
    clearRuntimeNodes.includes("experience_crystal") &&
    !clearRuntimeNodes.includes("node.queue_free()"),
  "RunSceneCoordinator.clear_runtime_nodes() must despawn active pickups instead of queue_free() during run transitions."
);

console.log("[verify_pr4_pickup_pool_contract] PASS");
